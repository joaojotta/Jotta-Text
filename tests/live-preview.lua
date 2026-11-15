local core=require 'core'
local command=require 'core.command'
local preview=require 'litefront.web_preview'
local function replace(doc,text)
  doc:remove(1,1,#doc.lines,#doc.lines[#doc.lines]);doc:insert(1,1,text)
end
local html=core.open_doc(core.project_dir..'/index.html');local html_view=core.root_view:open_doc(html)
local css=core.open_doc(core.project_dir..'/style.css');local css_view=core.root_view:open_doc(css)
local js=core.open_doc(core.project_dir..'/app.js');core.root_view:open_doc(js)
replace(html,'<h1>Initial unsaved é</h1>\n<link rel="stylesheet" href="style.css"><script src="app.js"></script>')
replace(css,'body { color: red; }');replace(js,'console.log("initial unsaved")')
core.root_view.root_node:get_node_for_view(html_view):set_active_view(html_view)
assert(command.perform('litefront:open-web-preview'))
local function write(name,text) local out=assert(io.open(USERDIR..'/'..name,'w'));out:write(text);out:close() end
for _=1,100 do if preview.url then break end;coroutine.yield(.05) end
assert(preview.url,'preview did not report a listening URL')
write('url',preview.url)
local previous,untitled
for _=1,600 do
  local input=io.open(USERDIR..'/action','r')
  local action=input and input:read('*a')
  if input then input:close() end
  if action and action~=previous then
    previous=action
    if action=='edit' then
      replace(html,'<h1>Changed while typing</h1>');replace(css,'body { color: green; }');replace(js,'console.log("changed while typing")')
    elseif action=='discard-css' then
      core.root_view.root_node:get_node_for_view(css_view):remove_view(core.root_view.root_node,css_view)
    elseif action=='undo' then
      core.root_view.root_node:get_node_for_view(html_view):set_active_view(html_view)
      assert(command.perform('doc:undo'))
      write('expected-undo',table.concat(html.lines))
    elseif action=='untitled' then
      untitled=core.open_doc();core.root_view:open_doc(untitled)
      require('plugins.litefront_workspace').set_language(untitled,require('core.syntax').get('untitled.html'))
      untitled:text_input('<h1>Untitled HTML</h1>')
      assert(command.perform('litefront:open-web-preview'))
      assert(not untitled.abs_filename and not untitled.filename,'preview saved an untitled document')
      write('untitled-url',preview.url:match('^http://[^/]+')..'/'..preview.virtual_path)
    elseif action=='edit-untitled' then
      replace(untitled,'<h1>Untitled live update</h1>')
    elseif action=='quit' then
      write('result','PASS');core.quit();return
    end
    write('ack',action)
  end
  coroutine.yield(.05)
end
error('Live preview integration test timed out')
