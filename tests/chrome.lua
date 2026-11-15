local core=require 'core'
local visual=require 'litefront.visual'
local common=require 'core.common'
local shell=require 'plugins.litefront_shell'
local visuals=require 'plugins.litefront_visuals'
local status=core.status_view
local layout=require 'litefront.status_layout'
local folder=common.basename(core.project_dir)
local doc=core.open_doc(os.getenv('SETTINGS_ROOT')..'/style.css');core.root_view:open_doc(doc)
core.root_view:update()
local draw_text=renderer.draw_text
local strings={}
renderer.draw_text=function(font,text,...) strings[text]=true;return draw_text(font,text,...) end
shell.bar:draw()
assert(not strings[folder],'workspace name is still drawn in the top menu bar')
strings={};status.message_timeout=0;status.tooltip_mode=false;status:update_active_items();status:draw()
renderer.draw_text=draw_text
assert(strings[folder],'workspace name is missing from the status bar')
local workspace=assert(status:get_item('litefront:workspace'))
assert(workspace.active,'workspace footer is inactive with an open folder')
for _,button in ipairs(visuals.rail:items()) do assert(button.command~='litefront:toggle-theme','old theme button is still in the sidebar') end
local theme=assert(status:get_item('litefront:theme-toggle'))
local function pinned()
  local r=layout.rect(status);local x,w=status:get_item_visible_area(theme)
  assert(x==r.x and w==r.w,'theme button hit area is not pinned')
  assert(math.abs(x+w-status.position.x-status.size.x)<.01,'theme button is not at the far-right edge')
  return r
end
local r=pinned()
-- Transient messages must not turn a theme click into Open Log.
status:show_message('i',require('core.style').text,'Long status message '..string.rep('x',300))
local log=0;local perform=require('core.command').perform
require('core.command').perform=function(name,...) if name=='core:open-log' then log=log+1 end;return perform(name,...) end
local mode=visual.mode
core.root_view:on_mouse_moved(r.x+r.w/2,r.y+r.h/2,0,0)
core.root_view:on_mouse_pressed('left',r.x+r.w/2,r.y+r.h/2,1)
core.root_view:on_mouse_released('left',r.x+r.w/2,r.y+r.h/2)
require('core.command').perform=perform
assert(visual.mode~=mode and log==0,'theme click opened the log or did not toggle')
status:draw()
-- Dragging outside the reserved button cancels its action.
mode=visual.mode;r=pinned()
core.root_view:on_mouse_pressed('left',r.x+r.w/2,r.y+r.h/2,1)
core.root_view:on_mouse_released('left',r.x-40,r.y+r.h/2)
assert(visual.mode==mode,'releasing outside theme button toggled the theme')
local width=status.size.x
status.size.x=320*SCALE;status:update_active_items();pinned();status:draw()
status.size.x=width;status:update_active_items()
core.root_view:close_all_docviews();core.root_view:update()
status:update_active_items()
assert(workspace.active,'workspace footer disappeared when the last document closed')
local no_project=core.litefront_no_project;core.litefront_no_project=true
status:update_active_items();assert(workspace.tooltip=='No folder open','empty workspace label did not update')
core.litefront_no_project=no_project
