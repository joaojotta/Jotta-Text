local core=require 'core'
local command=require 'core.command'
local lsp=require 'plugins.lsp'
local autocomplete=require 'plugins.autocomplete'
local workspace=require 'plugins.litefront_workspace'
local syntax=require 'core.syntax'
local keymap=require 'core.keymap'
-- Simulate a slow document-open write after CSS initialization. Another shared
-- server (Emmet) is already running, so its readiness must not stand in for CSS.
local Server=require 'plugins.lsp.server'
local notifications=Server.process_notifications
local delayed_css={}
function Server:process_notifications(...)
  local first=self.notification_list and self.notification_list[1]
  if self.name=='vscode_css_ls' and first and first.method=='textDocument/didOpen' then
    delayed_css[self]=delayed_css[self] or system.get_time()+.6
    if system.get_time()<delayed_css[self] then return end
  end
  return notifications(self,...)
end
local received={}
local requests={}
local request_completion=lsp.request_completion
lsp.request_completion=function(doc,line,col,forced)
  local filename=doc.filename or doc.litefront_lsp_filename or 'untitled'
  local css=lsp.servers_running.vscode_css_ls
  requests[#requests+1]=filename..' open='..tostring(doc.lsp_open)..' trigger='..tostring(lsp.in_trigger)..' css-ready='..tostring(css and css.initialized)
  return request_completion(doc,line,col,forced)
end
local complete=autocomplete.complete
autocomplete.complete=function(items,...)
  for label in pairs(items.items or {}) do received[label]=true end
  return complete(items,...)
end
local function wait_for(predicate,message,timeout)
  local until_time=system.get_time()+(timeout or 12)
  while not predicate() and system.get_time()<until_time do coroutine.yield(.05) end
  if not predicate() then error(type(message)=='function' and message() or message) end
end
local function query(doc,label,accept,automatic)
  if not automatic then received={} end
  core.root_view:open_doc(doc)
  doc:set_selection(1,#doc.lines[1])
  if not automatic then assert(command.perform('litefront:complete')) end
  wait_for(function() return received[label] end,function()
    local trace={}
    for i=math.max(1,#requests-8),#requests do trace[#trace+1]=requests[i] end
    return 'no real completion received for '..label..'\n'..table.concat(trace,'\n')
  end)
  coroutine.yield(.3)
  assert(autocomplete.is_open(),'completion results did not open the popup')
  local visible=false
  for _,set in pairs(autocomplete.map_manually) do
    for _,item in ipairs(set.items) do if item.text==label then visible=true end end
  end
  assert(visible,'completion result was replaced before it could be selected: '..label)
  if accept then
    local before=table.concat(doc.lines)
    assert(command.perform('autocomplete:complete'),'completion could not be selected')
    assert(table.concat(doc.lines)~=before,'selecting completion did not insert text')
  else autocomplete.close() end
end
local function embedded(text,label,accept_key,saved,automatic)
  autocomplete.close();received={}
  local marker=assert(text:find('|',1,true));local before=text:sub(1,marker-1)
  local doc=core.open_doc();core.root_view:open_doc(doc)
  workspace.set_language(doc,syntax.get('embedded.html'))
  doc:text_input(text:sub(1,marker-1)..text:sub(marker+1))
  local _,lines=before:gsub('\n','');local line=lines+1
  local col=#(before:match('([^\n]*)$'))+1
  if saved then
    local path=os.getenv('LITEFRONT_COMPLETION_PROJECT')..'/embedded.html'
    doc:save(path,path)
  end
  doc:set_selection(line,col)
  if automatic then
    local word=assert(before:match('([%w_%-]+)$'))
    doc:remove(line,col-#word,line,col);doc:set_selection(line,col-#word)
    received={};core.root_view:on_text_input(word)
  else assert(command.perform('litefront:complete')) end
  wait_for(function() return received[label] end,'no embedded CSS completion received for '..label)
  coroutine.yield(.3)
  local visible=false
  for _,set in pairs(autocomplete.map_manually) do for _,item in ipairs(set.items) do if item.text==label then visible=true end end end
  assert(visible,'another provider replaced embedded CSS suggestions: '..label)
  if accept_key then
    local count=#doc.lines
    assert(keymap.on_key_pressed(accept_key),'completion key was not handled: '..accept_key)
    assert(#doc.lines==count,'accepting completion inserted a newline')
    assert(table.concat(doc.lines):find(label,1,true),'completion key '..accept_key..' did not insert the CSS property: '..table.concat(doc.lines))
  else autocomplete.close() end
  assert(saved or not doc.filename,'embedded CSS completion saved an untitled buffer')
  return doc
end
core.add_thread(function()
  coroutine.yield(.1)
  local ok,err=pcall(function()
    local root=os.getenv('LITEFRONT_COMPLETION_PROJECT')
    -- ! + Tab works immediately, before any language server has initialized.
    local starter=core.open_doc();core.root_view:open_doc(starter)
    workspace.set_language(starter,syntax.get('starter.html'))
    core.root_view:on_text_input('!')
    assert(keymap.on_key_pressed('tab'))
    local text=table.concat(starter.lines)
    assert(text:match('^<!DOCTYPE html>') and text:find('<meta charset="UTF-8">',1,true)
      and text:find('name="viewport"',1,true) and text:find('</html>',1,true),'! + Tab did not insert the HTML starter')
    local function selected(doc) return doc:get_text(doc:get_selection()) end
    assert(selected(starter)=='en','language tabstop was not selected')
    assert(keymap.on_key_pressed('tab'))
    assert(selected(starter)=='Document','Tab did not advance to the title')
    core.root_view:on_text_input('My Page')
    assert(keymap.on_key_pressed('tab'))
    local body_line=starter:get_selection()
    assert(starter.lines[body_line-1]:match('<body>'),'Tab did not finish inside the body')
    assert(not starter.filename,'HTML expansion saved an untitled tab')
    -- Ordinary indentation and other languages keep their Tab behavior.
    local plain=core.open_doc();core.root_view:open_doc(plain)
    core.root_view:on_text_input('!')
    assert(keymap.on_key_pressed('tab'))
    assert(not table.concat(plain.lines):find('<!DOCTYPE',1,true),'HTML template expanded in Plain Text')
    local saved=core.open_doc(root..'/starter.html');core.root_view:open_doc(saved)
    saved:set_selection(1,2)
    assert(keymap.on_key_pressed('tab'))
    assert(table.concat(saved.lines):match('^<!DOCTYPE html>'),'! + Tab failed in a saved HTML file')
    command.perform('snippets:exit-all')
    local ordinary=core.open_doc();core.root_view:open_doc(ordinary)
    workspace.set_language(ordinary,syntax.get('ordinary.html'))
    assert(keymap.on_key_pressed('tab'))
    assert(ordinary.lines[1]:match('^ +\n$'),'ordinary HTML indentation changed')
    -- The actual key bindings must accept the highlighted suggestion rather
    -- than inserting indentation/newlines, with normal behavior when closed.
    for _,key in ipairs({'tab','return','keypad enter'}) do
      local test=core.open_doc();core.root_view:open_doc(test);test:text_input('back')
      autocomplete.complete{name='key-test',items={['background-color']=true}}
      assert(keymap.on_key_pressed(key))
      assert(table.concat(test.lines)=='background-color\n','completion was not accepted by '..key)
      assert(not autocomplete.is_open(),'accepted completion stayed open')
    end
    local newline=core.open_doc();core.root_view:open_doc(newline)
    assert(keymap.on_key_pressed('return') and #newline.lines==2,'Enter lost its normal newline behavior')
    embedded('<html><head><style>\nbody { background-col| }\n</style></head></html>','background-color','tab')
    embedded('<div style="background-col|"></div>','background-color','return')
    embedded('<style>\nbody { background-col| }\n</style>','background-color','keypad enter',true)
    embedded('<style>\nbody { background-col| }\n</style>','background-color','tab',false,true)
    embedded('<div style="display: inline-fl|"></div>','inline-flex','return')
    -- A minus sign inside JavaScript remains an operator, including in HTML.
    local script=core.open_doc();core.root_view:open_doc(script)
    workspace.set_language(script,syntax.get('embedded-script.html'))
    script:text_input('<script>let result = foo-ba')
    autocomplete.complete{name='script-test',items={bar=true}}
    assert(autocomplete.is_open(),'HTML CSS matching changed embedded JavaScript word boundaries')
    assert(keymap.on_key_pressed('return'))
    assert(table.concat(script.lines):find('foo-bar',1,true),'embedded JavaScript completion replaced the subtraction expression')
    -- A previously saved JavaScript file works without opening a project.
    query(core.open_doc(root..'/saved.js'),'log')
    -- A new unsaved tab selects a language without gaining a saved filename.
    local doc=core.open_doc();core.root_view:open_doc(doc)
    workspace.set_language(doc,syntax.get('test.html'))
    received={}
    core.root_view:on_text_input('<di')
    query(doc,'div',true,true)
    assert(not doc.filename and not doc.abs_filename,'completion changed an untitled document into a saved file')
    assert(doc.litefront_lsp_filename and not system.get_file_info(doc.litefront_lsp_filename),'completion wrote a hidden buffer file')
    doc:remove(1,1,#doc.lines,#doc.lines[#doc.lines]);doc:text_input('<di')
    doc:save(root..'/new.html',root..'/new.html')
    assert(not doc.litefront_lsp_filename,'Save did not retire the virtual identity')
    query(doc,'div')
    -- Saving a fresh CSS tab must start a new server, not merely reuse an HTML server.
    local css=core.open_doc();core.root_view:open_doc(css)
    css:text_input('body { dis')
    css:save(root..'/new.css',root..'/new.css')
    query(css,'display')
    assert(next(delayed_css),'delayed CSS startup was not exercised')
    local ts=core.open_doc();core.root_view:open_doc(ts)
    workspace.set_language(ts,syntax.get('buffer.ts'))
    core.root_view:on_text_input('new Date().')
    query(ts,'getDate')
    assert(not core.project_directories[1],'completion restored unwanted folder indexing')
    for _,item in ipairs(core.log_items) do
      assert(item.level~='ERROR',item.text)
    end
  end)
  local out=io.open(USERDIR..'/completion-test.txt','w')
  if ok then out:write('PASS\n') else
    out:write('FAIL: ',tostring(err),'\n')
    for _,item in ipairs(core.log_items) do
      if item.level=='ERROR' then out:write(item.level,': ',item.text,'\n',item.info or '','\n') end
    end
  end
  out:close();core.quit(true)
end)
