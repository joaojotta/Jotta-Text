#!/usr/bin/env python3
"""Locate excluded font/C++ libraries and dynamically loaded SDL3 runtimes."""
from pathlib import Path
import re
import subprocess
import sys
dependencies = {}
for binary in sys.argv[1:]:
    result=subprocess.run(['ldd',binary],capture_output=True,text=True,check=True)
    if 'not found' in result.stdout:
        raise SystemExit(f'Missing native dependency for {binary}:\n{result.stdout}')
    dependencies.update(re.findall(r'(\S+)\s+=>\s+(/\S+)',result.stdout))
for name,location in sorted(dependencies.items()):
    # Preserve the SONAME basename: linuxdeploy copies explicit libraries under
    # the supplied name, so resolving a symlink would break runtime lookup.
    if name.startswith(('libharfbuzz','libfreetype','libfontconfig','libstdc++','libgcc_s')):
        print(location)
    if name.startswith('libSDL2') and b'libSDL3.so' in Path(location).read_bytes():
        candidates=[Path(location).parent/'libSDL3.so.0']
        try:
            lookup=subprocess.run(['ldconfig','-p'],capture_output=True,text=True,check=True).stdout
            candidates += [Path(value) for value in re.findall(r'libSDL3\.so\.0\s+[^\n]*=>\s*(/\S+)',lookup)]
        except (FileNotFoundError,subprocess.CalledProcessError):pass
        library=next((value.absolute() for value in candidates if value.is_file()),None)
        if library is None:raise SystemExit('SDL2-compat requires SDL3, but libSDL3.so.0 could not be located.')
        print(library)
