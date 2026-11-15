-- mod-version:3
-- Project explorer backed by the editor's existing, watched project index.
local core=require 'core'
local common=require 'core.common'
local command=require 'core.command'
local keymap=require 'core.keymap'
local style=require 'core.style'
local View=require 'core.view'
local system=require 'system'
local config=require 'core.config'
local visual=require 'litefront.visual'
local Explorer=View:extend()
local DURATION=0.1
local extensions={
  html='html5',htm='html5',xhtml='html5',css='css3',scss='css3',sass='css3',less='css3',
  js='js',mjs='js',cjs='js',jsx='js',ts='file-code',tsx='file-code',json='json',jsonc='json',
  md='markdown',markdown='markdown',mdx='markdown',php='php',txt='txt',log='txt',
  png='png',jpg='jpeg',jpeg='jpeg',gif='gif',webp='webp',svg='svg',ico='image',bmp='image',tif='image',tiff='image',avif='image',
  mp3='audio',wav='audio',ogg='audio',flac='audio',mp4='video',webm='video',mov='video',
  zip='archive',gz='archive',tar='archive',['7z']='archive',rar='archive',
  ttf='font',otf='font',ttc='font',woff='fonts',woff2='fonts',sql='database',db='database',sqlite='database',
  lua='file-code',py='file-code',rb='file-code',sh='file-code',c='file-code',cpp='file-code',h='file-code',
  rs='file-code',go='file-code',java='file-code',xml='file-code',yaml='file-code',yml='file-code',toml='file-code',
}
function Explorer.icon_for(name,kind)
  if kind=='dir' then return 'file-folder' end
  name=name:lower()
  if name=='package.json' or name=='package-lock.json' or name=='yarn.lock' or name=='pnpm-lock.yaml' then return 'file-package' end
  return 'file-'..(extensions[name:match('%.([^.]+)$')] or 'file')
end
function Explorer:new()
  Explorer.super.new(self)
  self.scrollable=true
  self.visible=not config.litefront or config.litefront.explorer_visible~=false
  self.width=(config.litefront and config.litefront.explorer_width or 240)*SCALE
  self.rows={}
  self.expanded={}
  self.selected=1
  self.next_refresh=0
  self.target_width=0
end
function Explorer:get_name() return nil end
function Explorer:on_scale_change(new_scale,previous_scale)
  self.width=self.width*new_scale/previous_scale
end
function Explorer:has_project()
  return not core.litefront_no_project and #core.project_directories>0
end
function Explorer:has_content() return self.mode=='outline' or self:has_project() end
function Explorer:desired_width()
  return self.visible and self:has_content() and math.min(self.width,math.max(0,core.root_view.size.x-200*SCALE)) or 0
end
function Explorer:animate_to(width,now)
  if width==self.target_width then return end
  self.animation={time=now or system.get_time(),from=self.size.x,to=width}
  self.target_width=width
  core.redraw=true
end
function Explorer:advance_animation(now)
  local animation=self.animation
  if not animation then return end
  local t=common.clamp((now-animation.time)/DURATION,0,1)
  self.size.x=animation.from+(animation.to-animation.from)*t
  if t>=1 then self.size.x=animation.to;self.animation=nil end
  core.redraw=true
end
function Explorer:restore_editor()
  local view=self.return_view
  local node=view and core.root_view.root_node:get_node_for_view(view)
  if node and node.active_view==view then core.set_active_view(view)
  else core.set_active_view(core.root_view:get_primary_node().active_view) end
end
function Explorer:toggle()
  if self.mode=='outline' then
    require('litefront.outline').stop();self.mode='explorer';self.visible=true
    self.outline_scroll={y=self.scroll.y,to=self.scroll.to.y}
    local saved=self.file_scroll or {y=0,to=0};self.scroll.y,self.scroll.to.y=saved.y,saved.to;core.status_view:remove_tooltip()
  else self.visible=not self.visible end
  self:animate_to(self:desired_width())
  if (not self.visible or not self:has_content()) and core.active_view==self then self:restore_editor() end
end
function Explorer:set_target_size(axis,value)
  if axis~='x' then return end
  self.width=common.clamp(value,140*SCALE,math.max(140*SCALE,math.min(600*SCALE,core.root_view.size.x-self.position.x-200*SCALE)))
  self.target_width=self.width
  self.animation=nil
  self.size.x=self.width
  core.redraw=true
  return true
end
local function depth(name)
  local _,count=name:gsub('[/\\]','')
  return count+1
