-- mod-version:3
-- Optional trial entry point. Loading the editor never starts Git or a network request.
if JOTTA_WEB then return end
local core=require 'core'
local command=require 'core.command'
local RootView=require 'core.rootview'
local function enabled() return require('litefront.preferences').values.github_trial end
local function view() return package.loaded['litefront.github.view'] end
command.add(enabled,{['litefront:github-trial']=function() require('litefront.github.view').open() end})
require('core.keymap').add{['ctrl+alt+g']='litefront:github-trial'}
local draw=RootView.draw
function RootView:draw(...) draw(self,...);local panel=view();if panel then panel.draw() end end
local quit=core.on_quit_project
function core.on_quit_project(...)
  local service=package.loaded['litefront.github.service'];local job=service and service.job
  if job then
    service.cancel()
    if job.sent then pcall(job.child.wait,job.child,1500) else pcall(job.child.terminate,job.child) end
  end
  return quit(...)
end
local event=core.on_event
function core.on_event(kind,...)
  local panel=view();local state=panel and panel.active
  if not state or require('litefront.dialogs').active then return event(kind,...) end
  if kind=='mousepressed' then panel.click(...);return false
  elseif kind=='mousemoved' then panel.move(...);return false
  elseif kind=='mousereleased' then state.drag=nil;return false
  elseif kind=='mousewheel' then
    local dy=...;local count=state.data and #state.data.files or 0
    state.wheel=(state.wheel or 0)+dy*3
    local steps=state.wheel>=0 and math.floor(state.wheel) or math.ceil(state.wheel);state.wheel=state.wheel-steps
    state.scroll=math.max(0,math.min(math.max(0,count-(state.visible or 1)),state.scroll-steps));core.redraw=true;return false
  elseif kind=='textinput' then panel.input(...);return false
  elseif kind=='keypressed' then
    local key=...;if key:find('ctrl') or key:find('shift') or key:find('alt') or key=='lgui' or key=='rgui' then return event(kind,...) end
    -- The editor's return value controls SDL text suppression, not propagation.
    -- This modal already owns the event; printable key presses need text input.
    panel.key(key);return false
  elseif kind=='textediting' or kind=='filedropped' then return false end
  return event(kind,...)
end
return {enabled=enabled}
