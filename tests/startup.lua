local core=require 'core'
local dialogs=require 'litefront.dialogs'
local config=require 'core.config'
core.add_thread(function()
  coroutine.yield(0.25)
  local report=io.open(USERDIR..'/startup-report.txt','w')
  local ok,err=pcall(function()
    local mode=os.getenv('LITEFRONT_STARTUP_CASE')
    local fonts=require 'litefront.fonts'
    assert(fonts.ui_size==16 and fonts.code_size==18,'independent font sizes did not survive startup')
    local style=require 'core.style'
    assert(math.abs(style.font:get_size()-16*SCALE)<0.01 and math.abs(style.code_font:get_size()-18*SCALE)<0.01,'saved font sizes were not applied independently')
    if mode~='folder' then
      assert(core.litefront_no_project,'startup unexpectedly opened a project')
      assert(#core.project_directories==0 and #core.project_files==0,'startup indexed files without a chosen folder')
      assert(not dialogs.active,'startup showed a warning dialog')
      local explorer=require 'plugins.litefront_explorer'
      assert(explorer.size.x==0 and #explorer.rows==0,'explorer scanned or occupied space without an opened folder')
      if mode=='file' then
        assert(core.active_view.doc and core.active_view.doc.syntax.name=='HTML','standalone file did not open')
      end
      for _,path in ipairs(core.litefront_test_scans) do
        assert(not path:find(os.getenv('LITEFRONT_LARGE_ROOT'),1,true),'startup scanned the launch/recent folder: '..path)
      end
      -- Explicit Open Folder must still index a real project, including more than 2,000 entries.
      core.open_folder_project(os.getenv('LITEFRONT_LARGE_ROOT'))
    end
    assert(not core.litefront_no_project,'explicit folder did not enter project mode')
    coroutine.yield(0.15)
    local explorer=require 'plugins.litefront_explorer'
    assert(explorer.size.x>0 and #explorer.rows>0,'opening a folder did not show the explorer')
    local project=core.project_directories[1]
    assert(project and not project.files_limit,'explicit project indexing stopped early')
    assert(#project.files>2000 and config.max_project_files==50000,'project still uses the old file limit')
    for _,item in ipairs(project.files) do
      assert(not item.filename:match('^node_modules[/\\]') and not item.filename:match('^dist[/\\]'),'generated files were indexed')
    end
    for _,item in ipairs(core.log_items) do
      assert(item.level~='WARN' and item.level~='ERROR',item.text)
    end
  end)
  if ok then report:write('PASS\n') else report:write('FAIL: '..tostring(err)..'\n') end
  report:close()
  core.quit(true)
end)
