local core=require 'core'
local View=require 'core.view'
local style=require 'core.style'
local common=require 'core.common'
local visual=require 'litefront.visual'
local keymap=require 'core.keymap'
local MediaView=View:extend()
MediaView.context='session'
function MediaView:new(filename,kind)
  MediaView.super.new(self)
  self.filename=filename;self.abs_filename=filename;self.litefront_media=kind
  self.scrollable=true
  self.font_size=32;self.weight=400
  self.sample='The quick brown fox jumps over the lazy dog.'
  self:load()
end
function MediaView:get_name() return common.basename(self.filename) end
function MediaView:load()
  if self.litefront_media=='image' then
    local image=renderer.image.load(self.filename)
    self.image=image;self.image_width,self.image_height=image:get_size()
  else
    local font=renderer.font.load(self.filename,self.font_size*SCALE,{weight=self.weight,kerning=true,antialiasing='grayscale',hinting='slight'})
    self.font_info=font:get_info();self.font=font;self.specimen_key=nil
  end
  core.redraw=true
end
function MediaView:change_zoom(factor)
  if self.litefront_media=='image' then
    self.zoom=common.clamp(self:image_scale()*factor,.01,32)
  else self.font_size=common.clamp(math.floor(self.font_size*factor+.5),8,128);self:load() end
  core.redraw=true
end
function MediaView:edit_sample()
  core.command_view:enter('Sample text',{
    text=self.sample,select_text=true,show_suggestions=false,typeahead=false,
    submit=function(text) self.sample=text:sub(1,2048);self.specimen_key=nil;core.redraw=true end,
  })
