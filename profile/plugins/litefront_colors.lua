-- mod-version:3
-- Inline swatches and Jotta Edit's custom color editor, without source injection.
local core=require 'core'
local command=require 'core.command'
local DocView=require 'core.docview'
local RootView=require 'core.rootview'
local inline=require 'litefront.color_inline'
local picker=require 'litefront.color_picker'
local function swatch_at(view,x,y)
  if view==core.command_view or x<view.position.x or x>view.position.x+view.size.x or y<view.position.y or y>view.position.y+view.size.y then return end
  local line=view:resolve_screen_position(x,y)
  for _,hit in ipairs(inline.hits(view.doc,line)) do
    local rect=inline.rect(view,line,hit)
    if x>=rect.x-2*SCALE and x<rect.x+rect.w+2*SCALE and y>=rect.y and y<rect.y+rect.h then return hit,line end
  end
end
local pressed=DocView.on_mouse_pressed
function DocView:on_mouse_pressed(button,x,y,clicks)
  if button=='left' then
    local hit,line=swatch_at(self,x,y)
    if hit then picker.open(self,line,hit);return true end
  end
  return pressed(self,button,x,y,clicks)
end
local moved=DocView.on_mouse_moved
function DocView:on_mouse_moved(x,y,...)
  local result=moved(self,x,y,...)
  local hit=not self.mouse_selecting and swatch_at(self,x,y)
  if hit then
    self.cursor='hand';self.litefront_color_hover=true
    core.status_view:remove_tooltip()
  elseif self.litefront_color_hover then self.litefront_color_hover=nil;core.status_view:remove_tooltip() end
  return result
end
local draw=RootView.draw
function RootView:draw(...) draw(self,...);picker.draw() end
local event=core.on_event
function core.on_event(kind,...)
  if kind=='mousereleased' and picker.suppress_release then picker.suppress_release=nil;if picker.active then picker.active.drag=nil end;event(kind,...);return true end
  if not picker.active or require('litefront.dialogs').active then return event(kind,...) end
  if kind=='mousepressed' then picker.suppress_release=true;picker.click(...);return true
  elseif kind=='mousemoved' then picker.move(...);return true
  elseif kind=='mousereleased' then picker.active.drag=nil;event(kind,...);return true
  elseif kind=='mousewheel' then
    local dy=...;picker.layout();picker.active.scroll=require('litefront.colors').clamp(picker.active.scroll-dy*40*SCALE,0,picker.active.max_scroll);core.redraw=true;return true
  elseif kind=='textinput' then picker.input(...);return true
  elseif kind=='keypressed' then
    local key=...
    if key:find('ctrl') or key:find('shift') or key:find('alt') or key=='lgui' or key=='rgui' then return event(kind,...) end
    picker.key(key);return true
  elseif kind=='textediting' or kind=='filedropped' then return true end
  return event(kind,...)
end
command.add('core.docview',{['litefront:edit-color']=picker.at_cursor})
return picker
