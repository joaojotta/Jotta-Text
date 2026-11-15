local core=require 'core'
local command=require 'core.command'
local workspace=require 'plugins.litefront_workspace'
local syntax=require 'core.syntax'
local root=os.getenv('SETTINGS_ROOT')
local samples={
  {'CSS','body {color:red;}'}, {'HTML','<div>\n<p>Hello</p>\n</div>'},
  {'PHP','<?php $hello="world"; echo $hello;'}, {'JSON','{"hello":1}'},
  {'JavaScript','const value={hello:1};'}, {'Python','def hello():\n    return 1'},
  {'Lua','local hello = 1'}, {'Markdown','# Hello\n'},
}
for _,sample in ipairs(samples) do
  local doc=core.open_doc();core.root_view:open_doc(doc);doc:text_input(sample[2])
  assert(doc.syntax.name==sample[1],'wrong detection: '..sample[1]..' -> '..doc.syntax.name)
  workspace.set_language(doc,syntax.get(nil,nil));doc:text_input(' ')
  assert(doc.syntax.name=='Plain Text','manual Plain Text was overridden')
  workspace.set_language(doc,nil);assert(doc.syntax.name==sample[1],'Automatic did not restore detection')
end
local detection=require 'litefront.language_detection'
assert(detection.filename('const count: number = 1;')=='document.ts','typed variable was not detected as TypeScript')
assert(detection.filename('// comment\nconst value=1;')=='document.js','leading comment defeated detection')
assert(detection.filename('const sample = "<?php";')=='document.js','PHP inside a JS string defeated detection')
assert(not detection.filename('Example { color: red; }'),'prose was detected as CSS')
assert(detection.filename('{"data":"'..string.rep('x',9000))=='document.json','large JSON prefix not recognized')
local function format(doc)
  core.root_view:open_doc(doc)
  local seen={};for _,item in ipairs(core.log_items) do seen[item]=true end
  local start=process.start;local child
  process.start=function(...) child=start(...);return child end
  assert(command.perform('litefront:format-prettier'))
  process.start=start
  assert(child,'formatter did not start a process')
  local deadline=system.get_time()+6
  repeat
    coroutine.yield(.02)
    for _,item in ipairs(core.log_items) do
      if not seen[item] then
      assert(item.level~='ERROR',item.text)
      if item.text:find('Formatted ',1,true) then return end
      end
    end
  until system.get_time()>deadline
  error('formatter did not finish for '..doc.syntax.name)
end
for _,sample in ipairs({samples[1],samples[2],samples[3],samples[4],samples[5]}) do
  local doc=core.open_doc();doc:text_input(sample[2]);local before=table.concat(doc.lines)
  format(doc)
  assert(not doc.filename and doc:is_dirty(),'formatting saved an untitled document')
  assert(table.concat(doc.lines)~=before,'formatter did not change '..sample[1])
  doc:undo();assert(table.concat(doc.lines)==before,'formatting was not a single undo step')
end
local doc=core.open_doc(root..'/style.css');doc:set_selection(1,1,#doc.lines,#doc.lines[#doc.lines]);doc:text_input('body {color:blue;}')
doc.indent_info.type='hard';doc.indent_info.size=4
format(doc)
assert(table.concat(doc.lines):find('\tcolor: blue;',1,true),'formatter ignored the open document tab setting')
local file=assert(io.open(root..'/style.css'));local disk=file:read('*a');file:close()
assert(disk=='a { color: #abc; background: #112233; }\n','formatting wrote to disk')
assert(table.concat(doc.lines):find('blue',1,true) and doc:is_dirty(),'formatter ignored unsaved edits')
local large=core.open_doc();large:text_input(string.rep('.sample{color:red;}\n',5000))
format(large)
assert(table.concat(large.lines):find('color: red;',1,true),'formatter failed on large stdin/stdout')
local auto=core.open_doc();auto:text_input('body {color:red;}');auto:set_selection(1,1,#auto.lines,#auto.lines[#auto.lines]);auto:text_input('just a sentence')
assert(auto.syntax.name=='Plain Text','stale content detection survived replacement')

local invalid=core.open_doc();invalid:text_input('body { color:');workspace.set_language(invalid,syntax.get('document.css'))
core.root_view:open_doc(invalid)
local before=table.concat(invalid.lines);local report;local old_error=core.error
core.error=function(...) report=string.format(...) end
command.perform('litefront:format-prettier')
local deadline=system.get_time()+6
while not report and system.get_time()<deadline do coroutine.yield(.02) end
core.error=old_error
assert(report and report:find('Formatting failed:',1,true),'invalid code did not report a formatter error')
assert(table.concat(invalid.lines)==before,'failed formatting changed the buffer')
-- Stalled formatter jobs expose progress, cancel per document and time out safely.
local formatter=require 'plugins.litefront_prettier'
local actual_start=process.start;local timeout=formatter.timeout
local killed=0
process.start=function(args,...)
  if not args[2]:match('format%.mjs$') then return actual_start(args,...) end
  local running=true
  return {read_stdout=function() end,read_stderr=function() end,
    write=function(_,text) return #text end,close_stream=function() end,
    running=function() return running end,returncode=function() return -1 end,
    kill=function() killed=killed+1;running=false end}
end
local function start_job(text)
  local doc=core.open_doc();doc:text_input(text);core.root_view:open_doc(doc)
  command.perform('litefront:format-prettier')
  assert(formatter.jobs[doc],'formatter job missing')
  return doc,table.concat(doc.lines)
end
local first,first_source=start_job('body {color:red;}')
local second,second_source=start_job('a {color:blue;}')
assert(formatter.jobs[first] and formatter.jobs[second],'formatting is globally blocked')
local status=core.status_view:get_item('litefront:formatting')
assert(status and status.get_item()[2]:find('Click to cancel',1,true),'formatter has no progress action')
assert(command.perform('litefront:cancel-formatting'))
coroutine.yield(.05)
assert(not formatter.jobs[second] and formatter.jobs[first],'cancel did not isolate the active document')
command.perform('litefront:cancel-formatting');coroutine.yield(.05)
assert(not next(formatter.jobs),'cancel left formatting blocked')
assert(table.concat(first.lines)==first_source and table.concat(second.lines)==second_source,'cancelled formatting changed documents')
formatter.timeout=.05
local stalled,stalled_source=start_job('b {color:green;}')
local previous_error=core.error;local timed_out
core.error=function(text) timed_out=text end
local stop=system.get_time()+1
while formatter.jobs[stalled] and system.get_time()<stop do coroutine.yield(.02) end
core.error=previous_error
assert(timed_out and timed_out:find('timed out',1,true) and not formatter.jobs[stalled],'formatter timeout did not release the job')
assert(table.concat(stalled.lines)==stalled_source and killed>=3,'timeout did not terminate its process safely')
formatter.timeout=timeout;process.start=actual_start
