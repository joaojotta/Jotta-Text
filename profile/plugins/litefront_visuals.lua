-- mod-version:3
-- Jotta Edit-inspired workbench visuals, with only bundled Jotta Text actions.
local T=require('litefront.i18n').t
local core=require 'core'
local command=require 'core.command'
local common=require 'core.common'
local config=require 'core.config'
local style=require 'core.style'
local View=require 'core.view'
local Node=require 'core.node'
local RootView=require 'core.rootview'
local StatusView=require 'core.statusview'
local ContextMenu=require 'core.contextmenu'
local visual=require 'litefront.visual'
local Rail=View:extend()
local explorer
local function rect_contains(b,x,y) return x>=b.x and x<b.x+b.w and y>=b.y and y<b.y+b.h end
local function perform(name) if name then command.perform(name) end end

command.add(nil, {
  ['litefront:toggle-theme']=function()
    visual.syntax_theme='auto'
    perform(visual.mode=='dark' and 'litefront:theme-light' or 'litefront:theme-dark')
  end,
  ['litefront:icon-palette']=function()
    local choices=require 'litefront.icon-palette-choices'
    local labels,ids={},{}
    for _,item in ipairs(choices) do labels[#labels+1]=T(item.label);ids[T(item.label)]=item.id end
    core.command_view:enter('Explorer Icon Colors',{picker=true,typeahead=false,
      suggest=function(text) return text=='' and labels or common.fuzzy_match(labels,text) end,
      submit=function(text,item)
        local id=ids[item and item.text or text]
        if id then visual.icon_palette=id;visual.save_appearance();core.redraw=true end
      end,
    })
  end,
  ['litefront:syntax-theme']=function()
    local labels={T('Follow interface (Jotta)')}
    local choices={}
    for id,palette in pairs(visual.palettes) do choices[#choices+1]={id=id,label=palette.label} end
    table.sort(choices,function(a,b) return a.label<b.label end)
    local ids={[labels[1]]='auto'}
    for _,choice in ipairs(choices) do labels[#labels+1]=choice.label;ids[choice.label]=choice.id end
    core.command_view:enter('Color Theme',{picker=true,typeahead=false,
      suggest=function(text) return text=='' and labels or common.fuzzy_match(labels,text) end,
      submit=function(text,item)
        local id=ids[item and item.text or text]
        if id then
          visual.syntax_theme=id
          if visual.ui_theme=='auto' and visual.palettes[id] then visual.mode=visual.palettes[id].mode end
          visual.save_appearance()
          core.reload_module('colors.litefront_'..visual.mode)
          core.redraw=true
        end
      end,
    })
  end,
})

function Rail:new() Rail.super.new(self);self.size.x=36*SCALE end
function Rail:update() self.size.x=36*SCALE end
function Rail:items()
  local result={}
  for i,item in ipairs({
    {'folder',core.litefront_no_project and 'Open Folder…' or 'Toggle Explorer',core.litefront_no_project and 'core:open-project-folder' or 'litefront:toggle-explorer'},
    {'search','Search Project','project-search:find'},
    {'outline','Document outline','litefront:document-outline'},
    {'markdown-preview','Markdown Preview','litefront:md-preview'},
    {'live-preview','Web Preview','litefront:open-web-preview'},
    {'formatter','Format Document','litefront:format-prettier'},
  }) do
    result[#result+1]={x=self.position.x,y=self.position.y+8*SCALE+(i-1)*40*SCALE,w=self.size.x,h=36*SCALE,icon=item[1],label=item[2],command=item[3]}
  end
  return result
end
function Rail:draw()
  self:draw_background(style.background2)
  renderer.draw_rect(self.position.x+self.size.x-1,self.position.y,1,self.size.y,style.divider)
  for i,b in ipairs(self:items()) do
    local active=explorer.visible and ((b.command=='litefront:toggle-explorer' and explorer.mode~='outline') or (b.command=='litefront:document-outline' and explorer.mode=='outline'))
    if self.hovered==i or active then
      visual.rounded(b.x+3*SCALE,b.y+3*SCALE,b.w-6*SCALE,b.h-6*SCALE,4*SCALE,style.hover_background)
      renderer.draw_rect(b.x,b.y+8*SCALE,2*SCALE,b.h-16*SCALE,style.accent)
    end
    visual.icon(b.icon,b.x+(b.w-19*SCALE)/2,b.y+(b.h-19*SCALE)/2,19*SCALE,self.hovered==i and style.text or style.dim)
  end
end
function Rail:on_mouse_pressed(button,x,y)
  if core.last_active_view then core.set_active_view(core.last_active_view) end
  if button~='left' then return true end
  for _,b in ipairs(self:items()) do if rect_contains(b,x,y) then perform(b.command);break end end
  return true
end
function Rail:on_mouse_moved(x,y)
  local hovered
  for i,b in ipairs(self:items()) do
    if rect_contains(b,x,y) then hovered=i;core.status_view:show_tooltip({style.text,b.label});break end
  end
  if hovered~=self.hovered then self.hovered=hovered;core.redraw=true end
  self.cursor=hovered and 'hand' or 'arrow'
end
function Rail:on_mouse_left()
  self.hovered=nil;self.cursor='arrow';core.status_view:remove_tooltip();core.redraw=true
end
explorer=require 'plugins.litefront_explorer'
local rail=Rail()
local sidebar=core.root_view.root_node:get_node_for_view(explorer)
sidebar:split('left',rail,{x=true})
-- The outer divider resizes the explorer while the activity rail stays fixed.
-- A normal split requires both children to be resizable, which the rail isn't.
local sidebar_resizable,sidebar_resize=sidebar.is_resizable,sidebar.resize
function sidebar:is_resizable(axis)
  if axis=='x' then return explorer.visible and explorer:has_content() end
  return sidebar_resizable(self,axis)
end
function sidebar:resize(axis,value)
  if axis=='x' then return explorer:set_target_size(axis,value-rail.size.x-style.divider_size) end
  return sidebar_resize(self,axis,value)
end

-- Fixed, compact tabs leave space to double-click even on large screens.
local tools_width=120
local function tab_space(node) return math.max(1,node.size.x-tools_width*SCALE) end
local function visible_capacity(self)
  local available=tab_space(self)
  local count=math.max(1,math.floor(available/(100*SCALE)))
  if #self.views>count then count=math.max(1,math.floor((available-48*SCALE)/(100*SCALE))) end
  return math.max(1,math.min(#self.views,config.max_tabs,count))
end
function Node:get_visible_tabs_number()
  return math.max(1,math.min(visible_capacity(self),#self.views-self.tab_offset+1))
end
function Node:scroll_tabs_to_visible()
  local count=visible_capacity(self)
  local index=self:get_view_idx(self.active_view)
  self.tab_offset=common.clamp(self.tab_offset,1,math.max(1,#self.views-count+1))
  if index then
    if index<self.tab_offset then self.tab_offset=index
    elseif index>=self.tab_offset+count then self.tab_offset=index-count+1 end
  end
end
local function tab_capacity(node)
  local width=tab_space(node)
  if #node.views>node:get_visible_tabs_number() then width=width-48*SCALE end
  return math.max(1,width)
end
function Node:target_tab_width()
  return math.min(140*SCALE,tab_capacity(self)/self:get_visible_tabs_number())
end
function Node:get_tab_rect(index)
  local maxw=tab_capacity(self)
  local x1=self.position.x+common.clamp(self.tab_width*(index-1)-self.tab_shift,0,maxw)
  local x2=self.position.x+common.clamp(self.tab_width*index-self.tab_shift,0,maxw)
  return x1,self.position.y,x2-x1,28*SCALE
end
function Node:get_scroll_button_rect(index)
  local width=24*SCALE
  return self.position.x+tab_space(self)-(index==1 and 2 or 1)*width,self.position.y,width,28*SCALE,5*SCALE
end
function Node:get_scroll_button_index(x,y)
  if #self.views<=self:get_visible_tabs_number() then return end
  for i=1,2 do
    local bx,by,w,h=self:get_scroll_button_rect(i)
    if rect_contains({x=bx,y=by,w=w,h=h},x,y) then return i end
  end
end
function Node:draw_tab_borders(view,active,hovered,x,y,w,h)
  renderer.draw_rect(x,y,w,h,active and (style.ui_background or style.background) or hovered and style.hover_background or style.background2)
  renderer.draw_rect(x+w-1,y,1,h,style.divider)
  if active then renderer.draw_rect(x,y+h-SCALE,w,SCALE,style.accent) end
  return x+1,y,math.max(0,w-2),h
end
local file_types={html={'<>','#e88c56'},htm={'<>','#e88c56'},xhtml={'<>','#e88c56'},css={'#','#79aaf5'},scss={'#','#d88fb7'},js={'JS','#dfc766'},jsx={'JS','#79c8e6'},ts={'TS','#79aaf5'},tsx={'TS','#79c8e6'},php={'php','#a9a2da'},md={'MD','#a7b6cc'},json={'{}','#dfc766'},lua={'Lua','#829fe8'},py={'py','#dfc766'}}
local untitled=0
function Node:draw_tab_title(view,font,active,hovered,x,y,w,h)
  if not view then return end
  local name=view:get_name():gsub('%*$','')
  if view.litefront_media then
    local icon=require('plugins.litefront_explorer').icon_for(view.filename,'file')
    visual.icon(icon,x+6*SCALE,y+6*SCALE,16*SCALE,visual.file_color(icon))
    visual.text(style.label_font,name,x+31*SCALE,y,math.max(0,w-34*SCALE),h,active and style.text or style.dim)
    return
  end
  local doc=view.doc
  local type_info
  if doc then
    if doc.abs_filename then type_info=file_types[doc.abs_filename:lower():match('%.([%w]+)$')]
    else
      if not doc.litefront_tab_number then untitled=untitled+1;doc.litefront_tab_number=untitled end
      name='Untitled '..doc.litefront_tab_number
    end
  end
  local ix=x+3*SCALE
  if type_info then
    common.draw_text(style.small_font,visual.file_color(require('plugins.litefront_explorer').icon_for(doc.abs_filename,'file')),type_info[1],'center',ix,y,24*SCALE,h)
  else visual.icon(doc and 'file' or 'code',ix+3*SCALE,y+6*SCALE,16*SCALE,doc and style.dim or style.accent) end
  if doc and doc:is_dirty() then
    visual.rounded(x+w-7*SCALE,y+(h-6*SCALE)/2,6*SCALE,6*SCALE,3*SCALE,style.accent)
    w=w-12*SCALE
  end
  visual.text(style.label_font,name,x+31*SCALE,y,math.max(0,w-34*SCALE),h,active and style.text or style.dim)
end

local actions=ContextMenu()
actions:register(nil,{
  {text='Split Editor Right',command='root:split-right'},
  {text='Split Editor Down',command='root:split-down'},
  ContextMenu.DIVIDER,
  {text='Format Document',command='litefront:format-prettier'},
  {text='Markdown Preview',command='litefront:md-preview'},
  {text='Web Preview',command='litefront:open-web-preview'},
  ContextMenu.DIVIDER,
  {text='Choose Syntax Theme…',command='litefront:syntax-theme'},
  {text='Quick Open…',command='core:find-file'},
  {text='Command Palette…',command='core:find-command'},
})
local function toolbar(node)
  local result={}
  for i,item in ipairs({{'plus','core:new-doc','New File'},{'formatter','litefront:format-prettier','Format Document'},{'markdown-preview','litefront:md-preview','Markdown Preview'},{false,false,'Editor Actions'}}) do
    result[i]={x=node.position.x+node.size.x-(tools_width-4-(i-1)*28)*SCALE,y=node.position.y+2*SCALE,w=26*SCALE,h=24*SCALE,icon=item[1],command=item[2],label=item[3]}
  end
  return result
end
local draw_tabs=Node.draw_tabs
function Node:draw_tabs()
  draw_tabs(self)
  renderer.draw_rect(self.position.x+self.size.x-tools_width*SCALE,self.position.y,tools_width*SCALE,28*SCALE,style.background2)
  renderer.draw_rect(self.position.x+self.size.x-tools_width*SCALE,self.position.y,1,28*SCALE,style.divider)
  for i,b in ipairs(toolbar(self)) do
    if self.litefront_tool_hover==i then visual.rounded(b.x,b.y,b.w,b.h,4*SCALE,style.hover_background) end
    if b.icon then visual.icon(b.icon,b.x+5*SCALE,b.y+4*SCALE,16*SCALE,self.litefront_tool_hover==i and style.text or style.dim)
    else common.draw_text(style.bold_font,style.dim,'…','center',b.x,b.y,b.w,b.h) end
  end
end
local pressed,moved,draw,update=RootView.on_mouse_pressed,RootView.on_mouse_moved,RootView.draw,RootView.update
function RootView:on_mouse_pressed(button,x,y,clicks)
  local node=self.root_node:get_child_overlapping_point(x,y)
  if button=='left' and node and not node.locked then
    for _,b in ipairs(toolbar(node)) do
      if rect_contains(b,x,y) then
        self.dragged_node=nil
        core.set_active_view(node.active_view)
        if b.command then actions:hide();perform(b.command) else actions:show(b.x,b.y+b.h) end
        return true
      end
    end
  end
  if actions.show_context_menu and actions:on_mouse_pressed(button,x,y,clicks) then return true end
  return pressed(self,button,x,y,clicks)
end
function RootView:on_mouse_moved(x,y,...)
  if actions:on_mouse_moved(x,y) then return end
  for _,view in ipairs(self.root_node:get_children()) do
    local node=self.root_node:get_node_for_view(view)
    if node and not node.locked then
      local hovered
      for i,b in ipairs(toolbar(node)) do
        if rect_contains(b,x,y) then hovered=i;core.status_view:show_tooltip({style.text,b.label});break end
      end
      if node.litefront_tool_hover~=hovered then node.litefront_tool_hover=hovered;core.redraw=true end
    end
  end
  return moved(self,x,y,...)
end
function RootView:draw(...) draw(self,...);actions:draw() end
function RootView:update(...) update(self,...);actions:update() end
command.add(nil,{['litefront:close-editor-actions']=function() actions:hide() end})
command.add(function() return actions.show_context_menu end,{
  ['litefront-actions:next']=function() actions:focus_next() end,
  ['litefront-actions:previous']=function() actions:focus_previous() end,
  ['litefront-actions:select']=function() actions:call_selected_item() end,
  ['litefront-actions:close']=function() actions:hide() end,
})
require('core.keymap').add {['down']='litefront-actions:next',['up']='litefront-actions:previous',['return']='litefront-actions:select',['escape']='litefront-actions:close'}

-- Apply the reference's compact menu surfaces to all built-in context menus.
function ContextMenu:draw_context_menu()
  if not self.items then return end
  local x,y,w,h=self.position.x,self.position.y,self.items.width,self.height
  visual.rounded(x-4*SCALE,y+4*SCALE,w+8*SCALE,h+6*SCALE,7*SCALE,{0,0,0,60})
  visual.rounded(x-1,y-1,w+2,h+2,6*SCALE,style.divider)
  visual.rounded(x,y,w,h,5*SCALE,style.background2)
  core.push_clip_rect(x,y,w,h)
  for i,item,bx,by,bw,bh in self:each_item() do
    if item==ContextMenu.DIVIDER then renderer.draw_rect(bx,by+bh/2,bw,1,style.divider)
    else
      if self.selected==i and not item.disabled then visual.rounded(bx,by,bw,bh,3*SCALE,style.hover_background) end
      common.draw_text(style.font,item.disabled and style.dim or style.text,item.text,nil,bx+14*SCALE,by,bw-28*SCALE,bh)
      if item.info then common.draw_text(style.label_font,style.dim,item.info,'right',bx+14*SCALE,by,bw-28*SCALE,bh) end
    end
  end
  core.pop_clip_rect()
end

-- Jotta-style status layout: breadcrumb, position, indentation, encoding, language, theme.
local status=core.status_view
for _,name in ipairs({'doc:file','doc:position','doc:lines','command:files'}) do status:remove_item(name) end
local workspace_item=status:add_item {name='litefront:workspace',get_item=function(item)
  item.tooltip=core.litefront_no_project and T('No folder open') or core.project_dir
  return {}
end,alignment=StatusView.Item.LEFT}
workspace_item.on_draw=function(x,y,h,hovered,calc)
  local label=core.litefront_no_project and T('No folder open') or common.basename(core.project_dir)
  local width=math.min(style.label_font:get_width(label)+26*SCALE,math.max(60*SCALE,math.min(260*SCALE,core.root_view.size.x*.25)))
  if not calc then
    visual.icon('folder',x,y+(h-16*SCALE)/2,16*SCALE,style.dim)
    visual.text(style.label_font,label,x+22*SCALE,y,width-22*SCALE,h,style.text)
  end
  return width
end
status:add_item {name='litefront:breadcrumb',predicate=function() return visual.document_view()~=nil end,alignment=StatusView.Item.LEFT,get_item=function()
  local doc=visual.document_view().doc
  local filename=doc.abs_filename and (core.litefront_no_project and common.home_encode(doc.abs_filename) or common.relative_path(core.project_dir,doc.abs_filename)) or T('Untitled')
  filename=filename:gsub('[/\\]','  ›  ')
  return {style.label_font,style.text,filename}
end}
status:add_item {name='litefront:position',predicate=function() return visual.document_view()~=nil end,alignment=StatusView.Item.RIGHT,get_item=function()
  local line,col=visual.document_view().doc:get_selection()
  return {style.label_font,style.dim,T('Ln %d, Col %d',line,col)}
end,command='doc:go-to-line',tooltip='Go to line'}
status:add_item {name='litefront:encoding',predicate=function() return visual.document_view()~=nil end,alignment=StatusView.Item.RIGHT,get_item=function() return {style.label_font,style.dim,'UTF-8'} end}
local ending=status:get_item('doc:line-ending')
ending:set_predicate(function() return visual.document_view()~=nil end)
ending.get_item=function() return {style.label_font,style.dim,visual.document_view().doc.crlf and 'CRLF' or 'LF'} end
local indentation=status:get_item('doc:indentation')
indentation:set_predicate(function() return visual.document_view()~=nil end)
indentation.get_item=function()
  local kind,size=visual.document_view().doc:get_indent_info()
  return {style.label_font,style.dim,(kind=='hard' and 'Tabs: ' or 'Spaces: ')..size}
end
local theme_item=status:add_item {name='litefront:theme-toggle',get_item=function() return {} end,alignment=StatusView.Item.RIGHT,command='litefront:toggle-theme',tooltip='Toggle light and dark theme'}
require('litefront.status_layout').attach(status,theme_item)
StatusView.separator='    '
StatusView.separator2='    '
core.add_thread(function()
  status:order_items({'litefront:workspace','litefront:breadcrumb','litefront:position','doc:indentation','litefront:encoding','doc:line-ending','litefront:language','litefront:theme-toggle'})
end)
return {rail=rail,toolbar=toolbar,actions=actions}
