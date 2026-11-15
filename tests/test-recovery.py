#!/usr/bin/env python3
"""Kill an actual editor after periodic recovery, then verify unsaved buffers."""
import argparse
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time
ROOT=Path(__file__).resolve().parent.parent
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--flatpak-build',type=Path)
build=parser.parse_args().flatpak_build
build=build.resolve() if build else None
source=build/'files' if build else ROOT/'dist/native'
with tempfile.TemporaryDirectory(prefix='jotta-text-recovery-') as directory:
    temp=Path(directory);app=temp/'app';data=app/'share/lite-xl'
    shutil.copytree(source/'share/lite-xl',data,symlinks=True)
    (app/'bin').mkdir(parents=True);shutil.copy2(source/'bin/lite-xl',app/'bin/lite-xl')
    user=temp/'user';user.mkdir();saved=temp/'saved.css';saved.write_text('body {color:red;}\n')
    init=data/'litefront/init.lua'
    init.write_text(init.read_text()+r'''
local core=require 'core'
core.add_thread(function()
 coroutine.yield(.25)
 local ok,err=xpcall(function()
  if os.getenv('RECOVERY_PHASE')=='1' then
   local saved=core.open_doc(os.getenv('RECOVERY_FILE'));core.root_view:open_doc(saved)
   saved:text_input('/* SNAPSHOT_RECOVERY */\n')
   local untitled=core.open_doc();core.root_view:open_doc(untitled)
   untitled:text_input('const recovered = "UNSAVED_RECOVERY";')
   local first_id=saved:get_change_id()
   local deadline=system.get_time()+8
   while system.get_time()<deadline do
    local file=io.open(USERDIR..'/documents.lua','r')
    local text=file and file:read('*a') or '';if file then file:close() end
    if text:find('UNSAVED_RECOVERY',1,true) then break end
    coroutine.yield(.1)
   end
   saved:undo();saved:text_input('/* SNAPSHOT_RECOVERY_LATEST */\n')
   assert(saved:get_change_id()==first_id,'test did not reuse an undo revision')
  else
   local named,unnamed
   for _,doc in ipairs(core.docs) do if doc.abs_filename then named=doc else unnamed=doc end end
   assert(named and unnamed,'recovery lost open documents')
   assert(table.concat(named.lines):find('SNAPSHOT_RECOVERY_LATEST',1,true) and named:is_dirty(),'saved buffer edits were lost')
   assert(table.concat(unnamed.lines):find('UNSAVED_RECOVERY',1,true) and unnamed:is_dirty(),'untitled buffer was lost')
  end
 end,debug.traceback)
 local out=assert(io.open(USERDIR..'/result','w'));out:write(ok and 'PASS' or err);out:close()
 if os.getenv('RECOVERY_PHASE')~='1' or not ok then core.quit() end
end)
''')
    def command(phase):
        env=dict(os.environ,SDL_VIDEODRIVER='dummy',LITE_USERDIR=str(user),RECOVERY_PHASE=phase,RECOVERY_FILE=str(saved))
        invocation=[str(app/'bin/lite-xl')]
        if build:
            invocation=['flatpak','build','--runtime','--readonly',f'--filesystem={temp}',f'--bind-mount=/app={app}',
              *[f'--env={key}={env[key]}' for key in ['SDL_VIDEODRIVER','LITE_USERDIR','RECOVERY_PHASE','RECOVERY_FILE']],str(build),'/app/bin/lite-xl']
        return invocation,env
    args,env=command('1')
    child=subprocess.Popen(args,env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True)
    try:
        deadline=time.monotonic()+12
        while time.monotonic()<deadline:
            snapshot=user/'documents.lua'
            if snapshot.exists() and 'SNAPSHOT_RECOVERY_LATEST' in snapshot.read_text():break
            assert child.poll() is None,'editor exited before periodic snapshot'
            time.sleep(.1)
        else:raise AssertionError('periodic recovery snapshot not written')
        assert (user/'result').read_text()=='PASS',(user/'result').read_text()
    finally:
        if child.poll() is None:os.killpg(child.pid,signal.SIGKILL)
        child.wait(timeout=5)
    assert saved.read_text()=='body {color:red;}\n','recovery autosaved a source file'
    args,env=command('2');result=subprocess.run(args,env=env,capture_output=True,text=True,timeout=12)
    assert result.returncode==0,(result.stdout,result.stderr)
    assert (user/'result').read_text()=='PASS',(user/'result').read_text()
    assert saved.read_text()=='body {color:red;}\n','restart overwrote a source file'
    print('PASS: periodic snapshots, forced-process interruption, saved/untitled recovery and unchanged disk files')
