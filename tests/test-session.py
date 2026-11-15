#!/usr/bin/env python3
"""Exercise saved/dirty/untitled recovery across real editor processes."""
import os
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parent.parent
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--flatpak-build',type=Path)
build=parser.parse_args().flatpak_build
source=build.resolve()/'files' if build else ROOT/'dist/native'
with tempfile.TemporaryDirectory(prefix='jotta-text-session-') as directory:
    temp=Path(directory)
    data=temp/'share/lite-xl'
    shutil.copytree(source/'share/lite-xl',data,symlinks=True)
    (temp/'bin').mkdir()
    shutil.copy2(source/'bin/lite-xl',temp/'bin/lite-xl')
    user=temp/'user';user.mkdir()
    saved_text='# Saved\n'+('A long saved line '+('word '*70)+'\n')*120
    (user/'saved.md').write_text(saved_text)
    (user/'dirty.md').write_text('Disk version\n')
    init=data/'litefront/init.lua'
    init.write_text(init.read_text()+r'''
local core=require 'core'
core.add_thread(function()
 coroutine.yield(0.2)
 local ok,err=pcall(function()
  local phase=os.getenv('SESSION_PHASE')
  if phase=='1' then
   local saved=core.open_doc(USERDIR..'/saved.md');local saved_view=core.root_view:open_doc(saved)
   saved:set_selection(40,25)
   saved_view.scroll.x=64*SCALE;saved_view.scroll.to.x=64*SCALE
   saved_view.scroll.y=32*saved_view:get_line_height();saved_view.scroll.to.y=saved_view.scroll.y
   local dirty=core.open_doc(USERDIR..'/dirty.md');core.root_view:open_doc(dirty)
   dirty:text_input('Unsaved ')
   local untitled=core.open_doc();core.root_view:open_doc(untitled)
   require('plugins.litefront_workspace').set_language(untitled,require('core.syntax').get('note.md'))
   untitled:text_input('# Untitled recovery\n'..string.rep('Untitled line '..string.rep('word ',70)..'\n',120))
   untitled:set_selection(85,56)
   untitled:set_selections(2,93,48,92,8);untitled.last_selection=2
   local view=core.active_view
   view.scroll.x=80*SCALE;view.scroll.to.x=80*SCALE
   view.scroll.y=80*view:get_line_height();view.scroll.to.y=view.scroll.y
   view.last_line1,view.last_col1,view.last_line2,view.last_col2=untitled:get_selection()
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
   local saved=found[USERDIR..'/saved.md']
   assert(saved.lines[1]=='# Saved\n' and #saved.lines==121)
   assert(not saved:is_dirty())
   local line,col=saved:get_selection();assert(line==40 and col==25,'saved-file cursor was not restored')
   local saved_view=core.get_views_referencing_doc(saved)[1]
   assert(math.abs(saved_view.scroll.y/saved_view:get_line_height()-32)<.01,'saved-file vertical viewport was not restored')
   assert(math.abs(saved_view.scroll.x/SCALE-64)<.01,'saved-file horizontal viewport was not restored')
   assert(table.concat(found[USERDIR..'/dirty.md'].lines)=='Unsaved Disk version\n')
   assert(found[USERDIR..'/dirty.md']:is_dirty())
   local doc=found.untitled
   assert(doc.lines[1]=='# Untitled recovery\n' and #doc.lines>=121 and doc:is_dirty())
   assert(doc.syntax.name=='Markdown' and not doc.filename)
   assert(core.active_view.doc==doc)
   assert(#doc.selections==8 and doc.last_selection==2,'untitled cursors were not restored')
   local line,col,last_line,last_col=doc:get_selection()
   assert(line==93 and col==48 and last_line==92 and last_col==8,'untitled cursor/selection direction was not restored')
   local view=core.active_view
   assert(math.abs(view.scroll.y/view:get_line_height()-80)<.01,'untitled vertical viewport was not restored')
   assert(math.abs(view.scroll.x/SCALE-80)<.01,'untitled horizontal viewport was not restored')
   core.root_view:close_all_docviews()
  elseif phase=='3' then
   assert(#core.docs==0,'closed documents reopened')
  else
   assert(#core.docs==1,'older snapshot did not recover its untitled document')
   local doc=core.active_view.doc
   local line,col=doc:get_selection()
   assert(doc.lines[1]=='Legacy buffer\n' and line==1 and col==8,'older cursor snapshot was not restored')
  end
 end)
 local out=assert(io.open(USERDIR..'/result','w'));out:write(ok and 'PASS' or tostring(err));out:close()
 core.quit()
end)
''')
    for phase in ['1','2','3','4']:
        if phase=='4':
            (user/'documents.lua').write_text("return {documents={{text='Legacy buffer\\n',selection={1,8,1,8},dirty=true}},active=1}\n")
        env=dict(os.environ,SDL_VIDEODRIVER='dummy',LITE_USERDIR=str(user),SESSION_PHASE=phase)
        invocation=[str(temp/'bin/lite-xl')]
        if build:
            invocation=['flatpak','build','--runtime','--readonly',f'--filesystem={temp}',f'--bind-mount=/app={temp}',
                *[f'--env={key}={env[key]}' for key in ['SDL_VIDEODRIVER','LITE_USERDIR','SESSION_PHASE']],str(build.resolve()),'/app/bin/lite-xl']
        result=subprocess.run(invocation,env=env,capture_output=True,text=True,timeout=10)
        assert result.returncode==0,(result.returncode,result.stderr,result.stdout)
        assert (user/'result').read_text()=='PASS',(user/'result').read_text()
        assert (user/'dirty.md').read_text()=='Disk version\n'
    print('PASS: saved/unsaved/untitled recovery, multiple cursors, selection direction, horizontal/vertical viewports, active tab and closed tabs across launches')
