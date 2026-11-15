-- Background adapter for the removable GitHub trial worker.
local core=require 'core'
local json=require 'plugins.json'
local M={job=nil}
function M.cancel()
  local job=M.job;if not job then return end
  job.cancelled=true
  if job.sent and not job.cancel_sent then
    local payload='{"action":"cancel"}\n';local offset=job.cancel_offset or 1
    local ok,count=pcall(job.child.write,job.child,payload:sub(offset))
    if ok then job.cancel_offset=offset+(count or 0);job.cancel_sent=job.cancel_offset>#payload end
  end
end
function M.run(request,callback,onprogress)
  if M.job then return false end
  request.userdir=USERDIR
  local ok,child=pcall(process.start,{require('litefront.runtime').node,DATADIR..'/litefront/github-trial.mjs'})
  if not ok then callback(nil,tostring(child));return false end
  local job={child=child,started=system.get_time()};M.job=job
  core.add_thread(function()
    local response
    local success,failure=xpcall(function()
      local payload=json.encode(request)..'\n';local offset=1;local output,errors={},{};local bytes=0;local closed=false
      local pending=''
      local function consume(value)
        pending=pending..value
        while pending:find('\n',1,true) do
          local position=pending:find('\n',1,true)
          local line=pending:sub(1,position-1);pending=pending:sub(position+1)
          local item=json.decode(line)
          if item.event then if onprogress then core.try(onprogress,item) end
          else output[#output+1]=line end
        end
      end
      local function drain()
        for _,entry in ipairs({{'read_stdout',output},{'read_stderr',errors}}) do
          local value=child[entry[1]](child)
          if value and #value>0 then
            bytes=bytes+#value
            if entry[1]=='read_stdout' then consume(value) else entry[2][#entry[2]+1]=value end
          end
        end
        if bytes>5*1024*1024 then error('Git output exceeded the trial limit') end
      end
      repeat
        if system.get_time()-job.started>(request.action=='login' and 930 or request.action=='sync' and 400 or 135) then pcall(child.terminate,child);error('Git operation timed out') end
        drain()
        if not closed then
          if offset<=#payload then offset=offset+(child:write(payload:sub(offset,offset+16383)) or 0)
          else closed=true;job.sent=true end
        end
        if job.cancelled and job.sent and not job.cancel_sent then
          M.cancel()
        end
        if not child:running() then break end
        core.redraw=true;coroutine.yield(.03)
      until false
      for _,entry in ipairs({{'read_stdout',output},{'read_stderr',errors}}) do
        while true do
          local value=child[entry[1]](child);if not value or value=='' then break end
          if entry[1]=='read_stdout' then consume(value) else entry[2][#entry[2]+1]=value end
        end
      end
      if job.cancelled then error('Operation cancelled. Refresh to check the repository state.') end
      if child:returncode()~=0 then error(table.concat(errors)~='' and table.concat(errors) or 'Git worker stopped') end
      response=json.decode(table.concat(output)..pending)
    end,function(err) return tostring(err):gsub('^.-:%d+: ','') end)
    M.job=nil
    if not success then
      pcall(child.terminate,child);core.try(callback,nil,job.cancelled and 'Operation cancelled. Refresh to check the repository state.' or failure)
    elseif response.ok then core.try(callback,response.result)
    else core.try(callback,nil,response.error) end
    core.redraw=true
  end)
  return true
end
return M
