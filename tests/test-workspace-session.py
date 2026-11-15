#!/usr/bin/env python3
"""Check folder/explorer recovery, explicit launch arguments and missing folders."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parent.parent
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--flatpak-build',type=Path)
options=parser.parse_args()
build=options.flatpak_build.resolve() if options.flatpak_build else None
source=build/'files' if build else ROOT/'dist/native'
with tempfile.TemporaryDirectory(prefix='jotta-text-workspace-') as directory:
    temp=Path(directory);app=temp/'app';data=app/'share/lite-xl'
    shutil.copytree(source/'share/lite-xl',data,symlinks=True)
    (app/'bin').mkdir(parents=True);shutil.copy2(source/'bin/lite-xl',app/'bin/lite-xl')
    user=temp/'user';user.mkdir()
    root=temp/'folders';root.mkdir()
    for name in ['first','second','third']:(root/name).mkdir()
    (root/'first/nested').mkdir();(root/'first/nested/note.txt').write_text('Nested note\n')
    (root/'third/standalone.txt').write_text('Original file\n')
    (user/'session.lua').write_text('return {recents={'+json.dumps(str(root/'third'))+'}}')
    init=data/'litefront/init.lua'
    init.write_text(init.read_text()+r'''
local core=require 'core'
core.add_thread(function()
 coroutine.yield(0.3)
 local ok,err=pcall(function()
'''+(ROOT/'tests/workspace-session.lua').read_text()+r'''
 end)
 local out=assert(io.open(USERDIR..'/result','w'));out:write(ok and 'PASS' or tostring(err));out:close();core.quit()
end)
''')
    for phase in ['1','2','3','4','5']:
        args=[str(root/'third/standalone.txt')] if phase=='3' else [str(root/'third')] if phase=='4' else []
        if phase=='5':shutil.rmtree(root/'third')
        env=dict(os.environ,SDL_VIDEODRIVER='dummy',LITE_USERDIR=str(user),WORKSPACE_ROOT=str(root),WORKSPACE_PHASE=phase)
        invocation=[str(app/'bin/lite-xl'),*args]
        if build:
            invocation=['flatpak','build','--runtime','--readonly',f'--filesystem={temp}',f'--bind-mount=/app={app}',
                *[f'--env={key}={env[key]}' for key in ['SDL_VIDEODRIVER','LITE_USERDIR','WORKSPACE_ROOT','WORKSPACE_PHASE']],str(build),'/app/bin/lite-xl',*args]
        (user/'result').unlink(missing_ok=True)
        result=subprocess.run(invocation,cwd=root,env=env,capture_output=True,text=True,timeout=15)
        assert result.returncode==0,(result.stdout,result.stderr)
        assert (user/'result').read_text()=='PASS',(phase,(user/'result').read_text())
        if phase=='3':assert (root/'third/standalone.txt').read_text()=='Saved safely Original file\n'
    print('PASS: multiple folders, explorer state, unsaved tabs, explicit launch priority, standalone saves and missing folders across launches')
