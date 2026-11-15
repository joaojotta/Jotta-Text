#!/usr/bin/env python3
"""Exercise real npm through Node, including MSYS2-style layouts and shell paths."""
import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import json

ROOT=Path(__file__).resolve().parent.parent
spec=importlib.util.spec_from_file_location('fetch_dependencies',ROOT/'tools/fetch-dependencies.py')
fetch=importlib.util.module_from_spec(spec);spec.loader.exec_module(fetch)
command=fetch.npm_command('--version')
subprocess.run(command,check=True)
print('PASS: npm runs through its JavaScript entry point')

def check_install(project,base):
    project.mkdir()
    (project/'package.json').write_text(json.dumps({'name':'build-fixture','version':'1.0.0','private':True}))
    (project/'package-lock.json').write_text(json.dumps({'name':'build-fixture','version':'1.0.0',
        'lockfileVersion':3,'requires':True,'packages':{'':{'name':'build-fixture','version':'1.0.0'}}}))
    invocation=fetch.npm_command('ci','--prefix',str(project),'--offline','--ignore-scripts','--no-audit','--no-fund')
    env=dict(os.environ,npm_config_cache=str(base/'cache'),npm_config_userconfig=str(base/'empty-npmrc'))
    subprocess.run(invocation,env=env,cwd=project,check=True,capture_output=True,text=True)
    return invocation

with tempfile.TemporaryDirectory(prefix='Jotta npm & spaces ') as directory:
    base=Path(directory)
    check_install(base/'native project & files',base)
    print('PASS: real npm ci using the installed platform tools and a path with spaces/shell characters')

if os.name!='nt':
    real_node=Path(command[0]).resolve()
    real_npm=Path(command[1]).resolve().parent.parent
    with tempfile.TemporaryDirectory(prefix='Jotta npm & spaces ') as directory:
        base=Path(directory)
        original_path=os.environ.get('PATH','')
        try:
            for layout in ('msys2','node-windows'):
                prefix=base/layout
                binary=prefix/'bin' if layout=='msys2' else prefix
                binary.mkdir(parents=True)
                (binary/'node.exe').symlink_to(real_node)
                # Calling this shim would reproduce the Windows bootstrap bug.
                (binary/'npm').write_text('#!/bin/sh\nexit 99\n')
                (binary/'npm').chmod(0o755)
                modules=prefix/'lib/node_modules' if layout=='msys2' else prefix/'node_modules'
                modules.mkdir(parents=True);(modules/'npm').symlink_to(real_npm,target_is_directory=True)
                os.environ['PATH']=str(binary)+os.pathsep+original_path
                invocation=check_install(base/(layout+' project & files'),base)
                assert Path(invocation[0])==binary/'node.exe'
                print('PASS: real npm ci in',layout,'layout with spaces and shell characters')
        finally:os.environ['PATH']=original_path
