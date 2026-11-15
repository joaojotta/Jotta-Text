-- mod-version:3
-- Compact Jotta-style application chrome. Features are part of the application.
local T=require('litefront.i18n').t
local core = require 'core'
local command = require 'core.command'
local keymap = require 'core.keymap'
local style = require 'core.style'
local common = require 'core.common'
local View = require 'core.view'
local EmptyView = require 'core.emptyview'
local RootView = require 'core.rootview'
local Node = require 'core.node'
local ContextMenu = require 'core.contextmenu'
local visual = require 'litefront.visual'
local Bar = View:extend()
local popup = ContextMenu()
popup.keep_disabled = true
local active_menu
local menus = {
  {'File', {
    {text='New File',command='core:new-doc'},
    {text='Open File…',command='core:open-file'},
    {text='Open Folder…',command='core:open-project-folder'},
    ContextMenu.DIVIDER,
    {text='Save',command='doc:save'}, {text='Save As…',command='doc:save-as'},
    {text='Save All',command='litefront:save-all'},
    ContextMenu.DIVIDER,
    {text='Close File',command='root:close'}, {text='Quit',command='core:quit'},
  }},
  {'Edit', {
    {text='Undo',command='doc:undo'}, {text='Redo',command='doc:redo'},
    ContextMenu.DIVIDER,
    {text='Cut',command='doc:cut'}, {text='Copy',command='doc:copy'},
    {text='Paste',command='doc:paste'}, {text='Select All',command='doc:select-all'},
    ContextMenu.DIVIDER,
    {text='Find…',command='find-replace:find'}, {text='Replace…',command='find-replace:replace'},
  }},
  {'View', {
    {text='Toggle Explorer',command='litefront:toggle-explorer'},
    {text='Document outline',command='litefront:document-outline'},
    {text='Split Right',command='root:split-right'}, {text='Split Down',command='root:split-down'},
    {text='Toggle Minimap',command='minimap:toggle-visibility'},
    ContextMenu.DIVIDER,
    {text='Dark Theme',command='litefront:theme-dark'}, {text='Light Theme',command='litefront:theme-light'},
    {text='Syntax Theme…',command='litefront:syntax-theme'},
    {text='Explorer Icon Colors…',command='litefront:icon-palette'},
    {text='Increase Code Font',command='litefront:increase-code-font'},
    {text='Decrease Code Font',command='litefront:decrease-code-font'},
  }},
  {'Tools', {
    {text='Edit Color at Cursor…',command='litefront:edit-color'},
    {text='Format Document',command='litefront:format-prettier'},
    {text='Cancel Formatting',command='litefront:cancel-formatting'},
    {text='Markdown Preview',command='litefront:md-preview'},
    {text='Web Preview',command='litefront:open-web-preview'},
    ContextMenu.DIVIDER,
    {text='Quick Open…',command='core:find-file'},
    {text='Search Project…',command='project-search:find'},
    {text='Command Palette…',command='core:find-command'},
  }},
  {'Preferences', {
    {text='Settings…',command='litefront:settings'},
    ContextMenu.DIVIDER,
    {text='UI Font…',command='litefront:ui-font'},
    {text='Increase UI Font',command='litefront:increase-ui-font'},
    {text='Decrease UI Font',command='litefront:decrease-ui-font'},
    {text='Reset UI Font Size',command='litefront:reset-ui-font-size'},
    ContextMenu.DIVIDER,
    {text='Code Editor Font…',command='litefront:code-font'},
    {text='Increase Code Font',command='litefront:increase-code-font'},
    {text='Decrease Code Font',command='litefront:decrease-code-font'},
    {text='Reset Code Font Size',command='litefront:reset-code-font-size'},
    ContextMenu.DIVIDER,
    {text='Reset Fonts',command='litefront:reset-fonts'},
  }},
  {'Help', {{text='About Jotta Text',command='litefront:about'}, {text='Application Log',command='core:open-log'}}},
}
for i, menu in ipairs(menus) do
  popup:register(function() return active_menu == i end, menu[2])
  if i==4 and not JOTTA_WEB then
    popup:register(function() return active_menu==i and require('litefront.preferences').values.github_trial end,
      {ContextMenu.DIVIDER,{text='GitHub (experimental)…',command='litefront:github-trial'}})
  end
end

function Bar:new()
  Bar.super.new(self)
  self.size.y = math.max(28*SCALE,style.font:get_height()+12*SCALE)
end
function Bar:update() self.size.y = math.max(28*SCALE,style.font:get_height()+12*SCALE) end
function Bar:items()
  local items, x = {}, self.position.x+44*SCALE
  for i, menu in ipairs(menus) do
    local w = style.font:get_width(T(menu[1]))+24*SCALE
    items[i] = {x=x,y=self.position.y,w=w,h=self.size.y}
    x=x+w
  end
  return items
