-- mod-version:3
-- Language completion for new buffers, without giving them a saved filename.
local core=require 'core'
local command=require 'core.command'
local keymap=require 'core.keymap'
local Doc=require 'core.doc'
local lsp=require 'plugins.lsp'
local common=require 'core.common'
local autocomplete=require 'plugins.autocomplete'
local serial=0
local extensions={HTML='html',CSS='css',JSON='json',JavaScript='js',JSX='jsx',TypeScript='ts',['TypeScript with JSX']='tsx'}
local pending=setmetatable({},{__mode='k'})
local function close_identity(doc,path)
  if path and doc.lsp_open then
    local identity=setmetatable({filename=path,abs_filename=path},{__index=doc})
    lsp.close_document(identity)
  end
  doc.lsp_open=nil
  doc.litefront_lsp_open_servers=nil
  doc.lsp_changes={}
  doc.disable_symbols=false
end
local function ready(doc,filename)
  local path=core.project_absolute_path(filename)
  for name,server in pairs(lsp.servers) do
    if common.match_pattern(filename,server.file_patterns) then
      local running=lsp.servers_running[name]
      if not running or not running.initialized or not running.capabilities then return false end
      if not doc.litefront_lsp_open_servers or doc.litefront_lsp_open_servers[running]~=path then return false end
    end
  end
  return true
end
local function start(doc,forced)
  if not doc.syntax then return end
  local extension=extensions[doc.syntax.name]
  if not doc.filename then
    local old=doc.litefront_lsp_filename
    if not extension then
      if old then close_identity(doc,old);doc.litefront_lsp_filename=nil end
      pending[doc]=nil
      return
    end
    if not doc.litefront_completion_id then serial=serial+1;doc.litefront_completion_id=serial end
    local path=core.project_dir..PATHSEP..'.litefront-buffer-'..doc.litefront_completion_id..'.'..extension
    if path~=old then
      close_identity(doc,old)
      doc.litefront_lsp_filename=path
    end
  end
  local filename=doc.filename or doc.litefront_lsp_filename
  if not filename then return end
  local supported=false
  for _,server in pairs(lsp.servers) do if common.match_pattern(filename,server.file_patterns) then supported=true;break end end
  if not supported then if forced then autocomplete.open() end;return end
  if pending[doc] and pending[doc].filename==filename then
    pending[doc].forced=pending[doc].forced or forced
    return
  end
  if doc.lsp_open and ready(doc,filename) then
    if forced then
      autocomplete.close()
      local line,col=doc:get_selection()
      lsp.request_completion(doc,line,col,true)
    end
    return
  end
  local request={forced=forced,filename=filename}
  pending[doc]=request
  core.add_thread(function()
    lsp.start_server(filename,core.project_dir)
    -- Existing initialized servers need an explicit didOpen for the new document.
    if #lsp.get_active_servers(filename,true)>0 then lsp.open_document(doc) end
    local deadline=system.get_time()+12
    while pending[doc]==request and (not doc.lsp_open or not ready(doc,filename)) and system.get_time()<deadline do coroutine.yield(.05) end
    if pending[doc]~=request then return end
    pending[doc]=nil
    if not doc.lsp_open or not ready(doc,filename) or core.active_view.doc~=doc then return end
    local line,col=doc:get_selection()
    local prefix=doc:get_text(line,1,line,col)
    if request.forced or prefix:match('[%w_%.<]$') then
      autocomplete.close()
      lsp.request_completion(doc,line,col,true)
    end
  end)
end
local reset_syntax=Doc.reset_syntax
function Doc:reset_syntax(...)
  reset_syntax(self,...)
  -- Language selection/content detection runs here, including on untitled buffers.
  if not self.filename then start(self,false) end
end
local save=Doc.save
function Doc:save(...)
  local virtual=self.litefront_lsp_filename
  local result=save(self,...)
  if virtual and self.filename then
    close_identity(self,virtual)
    self.litefront_lsp_filename=nil
  end
  start(self,false)
  return result
end
local open_doc=core.open_doc
function core.open_doc(filename,...)
  if filename then
    local absolute=core.project_absolute_path(filename)
    for _,doc in ipairs(core.docs) do
      if doc.litefront_lsp_filename==absolute then return doc end
    end
  end
  return open_doc(filename,...)
end
command.add('core.docview',{
  ['litefront:complete']=function(view)
    if view.doc.syntax.name=='Plain Text' then return autocomplete.open() end
    start(view.doc,true)
  end,
})
keymap.add {['ctrl+space']='litefront:complete'}
return {start=start}
