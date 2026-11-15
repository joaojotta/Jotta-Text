-- mod-version:3
-- Always-visible tabs, double-click new documents, and per-document language selection.
local T=require('litefront.i18n').t
local core = require 'core'
local command = require 'core.command'
local style = require 'core.style'
local common = require 'core.common'
local syntax = require 'core.syntax'
local Doc = require 'core.doc'
local Node = require 'core.node'
local RootView = require 'core.rootview'
local StatusView = require 'core.statusview'
local EmptyView = require 'core.emptyview'
local files = require 'plugins.litefront_files'
local visual = require 'litefront.visual'

function Node:should_show_tabs() return not self.locked end
function EmptyView:get_name() return T('Welcome') end
local function language_area()
  if not visual.document_view() then return end
  local status=core.status_view
  local item=status:get_item('litefront:language')
  if not item or not item.active then return end
  local x,w=status:get_item_visible_area(item)
  return x,status.position.y,w,status.size.y
end
local pressed = RootView.on_mouse_pressed
function RootView:on_mouse_pressed(button,x,y,clicks)
  local lx,ly,lw,lh=language_area()
  if button=='left' and lx and x>=lx and x<lx+lw and y>=ly and y<ly+lh then
    command.perform('litefront-menu:close')
    command.perform('litefront:select-language')
    self.litefront_language_pressed=true
    return true
  end
  local node=self.root_node:get_child_overlapping_point(x,y)
  if button=='left' and clicks==2 and node and not node.locked then
    local _,top,_,height=node:get_tab_rect(1)
    if y>=top and y<top+height and not node:get_tab_overlapping_point(x,y)
      and node.hovered_scroll_button==0 then
      node:add_view(require('core.docview')(core.open_doc()))
      self.dragged_node=nil
      return true
    end
  end
  return pressed(self,button,x,y,clicks)
end

local released=RootView.on_mouse_released
function RootView:on_mouse_released(...)
  if self.litefront_language_pressed then self.litefront_language_pressed=nil; return true end
  return released(self,...)
end
local status_draw=StatusView.draw
function StatusView:draw(...)
  status_draw(self,...)
  -- Keep the selector visible while startup, save, and language-server messages are shown.
  if self.message and system.get_time()<=self.message_timeout then
    local x,y,w,h=language_area()
    if x and w>0 then
      renderer.draw_rect(x-style.padding.x,y,w+2*style.padding.x,h,style.background2)
      common.draw_text(style.label_font,style.dim,T(visual.document_view().doc.syntax.name),nil,x,y,w-20*SCALE,h)
      visual.icon('arrow-down',x+w-16*SCALE,y+(h-14*SCALE)/2,14*SCALE,style.dim)
    end
  end
end

-- An explicit language remains selected after edits and Save As; Automatic follows the filename.
local reset_syntax=Doc.reset_syntax
function Doc:reset_syntax()
  if self.litefront_language then
    if self.syntax~=self.litefront_language then
      self.syntax=self.litefront_language
      self.highlighter:soft_reset()
    end
  else
    local previous=self.syntax
    reset_syntax(self)
    self.litefront_content_language=false
    if syntax.get(self.abs_filename or self.filename).name=='Plain Text' then
      local filename=require('litefront.language_detection').filename(self:get_text(1,1,self:position_offset(1,1,8192)))
      if filename then
        self.syntax=syntax.get(filename)
      end
      self.litefront_content_language=self.syntax.name~='Plain Text'
    end
    if self.syntax~=previous then self.highlighter:soft_reset() end
  end
end
local on_text_change=Doc.on_text_change
function Doc:on_text_change(...)
  on_text_change(self,...)
  if not self.litefront_language and (not self.abs_filename or self.syntax.name=='Plain Text' or self.litefront_content_language) then
    self:reset_syntax()
  end
end
local function set_language(doc, language)
  doc.litefront_language=language
  doc:reset_syntax()
  core.redraw=true
end
command.add('core.docview', {['litefront:select-language']=function(view)
  local doc=view.doc
  local choices={{text='Automatic (filename and content)'},{text='Plain Text',language=syntax.get(nil,nil)}}
  local seen={['Plain Text']=true}
  for _,language in ipairs(syntax.items) do
    if not seen[language.name] then
      choices[#choices+1]={text=language.name,language=language}
      seen[language.name]=true
    end
  end
  table.sort(choices,function(a,b)
    local ranks={['Automatic (filename and content)']=1,['Plain Text']=2}
    local ar,br=ranks[a.text] or 3,ranks[b.text] or 3
    if ar~=br then return ar<br end
    return a.text:lower()<b.text:lower()
  end)
  local labels,by_name={},{}
  for _,choice in ipairs(choices) do labels[#labels+1]=T(choice.text); by_name[T(choice.text)]=choice end
  core.command_view:enter('Choose Language', {picker=true,typeahead=false,
    suggest=function(text) return text=='' and labels or common.fuzzy_match(labels,text) end,
    submit=function(text,item)
      local choice=by_name[item and item.text or text]
      if choice then set_language(doc,choice.language) end
    end,
  })
end})
command.add(nil, {['litefront:save-all']=function()
  local docs={}
  for _,doc in ipairs(core.docs) do if doc:is_dirty() then docs[#docs+1]=doc end end
  local index=0
  local function next_doc()
    index=index+1
    if docs[index] then files.save(docs[index],false,next_doc) end
  end
  next_doc()
end})
local language_item=core.status_view:add_item {
  name='litefront:language', predicate=function() return visual.document_view()~=nil end, alignment=StatusView.Item.RIGHT,
  get_item=function()
    return {style.label_font,style.dim,T(visual.document_view().doc.syntax.name)}
  end,
  command='litefront:select-language', tooltip='Choose document language or Plain Text',
  position=1,
}

language_item.on_draw=function(x,y,h,hovered,calc)
  local text=T(visual.document_view().doc.syntax.name)
  local width=style.label_font:get_width(text)+24*SCALE
  if not calc then
    common.draw_text(style.label_font,hovered and style.text or style.dim,text,nil,x,y,width-20*SCALE,h)
    visual.icon('arrow-down',x+width-16*SCALE,y+(h-14*SCALE)/2,14*SCALE,hovered and style.text or style.dim)
  end
  return width
end

-- Save and Close must wait for the asynchronous system dialog on an unnamed file.
local DocView=require 'core.docview'
local try_close=DocView.try_close
function DocView:try_close(do_close)
  if self.doc:is_dirty() and #core.get_views_referencing_doc(self.doc)==1 then
    core.nag_view:show('Unsaved Changes',T('Save changes to "%s"?',self.doc:get_name()), {
      {text='Save',default_yes=true},{text='Discard'},{text='Cancel',default_no=true},
    },function(item)
      if item.text=='Save' then
        core.add_thread(function() files.save(self.doc,false,do_close) end)
      elseif item.text=='Discard' then do_close() end
    end)
  else try_close(self,do_close) end
end
return {set_language=set_language}
