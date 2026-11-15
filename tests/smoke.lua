-- Appended only to a disposable test bundle, never shipped.
core.add_thread(function()
  coroutine.yield(0.5)
  local command=require 'core.command'
  assert(package.loaded['plugins.litefront_shell'], 'missing application chrome')
  assert(package.loaded['plugins.litefront_files'], 'missing native dialogs')
  assert(package.loaded['plugins.lsp'], 'missing bundled language client')
  assert(package.loaded['plugins.litemark'], 'missing bundled Markdown renderer')
  assert(not package.loaded['plugins.treeview'], 'legacy treeview unexpectedly loaded')
  assert(not command.map['core:open-user-module'], 'user extension configuration exposed')
  assert(not package.path:find(USERDIR,1,true), 'user modules can shadow bundled code')
  assert(not rawget(_G,'LITEFRONT_USER_EXTENSION_LOADED'), 'user plugin was executed')
  assert(not rawget(_G,'LITEFRONT_PROJECT_EXTENSION_LOADED'), 'project Lua was executed')
  assert(not rawget(_G,'LITEFRONT_USER_INIT_LOADED'), 'user init.lua was executed')
  local popup=require('plugins.litefront_shell').popup
  local explorer=require 'plugins.litefront_explorer'
  local previous=core.active_view
  core.set_active_view(explorer)
  assert(command.perform('litefront-menu:edit'))
  local count=0
  for _,item in ipairs(popup.items) do if item.command then
    count=count+1;assert(item.disabled,'editor command enabled in explorer')
  end end
  assert(count==8,'Edit menu hid unavailable commands')
  popup:focus_next();assert(popup.selected==-1,'keyboard selected a disabled command')
  popup:focus_previous();assert(popup.selected==-1,'reverse navigation selected a disabled command')
  local invoked=false;local original=command.perform
  command.perform=function(...) invoked=true;return original(...) end
  popup:on_selected(popup.items[1]);assert(not invoked,'disabled menu command executed')
  command.perform=original
  popup:hide();core.set_active_view(previous)
  assert(command.perform('litefront-menu:file'))
  coroutine.yield(0.1)
  command.perform('litefront-menu:next')
  command.perform('litefront-menu:close')
  command.perform('litefront:theme-light')
  coroutine.yield(0.1)
  command.perform('litefront:theme-dark')
  local doc=core.open_doc(core.project_dir..'/format.js')
  core.root_view:open_doc(doc)
  assert(command.perform('litefront-menu:edit'))
  local select_all
  for i,item in ipairs(popup.items) do if item.command then
    assert(not item.disabled,'editor command remained disabled with a document focused')
    if item.command=='doc:select-all' then select_all=i end
  end end
  popup.selected=assert(select_all);popup:call_selected_item()
  assert(doc:has_selection(),'Edit menu Select All did not run')
  doc:set_selection(1,1)
  assert(command.perform('litefront:format-prettier'))
  coroutine.yield(1)
  local formatted=io.open(doc.abs_filename,'r')
  assert(formatted:read('*a')=='const answer=42','formatter wrote to disk')
  assert(table.concat(doc.lines)=='const answer = 42;\n' and doc:is_dirty(),'formatter did not update the buffer')
  formatted:close()
  assert(command.perform('litefront:format-prettier'))
  doc:text_input('// keep newer editor edit')
  local revision=doc:get_change_id()
  coroutine.yield(0.6)
  assert(doc:get_change_id()==revision and doc:is_dirty(),'formatter discarded newer edits (revision '..revision..' -> '..doc:get_change_id()..', dirty '..tostring(doc:is_dirty())..')')
  -- Do not leave an unsaved edit in the disposable test session.
  doc:reload()
  local md=core.open_doc()
  core.root_view:open_doc(md)
  local markdown=core.project_dir..'/preview.md'
  local output=io.open(markdown,'w');output:write('# Preview\n');output:close()
  core.root_view:open_doc(core.open_doc(markdown))
  assert(command.perform('litefront:md-preview'))
  coroutine.yield(0.1)
  dofile(DATADIR..'/litefront/workspace-test.lua')
  dofile(DATADIR..'/litefront/dialogs-html-test.lua')
  dofile(DATADIR..'/litefront/visuals-test.lua')
  dofile(DATADIR..'/litefront/markdown-test.lua')
  dofile(DATADIR..'/litefront/explorer-test.lua')
  local file=io.open(USERDIR..'/smoke-result.txt','w')
  for _,item in ipairs(core.log_items) do
    file:write(item.level..': '..item.text..'\n')
  end
  file:write('SMOKE COMPLETE\n');file:close()
  core.quit(true)
end)
