-- Application-owned recovery of documents; source files are never autosaved.
local core=require 'core'
local common=require 'core.common'
local M={}
local path=USERDIR..'/documents.lua'
function M.save()
  local state={documents={},projects={}}
  if not core.litefront_no_project then
    for _,directory in ipairs(core.project_directories) do state.projects[#state.projects+1]=directory.name end
  end
  local explorer=require 'plugins.litefront_explorer'
  local row=explorer.rows[explorer.selected]
  state.explorer={visible=explorer.visible,mode=explorer.mode or 'explorer',width=explorer.width/SCALE,expanded=explorer.expanded,
    selected=row and row.path,scroll=explorer.scroll.to.y/SCALE}
  local active=require('litefront.visual').document_view()
  local DocView=require 'core.docview'
  local seen={}
  local function visit(node)
    if node.a then visit(node.a);visit(node.b);return end
    if node.locked then return end
    for _,view in ipairs(node.views or {}) do
      local doc=view.doc
      if view.litefront_media then
        state.documents[#state.documents+1]={filename=view.filename,media=view.litefront_media,zoom=view.zoom,
          font_size=view.font_size,weight=view.weight,sample=view.sample}
        if core.active_view==view or (core.active_view==core.command_view and core.last_active_view==view) then state.active=#state.documents end
      elseif doc and view:is(DocView) and not seen[doc] then
        seen[doc]=true
        local item={filename=doc.abs_filename,dirty=doc:is_dirty(),
          language=doc.litefront_language and doc.litefront_language.name,
          selection={doc:get_selection()},selections={table.unpack(doc.selections)},last_selection=doc.last_selection,
          crlf=doc.crlf,source=require('plugins.litefront_media').kind(doc.abs_filename)~=nil}
        local position_view=active and active.doc==doc and active or view
        item.scroll={x=position_view.scroll.to.x/SCALE,line=position_view.scroll.to.y/position_view:get_line_height()}
        if item.dirty or not item.filename then item.text=table.concat(doc.lines) end
        state.documents[#state.documents+1]=item
        if active and active.doc==doc then state.active=#state.documents end
      end
    end
  end
  visit(core.root_view.root_node)
  local file,err=io.open(path..'.tmp','w')
  if not file then return nil,err end
  local ok,message=file:write('return '..common.serialize(state))
  local closed,close_error=file:close()
  if not ok or not closed then return nil,message or close_error end
  return os.rename(path..'.tmp',path)
end
-- Save a recovery snapshot after editing settles, and at least every 15s while
-- editing continues. Atomic replacement preserves the last complete snapshot.
function M.start_recovery()
  if M.recovery_started then return end
  M.recovery_started=true
  local Doc=require 'core.doc';local changed=Doc.on_text_change
  function Doc:on_text_change(...)
    self.litefront_recovery_generation=(self.litefront_recovery_generation or 0)+1
    return changed(self,...)
  end
  core.add_thread(function()
    local previous,pending,last_change,last_saved=nil,false,0,system.get_time()
    local function fingerprint()
      local parts={}
      local function visit(node)
        if node.a then visit(node.a);visit(node.b);return end
        for _,view in ipairs(not node.locked and node.views or {}) do
          local doc=view.doc
          if doc then
            parts[#parts+1]=table.concat({
              tostring(doc),doc:get_change_id(),tostring(doc.abs_filename),tostring(doc:is_dirty()),
              doc.litefront_recovery_generation or 0,tostring(doc.litefront_language),
              table.concat(doc.selections,','),tostring(doc.last_selection),
              view.scroll.to.x,view.scroll.to.y,
            },':')
          elseif view.litefront_media then
            parts[#parts+1]=view.filename
          end
        end
      end
      visit(core.root_view.root_node)
      for _,dir in ipairs(core.project_directories) do parts[#parts+1]=dir.name end
      local explorer=package.loaded['plugins.litefront_explorer']
      if explorer then parts[#parts+1]=tostring(explorer.width)..tostring(explorer.visible)..tostring(explorer.mode)..common.serialize(explorer.expanded) end
      return table.concat(parts,'|')
    end
    while true do
      local now=system.get_time();local current=fingerprint()
      if current~=previous then previous=current;pending=true;last_change=now end
      if pending and now-last_saved>=2 and (now-last_change>=2 or now-last_saved>=15) then
        local ok,err=M.save()
        if ok then pending=false;M.recovery_error=nil
        elseif M.recovery_error~=tostring(err) then
          M.recovery_error=tostring(err);core.log('Recovery snapshot could not be saved: %s',err)
        end
        last_saved=now
      end
      coroutine.yield(.5)
    end
  end)
end
function M.restore()
  local chunk=loadfile(path,'t',{})
  if not chunk then return end
  local ok,state=pcall(chunk)
  if not ok or type(state)~='table' or type(state.documents)~='table' then return end
  local restore_outline=core.litefront_no_project and type(state.explorer)=='table' and state.explorer.mode=='outline'
  -- Explicit folder arguments win; a standalone file can accompany the last workspace.
  if core.litefront_no_project and require('litefront.preferences').values.restore_folders and type(state.projects)=='table' then
    local seen={}
    for _,directory in ipairs(state.projects) do
      local info=type(directory)=='string' and system.get_file_info(directory)
      if info and info.type=='dir' and not seen[directory] then
        seen[directory]=true
        if core.litefront_no_project then
          -- Already-open command-line files must keep their absolute locations across chdir.
          for _,doc in ipairs(core.docs) do if doc.abs_filename then doc.filename=doc.abs_filename end end
          if core.set_project_dir(directory) then core.litefront_no_project=false end
        end
        if not core.litefront_no_project then core.add_project_directory(directory) end
      end
    end
    for _,doc in ipairs(core.docs) do if doc.abs_filename then doc.filename=core.normalize_to_project_dir(doc.abs_filename) end end
    if not core.litefront_no_project and type(state.explorer)=='table' then
      local explorer=require 'plugins.litefront_explorer'
      local saved=state.explorer
      explorer.project,explorer.no_project,explorer.directories=core.project_dir,core.litefront_no_project,core.project_directories
      explorer.visible=saved.visible~=false
      if type(saved.width)=='number' and saved.width==saved.width then explorer.width=math.max(140,math.min(1000,saved.width))*SCALE end
      explorer.expanded={}
      for name,expanded in pairs(type(saved.expanded)=='table' and saved.expanded or {}) do
        if type(name)=='string' and type(expanded)=='boolean' then explorer.expanded[name]=expanded end
      end
      explorer:refresh()
      for index,row in ipairs(explorer.rows) do if row.path==saved.selected then explorer.selected=index;break end end
      if type(saved.scroll)=='number' and saved.scroll==saved.scroll then explorer.scroll.y=math.max(0,saved.scroll)*SCALE;explorer.scroll.to.y=explorer.scroll.y end
    end
  end
  local selected
  for i,item in ipairs(state.documents) do
    local success,err=pcall(function()
      if item.media then
        if not item.filename or not system.get_file_info(item.filename) then return end
        local view=core.root_view:open_doc(core.open_doc(item.filename))
        if view and view.litefront_media then
          local function bounded(value,low,high,default)
            return type(value)=='number' and value==value and math.max(low,math.min(high,value)) or default
          end
          view.zoom=bounded(item.zoom,.01,32,nil)
          view.font_size=bounded(item.font_size,8,128,32);view.weight=bounded(item.weight,100,900,400)
          view.sample=type(item.sample)=='string' and item.sample:sub(1,2048) or view.sample
          if view.litefront_media=='font' then view:load() end
          if i==state.active then selected=view end
        end
        return
      end
      local doc
      if item.filename and system.get_file_info(item.filename) then
        local media=require 'plugins.litefront_media'
        if item.source or (item.text and media.kind(item.filename)) then doc=media.text_doc(item.filename)
        else doc=core.open_doc(item.filename) end
      elseif item.text then
        doc=core.open_doc()
        if item.filename then doc:set_filename(item.filename,item.filename) end
      else return end
      if doc.litefront_media then
        local view=core.root_view:open_doc(doc)
        if i==state.active then selected=view end
        return
      end
      if item.text then
        doc:remove(1,1,#doc.lines,#doc.lines[#doc.lines])
        doc:insert(1,1,item.text:sub(1,-2))
        if item.dirty then doc.clean_change_id=-1 end
        if not item.dirty then doc:clean() end
      end
      doc.crlf=item.crlf
      if item.language then
        local syntax=require 'core.syntax'
        local language=item.language=='Plain Text' and syntax.get(nil,nil) or nil
        for _,entry in ipairs(syntax.items) do if entry.name==item.language then language=entry;break end end
        require('plugins.litefront_workspace').set_language(doc,language)
      end
      if item.selection then doc:set_selection(table.unpack(item.selection)) end
      if type(item.selections)=='table' and #item.selections>=4 and #item.selections%4==0 then
        local valid=true
        for _,value in ipairs(item.selections) do
          if type(value)~='number' or value~=value or value<1 or value==math.huge or value%1~=0 then valid=false;break end
        end
        if valid then
          doc.selections={}
          for index=1,#item.selections,4 do
            doc:set_selections((index+3)/4,table.unpack(item.selections,index,index+3))
          end
          doc.last_selection=type(item.last_selection)=='number' and item.last_selection==item.last_selection
            and common.clamp(math.floor(item.last_selection),1,#doc.selections/4) or 1
        end
      end
      local view=core.root_view:open_doc(doc)
      if type(item.scroll)=='table' then
        local function finite(value) return type(value)=='number' and value==value and value>=0 and value<math.huge end
        if finite(item.scroll.x) then view.scroll.x=math.min(item.scroll.x*SCALE,1e7);view.scroll.to.x=view.scroll.x end
        if finite(item.scroll.line) then
          view.scroll.y=common.clamp(item.scroll.line*view:get_line_height(),0,math.max(0,view:get_scrollable_size()-view.size.y))
          view.scroll.to.y=view.scroll.y
        end
        -- The first update must not treat the restored caret as a new move and
        -- replace the saved viewport. Subsequent user movement scrolls normally.
        view.last_line1,view.last_col1,view.last_line2,view.last_col2=doc:get_selection()
      end
      if i==state.active then selected=view end
    end)
    if not success then core.error('Could not restore document: %s',err) end
  end
  if selected then core.root_view.root_node:get_node_for_view(selected):set_active_view(selected) end
  if restore_outline then
    local explorer=require 'plugins.litefront_explorer';local saved=state.explorer
    explorer.mode='outline';explorer.visible=saved.visible~=false
    if type(saved.width)=='number' and saved.width==saved.width then explorer.width=math.max(140,math.min(600,saved.width))*SCALE end
  end
end
return M
