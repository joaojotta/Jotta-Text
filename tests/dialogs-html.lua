local core=require 'core'
local command=require 'core.command'
local syntax=require 'core.syntax'
local dialogs=require 'litefront.dialogs'
local workspace=require 'plugins.litefront_workspace'
for _,name in ipairs({'index.html','index.htm','INDEX.HTML','Index.HtM','index.xhtml','INDEX.XHTML'}) do
  assert(syntax.get(name).name=='HTML','HTML syntax not detected: '..name)
  local file=io.open(core.project_dir..'/'..name,'w');file:write('<!DOCTYPE html>\n<html><body>Hello</body></html>\n');file:close()
  local doc=core.open_doc(core.project_dir..'/'..name)
  assert(doc.syntax.name=='HTML','opened document was not detected as HTML: '..name)
end
local doc=core.open_doc()
core.root_view:open_doc(doc)
doc:text_input('<!DOCTYPE html>\n<html><body>Hello</body></html>')
assert(doc.syntax.name=='HTML','untitled HTML content was not detected')
workspace.set_language(doc,syntax.get(nil,nil))
assert(doc.syntax.name=='Plain Text','HTML detection overrode explicit Plain Text')
assert(command.perform('litefront:select-language'))
local choices=core.command_view.state.suggest('HTML')
local found=false
for _,name in ipairs(choices) do if name=='HTML' then found=true end end
assert(found,'HTML is missing from the language selector')
core.command_view:exit(false)
workspace.set_language(doc,nil)
assert(doc.syntax.name=='HTML','Automatic failed to detect HTML content')
-- Use the real log API and event routing. Remove only our intentional warning/error log entries.
local previous_message=core.status_view.message
local count=#core.log_items
core.warn('Test warning %s','detail')
assert(dialogs.active and dialogs.active.title=='Warning' and dialogs.active.message=='Test warning detail')
assert(core.status_view.message==previous_message,'warning was sent to the status bar')
assert(core.log_items[#core.log_items].level=='WARN','warning not retained in log')
local before=table.concat(doc.lines)
core.on_event('textinput','must not reach the editor')
assert(table.concat(doc.lines)==before,'modal allowed background typing')
core.error('Test error')
assert(#dialogs.queue==1,'error did not queue behind warning')
core.on_event('keypressed','return')
assert(dialogs.active and dialogs.active.title=='Error','queued error did not open')
core.on_event('keypressed','escape')
assert(not dialogs.active,'Escape did not dismiss the error dialog')
local answer
core.nag_view:show('Unsaved Changes','Keep this document?', {
  {text='Save',default_yes=true},{text='Discard'},{text='Cancel',default_no=true},
},function(option) answer=option.text end)
assert(dialogs.active and not core.nag_view.visible,'confirmation still uses the nag bar')
core.on_event('keypressed','escape')
coroutine.yield(0.1)
assert(answer=='Cancel','confirmation did not preserve the cancel action')
for i=#core.log_items,count+1,-1 do
  if core.log_items[i].text=='Test warning detail' or core.log_items[i].text=='Test error' then table.remove(core.log_items,i) end
end
-- About uses a dedicated branded card while retaining modal isolation.
assert(command.perform('litefront:about'))
local about=require 'litefront.about'
assert(dialogs.active and dialogs.active.about,'About did not open its dedicated card')
about.draw(dialogs.active,core.root_view)
assert(#dialogs.active.buttons==2,'About actions were not laid out')
local contents=table.concat(doc.lines)
core.on_event('textinput','blocked by About')
assert(table.concat(doc.lines)==contents,'About allowed editing behind the modal')
local copy=dialogs.active.buttons[1]
core.on_event('mousepressed','left',copy.x+copy.w/2,copy.y+copy.h/2,1)
core.on_event('mousereleased','left',copy.x+copy.w/2,copy.y+copy.h/2)
assert(dialogs.active and dialogs.active.copied,'Copy Details closed About or failed')
assert(system.get_clipboard():find('Jotta Text v'..APP_VERSION,1,true),'About did not copy version details')
local root=core.root_view;local width,height=root.size.x,root.size.y
root.size.x,root.size.y=360*SCALE,300*SCALE
about.draw(dialogs.active,root)
assert(dialogs.active.max_offset>0,'small About window did not offer scrolling')
core.on_event('mousewheel',-3,0)
assert(dialogs.active.offset>0,'About did not scroll')
about.draw(dialogs.active,root)
root.size.x,root.size.y=width,height
core.on_event('keypressed','escape')
assert(not dialogs.active,'Escape did not close About')
assert(command.perform('litefront:about'))
core.on_event('keypressed','return')
assert(not dialogs.active,'About default action did not close the window')
-- Discard only the disposable test document.
doc:clean()
