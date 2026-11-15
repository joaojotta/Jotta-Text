#!/usr/bin/env python3
"""Load the browser Lua profile in the real editor with a small bridge fixture."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='jotta-text-browser-profile-') as directory:
    temp=Path(directory);data=temp/'share/lite-xl';(temp/'bin').mkdir()
    shutil.copytree(ROOT/'dist/native/share/lite-xl',data,symlinks=True)
    shutil.copy2(ROOT/'dist/native/bin/lite-xl',temp/'bin/lite-xl')
    user=temp/'user';user.mkdir()
    start=data/'core/start.lua'
    start.write_text(start.read_text()+r'''
JOTTA_WEB=true
local replies,next_id={},0
package.preload.web=function() return {
 request=function(kind,payload) next_id=next_id+1;replies[next_id]='{"result":true}';return next_id end,
 poll=function(id) local result=replies[id];replies[id]=nil;return result end,
 cancel=function(id) replies[id]=nil end,
} end
process.start=function() error('Browser tried to start a native process') end
''')
    init=data/'litefront/init.lua'
    original=init.read_text()
    init.write_text(r'''
local core=require 'core'
core.add_thread(function()
 coroutine.yield(.5)
 local ok,err=xpcall(function()
  assert(not package.loaded['plugins.lsp'],'browser loaded desktop LSP')
  assert(not package.loaded['plugins.litefront_ycompletion'],'browser loaded desktop completion bridge')
  assert(package.loaded['plugins.litefront_shell'],'shared application shell missing')
  assert(package.loaded['plugins.litefront_files'].dialog==require('litefront.browser_files').dialog)
  local command=require 'core.command'
  assert(command.perform('litefront:settings'))
  local settings=require 'litefront.settings'
  for _,tab in ipairs(settings.tabs) do assert(tab[1]~='languages') end
  settings.close()
  local doc=core.open_doc();core.root_view:open_doc(doc);doc:text_input('# Browser recovery\n')
  assert(require('litefront.session').save())
  assert(require('litefront.session').save())
  for _,item in ipairs(core.log_items) do assert(item.level~='ERROR',item.text) end
 end,debug.traceback)
 local out=assert(io.open(USERDIR..'/result','w'));out:write(ok and 'PASS' or tostring(err));out:close()
 core.quit(true)
end)
'''+original)
    env=dict(os.environ,SDL_VIDEODRIVER='dummy',LITE_USERDIR=str(user))
    result=subprocess.run([str(temp/'bin/lite-xl')],env=env,capture_output=True,text=True,timeout=12)
    assert result.returncode==0 and (user/'result').is_file(),(result.stdout,result.stderr)
    assert (user/'result').read_text()=='PASS',(user/'result').read_text()
    assert 'Browser recovery' in (user/'documents.lua').read_text()
    print('PASS: shared browser UI, themes/fonts/settings, browser file adapter, recovery and no desktop processes')
