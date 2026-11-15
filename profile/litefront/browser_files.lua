local core=require 'core'
local command=require 'core.command'
local common=require 'core.common'
local browser=require 'litefront.browser'
local M={}
function M.dialog(mode,initial,name,callback)
  local keymap=require 'core.keymap'
  for name in pairs(keymap.modkeys) do keymap.modkeys[name]=false end
  browser.request('dialog',{mode=mode,initial=initial,name=name},function(path)
    if not path then return end
    callback(path)
  end)
end
function M.open(folder)
  M.dialog(folder and 'folder' or 'file','/persist/workspace',nil,function(path)
    if folder then core.confirm_close_docs(core.docs,function() core.open_folder_project(path) end)
    else core.root_view:open_doc(core.open_doc(path)) end
  end)
end
function M.save(doc,save_as,on_saved)
  local function write(path)
    for _,other in ipairs(core.docs) do
      if other~=doc and other.abs_filename==path then core.error('This file is already open in another document');return end
    end
    doc:save(core.normalize_to_project_dir(path),path)
    browser.download(path)
    if on_saved then on_saved() end
  end
  if doc.abs_filename and not save_as then write(doc.abs_filename)
  else M.dialog('save',doc.abs_filename and common.dirname(doc.abs_filename) or '/persist/workspace',
    doc.abs_filename and common.basename(doc.abs_filename) or 'untitled.txt',write) end
end
command.add('core.docview',{
  ['doc:save']=function(view) M.save(view.doc,false) end,
  ['doc:save-as']=function(view) M.save(view.doc,true) end,
})
command.add(nil,{
  ['core:open-file']=function() M.open(false) end,
  ['core:open-project-folder']=function() M.open(true) end,
  ['core:change-project-folder']=function() M.open(true) end,
})
return M
