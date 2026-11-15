#!/usr/bin/env python3
"""Verify all imported editor and UI schemes and independent persisted selections."""
import argparse
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
with tempfile.TemporaryDirectory(prefix='jotta-text-settings-') as directory:
    temp=Path(directory);app=temp/'app';data=app/'share/lite-xl'
    shutil.copytree(source/'share/lite-xl',data,symlinks=True)
    (app/'bin').mkdir(parents=True);shutil.copy2(source/'bin/lite-xl',app/'bin/lite-xl')
    user=temp/'user';user.mkdir();project=temp/'project';project.mkdir()
    original='a { color: #abc; background: #112233; }\n'
    (project/'style.css').write_text(original);(project/'.hidden.css').write_text('body {}\n')
    init=data/'litefront/init.lua'
    init.write_text(init.read_text()+r'''
local core=require 'core'
core.add_thread(function()
 coroutine.yield(.25)
 local ok,err=pcall(function()
'''+(ROOT/'tests/themes.lua').read_text()+r'''
 end)
 local out=assert(io.open(USERDIR..'/result','w'));out:write(ok and 'PASS' or tostring(err))
 if not ok then for _,item in ipairs(core.log_items) do if item.level=='ERROR' then out:write('\n'..item.text) end end end
 out:close();core.quit()
end)
''')
    for phase in ['1','2']:
        args=[str(project)] if phase=='1' else []
        env=dict(os.environ,SDL_VIDEODRIVER='dummy',LITE_USERDIR=str(user),SETTINGS_ROOT=str(project),SETTINGS_PHASE=phase)
        invocation=[str(app/'bin/lite-xl'),*args]
        if build:
            invocation=['flatpak','build','--runtime','--readonly',f'--filesystem={temp}',f'--bind-mount=/app={app}',
                *[f'--env={key}={env[key]}' for key in ['SDL_VIDEODRIVER','LITE_USERDIR','SETTINGS_ROOT','SETTINGS_PHASE']],str(build),'/app/bin/lite-xl',*args]
        (user/'result').unlink(missing_ok=True)
        result=subprocess.run(invocation,env=env,capture_output=True,text=True,timeout=15)
        assert result.returncode==0,(result.stdout,result.stderr)
        assert (user/'result').read_text()=='PASS',(phase,(user/'result').read_text())
        assert (project/'style.css').read_text()==original,'settings saved or changed the source file'
    print('PASS: all 21 editor and 21 UI schemes, independent selections, scoped overrides and restart persistence')
