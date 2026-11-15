local core=require 'core'
local command=require 'core.command'
local style=require 'core.style'
local media=require 'plugins.litefront_media'
local root=os.getenv('MEDIA_ROOT')
local function open(name) return core.root_view:open_doc(core.open_doc(root..'/'..name)) end
local function views()
  local result={}
  for _,view in ipairs(core.root_view.root_node:get_children()) do if view.litefront_media then result[#result+1]=view end end
  return result
end
local phase=os.getenv('MEDIA_PHASE')
if phase=='1' then
  local ui,code=style.font,style.code_font
  local opened={}
  for _,extension in ipairs({'png','jpg','gif','bmp','webp','svg','ico','tiff'}) do
    local view=assert(open('sample.'..extension),'could not open '..extension)
    assert(view.litefront_media=='image' and not view.doc,'image was opened as editable text')
    assert(view.image_width>0 and view.image_height>0,'missing image dimensions')
    view.size.x,view.size.y=350,300
    view:draw()
    assert(view==open('sample.'..extension),'duplicate image tab was opened')
    opened[#opened+1]=view
  end
  assert(#core.docs==0,'image decoder opened hidden text documents')
  local image=opened[1]
  core.set_active_view(image)
  assert(command.perform('litefront-media:zoom-in') and image.zoom,'image zoom command did not apply')
  local zoom=image.zoom
  command.perform('litefront-media:zoom-out');assert(image.zoom<zoom)
  command.perform('litefront-media:reset-zoom');assert(not image.zoom)
  image.zoom=32
  image:on_mouse_pressed('left',100,200,1)
  image:on_mouse_moved(70,160,-30,-40)
  image:on_mouse_released('left',70,160)
  assert(not image.panning and image.scroll.to.x>0 and image.scroll.to.y>0,'image pan did not move or release')
  local original=style.background
  command.perform('litefront:theme-light');image:draw()
  assert(style.background~=original,'image view theme did not change')
  command.perform('litefront:theme-dark')
  local font=assert(open('Rubik.ttf'))
  assert(font.litefront_media=='font' and font.font_info.variable and font.font_info.family:find('Rubik',1,true),'font did not open as a variable font specimen')
  font.size.x,font.size.y=400,400
  local runs,height=font:specimen();assert(#runs>10 and height>400,'font specimen is not scrollable')
  font:draw();font:change_zoom(1.2)
  assert(font.font_size>32,'font specimen size did not change')
  font.weight=600;font.sample='Custom sample é à ç';font:load();font:draw()
  -- Theme changes may replace style objects, but specimen zoom must not resize editor fonts.
  assert(style.font:get_size()==ui:get_size() and style.code_font:get_size()==code:get_size(),'specimen zoom resized editor fonts')
  assert(not command.perform('doc:save'),'binary font tab exposed text Save')
  assert(font==open('Rubik.ttf'),'duplicate font specimen was opened')
  local ok=pcall(renderer.image.load,root..'/broken.png');assert(not ok,'invalid image was accepted')
  ok=pcall(renderer.font.load,root..'/broken.ttf',24);assert(not ok,'invalid font was accepted')
  assert(command.perform('litefront:ui-font'))
  assert(core.command_view.state.preview,'font picker has no preview action')
  local cv=core.command_view
  core.root_view:update()
  local rows=math.max(1,math.min(10,math.floor((core.root_view.size.y-cv.position.y-44*SCALE-90*SCALE)/(34*SCALE))))
  local count=math.min(rows,#cv.suggestions)
  local px,py=cv.position.x+40*SCALE,cv.position.y+(52+count*34+8+22)*SCALE
  core.root_view:on_mouse_pressed('left',px,py,1)
  core.root_view:on_mouse_released('left',px,py)
  assert(core.active_view.litefront_media=='font','font picker Preview did not open a specimen')
  assert(not require('litefront.fonts').selected.ui,'previewing a font applied it')
  local count=#views()
  local old_error=core.error
  local reported=false
  core.error=function() reported=true end
  assert(not open('broken.png'),'invalid image created a tab')
  core.error=old_error
  assert(reported and #views()==count,'invalid image did not leave the workspace intact')
  local source=media.open_text(root..'/sample.svg')
  assert(source.doc and source.doc.abs_filename==root..'/sample.svg','SVG source view is unavailable')
  core.root_view:close_all_docviews()
  -- Leave two binary tabs and one text tab for real process-to-process recovery.
  image=assert(open('sample.png'));image.zoom=2
  font=assert(open('Rubik.ttf'));font.font_size=44;font.weight=600;font.sample='Restored sample';font:load()
  core.root_view:open_doc(core.open_doc(root..'/note.txt'))
  media.open_text(root..'/sample.svg')
  core.set_active_view(image)
elseif phase=='2' then
  assert(#views()==2 and #core.docs==2,'media tabs did not restore independently of text documents')
  local source_found=false
  for _,doc in ipairs(core.docs) do if doc.abs_filename==root..'/sample.svg' then source_found=true end end
  assert(source_found,'SVG source tab did not restore as text')
  local font,image
  for _,view in ipairs(views()) do if view.litefront_media=='image' then image=view else font=view end end
  assert(image.zoom==2 and core.active_view==image,'image zoom or active tab was not restored')
  assert(font.font_size==44 and font.weight==600 and font.sample=='Restored sample','font specimen state did not restore')
  image:draw();font:draw()
  core.root_view:close_all_docviews()
else
  assert(#views()==0,'closed media tabs reopened')
end
