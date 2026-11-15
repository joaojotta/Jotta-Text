#!/usr/bin/env python3
"""Apply the recorded engine changes without overwriting unrecorded local edits."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
ROOT=Path(__file__).resolve().parent.parent
source=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else ROOT/'vendor/lite-xl'
manifest=json.loads((ROOT/'tools/lite-xl-files.json').read_text())
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None
if all(digest(source/name)==info['after'] for name,info in manifest['files'].items()):
    print('Verified Jotta Text engine patches')
    raise SystemExit(0)
changed=[name for name,info in manifest['files'].items() if digest(source/name)!=info['before']]
if changed:
    raise SystemExit('Engine files differ from the recorded patch: '+', '.join(changed)+
        '. Preserve intentional edits with python3 tools/refresh-lite-xl-patch.py before rebuilding.')
subprocess.run(['git','apply','--whitespace=nowarn',str(ROOT/'tools/lite-xl.patch')],cwd=source,check=True)
if not all(digest(source/name)==info['after'] for name,info in manifest['files'].items()):
    raise SystemExit('Engine patch verification failed')
print('Applied and verified Jotta Text engine patches')
