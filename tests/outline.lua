local core=require 'core'
local command=require 'core.command'
local syntax=require 'core.syntax'
local workspace=require 'plugins.litefront_workspace'
local explorer=require 'plugins.litefront_explorer'
local outline=require 'litefront.outline'
local function wait_for(fn,message)
  local deadline=system.get_time()+8
  repeat
    if fn() then return end
    coroutine.yield(.025)
  until system.get_time()>deadline
  error(message..' ['..outline.status..']')
end
local function has(name)
  for i,item in ipairs(outline.rows) do if item.name==name then return i,item end end
end
if os.getenv('SETTINGS_PHASE')=='2' then
  assert(explorer.mode=='outline' and explorer.visible,'outline panel was not restored')
  assert(core.litefront_no_project,'standalone outline opened an unrelated folder')
  wait_for(function() return has('Restored heading') end,'restored outline did not follow recovered document')
  assert(not core.active_view.doc.filename and core.active_view.doc:is_dirty(),'outline changed recovered untitled state')
  outline.stop();return
end
assert(core.litefront_no_project,'outline test unexpectedly started with a project')
local doc=core.open_doc();local view=core.root_view:open_doc(doc)
workspace.set_language(doc,syntax.get('document.md'))
doc:text_input('---\ntitle: metadata\n---\n# Overview\n## Details\n\n```text\n# Fake\n```\n# End\n')
local source=table.concat(doc.lines);local revision=doc:get_change_id()
assert(command.perform('litefront:document-outline'))
wait_for(function() return #outline.rows==3 and not outline.job end,'Markdown outline did not load')
assert(explorer.size.x>0 and explorer:has_content() and not explorer:has_project(),'outline requires an opened folder')
assert(outline.rows[2].name=='Details' and outline.rows[2].depth==1,'outline hierarchy missing')
explorer:draw()
-- The actual sidebar click reveals the heading in its original editor.
local index,item=has('Details')
local x=explorer.position.x+60*SCALE
local y=explorer.position.y+outline.header_height()+(index-.5)*explorer:row_height()-explorer.scroll.y
core.root_view:on_mouse_pressed('left',x,y,1);core.root_view:on_mouse_released('left',x,y)
assert(core.active_view==view,'outline click did not restore the editor')
local line,col=doc:get_selection();assert(line==item.line and col==item.column,'outline navigation chose wrong source position')
wait_for(function() return outline.active and outline.active.name=='Details' end,'outline did not highlight the current section')
assert(table.concat(doc.lines)==source and doc:get_change_id()==revision,'outline navigation edited the source')
-- Inline filter input and keyboard selection remain isolated from the document.
local rect=outline.filter_rect(explorer)
core.root_view:on_mouse_pressed('left',rect.x+rect.w/2,rect.y+rect.h/2,1)
core.root_view:on_mouse_released('left',rect.x+rect.w/2,rect.y+rect.h/2)
core.on_event('textinput','Details')
assert(#outline.rows==1 and outline.rows[1].name=='Details','outline filter did not restrict rows')
core.on_event('keypressed','return')
assert(core.active_view==view and table.concat(doc.lines)==source,'filtered navigation changed document text')
outline.filter='';outline.caret=1;outline.anchor=1;outline.rebuild()
-- Editing refreshes the outline without saving. Clicking before refresh is safe.
doc:set_selection(#doc.lines,#doc.lines[#doc.lines]);doc:text_input('\n# Added live')
local caret={doc:get_selection()};outline.activate(1)
local current={doc:get_selection()};assert(current[1]==caret[1] and current[2]==caret[2],'stale outline moved the caret')
wait_for(function() return has('Added live') and not outline.job end,'outline did not refresh after unsaved edits')
assert(not doc.filename and doc:is_dirty(),'outline saved the buffer')
-- Late responses for another document must never replace the visible entries.
local js=core.open_doc();core.root_view:open_doc(js);workspace.set_language(js,syntax.get('document.js'))
js:text_input('class OldRequest { method(){} }')
wait_for(function() return outline.job~=nil end,'JavaScript request did not start')
local html=core.open_doc();local html_view=core.root_view:open_doc(html)
workspace.set_language(html,syntax.get('document.html'))
html:text_input('<main id="app"><style>.card{color:red}</style><p>Hello</p></main>')
wait_for(function() return has('.card') and outline.source==html_view and not outline.job end,'outline did not switch to HTML and embedded CSS')
assert(not has('OldRequest'),'late outline response replaced the active document')
local _,css=has('.card');assert(css.depth==2,'embedded CSS hierarchy missing')
-- Switching to Explorer stops its worker, and opening Outline works without folders.
command.perform('litefront:toggle-explorer');assert(explorer.mode=='explorer' and not outline.worker,'file explorer did not replace outline')
assert(command.perform('litefront:document-outline'))
wait_for(function() return has('main#app') end,'reopening outline did not reload active document')
-- The sidebar divider remains draggable in standalone outline mode.
core.root_view.root_node:update_layout()
local edge=explorer.position.x+explorer.size.x;local dy=explorer.position.y+18*SCALE
assert(core.root_view.root_node:get_divider_overlapping_point(edge,dy),'outline sidebar is not resizable without a folder')
core.root_view:on_mouse_pressed('left',edge,dy,1)
core.root_view:on_mouse_moved(edge+30*SCALE,dy,30*SCALE,0)
core.root_view:on_mouse_released('left',edge+30*SCALE,dy)
assert(explorer.width>=260*SCALE,'outline divider did not resize')
-- An explicit Plain Text choice disables outlining rather than guessing.
workspace.set_language(html,syntax.get(nil,nil))
wait_for(function() return outline.status=='Outline is not available for this language.' end,'unsupported language state missing')
assert(#outline.rows==0,'unsupported language retained stale symbols')
local restore=core.open_doc();core.root_view:open_doc(restore);workspace.set_language(restore,syntax.get('document.md'))
restore:text_input('# Restored heading\n')
wait_for(function() return has('Restored heading') and not outline.job end,'final outline did not load')
local prefs=require 'litefront.preferences'
local original_language=prefs.values.ui_language;prefs.values.ui_language='pt-PT';prefs.apply_config()
local texts={};local draw_text=renderer.draw_text
renderer.draw_text=function(font,text,...) texts[text]=true;return draw_text(font,text,...) end
outline.draw(explorer);renderer.draw_text=draw_text
assert(texts['Estrutura do documento'],'outline header was not localized')
prefs.values.ui_language=original_language;prefs.apply_config()
outline.stop()
