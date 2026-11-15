-- mod-version:3
local core=require 'core'
local command=require 'core.command'
local outline=require 'litefront.outline'
local explorer=require 'plugins.litefront_explorer'
command.add(nil,{['litefront:document-outline']=outline.show})
command.add(function() return explorer.mode=='outline' and explorer.visible end,{
  ['litefront:refresh-outline']=outline.refresh,
})
require('core.keymap').add{['ctrl+alt+o']='litefront:document-outline',['f5']='litefront:refresh-outline'}
local event=core.on_event
function core.on_event(kind,...)
  if explorer.mode=='outline' and explorer.visible and core.active_view==explorer then
    if kind=='textinput' then outline.input(...);return true end
    if kind=='keypressed' then
      local key=...
      if not (key:find('ctrl') or key:find('shift') or key:find('alt') or key=='lgui' or key=='rgui') and outline.key(key) then return true end
    end
  end
  return event(kind,...)
end
local quit=core.on_quit_project
function core.on_quit_project(...) outline.stop();return quit(...) end
return outline
