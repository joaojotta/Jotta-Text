-- Actual-editor regression checks for workspace interactions.
local core=require 'core'
local command=require 'core.command'
local syntax=require 'core.syntax'
local workspace=require 'plugins.litefront_workspace'
local node=core.root_view:get_active_node_default()
assert(node:should_show_tabs(),'single-document tab bar hidden')
local count=#node.views
local _,top,_,height=node:get_tab_rect(1)
local last=node:get_tab_rect(#node.views+1)
core.root_view:on_mouse_pressed('left',last+5,top+height/2,2)
assert(#node.views==count+1,'double click did not create a tab')
assert(core.active_view.doc and not core.active_view.doc.filename,'new tab is not an untitled document')
local doc=core.active_view.doc
local js
for _,item in ipairs(syntax.items) do if item.name=='JavaScript' then js=item end end
assert(js,'JavaScript syntax missing')
workspace.set_language(doc,js)
doc:text_input('const value=1')
doc:reset_syntax()
assert(doc.syntax==js,'explicit language lost on edit')
workspace.set_language(doc,syntax.get(nil,nil))
assert(doc.syntax.name=='Plain Text','Plain Text selection failed')
assert(command.perform('litefront:select-language'))
local state=core.command_view.state
assert(#state.suggest('JavaScript')>0,'language search does not match names')
state.submit('JavaScript',{text='JavaScript'})
assert(doc.syntax==js,'language chooser does not update syntax')
command.perform('command:escape')
workspace.set_language(doc,nil)
assert(doc.syntax.name=='JavaScript','Automatic did not detect untitled JavaScript')
-- Simulate the native dialog process without opening windows during the editor test.
local start=process.start
local response,code=core.project_dir..'/saved new.txt',0
process.start=function(args,...)
  if args[2]~='save' then return start(args,...) end
  assert(args[2]=='save','save did not request a native Save dialog')
  assert(args[4]~='','suggested filename missing')
  local read=false
  return {
    read_stdout=function() if not read then read=true; return response end end,
    read_stderr=function() return '' end,
    running=function() return false end,
    returncode=function() return code end,
  }
end
assert(command.perform('doc:save'))
coroutine.yield(0.15)
assert(doc.abs_filename==response and not doc:is_dirty(),'new-file save failed')
local file=io.open(response,'r');assert(file:read('*a')=='const value=1\n');file:close()
assert(doc.syntax.name=='JavaScript','content detection did not handle unknown saved extension')
workspace.set_language(doc,js)
local old_path=doc.abs_filename
response=core.project_dir..'/cancelled.txt';code=2
assert(command.perform('doc:save-as'))
coroutine.yield(0.15)
assert(doc.abs_filename==old_path and not io.open(response,'r'),'cancelled Save As changed the document')
response=core.project_dir..'/renamed.txt';code=0
assert(command.perform('doc:save-as'))
coroutine.yield(0.15)
assert(doc.abs_filename==response and doc.syntax==js,'Save As lost the language override')
process.start=start
local item=core.status_view:get_item('litefront:language')
assert(item,'language status-bar selector missing')
core.status_view:update()
local x,w=core.status_view:get_item_visible_area(item)
assert(w>0,'language selector has no clickable area')
core.root_view:on_mouse_pressed('left',x+w/2,core.status_view.position.y+5,1)
core.root_view:on_mouse_released('left',x+w/2,core.status_view.position.y+5)
assert(core.active_view==core.command_view and core.command_view.label=='Choose Language: ',
  'language selector did not open while a status message was visible')
command.perform('command:escape')
