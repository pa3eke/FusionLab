#!/usr/bin/env python3
"""Create an immutable local build input, unaffected by FileProvider metadata."""
import hashlib
import os
from pathlib import Path
import shutil
import sys
import tempfile

project, cache = map(Path, sys.argv[1:3])
files = [project / 'Package.swift'] + sorted(p for p in (project / 'Sources').rglob('*') if p.is_file() and p.name != '.DS_Store')
entries = [(str(p.relative_to(project)), p.read_bytes()) for p in files]
hash_value = hashlib.sha256()
for name, data in entries:
    hash_value.update(name.encode() + b'\0' + str(len(data)).encode() + b'\0' + data)
target = cache / ('Project-' + hash_value.hexdigest()[:20])
if not target.exists():
    staging = Path(tempfile.mkdtemp(prefix='Project-staging-', dir=cache))
    try:
        for name, data in entries:
            dest = staging / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(data)
        try:
            os.rename(staging, target)
        except FileExistsError:
            pass
    finally:
        if staging.exists():
            shutil.rmtree(staging)
print(target)
