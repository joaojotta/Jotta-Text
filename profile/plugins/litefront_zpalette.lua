-- mod-version:3
-- Floating Jotta-style command, quick-open, and language selectors.
-- Uses Lite XL's existing input/suggestion state, keyboard navigation, and callbacks.
local T=require('litefront.i18n').t
local core=require 'core'
local style=require 'core.style'
local Node=require 'core.node'
local RootView=require 'core.rootview'
local CommandView=require 'core.commandview'
local DocView=require 'core.docview'
local visual=require 'litefront.visual'
local cv=core.command_view
local function geometry()
  local w=math.max(1,math.min(630*SCALE,core.root_view.size.x-32*SCALE))
  local x=(core.root_view.size.x-w)/2
  local y=math.min(125*SCALE,core.root_view.size.y*.17)
  local header=cv.state.picker and 34*SCALE or 0
  local footer=cv.state.picker and 44*SCALE or 0
  local rows=math.max(1,math.min(10,math.floor((core.root_view.size.y-y-header-footer-90*SCALE)/(34*SCALE))))
  return x,y,w,rows,header,footer
end
local function list_geometry()
  local x,y,w,rows,header,footer=geometry()
  local count=cv.state.show_suggestions and math.min(rows,#cv.suggestions) or 0
  local top=y+header+56*SCALE
  local height=(count==0 and cv.state.show_suggestions and 1 or count)*34*SCALE
  local maximum=math.max(1,#cv.suggestions-count+1)
  cv.suggestions_offset=math.max(1,math.min(maximum,cv.suggestions_offset))
  local thumb=height>0 and math.min(height,math.max(24*SCALE,height*count/math.max(1,#cv.suggestions))) or 0
  return x,y,w,count,header,footer,top,height,maximum,thumb
end
local function reveal_selection()
  local _,_,_,count=list_geometry()
  if count>0 then
    cv.suggestions_offset=math.max(1,math.min(cv.suggestions_offset,cv.suggestion_idx))
    cv.suggestions_offset=math.max(cv.suggestions_offset,cv.suggestion_idx-count+1)
  end
end
local move_selection=CommandView.move_suggestion_idx
function CommandView:move_suggestion_idx(dir)
  if self==cv and self.state.picker and self.state.show_suggestions then
    self.suggestion_idx=math.max(1,math.min(#self.suggestions,self.suggestion_idx+dir))
  else move_selection(self,dir) end
  if self==cv then reveal_selection();core.redraw=true end
end
local submit=CommandView.submit
function CommandView:submit(...)
  if self.state.picker and not self.suggestions[self.suggestion_idx] then return end
  return submit(self,...)
end
local update_suggestions=CommandView.update_suggestions
function CommandView:update_suggestions(...)
  self.litefront_hover=nil;self.litefront_scroll_drag=nil
  return update_suggestions(self,...)
end
local locked_size=Node.get_locked_size
function Node:get_locked_size()
  if self.type=='leaf' and self.active_view==cv then return nil,0 end
  return locked_size(self)
end
local layout=Node.update_layout
function Node:update_layout()
  if self.type=='leaf' and self.active_view==cv then
    local x,y,w,_,header=geometry()
    cv.position.x,cv.position.y=x,y+header
    cv.size.x,cv.size.y=w,core.active_view==cv and 52*SCALE or 0
    return
  end
  return layout(self)
end
function CommandView:get_font() return style.font end
function CommandView:get_gutter_width() return 44*SCALE end
function CommandView:get_suggestion_line_height() return 34*SCALE end
-- Input fields follow the UI scheme even when the code pane uses another one.
function CommandView:draw_line_text(line,x,y)
  renderer.draw_text(self:get_font(),self.doc.lines[line]:gsub('\n$',''),x,y+self:get_line_text_y_offset(),style.text)
  return self:get_line_height()
end
function CommandView:draw_line_highlight(x,y)
  renderer.draw_rect(x,y,self.size.x,self:get_line_height(),style.input_background)
end
function CommandView:draw_line_body(line,x,y)
  self:draw_line_highlight(x+self.scroll.x,y)
  for _,l1,c1,l2,c2 in self.doc:get_selections(true) do
    if line>=l1 and line<=l2 then
      local first=line==l1 and c1 or 1;local last=line==l2 and c2 or #self.doc.lines[line]+1
      local x1=x+self:get_col_x_offset(line,first);local x2=x+self:get_col_x_offset(line,last)
      renderer.draw_rect(x1,y,x2-x1,self:get_line_height(),require('core.common').lerp(style.input_background,style.accent,.25))
    end
  end
  return self:draw_line_text(line,x,y)
end
function CommandView:draw_caret(x,y)
  renderer.draw_rect(x,y,style.caret_width,self:get_line_height(),style.accent)
end
function CommandView:draw_line_gutter()
  visual.icon('search',self.position.x+16*SCALE,self.position.y+17*SCALE,18*SCALE,style.accent)
  return self:get_line_height()
end
function CommandView:draw_background()
  renderer.draw_rect(self.position.x,self.position.y,self.size.x,self.size.y,style.background2)
end
function CommandView:draw() end -- Render once above the workbench, not in the bottom layout node.
local function draw_palette()
  if core.active_view~=cv or require('litefront.dialogs').active then return end
  local x,y,w,count,header,footer,top,list_height,maximum,thumb=list_geometry()
  cv.position.x,cv.position.y=x,y+header;cv.size.x,cv.size.y=w,52*SCALE
  local h=header+52*SCALE+list_height+8*SCALE+footer
  renderer.draw_rect(0,0,core.root_view.size.x,core.root_view.size.y,{0,0,0,105})
  visual.rounded(x-7*SCALE,y+8*SCALE,w+14*SCALE,h+12*SCALE,9*SCALE,{0,0,0,65})
  visual.rounded(x-1,y-1,w+2,h+2,7*SCALE,style.divider)
  visual.rounded(x,y,w,h,6*SCALE,style.background2)
  if header>0 then
    visual.text(style.bold_font,cv.label:gsub(': $',''),x+14*SCALE,y,w-54*SCALE,header,style.text)
    visual.icon('close',x+w-29*SCALE,y+9*SCALE,16*SCALE,style.dim)
  end
  core.push_clip_rect(x+1,y+header+1,w-2,51*SCALE)
  DocView.draw(cv)
  if cv:get_text()=='' then
    visual.text(style.font,(cv.state.picker and T('Search…') or cv.label:gsub(': $','')..'…'),x+44*SCALE,y+header,w-60*SCALE,52*SCALE,style.dim)
  end
  core.pop_clip_rect()
  renderer.draw_rect(x,y+header+52*SCALE,w,1,style.divider)
  if count>0 then
    local right=maximum>1 and 18*SCALE or 0
    core.push_clip_rect(x,top,w-right,list_height)
    for row=1,count do
      local index=cv.suggestions_offset+row-1
      local item=cv.suggestions[index]
      if item then
        local ry=top+(row-1)*34*SCALE
        if index==cv.suggestion_idx or index==cv.litefront_hover then visual.rounded(x+5*SCALE,ry,w-10*SCALE-right,32*SCALE,4*SCALE,style.hover_background) end
        local info=item.info and tostring(item.info) or ''
        local iw=math.min((w-right)*.4,style.small_font:get_width(info)+20*SCALE)
        visual.text(style.font,tostring(item.text),x+16*SCALE,ry,w-right-32*SCALE-iw,32*SCALE,index==cv.suggestion_idx and style.accent or style.text)
        if index==cv.suggestion_idx then renderer.draw_rect(x+6*SCALE,ry+5*SCALE,2*SCALE,22*SCALE,style.accent) end
        if info~='' then visual.text(style.small_font,info,x+w-right-iw-14*SCALE,ry,iw,32*SCALE,style.dim,'right') end
      end
    end
    core.pop_clip_rect()
  end
  if maximum>1 then
    local ty=top+(list_height-thumb)*(cv.suggestions_offset-1)/(maximum-1)
    visual.rounded(x+w-14*SCALE,top,8*SCALE,list_height,4*SCALE,style.background3)
    visual.rounded(x+w-14*SCALE,ty,8*SCALE,thumb,4*SCALE,style.dim)
  end
  if count==0 and cv.state.show_suggestions then
    visual.text(style.small_font,T('No matches'),x+16*SCALE,y+header+52*SCALE,w-32*SCALE,20*SCALE,style.dim)
  end
  if footer>0 then
    local fy=y+h-footer
    renderer.draw_rect(x,fy,w,1,style.divider)
    visual.rounded(x+w-190*SCALE,fy+7*SCALE,82*SCALE,30*SCALE,4*SCALE,style.hover_background)
    visual.text(style.font,T('Cancel'),x+w-190*SCALE,fy+7*SCALE,82*SCALE,30*SCALE,style.text,'center')
    if cv.state.preview then
      visual.rounded(x+12*SCALE,fy+7*SCALE,82*SCALE,30*SCALE,4*SCALE,style.hover_background)
      visual.text(style.font,T('Preview'),x+12*SCALE,fy+7*SCALE,82*SCALE,30*SCALE,style.text,'center')
    end
    local available=cv.suggestions[cv.suggestion_idx]~=nil
    visual.rounded(x+w-98*SCALE,fy+7*SCALE,84*SCALE,30*SCALE,4*SCALE,available and style.accent or style.background3)
    visual.text(style.font,T('Choose'),x+w-98*SCALE,fy+7*SCALE,84*SCALE,30*SCALE,available and style.accent_text or style.dim,'center')
  end
end
local draw,pressed,moved,released,wheel=RootView.draw,RootView.on_mouse_pressed,RootView.on_mouse_moved,RootView.on_mouse_released,RootView.on_mouse_wheel
function RootView:draw(...) draw(self,...);draw_palette() end
local function close_palette(self,submit)
  self.litefront_palette_release=true
  cv.litefront_scroll_drag=nil
  if submit then cv:submit() else cv:exit(false) end
end
function RootView:on_mouse_pressed(button,mx,my,clicks)
  if core.active_view~=cv then return pressed(self,button,mx,my,clicks) end
  local x,y,w,count,header,footer,top,height,maximum,thumb=list_geometry()
  local bottom=top+height+4*SCALE+footer
  if button=='left' then
    if mx<x or mx>x+w or my<y or my>bottom then close_palette(self,false)
    elseif header>0 and my<y+header then
      if mx>=x+w-38*SCALE then close_palette(self,false) end
    elseif footer>0 and my>=bottom-footer then
      local fy=bottom-footer
      if my>=fy+7*SCALE and my<=fy+37*SCALE then
        if cv.state.preview and mx>=x+12*SCALE and mx<=x+94*SCALE then
          local callback,item=cv.state.preview,cv.suggestions[cv.suggestion_idx]
          if item then close_palette(self,false);callback(item) end
        elseif mx>=x+w-98*SCALE and mx<=x+w-14*SCALE then
          if cv.suggestions[cv.suggestion_idx] then close_palette(self,true) end
        elseif mx>=x+w-190*SCALE and mx<=x+w-108*SCALE then close_palette(self,false) end
      end
    elseif maximum>1 and mx>=x+w-20*SCALE and my>=top and my<top+height then
      local ty=top+(height-thumb)*(cv.suggestions_offset-1)/(maximum-1)
      if my>=ty and my<=ty+thumb then cv.litefront_scroll_drag=my-ty
      else cv.suggestions_offset=math.max(1,math.min(maximum,cv.suggestions_offset+(my<ty and -count or count))) end
    elseif my>=top and my<top+height then
      local index=cv.suggestions_offset+math.floor((my-top)/(34*SCALE))
      if cv.suggestions[index] then
        cv.suggestion_idx=index
        if not cv.state.picker or clicks>=2 then close_palette(self,true) end
      end
    elseif my<y+header+52*SCALE then cv:on_mouse_pressed(button,mx,my,clicks) end
    core.redraw=true
  end
  return true
end
function RootView:on_mouse_moved(x,y,dx,dy)
  if core.active_view~=cv then return moved(self,x,y,dx,dy) end
  local px,_,w,_,_,_,top,height,maximum,thumb=list_geometry()
  if cv.litefront_scroll_drag then
    local fraction=(y-top-cv.litefront_scroll_drag)/math.max(1,height-thumb)
    cv.suggestions_offset=math.max(1,math.min(maximum,math.floor(1+fraction*(maximum-1)+.5)))
    cv.cursor='arrow'
  elseif y>=top and y<top+height and x>=px and x<px+w-20*SCALE then
    cv.litefront_hover=cv.suggestions_offset+math.floor((y-top)/(34*SCALE))
    cv.cursor='hand'
  else
    cv.litefront_hover=nil
    cv:on_mouse_moved(x,y,dx,dy)
  end
  core.redraw=true
end
function RootView:on_mouse_released(...)
  if self.litefront_language_pressed or self.litefront_palette_release then self.litefront_language_pressed=nil;self.litefront_palette_release=nil;return true end
  if core.active_view==cv then cv.litefront_scroll_drag=nil;cv:on_mouse_released(...);return true end
  return released(self,...)
end
function RootView:on_mouse_wheel(y,x)
  if core.active_view~=cv then return wheel(self,y,x) end
  local _,_,_,_,_,_,_,_,maximum=list_geometry()
  if y~=0 then cv.suggestions_offset=math.max(1,math.min(maximum,cv.suggestions_offset+(y>0 and -1 or 1)*math.max(1,math.floor(math.abs(y)*3)))) end
  cv.litefront_hover=nil
  core.redraw=true
  return true
end
