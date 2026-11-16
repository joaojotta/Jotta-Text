-- Browser requests replace desktop processes while keeping Lua editor behavior.
local core=require 'core'
local json=require 'plugins.json'
local bridge=require 'web'
local M={}
function M.request(kind,payload,callback)
  local id=bridge.request(kind,json.encode(payload or {}))
  core.add_thread(function()
    while true do
      local response=bridge.poll(id)
      if response then
        local result=json.decode(response)
        if result.error then core.error('Browser operation failed: %s',result.error)
        elseif callback then callback(result.result) end
        return
      end
      coroutine.yield(.03)
    end
  end)
end
function M.download(path) M.request('download',{path=path}) end
function M.worker(kind)
  local child={alive=true,input='',output='',errors='',code=0}
  function child:write(text)
    self.input=self.input..text
    local line,rest=self.input:match('^(.-)\n(.*)$')
    if line then
      self.input=rest
      self.id=bridge.request(kind,line)
    end
    return #text
  end
  function child:read_stdout()
    if self.id then
      local message=bridge.poll(self.id)
      if message then
        self.id=nil
        local response=json.decode(message)
        if response.error then self.errors=response.error;self.code=1
        elseif kind=='format' then self.output=response.result
        else self.output=json.encode(response.result)..'\n' end
        if kind=='format' or response.error then self.alive=false end
      end
    end
    local output=self.output;self.output='';return output
  end
  function child:read_stderr() local errors=self.errors;self.errors='';return errors end
  function child:running() return self.alive end
  function child:returncode() return self.code end
  function child:close_stream() end
  function child:kill() if self.id then bridge.cancel(self.id);self.id=nil end;self.alive=false end
  child.terminate=child.kill
  function child:wait() return not self.alive end
  return child
end
function M.print_markdown(doc)
  M.request('print',{html=require('litefront.markdown_html').document(table.concat(doc.lines),doc.abs_filename,false)})
end
function M.preview()
  local view=require('litefront.visual').document_view();local doc=view and view.doc
  if not doc then return end
  if doc.syntax.name=='Markdown' then
    M.request('preview',{html=require('litefront.markdown_html').document(table.concat(doc.lines),doc.abs_filename,false)})
  elseif doc.syntax.name=='HTML' then
    M.preview_doc=doc
    M.request('preview',{html=table.concat(doc.lines),filename=doc.abs_filename,files=M.buffers()})
  else core.error('Open an HTML or Markdown document to preview it') end
end
function M.buffers()
  local files={}
  for _,doc in ipairs(core.docs) do if doc.abs_filename then files[doc.abs_filename]=table.concat(doc.lines) end end
  return files
end
function M.install()
  local Doc=require 'core.doc';local changed=Doc.on_text_change
  function Doc:on_text_change(...)
    local result=changed(self,...)
    M.request('dirty',{})
    return result
  end
  core.add_thread(function()
    M.request('ready',{})
    local previous,last_sync,last_theme='',0,''
    while true do
      local event=bridge.poll(0)
      if event then
        local item=json.decode(event)
        -- Extra files chosen in one Open File dialog; the first opens directly.
        if item.kind=='file' then core.root_view:open_doc(core.open_doc(item.path)) end
      end
      if system.get_time()-last_sync>2 then
        require('litefront.session').save()
        M.request('sync',{})
        last_sync=system.get_time()
      end
      local style=require 'core.style';local palette={}
      for name,field in pairs({bg='ui_background',panel='background2',line='divider',ink='text',accent='accent'}) do
        local value=style[field] or style.background
        palette[name]=string.format('#%02x%02x%02x',value[1],value[2],value[3])
      end
      palette.mode=require('litefront.visual').mode
      local theme=json.encode(palette)
      if theme~=last_theme then last_theme=theme;M.request('theme',palette) end
      if M.preview_doc then
        local files=M.buffers();local signature=json.encode(files)..table.concat(M.preview_doc.lines)
        if signature~=previous then
          previous=signature
          M.request('preview-update',{html=table.concat(M.preview_doc.lines),filename=M.preview_doc.abs_filename,files=files})
        end
      end
      coroutine.yield(.2)
    end
  end)
end
return M
