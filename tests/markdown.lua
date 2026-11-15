local core=require 'core'
local command=require 'core.command'
local syntax=require 'core.syntax'
local workspace=require 'plugins.litefront_workspace'
local doc=core.open_doc()
local editor=core.root_view:open_doc(doc)
workspace.set_language(doc,syntax.get('test.md'))
doc:text_input('# Unsaved preview\n\nLive text with `inline` code\n\n```js\nconst answer = 42;\n```\n\n- [x] Done\n\n---\n')
local revision=doc:get_change_id()
assert(command.perform('litefront:md-preview'))
local preview=core.active_view
assert(preview._is_litemark and preview.doc==doc,'unsaved Markdown was not previewed')
assert(not doc.filename and not doc.abs_filename,'preview saved an untitled document')
assert(doc:is_dirty() and doc:get_change_id()==revision,'preview changed the document')
preview.size.x=500;preview:update_layout(true)
assert(#preview.display_list.list>0,'untitled preview did not render')
-- The preview uses active theme colors and selected UI/code typography.
local style=require 'core.style'
local visual=require 'litefront.visual'
local theme=require 'litefront.markdown_theme'
local assets=theme.assets()
assert(assets.fonts.REGULAR==style.font and assets.fonts.CODE==style.code_font,'preview ignored selected fonts')
assert(assets.fonts.HEADER[1][require('plugins.litemark.mdparse').TOKENS.SPAN.NONE]:get_path():find('Rubik',1,true),'preview heading did not use UI font family')
local function contains_color(color)
  for _,item in ipairs(preview.display_list.list) do if item.color==color then return true end end
end
assert(contains_color(style.accent),'preview heading does not follow theme accent')
assert(contains_color(style.background),'preview code background does not follow editor color scheme')
assert(contains_color(style.divider),'preview rules do not follow theme dividers')
local code_font_used=false
for _,item in ipairs(preview.display_list.list) do if item.font==style.code_font then code_font_used=true end end
assert(code_font_used,'preview code did not use selected editor font')
local before=preview.display_list
command.perform('litefront:theme-light');preview:update_layout()
assert(preview.display_list~=before and contains_color(style.accent),'open preview did not refresh after switching to light mode')
visual.syntax_theme='monokai';core.reload_module('colors.litefront_dark');preview:update_layout()
assert(contains_color(style.accent),'preview did not follow imported color scheme')
-- A change with the same background must still refresh the cached draw colors.
before=preview.display_list
local accent=style.accent
style.accent={123,167,211,255};preview:update_layout()
assert(preview.display_list~=before and contains_color(style.accent),'preview cached stale accent with an unchanged background')
style.accent=accent
before=preview.display_list
local keyword=style.syntax.keyword
style.syntax.keyword={211,167,123,255};preview:update_layout()
assert(preview.display_list~=before and contains_color(style.syntax.keyword),'preview code cached stale syntax colors')
style.syntax.keyword=keyword
before=preview.display_list
local body=style.font
style.font=body:copy(body:get_size()+2*SCALE);preview:update_layout()
assert(preview.display_list~=before and theme.assets().fonts.REGULAR==style.font,'preview did not refresh after UI font changes')
style.font=body
command.perform('litefront:theme-dark');preview:update_layout()
assert(doc:get_change_id()==revision and not doc.abs_filename,'theme changes modified or saved the Markdown buffer')
core.set_active_view(editor)
doc:set_selection(3,1)
doc:text_input('Updated ')
preview:update_layout()
assert(preview._layout_ver==doc:get_change_id(),'preview did not update from buffer')
assert(command.perform('litefront:md-preview'))
assert(core.active_view==preview,'preview opened a duplicate panel')
core.set_active_view(editor)
-- Toolbar wraps within a narrow editor and reserves the matching content height.
editor.size.x=230
local _,top=editor:get_content_offset()
assert(top-editor.position.y>=68*SCALE,'narrow Markdown toolbar did not wrap')
local function replace(text)
  doc:replace_cursor(1,1,1,#doc.lines,#doc.lines[#doc.lines],function() return (text:gsub("\n$", "")) end)
end
replace('alpha\nbeta\n')
doc:set_selection(1,1,2,5)
assert(command.perform('litefront:md-task-list'))
assert(table.concat(doc.lines)=='- [ ] alpha\n- [ ] beta\n','task list did not prefix selected lines: '..string.format('%q',table.concat(doc.lines)))
replace('word\n');doc:set_selection(1,1,1,5)
coroutine.yield(require('core.config').undo_merge_timeout+0.05)
assert(command.perform('litefront:md-underline'))
assert(table.concat(doc.lines)=='<u>word</u>\n','underline did not wrap selection')
assert(command.perform('doc:undo'))
assert(table.concat(doc.lines)=='word\n','formatting was not undoable')
for _,name in ipairs({'strike','subscript','superscript','image','code-block','ordered-list','rule','table','braces','export-html','export-pdf'}) do
  assert(command.map['litefront:md-'..name],'missing Markdown action: '..name)
end
local html=require('litefront.markdown_html').document('# Title\n\n<u>under</u> <sub>2</sub> <sup>3</sup> ~~strike~~\n\n| A | B |\n| --- | --- |\n| one | two |\n\n- [x] Done\n\n```\n<script>bad()</script>\n```\n',nil,false)
for _,fragment in ipairs({'<h1>Title</h1>','<u>under</u>','<sub>2</sub>','<sup>3</sup>','<del>strike</del>','<table>','<td> one </td>','type="checkbox" disabled checked','&lt;script&gt;'}) do
  assert(html:find(fragment,1,true),'HTML export missing '..fragment)
end
assert(not html:find('<script>bad()',1,true),'HTML export executed source code')
doc:clean()
-- Exercise export commands without opening a desktop dialog or browser.
local files=require 'plugins.litefront_files'
local original_dialog=files.dialog
local output_path=USERDIR..'/markdown-export.html'
files.dialog=function(mode,initial,name,callback)
  assert(mode=='save' and name=='Untitled.html','HTML export did not request a destination')
  callback(output_path)
end
core.set_active_view(editor)
local before=table.concat(doc.lines)
assert(command.perform('litefront:md-export-html'))
files.dialog=original_dialog
local exported=assert(io.open(output_path,'r'))
assert(exported:read('*a'):find('<p>word</p>',1,true),'HTML export did not write current buffer')
exported:close()
local pdf_path=USERDIR..'/Markdown with spaces.pdf'
local calls=0
files.dialog=function(mode,initial,name,callback)
  assert(mode=='save' and name=='Untitled.pdf','PDF export did not request a PDF destination')
  calls=calls+1
  callback(pdf_path)
end
assert(command.perform('litefront:md-export-pdf'))
files.dialog=original_dialog
local pdf
for _=1,80 do
  coroutine.yield(0.05)
  local file=io.open(pdf_path,'rb')
  if file then pdf=file:read('*a');file:close();break end
end
assert(calls==1 and pdf and pdf:sub(1,5)=='%PDF-','PDF export did not create a real PDF at the chosen path')
assert(pdf:find('%%EOF',1,true),'PDF export is incomplete')
-- Cancel must neither launch a browser nor create an output.
local start=process.start
process.start=function() error('PDF export started after Cancel') end
files.dialog=function() end
assert(command.perform('litefront:md-export-pdf'))
process.start=start;files.dialog=original_dialog
assert(table.concat(doc.lines)==before and not doc.abs_filename,'export saved or changed the Markdown source')
