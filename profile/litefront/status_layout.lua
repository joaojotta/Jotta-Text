-- Keep the theme control pinned while native status panels scroll or show messages.
local core=require 'core'
local StatusView=require 'core.statusview'
local style=require 'core.style'
local visual=require 'litefront.visual'
local T=require('litefront.i18n').t
local M={}
function M.rect(status)
  local w=math.min(32*SCALE,status.size.x)
  return {x=status.position.x+status.size.x-w,y=status.position.y,w=w,h=status.size.y}
end
local function contains(rect,x,y)
  return x>=rect.x and x<rect.x+rect.w and y>=rect.y and y<rect.y+rect.h
end
function M.attach(status,item)
  item.visible=false -- drawn in a reserved slot, outside the scrollable status panels
  local function body(self,fn,...)
    if self~=status or self.litefront_status_body then return fn(self,...) end
    local width=self.size.x;self.size.x=math.max(0,width-32*SCALE)
    self.litefront_status_body=true
    local result=table.pack(pcall(fn,self,...))
    self.litefront_status_body=nil;self.size.x=width
    if not result[1] then error(result[2],0) end
    return table.unpack(result,2,result.n)
  end
  local update=StatusView.update_active_items
  function StatusView:update_active_items(...)
    body(self,update,...)
    if self==status then item.active=self.visible end
  end
  local area=StatusView.get_item_visible_area
  function StatusView:get_item_visible_area(candidate)
    if self==status and candidate==item then local r=M.rect(self);return r.x,r.w end
    return body(self,area,candidate)
  end
  local draw=StatusView.draw
  function StatusView:draw(...)
    local hovered=self==status and self.hovered_item==item
    if hovered then self.hovered_item={} end
    body(self,draw,...)
    if hovered then self.hovered_item=item end
    if self~=status or self.size.y<=0 then return end
    local r=M.rect(self)
    renderer.draw_rect(r.x,r.y,r.w,r.h,style.background2)
    renderer.draw_rect(r.x,r.y,1,r.h,style.divider)
    if hovered then visual.rounded(r.x+3*SCALE,r.y+2*SCALE,r.w-6*SCALE,math.max(0,r.h-4*SCALE),4*SCALE,style.hover_background) end
    visual.icon('theme',r.x+(r.w-16*SCALE)/2,r.y+(r.h-16*SCALE)/2,16*SCALE,hovered and style.text or style.dim)
    item.tooltip=T('Toggle light and dark theme')
    if hovered then self:draw_item_tooltip(item) end
  end
  local pressed,released,moved=StatusView.on_mouse_pressed,StatusView.on_mouse_released,StatusView.on_mouse_moved
  function StatusView:on_mouse_pressed(button,x,y,...)
    if self==status and self.visible and button=='left' and contains(M.rect(self),x,y) then
      self.litefront_theme_pressed=true;core.set_active_view(core.last_active_view);return true
    end
    return pressed(self,button,x,y,...)
  end
  function StatusView:on_mouse_released(button,x,y,...)
    if self==status and self.litefront_theme_pressed then
      self.litefront_theme_pressed=nil
      if self.visible and button=='left' and contains(M.rect(self),x,y) then require('core.command').perform('litefront:toggle-theme') end
      return true
    end
    return released(self,button,x,y,...)
  end
  function StatusView:on_mouse_moved(x,y,...)
    if self==status and self.visible and self.dragged_panel=='' and contains(M.rect(self),x,y) then
      self.hovered_item=item;self.pointer.x,self.pointer.y=x,y;self.hovered_panel='';self.cursor='hand';core.redraw=true;return
    end
    return moved(self,x,y,...)
  end
end
return M
