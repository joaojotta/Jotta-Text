#!/usr/bin/env python3
"""Fail early when a source checkout is incomplete or contains broken gitlinks."""
import argparse
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parent.parent
REQUIRED=(
    '.gitattributes', 'VERSION', 'tools/lite-xl.patch', 'tools/lite-xl-files.json',
    'tools/dependencies.lock.json', 'tools/github-cli.lock.json',
    'tools/github-trial.mjs', 'tools/github-setup.mjs', 'tools/lua-LICENSE.txt',
    'profile/init.lua', 'profile/litefront/session.lua',
    'profile/litefront/completion_context.lua',
    'icons/icon.svg', 'fonts/Rubik-VariableFont_wght.ttf',
    'fonts/JetBrainsMono-VariableFont_wght.ttf',
    'vendor/litefront/tooling/package.json',
    'vendor/litefront/tooling/package-lock.json',
)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=ROOT)
    root=parser.parse_args().root.resolve()
    errors=[f'Missing source file: {name}' for name in REQUIRED if not (root/name).is_file()]
    if (root/'.git').exists():
        configured=set()
        if (root/'.gitmodules').is_file():
            result=subprocess.run(['git','config','-f',str(root/'.gitmodules'),'--get-regexp',r'^submodule\..*\.path$'],capture_output=True,text=True)
            configured={line.split(None,1)[1] for line in result.stdout.splitlines() if len(line.split(None,1))==2}
        result=subprocess.run(['git','-C',str(root),'ls-files','--stage','-z'],capture_output=True,text=True,check=True)
        for entry in result.stdout.split('\0'):
            if entry.startswith('160000 '):
                name=entry.split('\t',1)[1]
                if name not in configured:errors.append(f'Unconfigured nested repository: {name}. Remove its Git index entry; keep its local files.')
    if errors:
        raise SystemExit('\n'.join(errors)+'\nCommit the complete project source before running the builds.')
    print('PASS: required source files and repository layout')

if __name__=='__main__':
    main()
