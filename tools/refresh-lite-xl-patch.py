#!/usr/bin/env python3
"""Record local engine changes so fresh CI checkouts build the patched editor."""
import hashlib
import json
from pathlib import Path
import subprocess
ROOT=Path(__file__).resolve().parent.parent
source=ROOT/'vendor/lite-xl'
def git(*arguments):return subprocess.check_output(['git','-C',str(source),*arguments])
base=git('rev-parse','HEAD').decode().strip()
expected='f1ab7de4ea1b4951b49ca5b817726a470ad43da7'
if base!=expected:raise SystemExit('Patch baseline must be the pinned Lite XL v2.1.7 revision.')
names=git('diff','--name-only','HEAD','--','.',':(exclude)resources/icons').decode().splitlines()
names=[name for name in names if not name.startswith('resources/icons/')]
new=git('ls-files','--others','--exclude-standard','--','src','data','docs','resources','meson.build','meson_options.txt').decode().splitlines()
patch=git('diff','--no-ext-diff','--full-index','HEAD','--',*names) if names else b''
records={}
for name in sorted(set(names+new)):
    path=source/name
    if not path.is_file():raise SystemExit(f'Removing engine files is not supported by this patch recorder: {name}')
    before=None
    if name in new:
        result=subprocess.run(['git','diff','--no-index','--no-ext-diff','--','/dev/null',name],cwd=source,capture_output=True)
        if result.returncode!=1:raise SystemExit(result.stderr.decode())
        patch+=result.stdout
    else:before=hashlib.sha256(git('show',f'HEAD:{name}')).hexdigest()
    records[name]={'before':before,'after':hashlib.sha256(path.read_bytes()).hexdigest()}
(ROOT/'tools/lite-xl.patch').write_bytes(patch)
(ROOT/'tools/lite-xl-files.json').write_text(json.dumps({'commit':base,'files':records},indent=2)+'\n')
print(f'Recorded {len(records)} patched engine files ({len(patch):,} bytes)')