end
function Bar:draw()
  self:draw_background(style.title_background or style.background2)
  visual.logo(self.position.x+10*SCALE,self.position.y+4*SCALE,20*SCALE)
  renderer.draw_rect(self:items()[1].x-8*SCALE,self.position.y+7*SCALE,1,14*SCALE,style.divider)
  for i,b in ipairs(self:items()) do
    if (popup.show_context_menu and active_menu == i) or self.hovered_menu==i then
      visual.rounded(b.x+2*SCALE,b.y+3*SCALE,b.w-4*SCALE,b.h-6*SCALE,4*SCALE,style.hover_background)
    end
    common.draw_text(style.font, style.text, T(menus[i][1]), 'center', b.x,b.y,b.w,b.h)
  end
  renderer.draw_rect(self.position.x,self.position.y+self.size.y-1,self.size.x,1,style.divider)
end
function Bar:on_mouse_moved(x,y)
  local hovered
  for i,b in ipairs(self:items()) do
    if x>=b.x and x<b.x+b.w and y>=b.y and y<b.y+b.h then hovered=i;break end
  end
  if hovered~=self.hovered_menu then self.hovered_menu=hovered;core.redraw=true end
  self.cursor=hovered and 'hand' or 'arrow'
end
local bar = Bar()
-- Wrap the entire workspace, including the explorer and activity rail.
local workspace=require('plugins.litefront_explorer').workspace_node
local content=Node()
content:consume(workspace)
workspace:consume(Node('vsplit'))
workspace.a=Node()
workspace.a:add_view(bar)
workspace.a.locked={y=true}
workspace.b=content
local function show_menu(i)
  active_menu = i
  local b = bar:items()[i]
  popup:show(b.x,b.y+b.h)
  core.redraw = true
end
local draw, update = RootView.draw, RootView.update
local pressed, moved = RootView.on_mouse_pressed, RootView.on_mouse_moved
function RootView:draw(...)
  draw(self,...)
  popup:draw()
end
function RootView:update(...)
  update(self,...)
  popup:update()
end
function RootView:on_mouse_pressed(button,x,y,clicks)
  if button == 'left' then
    for i,b in ipairs(bar:items()) do
      if x>=b.x and x<b.x+b.w and y>=b.y and y<b.y+b.h then
        if popup.show_context_menu and active_menu==i then popup:hide() else show_menu(i) end
        return true
      end
    end
  end
  if popup.show_context_menu and popup:on_mouse_pressed(button,x,y,clicks) then return true end
  return pressed(self,button,x,y,clicks)
end
function RootView:on_mouse_moved(x,y,...)
  if popup.show_context_menu then
    for i,b in ipairs(bar:items()) do
      if x>=b.x and x<b.x+b.w and y>=b.y and y<b.y+b.h and active_menu~=i then show_menu(i) end
    end
    if popup:on_mouse_moved(x,y) then return end
  end
  return moved(self,x,y,...)
