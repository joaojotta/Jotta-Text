-- mod-version:3
-- Format a buffer through stdin/stdout; never save or rewrite its backing file.
local core=require 'core'
local command=require 'core.command'
local keymap=require 'core.keymap'
local M={jobs={},timeout=30}
local function current_job()
  return M.jobs[core.active_view.doc] or select(2,next(M.jobs))
end
function M.cancel()
  local job=current_job();if not job then return end
  job.cancelled=true;pcall(job.child.kill,job.child);core.redraw=true
end
local parsers={javascript='babel',typescript='typescript',json='json',html='html',css='css',scss='scss',less='less',
  php='php',['php source']='php',['typescript with jsx']='typescript',markdown='markdown',yaml='yaml',vue='vue',jsx='babel',tsx='typescript'}
local function format()
  local doc=core.active_view.doc
  if M.jobs[doc] then core.log('This document is already being formatted.');return end
  doc:reset_syntax()
  local parser=parsers[doc.syntax.name:lower()]
  if not parser then core.error('No formatter for %s. Choose a supported language in the status bar.',doc.syntax.name);return end
  local bundle=DATADIR..'/litefront'
  local kind,size=doc:get_indent_info()
  local args={require('litefront.runtime').node,bundle..'/format.mjs'}
  local revision=doc:get_change_id();local source=table.concat(doc.lines)
  local payload=require('plugins.json').encode({source=source,parser=parser,tabWidth=size,useTabs=kind=='hard'})..'\n'
  local ok,child
  if JOTTA_WEB then ok,child=true,require('litefront.browser').worker('format')
  else ok,child=pcall(process.start,args) end
  if not ok then core.error('Could not start formatter: %s',child);return end
  local job={doc=doc,child=child,started=system.get_time()};M.jobs[doc]=job;core.redraw=true
  core.add_thread(function()
    local success,failure=pcall(function()
    local output,errors={},{};local offset=1;local closed=false;local write_error
    local function drain()
      local text=child:read_stdout();if text and #text>0 then output[#output+1]=text end
      text=child:read_stderr();if text and #text>0 then errors[#errors+1]=text end
      return text
    end
    repeat
      if job.cancelled then core.log('Formatting cancelled.');return end
      if system.get_time()-job.started>=M.timeout then
        pcall(child.kill,child);core.error('Formatting timed out. Your document was left unchanged.');return
      end
      drain()
      if not closed then
        if offset<=#payload then
          local sent,n=pcall(child.write,child,payload:sub(offset,offset+16383))
          if not sent then write_error=n;closed=true else offset=offset+n end
        else child:close_stream(process.STREAM_STDIN);closed=true end
      end
      if not child:running() then break end
      coroutine.yield(0.01)
    until false
    -- Drain both pipes after exit; either can contain more than one chunk.
    for _,stream in ipairs({'read_stdout','read_stderr'}) do
      while true do
        local text=child[stream](child);if not text or #text==0 then break end
        local target=stream=='read_stdout' and output or errors;target[#target+1]=text
      end
    end
    if job.cancelled then core.log('Formatting cancelled.');return end
    if child:returncode()~=0 or write_error then core.error('Formatting failed: %s',table.concat(errors)..tostring(write_error or ''));return end
    if doc:get_change_id()~=revision or table.concat(doc.lines)~=source then
      core.log('Formatting skipped because the document changed. Format again to use your latest edits.');return
    end
    local result=table.concat(output):gsub('\r\n','\n')
    if result~=source then
      local selection={table.unpack(doc.selections)};local first=doc.undo_stack.idx
      doc:replace_cursor(1,1,1,#doc.lines,#doc.lines[#doc.lines],function() return (result:gsub('\n$','')) end)
      local group=system.get_time()-require('core.config').undo_merge_timeout-1
      for i=first,doc.undo_stack.idx-1 do doc.undo_stack[i].time=group end
      doc.selections=selection
      for i=1,#selection,2 do selection[i],selection[i+1]=doc:sanitize_position(selection[i],selection[i+1]) end
    end
    core.redraw=true;core.log('Formatted %s',doc:get_name())
    end)
    M.jobs[doc]=nil;core.redraw=true
    if not success then pcall(child.kill,child);core.error('Formatting failed: %s',failure) end
  end)
end
command.add('core.docview',{['litefront:format-prettier']=format})
keymap.add{['ctrl+alt+shift+f']='litefront:format-prettier'}

command.add(function() return current_job()~=nil end,{['litefront:cancel-formatting']=M.cancel})
keymap.add{['ctrl+alt+shift+x']='litefront:cancel-formatting'}
local StatusView=require 'core.statusview'
core.status_view:add_item{name='litefront:formatting',alignment=StatusView.Item.LEFT,
  predicate=function() return next(M.jobs)~=nil end,
  get_item=function()
    local job=current_job()
    return {require('core.style').accent,require('litefront.i18n').t('Formatting %s… Click to cancel',job.doc:get_name())}
  end,command='litefront:cancel-formatting',tooltip='Cancel formatting'}
return M
