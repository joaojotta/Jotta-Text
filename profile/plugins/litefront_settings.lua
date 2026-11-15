-- mod-version:3
local core=require 'core'
local command=require 'core.command'
local RootView=require 'core.rootview'
local settings=require 'litefront.settings'
local update=RootView.update
function RootView:update(...) update(self,...);settings.update() end
local draw=RootView.draw
function RootView:draw(...) draw(self,...);settings.draw() end
local event=core.on_event
function core.on_event(kind,...)
  if kind=='mousereleased' and settings.suppress_release then
    settings.suppress_release=nil;if settings.active then settings.active.drag=nil end;event(kind,...);return true
  end
  local s=settings.active
  if not s or s.suspended or require('litefront.dialogs').active then return event(kind,...) end
  if kind=='mousepressed' then settings.suppress_release=true;settings.click(...);return true
  elseif kind=='mousemoved' then settings.move(...);return true
  elseif kind=='mousereleased' then s.drag=nil;event(kind,...);return true
  elseif kind=='mousewheel' then
    local dy=...;settings.wheel(dy);return true
  elseif kind=='textinput' then settings.input(...);return true
  elseif kind=='keypressed' then
    local key=...;if key:find('ctrl') or key:find('shift') or key:find('alt') or key=='lgui' or key=='rgui' then return event(kind,...) end
    settings.key(key);return true
  elseif kind=='textediting' or kind=='filedropped' then return true end
  return event(kind,...)
end
command.add(nil,{['litefront:settings']=settings.open})
require('core.keymap').add{['ctrl+,']='litefront:settings'}
return settings
