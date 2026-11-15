local core=require 'core'
local explorer=require 'plugins.litefront_explorer'
local root=os.getenv('WORKSPACE_ROOT')
local first,second,third=root..'/first',root..'/second',root..'/third'
local phase=os.getenv('WORKSPACE_PHASE')
if phase=='1' then
  assert(core.litefront_no_project and #core.project_directories==0,'fresh launch opened cwd or recents')
  core.open_folder_project(first);core.add_project_directory(second)
  explorer:update()
  explorer.width=310*SCALE;explorer.visible=true
  explorer.expanded[first..'/nested']=true;explorer.expanded[second]=false
  explorer:refresh()
  for index,row in ipairs(explorer.rows) do if row.path==first..'/nested/note.txt' then explorer.selected=index end end
  local doc=core.open_doc();core.root_view:open_doc(doc);doc:text_input('Unsaved workspace note')
elseif phase=='2' or phase=='3' then
  assert(not core.litefront_no_project and #core.project_directories==2,'open folders were not restored')
  assert(core.project_directories[1].name==first and core.project_directories[2].name==second,'restored folders or order changed')
  assert(math.abs(explorer.width-310*SCALE)<.01,'explorer width was not restored')
  assert(explorer.expanded[first..'/nested'] and explorer.expanded[second]==false,'explorer expansion state was not restored')
  if phase=='2' then
    assert(explorer.visible,'visible explorer was not restored')
    assert(explorer.rows[explorer.selected].path==first..'/nested/note.txt','explorer selection was not restored')
    assert(#core.docs==1 and core.docs[1]:is_dirty(),'unsaved document did not survive folder restoration')
    explorer.visible=false
  else
    assert(not explorer.visible,'hidden explorer was not remembered')
    local found
    for _,doc in ipairs(core.docs) do if doc.abs_filename==third..'/standalone.txt' then found=doc end end
    assert(found and found.filename==third..'/standalone.txt','standalone file location changed after restoring folder')
    found:text_input('Saved safely ');found:save()
    assert(not system.get_file_info(first..'/standalone.txt'),'standalone file was saved into restored project')
  end
elseif phase=='4' then
  assert(not core.litefront_no_project and #core.project_directories==1 and core.project_directories[1].name==third,'saved workspace overrode explicit folder argument')
  assert(explorer.visible,'old explorer visibility was applied to a different explicit workspace')
  core.root_view:close_all_docviews()
else
  assert(core.litefront_no_project and #core.project_directories==0,'missing folder reopened a recent folder or cwd')
  assert(#core.docs==0,'closed tabs reopened')
end