end
function Explorer:refresh()
  local selected=self.rows[self.selected]
  local previous=selected and selected.path
  self.rows={}
  if not self:has_project() then return end
  for _,dir in ipairs(core.project_directories) do
    local root=dir.name
    if self.expanded[root]==nil then self.expanded[root]=true end
    self.rows[#self.rows+1]={path=root,name=common.basename(root),type='dir',depth=0,dir=dir,relative=''}
    if self.expanded[root] then
      local skip_depth
      for _,item in ipairs(dir.files or {}) do
        local level=depth(item.filename)
        if skip_depth and level<=skip_depth then skip_depth=nil end
        if not skip_depth then
          local hidden=common.basename(item.filename):sub(1,1)=='.'
          if hidden and config.litefront and not config.litefront.show_hidden then
            if item.type=='dir' then skip_depth=level end
          else
          local path=root..PATHSEP..item.filename
          self.rows[#self.rows+1]={path=path,name=common.basename(item.filename),type=item.type,depth=level,dir=dir,relative=item.filename}
          if item.type=='dir' and not self.expanded[path] then skip_depth=level end
          end
        end
      end
    end
  end
  self.selected=math.max(1,math.min(self.selected,#self.rows))
  for i,row in ipairs(self.rows) do if row.path==previous then self.selected=i;break end end
  core.redraw=true
end
function Explorer:update()
  local now=system.get_time()
  if self.project~=core.project_dir or self.no_project~=core.litefront_no_project or self.directories~=core.project_directories then
    self.project,self.no_project,self.directories=core.project_dir,core.litefront_no_project,core.project_directories
    self.expanded={};self.rows={};self.selected=1;self.hovered=nil
    self.scroll.y,self.scroll.to.y=0,0;self.file_scroll=nil
    self.next_refresh=0
  end
  self:animate_to(self:desired_width(),now)
  self:advance_animation(now)
  if self.mode=='outline' then require('litefront.outline').update(self)
  elseif self.size.x>0 and now>=self.next_refresh then self:refresh();self.next_refresh=now+0.25 end
  Explorer.super.update(self)
end
function Explorer:row_height() return math.max(28*SCALE,style.label_font:get_height()+10*SCALE) end
function Explorer:header_height() return math.max(34*SCALE,style.small_font:get_height()+14*SCALE) end
function Explorer:get_scrollable_size()
  if self.mode=='outline' then return require('litefront.outline').scrollable_size(self) end
  return self:header_height()+#self.rows*self:row_height()+6*SCALE end
function Explorer:get_content_offset()
  local x,y=Explorer.super.get_content_offset(self)
  return x,y+self:header_height()
end
function Explorer:row_at(x,y)
  if x<self.position.x or x>=self.position.x+self.size.x or y<self.position.y+self:header_height() or y>=self.position.y+self.size.y then return end
  local _,top=self:get_content_offset()
  local i=math.floor((y-top)/self:row_height())+1
  return self.rows[i] and i
end
function Explorer:activate(index)
  local row=self.rows[index]
  if not row then return end
  self.selected=index
  if row.type=='dir' then
    self.expanded[row.path]=not self.expanded[row.path]
    if row.dir.files_limit then core.update_project_subdir(row.dir,row.relative,self.expanded[row.path]) end
    self:refresh()
  else
    self:restore_editor()
    core.root_view:open_doc(core.open_doc(row.path))
  end
  core.redraw=true
end
function Explorer:move_selection(delta)
  self.selected=common.clamp(self.selected+delta,1,math.max(1,#self.rows))
  local top=(self.selected-1)*self:row_height()
  local height=self.size.y-self:header_height()
  if top<self.scroll.to.y then self.scroll.to.y=top
  elseif top+self:row_height()>self.scroll.to.y+height then self.scroll.to.y=top+self:row_height()-height end
  core.redraw=true
end
function Explorer:collapse()
  local row=self.rows[self.selected]
  if not row then return end
  if row.type=='dir' and self.expanded[row.path] then self:activate(self.selected)
  else
    for i=self.selected-1,1,-1 do
      if self.rows[i].depth<row.depth then self.selected=i;self:move_selection(0);break end
    end
  end
end
function Explorer:expand()
  local row=self.rows[self.selected]
  if not row or row.type~='dir' then return end
  if not self.expanded[row.path] then self:activate(self.selected)
  elseif self.rows[self.selected+1] and self.rows[self.selected+1].depth>row.depth then self:move_selection(1) end
end
function Explorer:on_mouse_pressed(button,x,y,clicks)
  if core.last_active_view and core.last_active_view~=self then self.return_view=core.last_active_view end
  if self.mode=='outline' then
    if Explorer.super.on_mouse_pressed(self,button,x,y,clicks) then return true end
    return require('litefront.outline').click(self,button,x,y)
  end
  if button~='left' then return true end
  if y<self.position.y+self:header_height() then
    if x>=self.position.x+self.size.x-30*SCALE then self:toggle() end
    return true
  end
  if Explorer.super.on_mouse_pressed(self,button,x,y,clicks) then return true end
  local index=self:row_at(x,y)
  if index then self:activate(index) end
  return true
end
function Explorer:on_mouse_moved(x,y,...)
  Explorer.super.on_mouse_moved(self,x,y,...)
  if self.mode=='outline' then
    if not self:scrollbar_dragging() and not self:scrollbar_hovering() then require('litefront.outline').move(self,x,y) end
    return
  end
  local index=self:row_at(x,y)
  if self.hovered~=index then self.hovered=index;core.redraw=true end
  if index then core.status_view:show_tooltip({style.text,self.rows[index].path})
  else core.status_view:remove_tooltip() end
  self.cursor=index and 'hand' or 'arrow'
end
function Explorer:on_mouse_left()
  if self.mode=='outline' then require('litefront.outline').hovered=nil end
  self.hovered=nil;core.status_view:remove_tooltip();core.redraw=true
end
function Explorer:draw()
  if self.mode=='outline' then return require('litefront.outline').draw(self) end
  if self.size.x<1 then return end
  self:draw_background(style.sidebar_background or style.background2)
  local x,y,w,h=self.position.x,self.position.y,self.size.x,self.size.y
  local header=self:header_height()
  local _,top=self:get_content_offset()
  local row_height=self:row_height()
  local view=visual.document_view()
  local active_path=view and view.doc.abs_filename
  core.push_clip_rect(x,y+header,w,math.max(0,h-header))
  local first=math.max(1,math.floor((y+header-top)/row_height)+1)
  local last=math.min(#self.rows,first+math.ceil(h/row_height))
  for i=first,last do
    local row=self.rows[i]
    local ry=top+(i-1)*row_height
    if row.path==active_path or (core.active_view==self and i==self.selected) then
      renderer.draw_rect(x,ry,w,row_height,style.ui_selection or style.line_highlight)
    elseif i==self.hovered then renderer.draw_rect(x,ry,w,row_height,style.hover_background) end
    local indent=x+8*SCALE+row.depth*14*SCALE
    if row.type=='dir' then visual.icon(self.expanded[row.path] and 'arrow-down' or 'arrow-right',indent,ry+7*SCALE,12*SCALE,style.dim) end
    visual.icon(Explorer.icon_for(row.name,row.type),indent+15*SCALE,ry+5*SCALE,18*SCALE,visual.file_color(Explorer.icon_for(row.name,row.type)))
    visual.text(style.label_font,row.name,indent+39*SCALE,ry,math.max(0,x+w-indent-49*SCALE),row_height,style.text)
  end
  core.pop_clip_rect()
  core.push_clip_rect(x,y,w,math.min(header,h))
  common.draw_text(style.small_font,style.dim,require('litefront.i18n').t('EXPLORER'),nil,x+12*SCALE,y,math.max(0,w-45*SCALE),header)
  visual.icon('close',x+w-25*SCALE,y+9*SCALE,16*SCALE,style.dim)
  core.pop_clip_rect()
  self:draw_scrollbar()
  renderer.draw_rect(x+w-1,y,1,h,style.divider)
end
local explorer=Explorer()
local workspace=core.root_view:get_active_node_default()
workspace:split('left',explorer,{x=true},true)
explorer.workspace_node=workspace
command.add(nil,{['litefront:toggle-explorer']=function() explorer:toggle() end})
command.add(function() return core.active_view==explorer and explorer.mode~='outline' end,{
  ['litefront-explorer:next']=function() explorer:move_selection(1) end,
  ['litefront-explorer:previous']=function() explorer:move_selection(-1) end,
  ['litefront-explorer:open']=function() explorer:activate(explorer.selected) end,
  ['litefront-explorer:collapse']=function() explorer:collapse() end,
  ['litefront-explorer:expand']=function() explorer:expand() end,
  ['litefront-explorer:focus-editor']=function() explorer:restore_editor() end,
})
keymap.add {
  ['ctrl+b']='litefront:toggle-explorer',
  ['ctrl+\\']='litefront:toggle-explorer',
  ['down']='litefront-explorer:next',['up']='litefront-explorer:previous',
  ['left']='litefront-explorer:collapse',['right']='litefront-explorer:expand',
  ['return']='litefront-explorer:open',['escape']='litefront-explorer:focus-editor',
}
return explorer
