-- mod-version:3
-- Jotta Text prototype commands and a small Markdown toolbar.
local core = require 'core'
local command = require 'core.command'
local keymap = require 'core.keymap'
local style = require 'core.style'
local DocView = require 'core.docview'
local config = require 'core.config'
local visual = require 'litefront.visual'

local function is_markdown(view)
  return view and view.doc and view.doc.syntax and view.doc.syntax.name=='Markdown'
end

local function theme(name)
  require('litefront.visual').syntax_theme='auto'
  require('litefront.visual').ui_theme='auto'
  core.reload_module('colors.litefront_' .. name)
  require('litefront.visual').save_appearance()
  core.redraw = true
  core.log('Jotta Text theme: %s', name)
end

local function wrap_md(before, after, placeholder)
  local view = visual.document_view()
  if not is_markdown(view) then return end
  local doc = view.doc
  if doc:has_any_selection() then
    -- One replacement at a time ensures different multi-caret selections are preserved.
    for idx, line1, col1, line2, col2 in doc:get_selections(true, true) do
      if line1 ~= line2 or col1 ~= col2 then
        doc:replace_cursor(idx, line1, col1, line2, col2, function(old)
          return before .. old .. after
        end)
      end
    end
  else
    doc:text_input(before .. (placeholder or '') .. after)
  end
  core.redraw = true
end

local markdown_actions = require('litefront.markdown').actions(wrap_md)

local H = 34
local function button_rects(view)
  local result={}
  local left=view.position.x+4*SCALE
  local x,y=left,view.position.y+4*SCALE
  local right=view.position.x+view.size.x-4*SCALE
  for _,item in ipairs(markdown_actions) do
    local w=(item.width or 28)*SCALE
    if x+w>right and x>left then x=left;y=y+H*SCALE end
    result[#result+1]={item=item,x=x,y=y,w=math.min(w,math.max(1,right-left)),h=H*SCALE-8*SCALE}
    x=x+w+2*SCALE
  end
  return result,y-view.position.y+H*SCALE-4*SCALE
end
local function toolbar_height(view)
  local _,h=button_rects(view)
  return h
end

local original_offset = DocView.get_content_offset
local original_bounds = DocView.get_content_bounds
local original_draw = DocView.draw
local original_press = DocView.on_mouse_pressed
local original_scroll_size = DocView.get_scrollable_size

function DocView:get_content_offset()
  local x,y=original_offset(self)
  if is_markdown(self) then y=y+toolbar_height(self) end
  return x,y
end
function DocView:get_content_bounds()
  local x,y,x2,y2=original_bounds(self)
  if is_markdown(self) then y2=y2-toolbar_height(self) end
  return x,y,x2,y2
end
function DocView:get_scrollable_size()
  local sz=original_scroll_size(self)
  return is_markdown(self) and sz+toolbar_height(self) or sz
end

function DocView:draw()
  original_draw(self)
  if not is_markdown(self) then return end
  renderer.draw_rect(self.position.x,self.position.y,self.size.x,toolbar_height(self),style.background2 or style.background)
  for _,b in ipairs(button_rects(self)) do
    if self.litefront_md_hover==b.item.name then visual.rounded(b.x,b.y,b.w,b.h,4*SCALE,style.hover_background) end
    if b.item.icon then
      visual.icon(b.item.icon,b.x+(b.w-16*SCALE)/2,b.y+5*SCALE,16*SCALE,style.dim)
    else
      require('core.common').draw_text(style.label_font,style.dim,b.item.glyph or b.item.label,'center',b.x,b.y,b.w,b.h)
    end
  end
end
function DocView:on_mouse_pressed(button,x,y,clicks)
  if button=='left' and is_markdown(self) and y>=self.position.y and y<self.position.y+toolbar_height(self) then
    for _,b in ipairs(button_rects(self)) do
      if x>=b.x and x<=b.x+b.w and y>=b.y and y<=b.y+b.h then
        core.set_active_view(self)
        command.perform(b.item.name)
        return true
      end
    end
    return true
  end
  return original_press(self,button,x,y,clicks)
end

local original_move=DocView.on_mouse_moved
function DocView:on_mouse_moved(x,y,...)
  if is_markdown(self) and y>=self.position.y and y<self.position.y+toolbar_height(self) then
    local hovered
    for _,b in ipairs(button_rects(self)) do
      if x>=b.x and x<b.x+b.w and y>=b.y and y<b.y+b.h then
        hovered=b.item.name
        core.status_view:show_tooltip({style.text,b.item.tooltip or b.item.label})
        break
      end
    end
    if self.litefront_md_hover~=hovered then self.litefront_md_hover=hovered;core.redraw=true end
    self.cursor=hovered and 'hand' or 'arrow'
    return
  end
  if self.litefront_md_hover then self.litefront_md_hover=nil;core.status_view:remove_tooltip();core.redraw=true end
  return original_move(self,x,y,...)
end

-- Preview buffers stay in memory and reach the server through its private stdin.
local web_preview=require 'litefront.web_preview'
local quit=core.on_quit_project
function core.on_quit_project(...)
  web_preview.stop()
  return quit(...)
end

local map={
  ['litefront:open-web-preview']=web_preview.open,
  ['litefront:theme-dark']=function() theme('dark') end,
  ['litefront:theme-light']=function() theme('light') end,
}
for _,a in ipairs(markdown_actions) do map[a.name]=a.fn end
command.add(nil,map)
keymap.add {
  ['ctrl+alt+1']='litefront:theme-dark',
  ['ctrl+alt+2']='litefront:theme-light',
  ['ctrl+alt+m']='litefront:md-preview',
  ['ctrl+alt+b']='litefront:md-bold',
  ['ctrl+alt+p']='litefront:open-web-preview',
}
