-- Application modal dialogs. Keep warnings in the log without using the status/nag bar.
local T=require('litefront.i18n').t
local core=require 'core'
local style=require 'core.style'
local common=require 'core.common'
local command=require 'core.command'
local visual=require 'litefront.visual'
local RootView=require 'core.rootview'
local dialogs={queue={},active=nil}

local function next_dialog()
  dialogs.active=table.remove(dialogs.queue,1)
  if dialogs.active then
    command.perform('litefront-menu:close')
    command.perform('litefront:close-editor-actions')
    local menu=package.loaded['plugins.contextmenu']
    if menu then menu:hide() end
  end
  core.redraw=true
end
function dialogs.show(title,message,options,callback)
  title,message=tostring(title),tostring(message)
  for _,item in ipairs(dialogs.queue) do
    if item.title==title and item.message==message then return end
  end
  if dialogs.active and dialogs.active.title==title and dialogs.active.message==message then return end
  local item={title=title,message=message,options=options or {{text='OK',default_yes=true,default_no=true}},callback=callback,selected=1,offset=0,buttons={}}
  for i,option in ipairs(item.options) do if option.default_yes then item.selected=i; break end end
  dialogs.queue[#dialogs.queue+1]=item
  if not dialogs.active then next_dialog() end
  return item
end
function dialogs.choose(index)
  local item=dialogs.active
  if not item or not item.options[index] then return end
  if item.options[index].keep_open then
    system.set_clipboard(require('litefront.about').details());item.copied=true;core.redraw=true;return
  end
  next_dialog()
  if item.callback then
    core.add_thread(function() item.callback(item.options[index]) end)
  end
end

function dialogs.show_about()
  local item=dialogs.show('About Jotta Text','',{
    {text='Copy Details',keep_open=true},
    {text='Close',default_yes=true,default_no=true},
  })
  if item then item.about=true end
end

local function wrap(text,width)
  local lines,line={},''
  for char in common.utf8_chars(text) do
    if char=='\n' then lines[#lines+1]=line; line=''
    else
      if style.font:get_width(line..char)>width and line~='' then lines[#lines+1]=line; line='' end
      line=line..char
    end
  end
  lines[#lines+1]=line
  return lines
end
local original_draw=RootView.draw
function RootView:draw(...)
  original_draw(self,...)
  local item=dialogs.active
  if not item then return end
  if item.about then require('litefront.about').draw(item,self);return end
  local pad=20*SCALE
  local w=math.max(1,math.min(640*SCALE,self.size.x-2*pad))
  local lines=wrap(T(item.message),math.max(1,w-2*pad))
  local lh=style.font:get_height()+4*SCALE
  local h=math.min(self.size.y-2*pad,120*SCALE+#lines*lh)
  h=math.max(1,h)
  local x,y=(self.size.x-w)/2,(self.size.y-h)/2
  renderer.draw_rect(0,0,self.size.x,self.size.y,{0,0,0,150})
  visual.rounded(x-8*SCALE,y+8*SCALE,w+16*SCALE,h+12*SCALE,10*SCALE,{0,0,0,55})
  visual.rounded(x-1,y-1,w+2,h+2,7*SCALE,style.divider)
  visual.rounded(x,y,w,h,6*SCALE,style.background2)
  core.push_clip_rect(x,y,w,h)
  visual.icon('problem',x+pad,y+17*SCALE,20*SCALE,style.accent)
  renderer.draw_text(style.bold_font,T(item.title),x+pad+30*SCALE,y+pad,style.text)
  local rows=math.max(1,math.floor((h-110*SCALE)/lh))
  item.max_offset=math.max(0,#lines-rows)
  item.offset=math.min(item.offset,item.max_offset)
  core.push_clip_rect(x+pad,y+54*SCALE,w-2*pad,math.max(1,h-110*SCALE))
  for i=item.offset+1,math.min(#lines,item.offset+rows) do
    renderer.draw_text(style.font,lines[i],x+pad,y+54*SCALE+(i-item.offset-1)*lh,style.text)
  end
  core.pop_clip_rect()
  item.buttons={}
  local bx=x+w-pad
  for i=#item.options,1,-1 do
    local label=T(item.options[i].text)
    local bw=math.max(72*SCALE,style.font:get_width(label)+24*SCALE)
    bx=bx-bw
    local by=y+h-44*SCALE
    visual.rounded(bx,by,bw,30*SCALE,4*SCALE,i==item.selected and style.accent or style.background3)
    common.draw_text(style.font,i==item.selected and style.accent_text or style.text,label,'center',bx,by,bw,30*SCALE)
    item.buttons[i]={x=bx,y=by,w=bw,h=30*SCALE}
    bx=bx-8*SCALE
  end
  core.pop_clip_rect()
end
local on_event=core.on_event
function core.on_event(kind,...)
  if kind=='mousereleased' and dialogs.suppress_release then dialogs.suppress_release=nil; return true end
  local item=dialogs.active
  if not item then return on_event(kind,...) end
  if kind=='keypressed' then
    local key=...
    if key=='return' or key=='keypad enter' then dialogs.choose(item.selected)
    elseif key=='escape' then
      for i,option in ipairs(item.options) do
        if option.default_no or option.text=='Cancel' or #item.options==1 then dialogs.choose(i); break end
      end
    elseif key=='left' or key=='right' or key=='tab' then
      item.selected=(item.selected+(key=='left' and -2 or 0))%#item.options+1
      core.redraw=true
    elseif key=='up' or key=='down' then
      item.offset=math.max(0,math.min(item.max_offset or 0,item.offset+(key=='up' and -1 or 1)))
      core.redraw=true
    end
    return true
  elseif kind=='mousepressed' then
    local button,x,y=...
    if button=='left' then
      for i,b in ipairs(item.buttons) do
        if x>=b.x and x<b.x+b.w and y>=b.y and y<b.y+b.h then dialogs.suppress_release=true; dialogs.choose(i); break end
      end
    end
    return true
  elseif kind=='mousewheel' then
    local dy=...
    item.offset=math.max(0,math.min(item.max_offset or 0,item.offset-dy*3));core.redraw=true
    return true
  elseif kind=='textinput' or kind=='textediting' or kind=='mousemoved' or kind=='mousereleased' or kind=='filedropped' then
    return true
  end
  -- Let modifier releases, resize, focus and window-close events reach the editor.
  return on_event(kind,...)
end
local custom_log=core.custom_log
function core.custom_log(level,show,backtrace,...)
  if show and (level=='WARN' or level=='ERROR') then
    local item=custom_log(level,false,backtrace,...)
    dialogs.show(level=='WARN' and 'Warning' or 'Error',item.text)
    return item
  end
  return custom_log(level,show,backtrace,...)
end
function core.nag_view:show(title,message,options,on_select)
  dialogs.show(title,message,options,on_select)
end
return dialogs
