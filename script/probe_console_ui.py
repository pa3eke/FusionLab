#!/usr/bin/env python3
"""Stress only the native console: no radio connection, microphone or credentials.

Optional --source accepts an already hydrated, immutable project snapshot for
before/after comparisons. This never installs or closes the user's radio app.
"""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source',type=Path)
args=parser.parse_args()
project=Path(__file__).resolve().parent.parent
cache=Path('/private/tmp')/f'FusionLab-build-{os.getuid()}'
cache.mkdir(mode=0o700,exist_ok=True)
source=args.source or Path(subprocess.check_output(['python3',str(project/'script/snapshot_sources.py'),str(project),str(cache)],text=True).strip())
common=['--package-path',str(source),'--scratch-path',str(cache)]
subprocess.run(['swift','build']+common,check=True)
bin_dir=Path(subprocess.check_output(['swift','build']+common+['--show-bin-path'],text=True).strip())
with tempfile.TemporaryDirectory(prefix='ConsoleProbe-',dir=cache) as temporary:
    executable=Path(temporary)/'ConsoleProbe'
    command=['swiftc','-parse-as-library','-o',str(executable),'-I',str(bin_dir)]
    for module in ['YSFCodec','MD380Codec']:
        command+=['-Xcc','-fmodule-map-file='+str(bin_dir/(module+'.build/module.modulemap'))]
    command+=['-Xcc','-I','-Xcc',str(source/'Sources/YSFCodec/include')]
    for folder in ['Models','Services','Views']:
        command+=list(map(str,sorted((source/'Sources/FusionLab'/folder).glob('*.swift'))))
    command+=[str(project/'script/console_performance_probe.swift')]
    for module in ['YSFCodec','MD380Codec']:
        command+=list(map(str,(bin_dir/(module+'.build')).glob('*.o')))
    command+=['-lc++']
    subprocess.run(command,check=True)
    subprocess.run([str(executable)],check=True)
