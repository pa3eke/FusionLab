#!/usr/bin/env python3
"""Prepare the local MD380 runtime. Firmware is never added to the repository."""
from pathlib import Path
import hashlib, shutil, subprocess, sys, tempfile, urllib.request

destination=Path.home()/'Library/Application Support/FusionLab/MD380'
destination.mkdir(parents=True,exist_ok=True)
expected={
 'md380fw.img':'c0351f250a834660641bca3b06be931c80cc1ed0ef808356c550b99cd0f4c632',
 'md380ram.img':'d40398183e9aa8db6288a62d9a0e0c233cb143ef5633680abd829cc03c719f66',
}
for name,digest in expected.items():
 path=destination/name
 if path.exists() and hashlib.sha256(path.read_bytes()).hexdigest()==digest:continue
 with urllib.request.urlopen('https://www.dudetronics.com/radio/'+name,timeout=30) as response:data=response.read(2_000_000)
 if hashlib.sha256(data).hexdigest()!=digest:raise SystemExit('Unexpected firmware checksum: '+name)
 temporary=path.with_suffix('.download');temporary.write_bytes(data);temporary.replace(path)
with tempfile.TemporaryDirectory(prefix='FusionLab-Unicorn-') as temporary:
 env=Path(temporary)/'venv'
 subprocess.run([sys.executable,'-m','venv',str(env)],check=True)
 subprocess.run([str(env/'bin/python'),'-m','pip','install','--disable-pip-version-check','unicorn==2.1.4'],check=True)
 package=Path(subprocess.check_output([str(env/'bin/python'),'-c','import unicorn,pathlib;print(pathlib.Path(unicorn.__file__).parent)'],text=True).strip())
 shutil.copy2(package/'lib/libunicorn.2.dylib',destination/'libunicorn.2.dylib')
print('MD380 runtime ready:',destination)
