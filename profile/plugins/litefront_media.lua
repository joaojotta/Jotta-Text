-- mod-version:3
-- Route binary media before core.open_doc can read it as text.
local core=require 'core'
local command=require 'core.command'
local RootView=require 'core.rootview'
local MediaView=require 'litefront.media_view'
local M={}
local images={png=true,jpg=true,jpeg=true,gif=true,bmp=true,webp=true,svg=true,ico=true,tif=true,tiff=true}
local fonts={ttf=true,otf=true,ttc=true,woff=true,woff2=true}
function M.kind(filename)
  local extension=filename and filename:lower():match('%.([^./\\]+)$')
  return images[extension] and 'image' or fonts[extension] and 'font' or nil
end
local open_doc=core.open_doc
function core.open_doc(filename,...)
  local kind=M.kind(filename)
  if not kind then return open_doc(filename,...) end
  return {litefront_media=kind,filename=core.project_absolute_path(filename)}
end
local open_view=RootView.open_doc
function M.text_doc(filename) return open_doc(filename) end
function M.open_text(filename) return open_view(core.root_view,M.text_doc(filename)) end
function RootView:open_doc(doc)
  if not doc.litefront_media then return open_view(self,doc) end
  for _,view in ipairs(self.root_node:get_children()) do
    if view.litefront_media and view.filename==doc.filename then
      self.root_node:get_node_for_view(view):set_active_view(view);return view
    end
  end
  local ok,view=pcall(MediaView,doc.filename,doc.litefront_media)
  if not ok then core.error('Could not preview %s: %s',doc.filename,view);return end
  self:get_active_node_default():add_view(view)
  self.root_node:update_layout();return view
end
command.add(MediaView,{
  ['litefront-media:zoom-in']=function(view) view:change_zoom(1.2) end,
  ['litefront-media:zoom-out']=function(view) view:change_zoom(1/1.2) end,
  ['litefront-media:reset-zoom']=function(view)
    if view.litefront_media=='image' then view.zoom=nil else view.font_size=32;view:load() end
    view.scroll.to.x=0;view.scroll.to.y=0;core.redraw=true
  end,
  ['litefront-media:reload']=function(view) view:load() end,
})
require('core.keymap').add{['ctrl+=']='litefront-media:zoom-in',['ctrl+-']='litefront-media:zoom-out',['ctrl+0']='litefront-media:reset-zoom'}
return M
