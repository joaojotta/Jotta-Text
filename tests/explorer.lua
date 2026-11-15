local core=require 'core'
local command=require 'core.command'
local system=require 'system'
local explorer=require 'plugins.litefront_explorer'
local glyphs=require 'litefront.icon-map'
local icons={
  ['start.html']='file-html5',['style.CSS']='file-css3',['test.js']='file-js',
  ['package.json']='file-package',['readme.md']='file-markdown',['font.woff2']='file-fonts',
  ['photo.webp']='file-webp',['unknown.xyz']='file-file',
}
for filename,icon in pairs(icons) do
  assert(explorer.icon_for(filename,'file')==icon and glyphs[icon],'missing file icon: '..filename)
end
assert(explorer.icon_for('nested','dir')=='file-folder' and glyphs['file-folder'],'missing folder icon')
core.root_view:update()
assert(explorer.visible and explorer.size.x>0,'opened project has no explorer')
explorer:refresh()
local function find(path)
  for i,row in ipairs(explorer.rows) do if row.relative==path then return i,row end end
end
local nested=find('nested')
assert(nested,'project folder missing from explorer')
assert(not find('nested'..PATHSEP..'note.md'),'collapsed folder leaked children')
local editor=core.active_view
local function click(index)
  local _,top=explorer:get_content_offset()
  local x=explorer.position.x+100*SCALE
  local y=top+(index-0.5)*explorer:row_height()
  core.root_view:on_mouse_pressed('left',x,y,1)
end
click(nested)
local file=find('nested'..PATHSEP..'note.md')
assert(file,'expanding a folder did not show its files')
click(file)
assert(core.active_view.doc and core.active_view.doc.abs_filename==core.project_dir..'/nested/note.md','file click did not open the document')
assert(not core.root_view.root_node:get_node_for_view(core.active_view).locked,'file opened inside the sidebar')
-- Test elapsed-time animation and interrupted transitions without sleeping.
local bar=require('plugins.litefront_shell').bar
local menu_x,menu_y,menu_width=bar.position.x,bar.position.y,bar.size.x
local function check_menu()
  core.root_view.root_node:update_layout()
  assert(bar.position.x==menu_x and bar.position.y==menu_y and bar.size.x==menu_width,'explorer shifted the menu bar')
  assert(explorer.position.y>=bar.position.y+bar.size.y,'explorer overlaps the menu bar')
end
check_menu()
local width=explorer.size.x
assert(command.perform('litefront:toggle-explorer'))
local animation=assert(explorer.animation)
explorer:advance_animation(animation.time+0.05)
assert(math.abs(explorer.size.x-width/2)<0.01,'hide is not halfway at 50ms')
local halfway=explorer.size.x
assert(command.perform('litefront:toggle-explorer'))
assert(math.abs(explorer.size.x-halfway)<0.01,'reversing animation jumped')
animation=assert(explorer.animation)
explorer:advance_animation(animation.time+0.1001)
assert(explorer.size.x==width and not explorer.animation,'show did not finish in 100ms')
assert(command.perform('litefront:toggle-explorer'))
animation=assert(explorer.animation)
explorer:advance_animation(animation.time+0.1001)
core.root_view.root_node:update_layout()
assert(explorer.size.x==0,'hidden explorer retains width')
check_menu()
assert(core.active_view.doc,'hiding explorer lost editor focus')
assert(command.perform('litefront:toggle-explorer'))
animation=assert(explorer.animation)
explorer:advance_animation(animation.time+0.1001)
core.root_view.root_node:update_layout()
check_menu()
explorer:set_target_size('x',270*SCALE)
check_menu()
explorer:set_target_size('x',240*SCALE)
check_menu()
-- Exercise real divider hit testing, mouse capture and dragging with the rail.
local root=core.root_view
local edge=explorer.position.x+explorer.size.x
local y=explorer.position.y+explorer:header_height()/2
local divider=assert(root.root_node:get_divider_overlapping_point(edge,y),'explorer edge is not resizable')
local rail_width=divider.a.a.size.x
root:on_mouse_moved(edge,y,0,0)
root:on_mouse_pressed('left',edge,y,1)
assert(root.dragged_divider==divider,'explorer divider did not capture the mouse')
root:on_mouse_moved(edge+60*SCALE,y,60*SCALE,0)
check_menu()
assert(math.abs(explorer.width-300*SCALE)<2*SCALE,'divider drag did not resize explorer')
assert(divider.a.a.size.x==rail_width,'resizing explorer changed icon rail width')
root:on_mouse_released('left',edge+60*SCALE,y)
assert(not root.dragged_divider,'explorer divider did not release mouse capture')
root:on_mouse_pressed('left',explorer.position.x+explorer.size.x,y,1)
root:on_mouse_moved(explorer.position.x+20*SCALE,y,-280*SCALE,0)
root:on_mouse_released('left',explorer.position.x+20*SCALE,y)
assert(explorer.width==140*SCALE,'explorer drag ignored minimum width')
explorer:set_target_size('x',240*SCALE);check_menu()

-- Keyboard navigation and Escape restore the editor; scroll keeps selection visible.
explorer.return_view=core.active_view
core.set_active_view(explorer)
explorer.selected=find('nested')
assert(command.perform('litefront-explorer:collapse'))
assert(not find('nested'..PATHSEP..'note.md'),'collapse did not hide children')
assert(command.perform('litefront-explorer:expand'))
assert(find('nested'..PATHSEP..'note.md'),'keyboard expand failed')
assert(command.perform('litefront-explorer:focus-editor'))
assert(core.active_view.doc,'Escape did not restore document focus')
-- File watcher changes appear without reopening the folder.
local path=core.project_dir..'/explorer-new.txt'
local output=assert(io.open(path,'w'));output:write('new');output:close()
for i=1,20 do
  coroutine.yield(0.05);explorer:refresh()
  if find('explorer-new.txt') then break end
end
assert(find('explorer-new.txt'),'new project file did not appear')
os.remove(path)
for i=1,20 do
  coroutine.yield(0.05);explorer:refresh()
  if not find('explorer-new.txt') then break end
end
assert(not find('explorer-new.txt'),'deleted project file remained in explorer')
core.set_active_view(editor)
