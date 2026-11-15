#!/usr/bin/env python3
"""Regression: opening the app/file must not recursively index cwd or recent folders."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parent.parent
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--flatpak-build',type=Path,help='Test the packaged editor in its Flatpak runtime without installing it')
options=parser.parse_args()
build=options.flatpak_build.resolve() if options.flatpak_build else None
source=build/'files' if build else ROOT/'dist/native'
with tempfile.TemporaryDirectory(prefix='litefront-startup-') as directory:
    temp=Path(directory)
    app=temp/'app'
    data=app/'share/lite-xl'
    shutil.copytree(source/'share/lite-xl',data,symlinks=True)
    (app/'bin').mkdir()
    for name in ['lite-xl','litefront-file-dialog']:shutil.copy2(source/'bin'/name,app/'bin'/name)
    project=temp/'large-project';project.mkdir()
    for i in range(80):
        folder=project/f'source-{i:03}';folder.mkdir()
        for j in range(30):(folder/f'file-{j:03}.txt').write_text('source\n')
    for name in ['node_modules','dist']:
        generated=project/name;generated.mkdir()
        for j in range(100):(generated/f'generated-{j}.txt').write_text('not source\n')
    html=project/'single.html';html.write_text('<!DOCTYPE html><html><body>Hello</body></html>')
    init=data/'litefront/init.lua'
    # Record actual directory enumeration while the real editor initializes.
    init.write_text('''local core=require 'core'
core.litefront_test_scans={}
local list_dir=system.list_dir
system.list_dir=function(path)
  core.litefront_test_scans[#core.litefront_test_scans+1]=path
  return list_dir(path)
end
core.add_thread(function()
 coroutine.yield(5)
 local out=io.open(USERDIR..'/startup-report.txt','w')
 for _,item in ipairs(core.log_items) do out:write(item.level..': '..item.text..'\\n') end
 out:close();core.quit(true)
end)
''' +init.read_text()+'\n'+(ROOT/'tests/startup.lua').read_text())
    for mode in ['welcome','file','folder']:
        user=temp/f'user-{mode}';user.mkdir()
        (user/'fonts.txt').write_text('\n\n16\n18\n')
        (user/'session.lua').write_text('return {recents={'+json.dumps(str(project))+'}}')
        args=[] if mode=='welcome' else [str(html)] if mode=='file' else [str(project)]
        env=dict(os.environ,SDL_VIDEODRIVER='dummy',LITE_USERDIR=str(user),LITEFRONT_STARTUP_CASE=mode,LITEFRONT_LARGE_ROOT=str(project))
        report=user/'startup-report.txt'
        for launch in range(2):
            # This test isolates fresh startup; remembered workspaces have their own test.
            (user/'documents.lua').unlink(missing_ok=True)
            report.unlink(missing_ok=True)
            invocation=[str(app/'bin/lite-xl'),*args]
            if build:
                invocation=['flatpak','build','--runtime','--readonly',f'--filesystem={temp}',f'--bind-mount=/app={app}',
                    *[f'--env={key}={env[key]}' for key in ['SDL_VIDEODRIVER','LITE_USERDIR','LITEFRONT_STARTUP_CASE','LITEFRONT_LARGE_ROOT']],
                    str(build),'/app/bin/lite-xl',*args]
            result=subprocess.run(invocation,cwd=project,env=env,capture_output=True,text=True,timeout=15)
            assert result.returncode==0 and report.exists(),result.stderr+result.stdout
            assert report.read_text()=='PASS\n',report.read_text()
            assert (user/'empty-workspace').is_dir()
            print('PASS:',mode,'startup',launch+1,'with a large cwd and persistent settings')
