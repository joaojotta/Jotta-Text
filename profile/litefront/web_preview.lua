local core=require 'core'
local common=require 'core.common'
local json=require 'plugins.json'
local Doc=require 'core.doc'
local M={}
local extensions={html=true,htm=true,xhtml=true,css=true,js=true,mjs=true,cjs=true,json=true,svg=true,txt=true}
local changed=Doc.on_text_change
function Doc:on_text_change(...)
  local result=changed(self,...)
  self.litefront_preview_revision=(self.litefront_preview_revision or 0)+1
  return result
end
local function inside(filename,root) return filename and filename:sub(1,#root+1)==root..PATHSEP end
function M.snapshot(root)
  local files={}
  for _,doc in ipairs(core.docs) do
    local filename=doc.abs_filename
    if doc==M.virtual_doc then files[M.virtual_path]=table.concat(doc.lines)
    elseif inside(filename,root) and doc:is_dirty() and extensions[filename:lower():match('%.([^./]+)$')] then
      files[filename:sub(#root+2)]=table.concat(doc.lines)
    end
  end
  return files
end
local function signature(root)
  local parts={root,tostring(M.virtual_doc),tostring(M.virtual_revision or 0)}
  for _,doc in ipairs(core.docs) do
    if doc==M.virtual_doc or inside(doc.abs_filename,root) then
      parts[#parts+1]=table.concat({tostring(doc),doc.abs_filename or '',doc:is_dirty() and 'dirty' or 'clean',doc.litefront_preview_revision or 0},':')
    end
  end
  return table.concat(parts,'\0')
end
function M.stop()
  if M.process and M.process:running() then M.process:terminate();M.process:wait(1000) end
  M.process=nil;M.root=nil;M.url=nil;M.virtual_doc=nil;M.virtual_path=nil
end
function M.open()
  if JOTTA_WEB then return require('litefront.browser').preview() end
  local view=require('litefront.visual').document_view()
  local doc=view and view.doc
  local current=doc and doc.abs_filename
  local root=not core.litefront_no_project and core.project_dir or nil
  local file='index.html'
  local virtual
  if current and (current:lower():match('%.html?$') or current:lower():match('%.xhtml$')) then
    if not root or not inside(current,root) then root=common.dirname(current) end
    file=current:sub(#root+2)
  elseif doc and not current and doc.syntax and doc.syntax.name=='HTML' then
    root=root or core.project_dir;virtual=doc
    M.virtual_counter=(M.virtual_counter or 0)+1
    file=M.virtual_doc==doc and M.virtual_path or '__jotta-text_unsaved_'..os.time()..'_'..M.virtual_counter..'.html'
  elseif not root then core.error('Open an HTML file or choose HTML as the language to start web preview');return end
  local helper=os.getenv('LITEFRONT_PREVIEW_BROWSER') or require('litefront.runtime').dialog
  local uri_path=file:gsub('[^%w%-%._~/]',function(c) return string.format('%%%02X',c:byte()) end)
  if M.process and M.process:running() and M.root==root then
    if M.virtual_doc~=virtual then M.virtual_revision=(M.virtual_revision or 0)+1 end
    M.virtual_doc=virtual;M.virtual_path=virtual and file or nil
    if M.url then process.start({helper,'uri',M.url:match('^http://[^/]+')..'/'..uri_path}) end
    return
  end
  M.stop();M.root=root;M.virtual_doc=virtual;M.virtual_path=virtual and file or nil
  local bundle=DATADIR..'/litefront'
  local ok,child=pcall(process.start,{require('litefront.runtime').node,bundle..'/preview.mjs',root,file,helper,'--editor'})
  if not ok then core.error('Could not start web preview: %s',child);return end
  M.process=child
  core.add_thread(function()
    local previous
    local stdout=''
    while M.process==child and child:running() do
      local next=signature(root)
      if next~=previous then
        local payload=json.encode({files=M.snapshot(root)})..'\n'
        local offset=1
        while offset<=#payload and M.process==child and child:running() do
          local written,err=child:write(payload:sub(offset))
          if err then core.error('Could not update web preview: %s',err);M.stop();return end
          offset=offset+(written or 0)
          if offset<=#payload then coroutine.yield(.01) end
        end
        previous=next
      end
      local output=child:read_stdout()
      if output and output~='' then
        stdout=stdout..output
        local url=stdout:match('(http://127%.0%.0%.1:%d+/[^\r\n]*)[\r\n]')
        if url and not M.url then M.url=url;core.log('Web preview: %s',M.url) end
      end
      coroutine.yield(.1)
    end
    if M.process==child then
      local err=child:read_stderr()
      if child:returncode()~=0 then core.error('Web preview failed: %s',err or 'could not start server') end
      M.process=nil
    end
  end)
end
return M