end
function MediaView:choose_weight()
  local choices={}
  for weight=100,900,100 do choices[#choices+1]={text=tostring(weight),weight=weight} end
  core.command_view:enter('Font weight',{picker=true,typeahead=false,
    suggest=function(text)
      local result={}
      for _,item in ipairs(choices) do if item.text:find(text,1,true) then result[#result+1]=item end end
      return result
    end,
    submit=function(_,item) if item then self.weight=item.weight;self:load() end end,
  })
end
function MediaView:toolbar()
  local actions
  if self.litefront_media=='image' then
    actions={{'Fit',function() self.zoom=nil;self.scroll.to.x=0;self.scroll.to.y=0 end},
      {'100%',function() self.zoom=1;self.scroll.to.x=0;self.scroll.to.y=0 end},
      {'−',function() self:change_zoom(1/1.25) end},{'+',function() self:change_zoom(1.25) end}}
  else
    actions={{'−',function() self:change_zoom(1/1.2) end},{'+',function() self:change_zoom(1.2) end},
      {'Sample text…',function() self:edit_sample() end}}
    if self.font_info.variable then actions[#actions+1]={require('litefront.i18n').t('Weight %d…',self.weight),function() self:choose_weight() end} end
  end
  if self.filename:lower():match('%.svg$') then actions[#actions+1]={'Source',function() require('plugins.litefront_media').open_text(self.filename) end} end
  if self.litefront_media=='font' then
    for _,entry in ipairs({{'Use for UI','ui'},{'Use for Code','code'}}) do
      local kind=entry[2]
      actions[#actions+1]={entry[1],function()
        local preferences=require 'litefront.fonts'
        preferences.selected[kind]=self.filename;preferences.save();visual.theme_fonts(visual.mode)
      end}
    end
  end
  actions[#actions+1]={'Reload',function() self:load() end}
  local x,y=8*SCALE,6*SCALE
  local buttons={}
  for _,action in ipairs(actions) do
    local width=style.font:get_width(require('litefront.i18n').t(action[1]))+20*SCALE
    if x+width>self.size.x-8*SCALE and x>8*SCALE then x=8*SCALE;y=y+34*SCALE end
    buttons[#buttons+1]={x=x,y=y,w=width,h=28*SCALE,label=action[1],action=action[2]}
    x=x+width+6*SCALE
  end
  return buttons,y+56*SCALE
end
function MediaView:image_scale()
  if self.zoom then return self.zoom end
  local _,header=self:toolbar()
  return math.max(.001,math.min(1,math.max(1,self.size.x-32*SCALE)/self.image_width,
    math.max(1,self.size.y-header-32*SCALE)/self.image_height))
end
function MediaView:specimen()
  local _,header=self:toolbar()
  local key=table.concat({self.size.x,SCALE,self.font_size,self.weight,self.sample,tostring(style.small_font)},':')
  if key==self.specimen_key then return self.specimen_runs,self.specimen_height+header end
  local runs,y={},20*SCALE
  local width=math.max(1,self.size.x-40*SCALE)
  for _,size in ipairs({math.max(12,math.floor(self.font_size*.6)),self.font_size,math.floor(self.font_size*1.5)}) do
    local font=renderer.font.load(self.filename,size*SCALE,{weight=self.weight,kerning=true,antialiasing='grayscale',hinting='slight'})
    runs[#runs+1]={text=size..' px',font=style.small_font,y=y,label=true};y=y+style.small_font:get_height()+8*SCALE
    for _,text in ipairs({self.sample,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz','0123456789 !? @#$% &* () [] {} — é à ç ñ'}) do
      local line=''
      for char in common.utf8_chars(text) do
        if line~='' and font:get_width(line..char)>width then
          runs[#runs+1]={text=line,font=font,y=y};y=y+font:get_height()+6*SCALE;line=''
        end
        line=line..char
      end
      runs[#runs+1]={text=line,font=font,y=y};y=y+font:get_height()+6*SCALE
    end
    y=y+24*SCALE
  end
  self.specimen_key=key;self.specimen_runs=runs;self.specimen_height=y
  return runs,y+header
end
function MediaView:get_scrollable_size()
  local _,header=self:toolbar()
  if self.litefront_media=='image' then return header+self.image_height*self:image_scale()+32*SCALE end
  local _,height=self:specimen();return height
end
function MediaView:get_h_scrollable_size()
  if self.litefront_media=='image' then return self.image_width*self:image_scale()+32*SCALE end
  return self.size.x
end
function MediaView:on_mouse_pressed(button,x,y,clicks)
  local buttons,header=self:toolbar()
  if button=='left' and y<self.position.y+header then
    for _,b in ipairs(buttons) do
      if x>=self.position.x+b.x and x<self.position.x+b.x+b.w and y>=self.position.y+b.y and y<self.position.y+b.y+b.h then
        local ok,err=pcall(b.action)
        if not ok then core.error('Could not preview file: %s',err) end
        core.redraw=true;return true
      end
    end
    return true
  end
  if MediaView.super.on_mouse_pressed(self,button,x,y,clicks) then return true end
  if button=='left' and self.litefront_media=='image' then self.panning=true;self.cursor='hand';return true end
end
function MediaView:on_mouse_moved(x,y,dx,dy)
  if self.panning then self.scroll.to.x=self.scroll.to.x-dx;self.scroll.to.y=self.scroll.to.y-dy;self:clamp_scroll_position();core.redraw=true;return true end
  return MediaView.super.on_mouse_moved(self,x,y,dx,dy)
end
function MediaView:on_mouse_released(...)
  self.panning=false;self.cursor='arrow';return MediaView.super.on_mouse_released(self,...)
end
function MediaView:on_mouse_wheel(y,x)
  if keymap.modkeys['ctrl'] then self:change_zoom(y>0 and 1.2 or 1/1.2)
  else self.scroll.to.y=self.scroll.to.y-y*40*SCALE;self.scroll.to.x=self.scroll.to.x-(x or 0)*40*SCALE end
  core.redraw=true;return true
end
function MediaView:draw()
  self:draw_background(style.ui_background or style.background)
  local buttons,header=self:toolbar()
  local left,top=self.position.x,self.position.y
  core.push_clip_rect(left,top+header,self.size.x,math.max(0,self.size.y-header))
  if self.litefront_media=='image' then
    local scale=self:image_scale()
    local width,height=self.image_width*scale,self.image_height*scale
    local x=left+math.max(16*SCALE,(self.size.x-width)/2)-self.scroll.x
    local y=top+header+math.max(16*SCALE,(self.size.y-header-height)/2)-self.scroll.y
    local tile=12*SCALE
    -- Only draw visible checkerboard cells, even when zoomed far beyond the pane.
    local x1=math.max(0,math.floor((left-x)/tile));local x2=math.min(math.ceil(width/tile)-1,math.ceil((left+self.size.x-x)/tile))
    local y1=math.max(0,math.floor((top+header-y)/tile));local y2=math.min(math.ceil(height/tile)-1,math.ceil((top+self.size.y-y)/tile))
    for row=y1,y2 do for col=x1,x2 do
      renderer.draw_rect(x+col*tile,y+row*tile,math.min(tile,width-col*tile),math.min(tile,height-row*tile),(row+col)%2==0 and style.background2 or style.background3)
    end end
    renderer.draw_image(self.image,x,y,width,height)
  else
    for _,run in ipairs(self:specimen()) do
      local y=top+header+run.y-self.scroll.y
      if y+run.font:get_height()>top+header and y<top+self.size.y then
        renderer.draw_text(run.font,run.text,left+20*SCALE,y,run.label and style.dim or style.text)
      end
    end
  end
  core.pop_clip_rect()
  self:draw_scrollbar()
  renderer.draw_rect(left,top,self.size.x,header,style.background2)
  for _,b in ipairs(buttons) do
    visual.rounded(left+b.x,top+b.y,b.w,b.h,4*SCALE,style.hover_background)
    visual.text(style.font,require('litefront.i18n').t(b.label),left+b.x,top+b.y,b.w,b.h,style.text,'center')
  end
  local info
  if self.litefront_media=='image' then info=self.image_width..' × '..self.image_height..' px  ·  '..math.floor(self:image_scale()*100+.5)..'%'
  else info=self.font_info.family..'  ·  '..self.font_info.style..'  ·  '..self.font_size..' px' end
  visual.text(style.small_font,info,left+10*SCALE,top+header-22*SCALE,self.size.x-20*SCALE,20*SCALE,style.dim)
  renderer.draw_rect(left,top+header-1,self.size.x,1,style.divider)
end
return MediaView
