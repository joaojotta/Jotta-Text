-- Native adaptation of Jotta Edit's custom color editor (assets/reference/).
local T=require('litefront.i18n').t
local core=require 'core'
local style=require 'core.style'
local common=require 'core.common'
local colors=require 'litefront.colors'
local inline=require 'litefront.color_inline'
local visual=require 'litefront.visual'
local json=require 'plugins.json'
local M={active=nil,favorites={},recents={}}
local path=USERDIR..'/colors.json'
local function clone(c) return {r=c.r,g=c.g,b=c.b,a=c.a or 1,kind=c.kind} end
local function key(c) return colors.format({r=c.r,g=c.g,b=c.b,a=1})..'/'..tostring(c.a or 1) end
local function normalize(list,limit)
  local result,seen={},{}
  for _,entry in ipairs(type(list)=='table' and list or {}) do
    local c=type(entry)=='table' and colors.parse(entry.colour)
    if c and type(entry.alpha)=='number' and entry.alpha>=0 and entry.alpha<=1 then
      c.a=entry.alpha
      if not seen[key(c)] then
        result[#result+1]={color=c,name=type(entry.name)=='string' and entry.name:sub(1,64) or ''};seen[key(c)]=true
        if #result>=limit then break end
      end
    end
  end
  return result
end
local file=io.open(path,'r')
if file then
  local ok,data=pcall(json.decode,file:read('*a'));file:close()
  if ok and type(data)=='table' then M.favorites=normalize(data.favorites,30);M.recents=normalize(data.recents,12) end
end
function M.save_library()
  local function encode(list)
    local result={}
    for _,entry in ipairs(list) do result[#result+1]={colour=colors.format({r=entry.color.r,g=entry.color.g,b=entry.color.b,a=1}),alpha=entry.color.a,name=entry.name} end
    return result
  end
  local out,err=io.open(path..'.tmp','w')
  if not out then core.error('Could not save colors: %s',err);return end
  local written,message=out:write(json.encode({favorites=encode(M.favorites),recents=encode(M.recents)}))
  local closed,close_error=out:close()
  if not written or not closed then core.error('Could not save colors: %s',message or close_error);return end
  local renamed,rename_error=os.rename(path..'.tmp',path)
  if not renamed then core.error('Could not save colors: %s',rename_error) end
end
local function fields(state)
  if state.format=='hex' then return {{id='hex',label='HEX'}} end
  if state.format=='rgba' then return {{id='r',label='R',min=0,max=255},{id='g',label='G',min=0,max=255},{id='b',label='B',min=0,max=255},{id='a',label='A',min=0,max=1}} end
  if state.format=='hsl' then return {{id='h',label='H °',min=0,max=360},{id='s',label='S %',min=0,max=100},{id='l',label='L %',min=0,max=100},{id='a',label='A',min=0,max=1}} end
  return {{id='c',label='C %',min=0,max=100},{id='m',label='M %',min=0,max=100},{id='y',label='Y %',min=0,max=100},{id='k',label='K %',min=0,max=100}}
end
local function sync(skip)
  local state=M.active;if not state then return end
  local c=state.current;local h=state.hsl;local cm=colors.to_cmyk(c)
  local values={hex=colors.format(c),r=c.r,g=c.g,b=c.b,a=math.floor(c.a*100+.5)/100,h=h.h,s=h.s,l=h.l,c=cm.c,m=cm.m,y=cm.y,k=cm.k}
  for id,value in pairs(values) do
    if id~=skip then state.inputs[id]=tostring(value):gsub('%.0$','') end
  end
  core.redraw=true
end
function M.set_color(color,keep_hsl,skip)
  local state=M.active;if not state then return end
  state.current=clone(color);state.valid=true
  if not keep_hsl then state.hsl=colors.to_hsl(state.current) end
  sync(skip)
end
local function validate_input(id)
  local state=M.active
  if id=='name' then return end
  if state.format=='hex' then
    local value=state.inputs.hex
    local c=colors.parse(value:sub(1,1)=='#' and value or '#'..value)
    if not c or c.kind~='hex' then state.valid=false;return end
    M.set_color(c,false,id);return
  end
  local values={}
  for _,field in ipairs(fields(state)) do
    local value=tonumber(((state.inputs[field.id] or ''):gsub('%%$','')))
    if not value or value<field.min or value>field.max then state.valid=false;return end
    values[field.id]=value
  end
  if state.format=='rgba' then
    M.set_color({r=math.floor(values.r+.5),g=math.floor(values.g+.5),b=math.floor(values.b+.5),a=values.a},false,id)
  elseif state.format=='hsl' then
    state.hsl={h=values.h,s=values.s,l=values.l};M.set_color(colors.hsl(values.h,values.s,values.l,values.a),true,id)
  else M.set_color(colors.cmyk(values.c,values.m,values.y,values.k,state.current.a),false,id) end
end
function M.close()
  local state=M.active;M.active=nil;core.redraw=true
  if state and state.on_close then state.on_close() end
end
local group=-1000000
function M.remember(remembered)
  for i=#M.recents,1,-1 do if key(M.recents[i].color)==key(remembered) then table.remove(M.recents,i) end end
  table.insert(M.recents,1,{color=clone(remembered),name=''})
  while #M.recents>12 do table.remove(M.recents) end
  M.save_library()
end
function M.open_external(color,callback,on_close)
  local c=type(color)=='string' and colors.parse(color) or color
  if not c then return end
  M.active={external=true,on_apply=callback,on_close=on_close,original=clone(c),current=clone(c),hsl=colors.to_hsl(c),format='hex',inputs={name=''},valid=true,scroll=0,caret=1,anchor=1}
  sync()
end
function M.apply()
  local state=M.active
  if not state or not state.valid then return end
  if state.external then
    local c=clone(state.current);local callback=state.on_apply;M.close()
    if callback(colors.format(c,'hex'),c)~=false then M.remember(c) end
    return
  end
  if not core.root_view.root_node:get_node_for_view(state.view) or state.doc.lines[state.line]~=state.source then
    M.close();core.error('Color could not be applied: source changed');return
  end
  local output=colors.format(state.current,state.format)
  local doc=state.doc;local hit=state.hit
  local first=doc.undo_stack.idx
  if output~=hit.text then
    doc:replace_cursor(1,state.line,hit.start,state.line,hit.finish,function() return output end)
    group=group-require('core.config').undo_merge_timeout-1
    for i=first,doc.undo_stack.idx-1 do doc.undo_stack[i].time=group end
    doc:set_selection(state.line,hit.start,state.line,hit.start+#output)
  end
  local node=core.root_view.root_node:get_node_for_view(state.view)
  node:set_active_view(state.view)
  local remembered=clone(state.current)
  M.close();M.remember(remembered)
end
function M.open(view,line,hit)
  if require('litefront.dialogs').active then return end
  require('core.command').perform('litefront-menu:close')
  require('core.command').perform('litefront:close-editor-actions')
  local menu=package.loaded['plugins.contextmenu'];if menu then menu:hide() end
  core.status_view:remove_tooltip()
  M.active={view=view,doc=view.doc,line=line,hit=hit,source=view.doc.lines[line],original=clone(hit.color),
    current=clone(hit.color),hsl=colors.to_hsl(hit.color),format=hit.color.kind=='rgba' and 'rgba' or hit.color.kind,
    inputs={name=''},valid=true,scroll=0,caret=1,anchor=1}
  sync()
end
function M.at_cursor()
  local view=visual.document_view()
  if not view then return end
  local line,col=view.doc:get_selection()
  for _,hit in ipairs(inline.hits(view.doc,line)) do if col>=hit.start and col<=hit.finish then M.open(view,line,hit);return end end
  core.log('Place the cursor on a HEX, RGB or HSL color value to edit it')
end
function M.layout()
  local state=M.active;if not state then return end
  local scale=SCALE
  local w=math.max(1,math.min(480*scale,core.root_view.size.x-24*scale))
  local h=math.max(1,math.min(840*scale,core.root_view.size.y-24*scale))
  local x=colors.clamp(state.x or (core.root_view.size.x-w)/2,0,math.max(0,core.root_view.size.x-w))
  local y=colors.clamp(state.y or (core.root_view.size.y-h)/2,0,math.max(0,core.root_view.size.y-h))
  state.panel={x=x,y=y,w=w,h=h};state.body={x=x,y=y+42*scale,w=w,h=math.max(1,h-94*scale)}
  state.controls={}
  local controls=state.controls
  local function add(kind,id,px,py,pw,ph,data,body)
    local c={kind=kind,id=id,x=px,y=py,w=pw,h=ph,data=data,body=body}
    controls[#controls+1]=c;return c
  end
  local pad,cw=18*scale,w-48*scale
  local yy=8*scale
  local function body(kind,id,px,py,pw,ph,data) return add(kind,id,x+pad+px,state.body.y+py-state.scroll,pw,ph,data,true) end
  body('preview','original',0,yy,cw/2,54*scale,state.original)
  body('preview','selected',cw/2,yy,cw/2,54*scale,state.current);yy=yy+56*scale
  body('label','original-label',0,yy,cw/2,22*scale,'Original')
  body('label','selected-label',cw/2,yy,cw/2,22*scale,'Selected');yy=yy+24*scale
  body('label','output',0,yy,cw,26*scale,colors.format(state.current,state.format));yy=yy+30*scale
  for i,format in ipairs({'hex','rgba','hsl','cmyk'}) do body('tab',format,(i-1)*cw/4,yy,cw/4-4*scale,28*scale,format:upper()) end
  yy=yy+48*scale
  local defs=fields(state);local width=(cw-(#defs-1)*8*scale)/#defs
  for i,field in ipairs(defs) do
    body('label','label-'..field.id,(i-1)*(width+8*scale),yy-18*scale,width,18*scale,field.label)
    body('field',field.id,(i-1)*(width+8*scale),yy,width,30*scale,field)
  end
  yy=yy+34*scale
  body('label','validation',0,yy,cw,20*scale,not state.valid and 'Enter a valid color value' or state.format=='cmyk' and 'Approximate CMYK; applies CSS-compatible HEX.' or '')
  yy=yy+26*scale
  for _,slider in ipairs({{'h','Hue',360},{'s','Saturation',100},{'l','Lightness',100},{'a','Opacity',1}}) do
    body('label','slider-label-'..slider[1],0,yy,cw,18*scale,slider[2])
    body('slider',slider[1],0,yy+20*scale,cw,18*scale,slider[3]);yy=yy+48*scale
  end
  body('label','presets-title',0,yy,cw,24*scale,'Preset colors');yy=yy+26*scale
  local columns=math.max(1,math.min(10,math.floor(cw/(32*scale))));local cell=cw/columns
  for i,value in ipairs(colors.presets) do body('color','preset-'..i,((i-1)%columns)*cell,yy+math.floor((i-1)/columns)*34*scale,26*scale,26*scale,colors.parse(value)) end
  yy=yy+math.ceil(#colors.presets/columns)*34*scale+8*scale
  body('label','favorites-title',0,yy,cw,24*scale,T('Favorites (%d/30)',#M.favorites));yy=yy+26*scale
  body('field','name',0,yy,math.max(1,cw-120*scale),30*scale,{label='Name (optional)'})
  body('button','save-favorite',cw-112*scale,yy,112*scale,30*scale,'Save current');yy=yy+38*scale
  if #M.favorites==0 then body('label','empty-favorites',0,yy,cw,24*scale,'No favorite colors yet.');yy=yy+28*scale end
  for i,entry in ipairs(M.favorites) do
    local fx=((i-1)%2)*cw/2;local fy=yy+math.floor((i-1)/2)*34*scale
    body('favorite','favorite-'..i,fx,fy,cw/2-24*scale,28*scale,entry)
    body('delete','delete-'..i,fx+cw/2-24*scale,fy,20*scale,28*scale,i)
  end
  yy=yy+math.ceil(#M.favorites/2)*34*scale+8*scale
  body('label','recents-title',0,yy,cw-84*scale,24*scale,'Recent colors')
  body('button','clear-recents',cw-78*scale,yy,78*scale,24*scale,'Clear');yy=yy+28*scale
  for i,entry in ipairs(M.recents) do body('color','recent-'..i,((i-1)%columns)*cell,yy+math.floor((i-1)/columns)*34*scale,26*scale,26*scale,entry.color) end
  yy=yy+math.max(1,math.ceil(#M.recents/columns))*34*scale+16*scale
  state.max_scroll=math.max(0,yy-state.body.h)
  local old=state.scroll;state.scroll=colors.clamp(state.scroll,0,state.max_scroll)
  for _,c in ipairs(controls) do if c.body then c.y=c.y+old-state.scroll end end
  add('close','close',x+w-34*scale,y+7*scale,26*scale,28*scale)
  add('button','cancel',x+w-206*scale,y+h-40*scale,88*scale,30*scale,'Cancel')
  add('button','apply',x+w-108*scale,y+h-40*scale,90*scale,30*scale,'Apply')
  if state.max_scroll>0 then
    local thumb=math.max(24*scale,state.body.h*state.body.h/yy)
    add('scroll-track','scroll-track',x+w-12*scale,state.body.y,7*scale,state.body.h)
    add('scrollbar','scrollbar',x+w-12*scale,state.body.y+(state.body.h-thumb)*state.scroll/state.max_scroll,7*scale,thumb)
  end
  return state
end
local function inside(c,x,y) return x>=c.x and x<c.x+c.w and y>=c.y and y<c.y+c.h end
function M.control_at(x,y)
  local state=M.layout();if not state then return end
  for i=#state.controls,1,-1 do local c=state.controls[i];if inside(c,x,y) and (not c.body or inside(state.body,x,y)) then return c end end
end
local function gradient(state,id,value)
  local h=state.hsl
  if id=='h' then return colors.hsl(value,100,50,1)
  elseif id=='s' then return colors.hsl(h.h,value,h.l,1)
  elseif id=='l' then return colors.hsl(h.h,h.s,value,1)
  else local c=clone(state.current);c.a=value;return c end
end
function M.draw()
  local state=M.layout();if not state or require('litefront.dialogs').active then return end
  local p=state.panel
  renderer.draw_rect(0,0,core.root_view.size.x,core.root_view.size.y,{0,0,0,110})
  visual.rounded(p.x-1,p.y-1,p.w+2,p.h+2,8*SCALE,style.divider)
  visual.rounded(p.x,p.y,p.w,p.h,8*SCALE,style.background2)
  visual.text(style.bold_font,T('Edit Color'),p.x+18*SCALE,p.y,p.w-60*SCALE,42*SCALE,style.text)
  local function draw(c)
    if c.kind=='label' then
      visual.text(c.id=='output' and style.code_font or style.small_font,T(c.data),c.x,c.y,c.w,c.h,c.id=='validation' and not state.valid and {224,90,90,255} or style.dim)
    elseif c.kind=='preview' then
      local step=8*SCALE
      for row=0,math.ceil(c.h/step)-1 do for col=0,math.ceil(c.w/step)-1 do renderer.draw_rect(c.x+col*step,c.y+row*step,math.min(step,c.w-col*step),math.min(step,c.h-row*step),(row+col)%2==0 and {220,220,220,255} or {150,150,150,255}) end end
      renderer.draw_rect(c.x,c.y,c.w,c.h,colors.rgba(c.data))
    elseif c.kind=='tab' or c.kind=='button' then
      local selected=c.kind=='tab' and state.format==c.id or c.id=='apply'
      local disabled=(c.id=='apply' or c.id=='save-favorite') and not state.valid
      visual.rounded(c.x,c.y,c.w,c.h,4*SCALE,selected and not disabled and style.accent or style.hover_background)
      visual.text(style.font,T(c.data),c.x,c.y,c.w,c.h,disabled and style.dim or selected and style.accent_text or style.text,'center')
    elseif c.kind=='field' then
      visual.rounded(c.x-1,c.y-1,c.w+2,c.h+2,4*SCALE,state.focus==c.id and style.accent or style.divider)
      visual.rounded(c.x,c.y,c.w,c.h,3*SCALE,style.input_background)
      local text=state.inputs[c.id] or ''
      core.push_clip_rect(c.x+5*SCALE,c.y,c.w-10*SCALE,c.h)
      local offset=0
      if state.focus==c.id then offset=math.max(0,style.font:get_width(text:sub(1,state.caret-1))-c.w+18*SCALE) end
      local tx=c.x+7*SCALE-offset
      if state.focus==c.id and state.anchor~=state.caret then
        local first,last=math.min(state.anchor,state.caret),math.max(state.anchor,state.caret)
        renderer.draw_rect(tx+style.font:get_width(text:sub(1,first-1)),c.y+4*SCALE,style.font:get_width(text:sub(first,last-1)),c.h-8*SCALE,style.ui_selection or style.selection)
      end
      local ty=c.y+(c.h-style.font:get_height())/2
      renderer.draw_text(style.font,text=='' and c.id=='name' and T('Name (optional)') or text,tx,ty,text=='' and style.dim or style.text)
      if state.focus==c.id then renderer.draw_rect(tx+style.font:get_width(text:sub(1,state.caret-1)),c.y+5*SCALE,1, c.h-10*SCALE,style.caret) end
      core.pop_clip_rect()
    elseif c.kind=='slider' then
      for i=0,95 do renderer.draw_rect(c.x+i*c.w/96,c.y,math.ceil(c.w/96),c.h,colors.rgba(gradient(state,c.id,i/95*c.data))) end
      local value=c.id=='a' and state.current.a or state.hsl[c.id]
      local pos=c.x+value/c.data*c.w
      renderer.draw_rect(pos-2*SCALE,c.y-2*SCALE,4*SCALE,c.h+4*SCALE,style.text)
      visual.text(style.small_font,string.format(c.id=='h' and '%.0f°' or c.id=='a' and '%.0f%%' or '%.0f%%',c.id=='a' and value*100 or value),c.x+c.w-65*SCALE,c.y-20*SCALE,65*SCALE,18*SCALE,style.text,'right')
    elseif c.kind=='color' then
      inline.swatch(c.x,c.y,c.w,c.data)
      if key(c.data)==key(state.current) then renderer.draw_rect(c.x,c.y+c.h+2*SCALE,c.w,2*SCALE,style.accent) end
    elseif c.kind=='favorite' then
      inline.swatch(c.x,c.y,24*SCALE,c.data.color)
      visual.text(style.small_font,c.data.name~='' and c.data.name or colors.format(c.data.color),c.x+30*SCALE,c.y,c.w-32*SCALE,c.h,style.text)
    elseif c.kind=='delete' or c.kind=='close' then visual.icon('close',c.x+(c.w-14*SCALE)/2,c.y+(c.h-14*SCALE)/2,14*SCALE,style.dim)
    elseif c.kind=='scroll-track' then visual.rounded(c.x,c.y,c.w,c.h,3*SCALE,style.background3)
    elseif c.kind=='scrollbar' then visual.rounded(c.x,c.y,c.w,c.h,3*SCALE,style.dim) end
  end
  core.push_clip_rect(state.body.x,state.body.y,state.body.w,state.body.h)
  for _,c in ipairs(state.controls) do if c.body and c.y+c.h>=state.body.y and c.y<=state.body.y+state.body.h then draw(c) end end
  core.pop_clip_rect()
  renderer.draw_rect(p.x,p.y+p.h-52*SCALE,p.w,1,style.divider)
  for _,c in ipairs(state.controls) do if not c.body then draw(c) end end
end
local function slide(c,x)
  local state=M.active;local value=colors.clamp((x-c.x)/c.w,0,1)*c.data
  state.focus=nil;state.slider_focus=c.id
  if c.id=='a' then state.current.a=value else state.hsl[c.id]=value;state.current=colors.hsl(state.hsl.h,state.hsl.s,state.hsl.l,state.current.a) end
  state.valid=true;sync()
end
function M.click(button,x,y)
  if button~='left' then return end
  local state=M.layout();if not state then return end
  local c=M.control_at(x,y)
  if not c then
    if not inside(state.panel,x,y) then M.close()
    elseif y<state.body.y then state.drag={kind='window',dx=x-state.panel.x,dy=y-state.panel.y} end
    return
  end
  if c.kind~='slider' then state.slider_focus=nil end
  if c.kind=='field' then state.focus=c.id;state.caret=#(state.inputs[c.id] or '')+1;state.anchor=1
  elseif c.kind=='slider' then state.drag={kind='slider',control=c};slide(c,x)
  elseif c.kind=='scroll-track' then
    local thumb
    for _,control in ipairs(state.controls) do if control.kind=='scrollbar' then thumb=control;break end end
    state.scroll=colors.clamp(state.scroll+(y<thumb.y and -1 or 1)*state.body.h,0,state.max_scroll)
  elseif c.kind=='scrollbar' then state.drag={kind='scrollbar',dy=y-c.y,height=c.h}
  elseif c.kind=='tab' then state.format=c.id;state.focus=nil;state.valid=true;sync()
  elseif c.kind=='color' or c.kind=='favorite' then state.focus=nil;M.set_color(c.kind=='favorite' and c.data.color or c.data)
  elseif c.kind=='delete' then table.remove(M.favorites,c.data);M.save_library()
  elseif c.id=='close' or c.id=='cancel' then M.close()
  elseif c.id=='apply' then M.apply()
  elseif c.id=='clear-recents' then M.recents={};M.save_library()
  elseif c.id=='save-favorite' and state.valid then
    local found
    for _,entry in ipairs(M.favorites) do if key(entry.color)==key(state.current) then found=entry;break end end
    local name=(state.inputs.name or ''):match('^%s*(.-)%s*$'):sub(1,64)
    if found then if name~='' then found.name=name end
    elseif #M.favorites<30 then M.favorites[#M.favorites+1]={color=clone(state.current),name=name} end
    M.save_library()
  end
  core.redraw=true
end
function M.move(x,y)
  local state=M.active;if not state or not state.drag then return end
  local drag=state.drag
  if drag.kind=='window' then state.x=x-drag.dx;state.y=y-drag.dy
  elseif drag.kind=='slider' then slide(drag.control,x)
  else state.scroll=colors.clamp((y-state.body.y-drag.dy)/math.max(1,state.body.h-drag.height)*state.max_scroll,0,state.max_scroll) end
  core.redraw=true
end
local function previous(text,pos) return pos>1 and (utf8.offset(text,-1,pos) or 1) or 1 end
local function following(text,pos) return pos<=#text and (utf8.offset(text,2,pos) or #text+1) or #text+1 end
function M.input(text)
  local state=M.active;if not state or not state.focus then return end
  local id=state.focus;local value=state.inputs[id] or ''
  local first,last=math.min(state.anchor,state.caret),math.max(state.anchor,state.caret)
  text=text:gsub('[\r\n]','')
  if #value- (last-first)+#text>(id=='name' and 64 or 100) then return end
  state.inputs[id]=value:sub(1,first-1)..text..value:sub(last)
  state.caret=first+#text;state.anchor=state.caret
  validate_input(id);core.redraw=true
end
function M.key(key)
  local state=M.active;if not state then return end
  local mods=require('core.keymap').modkeys
  if key=='escape' then M.close();return end
  if key=='return' or key=='keypad enter' then M.apply();return end
  if key=='tab' then
    local defs=fields(state);defs[#defs+1]={id='name'}
    local index=0;for i,field in ipairs(defs) do if field.id==state.focus then index=i end end
    if index==0 and mods.shift then index=1 end
    local field=defs[(index+(mods.shift and -2 or 0))%#defs+1]
    state.focus=field.id;state.caret=#(state.inputs[field.id] or '')+1;state.anchor=1;core.redraw=true;return
  end
  if not state.focus then
    if state.slider_focus and (key=='left' or key=='right' or key=='up' or key=='down') then
      local id=state.slider_focus;local direction=(key=='left' or key=='down') and -1 or 1
      if id=='a' then state.current.a=colors.clamp(state.current.a+direction*.01,0,1)
      else state.hsl[id]=colors.clamp(state.hsl[id]+direction,0,id=='h' and 360 or 100);state.current=colors.hsl(state.hsl.h,state.hsl.s,state.hsl.l,state.current.a) end
      state.valid=true;sync()
    end
    return
  end
  local value=state.inputs[state.focus] or ''
  if key=='up' or key=='down' then
    for _,field in ipairs(fields(state)) do
      if field.id==state.focus and field.min then
        local v=tonumber(value) or field.min
        state.inputs[field.id]=tostring(colors.clamp(v+(key=='up' and 1 or -1)*(field.id=='a' and .01 or 1),field.min,field.max))
        state.caret=#state.inputs[field.id]+1;state.anchor=state.caret;validate_input(field.id);core.redraw=true;return
      end
    end
  end
  if mods.ctrl and key=='a' then state.anchor=1;state.caret=#value+1
  elseif mods.ctrl and (key=='c' or key=='x') then
    local first,last=math.min(state.anchor,state.caret),math.max(state.anchor,state.caret)
    system.set_clipboard(value:sub(first,last-1));if key=='x' then M.input('') end
  elseif mods.ctrl and key=='v' then M.input(system.get_clipboard() or '')
  elseif key=='left' or key=='right' or key=='home' or key=='end' then
    local pos=key=='home' and 1 or key=='end' and #value+1 or key=='left' and previous(value,state.caret) or following(value,state.caret)
    state.caret=pos;if not mods.shift then state.anchor=pos end
  elseif key=='backspace' or key=='delete' then
    if state.caret==state.anchor then if key=='backspace' then state.anchor=previous(value,state.caret) else state.anchor=following(value,state.caret) end end
    M.input('')
  end
  core.redraw=true
end
return M