end
command.add(function() return popup.show_context_menu end, {
  ['litefront-menu:next']=function() popup:focus_next() end,
  ['litefront-menu:previous']=function() popup:focus_previous() end,
  ['litefront-menu:select']=function() popup:call_selected_item() end,
  ['litefront-menu:close']=function() popup:hide() end,
  ['litefront-menu:left']=function() show_menu((active_menu-2)%#menus+1) end,
  ['litefront-menu:right']=function() show_menu(active_menu%#menus+1) end,
})
local menu_commands, menu_keys = {}, {}
for i, menu in ipairs(menus) do
  local name = 'litefront-menu:'..menu[1]:lower()
  menu_commands[name]=function() show_menu(i) end
  menu_keys['alt+'..menu[1]:sub(1,1):lower()]=name
end
command.add(nil,menu_commands)
keymap.add(menu_keys)
keymap.add {
  ['down']='litefront-menu:next', ['up']='litefront-menu:previous',
  ['return']='litefront-menu:select', ['escape']='litefront-menu:close',
  ['left']='litefront-menu:left', ['right']='litefront-menu:right',
}
command.add(nil, {['litefront:save-all']=function()
  for _,doc in ipairs(core.docs) do if doc.abs_filename and doc:is_dirty() then doc:save() end end
end, ['litefront:about']=function()
  require('litefront.dialogs').show_about()
end})
-- Extension management and executable user/project configuration are not product features.
for _, name in ipairs({'core:open-user-module','core:open-project-module','core:reload-module'}) do
  command.map[name]=nil
end

local draw_borders = Node.draw_tab_borders
function Node:draw_tab_borders(view, is_active, is_hovered, x,y,w,h,standalone)
  local nx,ny,nw,nh = draw_borders(self,view,is_active,is_hovered,x,y,w,h,standalone)
  if is_active then renderer.draw_rect(x,y+h-2*SCALE,w,2*SCALE,style.accent) end
  return nx,ny,nw,nh
end
function EmptyView:draw()
  self:draw_background(style.ui_background or style.background)
  core.push_clip_rect(self.position.x,self.position.y,self.size.x,self.size.y)
  local w=math.max(1,math.min(360*SCALE,self.size.x-40*SCALE))
  local x=self.position.x+(self.size.x-w)/2
  local y=self.position.y+math.max(20*SCALE,(self.size.y-480*SCALE)/2)
  visual.logo(x+(w-100*SCALE)/2,y,100*SCALE)
  common.draw_text(style.big_font,style.text,'Jotta Text','center',x,y+118*SCALE,w,36*SCALE)
  common.draw_text(style.font,style.dim,T('A clean space for code.'),'center',x,y+154*SCALE,w,30*SCALE)
  self.litefront_buttons={}
  local shortcuts={
    {keys={'Ctrl','P'},label='Quick open',command='core:find-file'},
    {keys={'Ctrl','Shift','P'},label='Commands',command='core:find-command'},
    {keys={'Ctrl','O'},label='Open file',command='core:open-file'},
    {keys={'Ctrl','Shift','O'},label='Open folder',command='core:open-project-folder'},
    {keys={'Ctrl','N'},label='New file',command='core:new-doc'},
  }
  for i,item in ipairs(shortcuts) do
    local by=y+(204+(i-1)*36)*SCALE
    if self.hovered_welcome==i then visual.rounded(x-8*SCALE,by-2*SCALE,w+16*SCALE,32*SCALE,4*SCALE,style.background2) end
    local kx=x
    for n,key in ipairs(item.keys) do
      if n>1 then
        common.draw_text(style.small_font,style.dim,'+',nil,kx,by,14*SCALE,26*SCALE)
        kx=kx+14*SCALE
      end
      local kw=style.small_font:get_width(key)+12*SCALE
      visual.rounded(kx,by,kw,25*SCALE,4*SCALE,style.divider)
      visual.rounded(kx+1,by+1,kw-2,22*SCALE,3*SCALE,style.input_background)
      common.draw_text(style.small_font,style.dim,key,'center',kx,by,kw,24*SCALE)
      kx=kx+kw+5*SCALE
    end
    common.draw_text(style.label_font,style.dim,T(item.label),'right',x,by,w,26*SCALE)
    self.litefront_buttons[i]={x=x-8*SCALE,y=by-2*SCALE,w=w+16*SCALE,h=32*SCALE,command=item.command}
  end
  local recent_y=y+404*SCALE
  local recents={}
  for _,path in ipairs(core.recent_projects or {}) do
    if #recents==3 then break end
    local info=system.get_file_info(path)
    if info and info.type=='dir' then recents[#recents+1]=path end
  end
  if #recents>0 and recent_y+48*SCALE<self.position.y+self.size.y then
    renderer.draw_text(style.small_font,T('RECENT WORKSPACES'),x,recent_y,style.dim)
    for i,path in ipairs(recents) do
      local by=recent_y+(25+(i-1)*28)*SCALE
      if by+28*SCALE>self.position.y+self.size.y then break end
      visual.icon('folder',x,by+5*SCALE,16*SCALE,style.dim)
      visual.text(style.label_font,common.basename(path),x+24*SCALE,by,w-24*SCALE,26*SCALE,style.dim)
      local selected_path=path
      self.litefront_buttons[#self.litefront_buttons+1]={x=x,y=by,w=w,h=26*SCALE,fn=function()
        core.confirm_close_docs(core.docs,function() core.open_folder_project(selected_path) end)
      end}
    end
  end
  core.pop_clip_rect()
end
function EmptyView:on_mouse_pressed(button,x,y)
  if button~='left' then return end
  for _,b in ipairs(self.litefront_buttons or {}) do
    if x>=b.x and x<b.x+b.w and y>=b.y and y<b.y+b.h then
      if b.fn then b.fn() else command.perform(b.command) end
      return true
    end
  end
end
function EmptyView:on_mouse_moved(x,y)
  local hovered
  for i,b in ipairs(self.litefront_buttons or {}) do
    if x>=b.x and x<b.x+b.w and y>=b.y and y<b.y+b.h then hovered=i;break end
  end
  if hovered~=self.hovered_welcome then self.hovered_welcome=hovered;core.redraw=true end
  self.cursor=hovered and 'hand' or 'arrow'
end

return {bar=bar,popup=popup}
