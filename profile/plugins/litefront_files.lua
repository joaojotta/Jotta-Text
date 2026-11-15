-- mod-version:3
-- Open files and folders with the desktop's traditional native dialogs.
if JOTTA_WEB then return require 'litefront.browser_files' end
local core = require 'core'
local command = require 'core.command'
local keymap = require 'core.keymap'
local common = require 'core.common'
local busy = false

local function dialog(mode, initial, name, callback)
  if busy then return end
  local helper = os.getenv('LITEFRONT_DIALOG') or require('litefront.runtime').dialog
  local ok, child = pcall(process.start, {helper, mode, initial or core.project_dir or '', name or '',require('litefront.i18n').language()})
  if not ok then core.error('Could not open the system dialog: %s', child); return end
  busy = true
  core.add_thread(function()
    local success, err = pcall(function()
      local output, errors = {}, {}
      repeat
        local text = child:read_stdout()
        if text and #text > 0 then output[#output+1] = text end
        text = child:read_stderr()
        if text and #text > 0 then errors[#errors+1] = text end
        if child:running() then coroutine.yield(0.03) else break end
      until false
      -- Drain the final output after process termination.
      while true do
        local text = child:read_stdout()
        if not text or #text == 0 then break end
        output[#output+1] = text
      end
      while true do
        local text = child:read_stderr()
        if not text or #text == 0 then break end
        errors[#errors+1] = text
      end
      local code = child:returncode()
      if code == 2 then busy=false; return end -- Cancel leaves the workspace unchanged.
      if code ~= 0 then error(table.concat(errors) ~= '' and table.concat(errors) or 'System file dialog failed') end
      local path = table.concat(output)
      busy=false
      callback(path)
    end)
    if not success then busy=false; core.error('File dialog failed: %s', tostring(err)) end
  end)
end
local function initial_folder()
  local view=core.active_view
  if view and view.doc and view.doc.abs_filename then return common.dirname(view.doc.abs_filename) end
  if view and view.litefront_media then return common.dirname(view.filename) end
  if not core.litefront_no_project then return core.project_dir end
  return os.getenv('HOME') or core.project_dir
end
local function open(folder)
  dialog(folder and 'folder' or 'file', initial_folder(), nil, function(path)
    local info=system.get_file_info(path)
    if not info or info.type~=(folder and 'dir' or 'file') then error('The selected path is no longer available') end
    if folder then
      if core.litefront_no_project or path~=core.project_dir then core.confirm_close_docs(core.docs, function() core.open_folder_project(path) end) end
    else core.root_view:open_doc(core.open_doc(path)) end
  end)
end

local function save(doc, save_as, on_saved)
  local function write(path)
    local info=system.get_file_info(path)
    if info and info.type~='file' then error('Cannot save to a folder') end
    for _,other in ipairs(core.docs) do
      if other~=doc and other.abs_filename==path then error('This file is already open in another document') end
    end
    doc:save(core.normalize_to_project_dir(path), path)
    core.log('Saved "%s"',path)
    if on_saved then on_saved() end
  end
  if doc.abs_filename and not save_as then
    local ok,err=pcall(write,doc.abs_filename)
    if not ok then core.error('Could not save file: %s',tostring(err)) end
  else
    local initial=doc.abs_filename and common.dirname(doc.abs_filename) or initial_folder()
    local name=doc.abs_filename and common.basename(doc.abs_filename) or 'untitled.txt'
    dialog('save',initial,name,write)
  end
end
command.add('core.docview', {
  ['doc:save']=function(view) save(view.doc,false) end,
  ['doc:save-as']=function(view) save(view.doc,true) end,
})
local find_file=command.map['core:find-file'].perform
command.add(nil, {
  ['core:find-file']=function() if core.litefront_no_project then open(false) else find_file() end end,
  ['core:open-file'] = function() open(false) end,
  ['core:open-project-folder'] = function() open(true) end,
  ['core:change-project-folder'] = function() open(true) end,
})
keymap.add { ['ctrl+o']='core:open-file', ['ctrl+shift+o']='core:open-project-folder', ['ctrl+s']='doc:save', ['ctrl+shift+s']='doc:save-as' }
return { open = open, save = save, dialog = dialog }
