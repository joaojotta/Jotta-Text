local core=require 'core'
local command=require 'core.command'
local colors=require 'litefront.colors'
local inline=require 'litefront.color_inline'
local picker=require 'litefront.color_picker'
local style=require 'core.style'
local root=os.getenv('COLOR_ROOT')
local function near(a,b) assert(math.abs(a-b)<.01,tostring(a)..' differs from '..tostring(b)) end
local function click(id,kind)
  local state=picker.layout();local target
  for _,c in ipairs(state.controls) do if c.id==id and (not kind or c.kind==kind) then target=c;break end end
  assert(target,'missing picker control '..id)
  if target.body and (target.y<state.body.y or target.y+target.h>state.body.y+state.body.h) then
    state.scroll=colors.clamp(state.scroll+target.y-state.body.y,0,state.max_scroll)
    picker.layout()
    for _,c in ipairs(state.controls) do if c.id==id and (not kind or c.kind==kind) then target=c;break end end
  end
  core.on_event('mousepressed','left',target.x+target.w/2,target.y+target.h/2,1)
  core.on_event('mousereleased','left',target.x+target.w/2,target.y+target.h/2)
end
local function fill(id,text) click(id,'field');core.on_event('textinput',text) end
if os.getenv('COLOR_PHASE')=='2' then
  assert(#picker.favorites==1 and picker.favorites[1].name=='My pink','favorite name did not persist')
  near(picker.favorites[1].color.a,.5)
  assert(#picker.recents==1,'recent colors did not persist');near(picker.recents[1].color.a,.5)
  assert(#core.docs==1 and core.docs[1]:is_dirty(),'applied color was not retained with unsaved document')
  return
end
-- Parse the same CSS forms as the reference, including opacity and CSS4 notation.
local tests={['#abc']={170,187,204,1},['#abcd']={170,187,204,221/255},['#11223380']={17,34,51,128/255},
 ['rgba(255, 0, 128, 0.5)']={255,0,128,.5},['rgb(100% 0% 50% / 50%)']={255,0,128,.5},['hsl(120deg, 100%, 50%)']={0,255,0,1},['hsl(240 100% 50% / .25)']={0,0,255,.25}}
for value,expected in pairs(tests) do local c=assert(colors.parse(value),value);near(c.r,expected[1]);near(c.g,expected[2]);near(c.b,expected[3]);near(c.a,expected[4]) end
for _,value in ipairs({'#12','#12345','#1234567','rgb(999,0,0)','rgb(10%, 20%, 110%)','rgba(0,0,0,2)','hsl(1e999,100%,50%)'}) do assert(not colors.parse(value),'accepted invalid color '..value) end
assert(colors.format(colors.cmyk(0,100,100,0))=='#ff0000','CMYK conversion failed')
local doc=core.open_doc(root..'/style.css');local view=core.root_view:open_doc(doc)
core.root_view:update()
local source=table.concat(doc.lines);local revision=doc:get_change_id()
local hits=inline.hits(doc,1);assert(#hits==3,'inline detector did not find all CSS colors')
local gap=inline.gap(view:get_font())
for i,hit in ipairs(hits) do
  near(view:get_col_x_offset(1,hit.start)-view:get_font():get_width(doc.lines[1]:sub(1,hit.start-1)),gap*i)
  local x,y=view:get_line_screen_position(1,hit.start)
  local line,col=view:resolve_screen_position(x+.01,y+view:get_line_height()/2)
  assert(line==1 and col==hit.start,'color insertion broke source/cursor coordinates')
end
local unicode_hit=inline.hits(doc,2)[1]
local ux,uy=view:get_line_screen_position(2,unicode_hit.start)
local ul,uc=view:resolve_screen_position(ux+.01,uy+view:get_line_height()/2)
assert(ul==2 and uc==unicode_hit.start,'UTF-8 prefix broke color/caret mapping')
view:draw()
assert(table.concat(doc.lines)==source and doc:get_change_id()==revision and not doc:is_dirty(),'drawing swatches modified source')
local rect=inline.rect(view,1,hits[1])
-- Color hovering cancels property help, including replies already in flight.
local lsp=require 'plugins.lsp';local listbox=require 'plugins.lsp.listbox'
local active_servers=lsp.get_active_servers;local opened=doc.lsp_open
local show_text=listbox.show_text;local shown=false;local reply
listbox.show_text=function() shown=true end
doc.lsp_open=true
lsp.get_active_servers=function() return {'color_hover_test'} end
local server={capabilities={hoverProvider=true},push_request=function(_,_,request) reply=request.callback end}
lsp.servers_running.color_hover_test=server
local px,py=view:get_line_screen_position(1,2);py=py+view:get_line_height()/2
core.root_view:on_mouse_moved(px,py,0,0)
assert(not lsp.hover_position.color_suppressed,'normal code hover was suppressed')
lsp.request_hover(doc,1,2);assert(reply,'hover request did not start')
local sx,sy=rect.x+rect.w/2,rect.y+rect.h/2
core.root_view:on_mouse_moved(sx,sy,0,0)
assert(lsp.hover_position.color_suppressed and not lsp.hover_timer.started,'swatch hover scheduled language help')
assert(not lsp.get_hovered_location(sx,sy),'swatch returned a language hover target')
reply(server,{result={contents='Property help that arrived late'}})
assert(not shown,'pending hover reply appeared over a color')
local cx,cy=view:get_line_screen_position(1,hits[1].start+1)
core.root_view:on_mouse_moved(cx,cy+view:get_line_height()/2,0,0)
assert(lsp.hover_position.color_suppressed,'color source value still allowed a tooltip')
core.root_view:on_mouse_moved(px,py,0,0)
assert(not lsp.hover_position.color_suppressed and lsp.hover_timer.started,'normal hover did not resume')
reply(server,{result={contents='Normal property help'}})
assert(shown,'normal hover help was disabled')
lsp.hover_timer:stop();listbox.show_text=show_text
lsp.get_active_servers=active_servers;lsp.servers_running.color_hover_test=nil;doc.lsp_open=opened

view:on_mouse_pressed('left',rect.x+rect.w/2,rect.y+rect.h/2,1)
assert(picker.active and picker.active.hit.text=='#abc','clicking swatch did not open picker')
picker.draw()
-- Slider drag, tab navigation and typed fields only change the selected preview.
local hue
for _,c in ipairs(picker.layout().controls) do if c.kind=='slider' and c.id=='h' then hue=c;break end end
picker.active.scroll=math.max(0,hue.y-picker.active.body.y)
picker.layout()
for _,c in ipairs(picker.active.controls) do if c.kind=='slider' and c.id=='h' then hue=c;break end end
core.on_event('mousepressed','left',hue.x+hue.w*.3,hue.y+hue.h/2,1)
core.on_event('mousemoved',hue.x+hue.w*.5,hue.y+hue.h/2,20,0)
core.on_event('mousereleased','left',hue.x+hue.w*.5,hue.y+hue.h/2)
near(picker.active.hsl.h,180);assert(not picker.active.drag,'slider drag did not release')
core.on_event('keypressed','right');near(picker.active.hsl.h,181)
click('rgba');fill('r','255');fill('g','0');fill('b','128');fill('a','0.5')
assert(picker.active.valid,'valid RGBA fields rejected')
assert(table.concat(doc.lines)==source and not doc:is_dirty(),'picker preview changed source before Apply')
click('apply')
local expected=source:sub(1,hits[1].start-1)..'rgba(255, 0, 128, 0.5)'..source:sub(hits[1].finish)
assert(not picker.active and table.concat(doc.lines)==expected,'Apply changed the wrong range')
assert(command.perform('doc:undo'));assert(table.concat(doc.lines)==source and not doc:is_dirty(),'color edit was not one isolated undo step')
assert(command.perform('doc:redo'));assert(table.concat(doc.lines)==expected,'color redo failed')
command.perform('doc:undo')
-- Invalid inputs cannot apply. Cancel and Escape leave content/revision untouched.
picker.open(view,1,inline.hits(doc,1)[1]);fill('hex','#12')
assert(not picker.active.valid,'invalid HEX was accepted');core.on_event('keypressed','return')
assert(picker.active and table.concat(doc.lines)==source,'invalid color applied')
local panel=picker.layout().panel
local old_x,old_y=panel.x,panel.y
core.on_event('mousepressed','left',panel.x+100*SCALE,panel.y+15*SCALE,1)
core.on_event('mousemoved',panel.x+110*SCALE,panel.y+25*SCALE,10*SCALE,10*SCALE)
core.on_event('mousereleased','left',panel.x+110*SCALE,panel.y+25*SCALE)
near(picker.layout().panel.x,old_x+10*SCALE);near(picker.active.panel.y,old_y+10*SCALE)
core.on_event('mousewheel',-3,0)
assert(picker.active.scroll>0,'color dialog wheel did not scroll')
local thumb
for _,c in ipairs(picker.layout().controls) do if c.kind=='scrollbar' then thumb=c end end
assert(thumb,'color dialog has no scrollbar')
core.on_event('mousepressed','left',thumb.x+thumb.w/2,thumb.y+thumb.h/2,1)
core.on_event('mousemoved',thumb.x,9999,0,100)
core.on_event('mousereleased','left',thumb.x,9999)
near(picker.active.scroll,picker.active.max_scroll)
click('cancel');assert(not picker.active and table.concat(doc.lines)==source)
picker.open(view,1,inline.hits(doc,1)[1]);core.on_event('keypressed','escape')
assert(not picker.active and not picker.suppress_release,'keyboard cancel leaked a mouse-release capture')
-- Favorites and recent colors use the reference presets, names and transparency.
picker.open(view,1,inline.hits(doc,1)[1]);picker.set_color(colors.parse('rgba(255,0,128,.5)'))
fill('name','My pink');click('save-favorite')
assert(#picker.favorites==1 and picker.favorites[1].name=='My pink','favorite was not saved')
click('clear-recents');assert(#picker.recents==0,'recent colors did not clear')
click('cmyk');picker.draw();assert(picker.active.valid,'CMYK tab failed')
fill('c','0');fill('m','100');fill('y','100');fill('k','0')
assert(picker.active.current.r==255 and picker.active.current.g==0 and picker.active.current.b==0,'CMYK fields did not convert to CSS color')
click('hsl');fill('h','120');fill('s','100');fill('l','50');fill('a','0.75')
assert(picker.active.current.g==255 and picker.active.current.r==0,'HSL fields did not update selected color')
picker.set_color(colors.parse('rgba(255,0,128,.5)'))
click('hex');click('apply')
assert(doc:is_dirty() and table.concat(doc.lines):find('#ff008080',1,true),'HEX opacity was lost')
-- Wrapped lines must account for every inline gap, including clicks and row height.
view.size.x=310
assert(command.perform('line-wrapping:toggle'))
require('plugins.linewrapping').update_docview_breaks(view)
assert(view.wrapped_settings and #view.wrapped_lines>2,'test line did not wrap')
for _,hit in ipairs(inline.hits(doc,1)) do
  local x,y=view:get_line_screen_position(1,hit.start)
  local line,col=view:resolve_screen_position(x+.01,y+view:get_line_height()/2)
  assert(line==1 and col==hit.start,'wrapped swatch broke source/cursor coordinates: '..col..' vs '..hit.start)
end
local count=0
for i=1,#view.wrapped_lines,2 do if view.wrapped_lines[i]==1 then count=count+1 end end
view:draw()
local x,y=view:get_line_screen_position(1)
near(view:draw_line_text(1,x,y),count*view:get_line_height())
command.perform('line-wrapping:toggle')
-- A background edit while the picker is open must not overwrite stale coordinates.
local hit=inline.hits(doc,1)[1];picker.open(view,1,hit)
doc:insert(1,1,'/* background edit */ ')
local changed=table.concat(doc.lines)
local error_fn=core.error;local reported=false
core.error=function() reported=true end
picker.apply();core.error=error_fn
assert(reported and not picker.active and table.concat(doc.lines)==changed,'stale color picker overwrote a newer edit')
