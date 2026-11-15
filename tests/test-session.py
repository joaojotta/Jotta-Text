#!/usr/bin/env python3
"""Exercise saved/dirty/untitled recovery across real editor processes."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='jotta-text-session-') as directory:
    temp=Path(directory)
    data=temp/'share/lite-xl'
    shutil.copytree(ROOT/'dist/native/share/lite-xl',data,symlinks=True)
    (temp/'bin').mkdir()
    shutil.copy2(ROOT/'dist/native/bin/lite-xl',temp/'bin/lite-xl')
    user=temp/'user';user.mkdir()
    (user/'saved.md').write_text('# Saved\n')
    (user/'dirty.md').write_text('Disk version\n')
    init=data/'litefront/init.lua'
    init.write_text(init.read_text()+r'''
local core=require 'core'
core.add_thread(function()
 coroutine.yield(0.2)
 local ok,err=pcall(function()
  local phase=os.getenv('SESSION_PHASE')
  if phase=='1' then
   core.root_view:open_doc(core.open_doc(USERDIR..'/saved.md'))
   local dirty=core.open_doc(USERDIR..'/dirty.md');core.root_view:open_doc(dirty)
   dirty:text_input('Unsaved ')
   local untitled=core.open_doc();core.root_view:open_doc(untitled)
   require('plugins.litefront_workspace').set_language(untitled,require('core.syntax').get('note.md'))
   untitled:text_input('# Untitled recovery')
   untitled:set_selection(1,5)
   local visual=require 'litefront.visual'
   visual.syntax_theme='nord';visual.mode='dark';visual.icon_palette='material';visual.save_appearance()
  elseif phase=='2' then
   local visual=require 'litefront.visual'
   assert(visual.syntax_theme=='nord' and visual.icon_palette=='material','theme choices did not survive restart')
   assert(require('core.style').background[1]==0x2e,'saved workbench colors were not applied')
   assert(#core.docs==3,'wrong restored document count: '..#core.docs)
   local found={}
   for _,doc in ipairs(core.docs) do
    found[doc.abs_filename or 'untitled']=doc
   end
   assert(table.concat(found[USERDIR..'/saved.md'].lines)=='# Saved\n')
   assert(not found[USERDIR..'/saved.md']:is_dirty())
   assert(table.concat(found[USERDIR..'/dirty.md'].lines)=='Unsaved Disk version\n')
   assert(found[USERDIR..'/dirty.md']:is_dirty())
   local doc=found.untitled
   assert(table.concat(doc.lines)=='# Untitled recovery\n' and doc:is_dirty())
   assert(doc.syntax.name=='Markdown' and not doc.filename)
   assert(core.active_view.doc==doc)
   local _,col=doc:get_selection();assert(col==5)
   core.root_view:close_all_docviews()
  else
   assert(#core.docs==0,'closed documents reopened')
  end
 end)
 local out=assert(io.open(USERDIR..'/result','w'));out:write(ok and 'PASS' or tostring(err));out:close()
 core.quit()
end)
''')
    for phase in ['1','2','3']:
        result=subprocess.run([str(temp/'bin/lite-xl')],env=dict(os.environ,SDL_VIDEODRIVER='dummy',LITE_USERDIR=str(user),SESSION_PHASE=phase),capture_output=True,text=True,timeout=10)
        assert result.returncode==0,(result.returncode,result.stderr,result.stdout)
        assert (user/'result').read_text()=='PASS',(user/'result').read_text()
        assert (user/'dirty.md').read_text()=='Disk version\n'
    print('PASS: saved files, unsaved edits, untitled Markdown, selection, active tab and closed tabs across launches')
