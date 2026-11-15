-- Native outline sidebar adapted from Jotta Edit's document-outline panel.
local core=require 'core'
local style=require 'core.style'
local common=require 'core.common'
local Doc=require 'core.doc'
local DocView=require 'core.docview'
local visual=require 'litefront.visual'
local json=require 'plugins.json'
local T=require('litefront.i18n').t
local M={entries={},rows={},filter='',caret=1,anchor=1,selected=1,generation=0,status='Open a document to see its outline.'}
local supported={markdown=true,html=true,javascript=true,jsx=true,typescript=true,tsx=true,css=true,scss=true,less=true,php=true,python=true}
local function language(doc)
  if not doc.litefront_language and doc.filename then
    local extension=doc.filename:lower():match('%.([^./]+)$')
    if extension=='scss' or extension=='less' then return extension end
  end
  local name=doc.syntax.name:lower()
  return name=='php source' and 'php' or name=='typescript with jsx' and 'tsx' or name
end
local function key_for(doc,view)
  return tostring(doc)..':'..doc:get_change_id()..':'..tostring(doc.litefront_outline_version)..':'..language(doc)..':'..tostring(view)
end
local changed=Doc.on_text_change
function Doc:on_text_change(...)
  self.litefront_outline_version=(self.litefront_outline_version or 0)+1
  return changed(self,...)
end
local function valid(view)
  local node=view and core.root_view.root_node:get_node_for_view(view)
  return node and node.active_view==view and view~=core.command_view and view:extends(DocView)
end
function M.source_view(explorer)
  local active=core.active_view
  if valid(active) then return active end
  if active==core.command_view and valid(core.last_active_view) then return core.last_active_view end
  if active==explorer or active==core.status_view then
    if valid(M.source) then return M.source end
    if valid(explorer.return_view) then return explorer.return_view end
    local primary=core.root_view:get_primary_node().active_view
    if valid(primary) then return primary end
  end
end
function M.stop(keep_key)
  local worker=M.worker;M.worker=nil;M.job=nil;if not keep_key then M.document_key=nil end
  if worker then pcall(worker.child.kill,worker.child) end
end
function M.rebuild()
  M.rows={}
  local query=M.filter:match('^%s*(.-)%s*$'):lower()
  for _,item in ipairs(M.entries) do
    if query=='' or item.name:lower():find(query,1,true) then M.rows[#M.rows+1]=item end
  end
  M.selected=common.clamp(M.selected,1,math.max(1,#M.rows));core.redraw=true
end
local function failed()
  M.status='Could not load outline. Try Refresh.';M.entries={};M.rows={};core.redraw=true
end
local function accept(worker,result)
  local job=M.job
  if M.worker~=worker or not job or result.id~=job.id then return end
  M.job=nil
  local view=M.source_view(M.view)
  if not view or view~=job.view or M.generation~=job.id
    or view.doc:get_change_id()~=job.revision or view.doc.litefront_outline_version~=job.version
    or language(view.doc)~=job.language then return end
  if result.error then failed();return end
  M.entries=result.entries or {};M.limited=result.limited
  M.status=result.tooLarge and 'This document is too large for the outline.'
    or not result.supported and 'Outline is not available for this language.'
    or result.limited and 'Showing the first 1,000 outline entries.'
    or #M.entries>0 and 'Select an entry to jump to it.' or 'No headings, elements, functions or selectors found.'
  M.rebuild()
end
local function ensure_worker()
  if M.worker then return M.worker end
  local ok,child
  if JOTTA_WEB then ok,child=true,require('litefront.browser').worker('outline')
  else ok,child=pcall(process.start,{require('litefront.runtime').node,DATADIR..'/litefront/outline.mjs'}) end
  if not ok then failed();return end
  local worker={child=child,output=''};M.worker=worker
  core.add_thread(function()
    local success=pcall(function()
      while M.worker==worker do
        local send=worker.send
        if send then
          local count=child:write(send.text:sub(send.offset,send.offset+65535))
          send.offset=send.offset+(count or 0)
          if send.offset>#send.text then worker.send=nil end
        end
        for _=1,32 do
          local text=child:read_stdout();if not text or text=='' then break end
          worker.output=worker.output..text
        end
        while true do
          local finish=worker.output:find('\n',1,true);if not finish then break end
          local message=worker.output:sub(1,finish-1);worker.output=worker.output:sub(finish+1)
          local parsed,result=pcall(json.decode,message)
          if parsed then accept(worker,result) else error('Invalid outline response') end
        end
        child:read_stderr()
        if #worker.output>2*1024*1024 then error('Outline response too large') end
        if not child:running() then error('Outline worker stopped') end
        if M.job and system.get_time()-M.job.started>10 then error('Outline worker timed out') end
        coroutine.yield(.01)
      end
    end)
    if M.worker==worker then
      local current=M.job and M.job.id==M.generation
      M.stop(true)
      if not success and current then M.pending=false;failed() end
    end
  end)
  return worker
end
function M.refresh()
  if M.job then M.stop() end
  M.document_key=nil;M.generation=M.generation+1;M.changed_at=system.get_time()-.22;core.redraw=true
end
function M.update(view)
  M.view=view
  if not view.visible then if M.worker then M.stop() end;return end
  local source=M.source_view(view);local doc=source and source.doc
  local key=doc and key_for(doc,source) or 'none'
  if key~=M.document_key then
    local new_doc=M.doc~=doc;M.doc=doc;M.source=source;M.document_key=key;M.generation=M.generation+1
    M.changed_at=system.get_time();M.pending=doc~=nil;M.entries={};M.rows={};M.active=nil
    M.status=doc and 'Loading outline…' or 'Open a document to see its outline.'
    if new_doc then view.scroll.y,view.scroll.to.y=0,0;M.selected=1 end
    if doc and not supported[language(doc)] then M.pending=false;M.status='Outline is not available for this language.' end
    core.redraw=true
  end
  if M.pending and not M.job and system.get_time()-M.changed_at>=.22 then
    M.pending=false
    local size=0;for _,line in ipairs(doc.lines) do size=size+#line;if size>2*1024*1024 then break end end
    if size>2*1024*1024 then M.status='This document is too large for the outline.';core.redraw=true
    else
      local worker=ensure_worker()
      if worker then
        local id=M.generation
        M.job={id=id,view=source,revision=doc:get_change_id(),version=doc.litefront_outline_version,language=language(doc),started=system.get_time()}
        worker.send={text=json.encode({id=id,source=table.concat(doc.lines),language=language(doc)})..'\n',offset=1}
      end
    end
  end
  local active
  if doc then
    local line,col=doc:get_selection()
    for _,item in ipairs(M.rows) do
      if (line>item.line or line==item.line and col>=item.column)
        and (line<item.endLine or line==item.endLine and col<=item.endColumn) then active=item end
    end
  end
  if M.active~=active then M.active=active;core.redraw=true end
end
function M.show()
  local view=require 'plugins.litefront_explorer'
  M.source=M.source_view(view);M.document_key=nil
  if view.mode~='outline' then
    view.file_scroll={y=view.scroll.y,to=view.scroll.to.y}
    local saved=view.outline_scroll or {y=0,to=0};view.scroll.y,view.scroll.to.y=saved.y,saved.to
  end
  view.mode='outline';view.visible=true
  view:animate_to(view:desired_width());core.status_view:remove_tooltip();core.redraw=true
end
local function metrics()
  local title=math.max(34*SCALE,style.small_font:get_height()+14*SCALE)
  local source=style.small_font:get_height()+8*SCALE
  local filter=math.max(30*SCALE,style.font:get_height()+10*SCALE)
  local status=title+source+4*SCALE+filter+6*SCALE
  return title,source,filter,status,status+2*(style.small_font:get_height()+2*SCALE)+8*SCALE
end
function M.header_height() local _,_,_,_,height=metrics();return height end
function M.scrollable_size(view) return M.header_height()+#M.rows*view:row_height()+6*SCALE end
function M.row_at(view,x,y)
  if x<view.position.x or x>=view.position.x+view.size.x or y<view.position.y+M.header_height() or y>=view.position.y+view.size.y then return end
  local index=math.floor((y-view.position.y-M.header_height()+view.scroll.y)/view:row_height())+1
  return M.rows[index] and index
end
local function filter_rect(view)
  local title,source,filter=metrics()
  return {x=view.position.x+10*SCALE,y=view.position.y+title+source+4*SCALE,w=math.max(1,view.size.x-20*SCALE),h=filter}
end
local function inside(rect,x,y) return x>=rect.x and x<rect.x+rect.w and y>=rect.y and y<rect.y+rect.h end
function M.reveal(view)
  local top=(M.selected-1)*view:row_height();local height=math.max(1,view.size.y-M.header_height())
  if top<view.scroll.to.y then view.scroll.to.y=top
  elseif top+view:row_height()>view.scroll.to.y+height then view.scroll.to.y=top+view:row_height()-height end
end
function M.activate(index)
  local item=M.rows[index];local view=M.source;local doc=view and view.doc
  if not item or not valid(view) or M.pending or M.job then return end
  local key=key_for(doc,view)
  if key~=M.document_key then M.refresh();return end
  M.selected=index;M.focus='list'
  core.set_active_view(view);doc:set_selection(item.line,item.column)
  view:scroll_to_line(item.line,true,true);core.redraw=true
end
local function restore_source(view)
  if valid(M.source) then core.set_active_view(M.source) else view:restore_editor() end
end
function M.click(view,button,x,y)
  if button~='left' then return true end
  if y<view.position.y+select(1,metrics()) then
    if x>=view.position.x+view.size.x-30*SCALE then
      view.visible=false;M.stop();view:animate_to(0);if core.active_view==view then restore_source(view) end
    elseif x>=view.position.x+view.size.x-58*SCALE then M.refresh() end
  elseif inside(filter_rect(view),x,y) then
    M.focus='filter';M.anchor=1;M.caret=#M.filter+1
  else local index=M.row_at(view,x,y);if index then M.activate(index) end end
  core.redraw=true;return true
end
function M.move(view,x,y)
  local index=M.row_at(view,x,y)
  if M.hovered~=index then M.hovered=index;core.redraw=true end
  if index then
    local item=M.rows[index]
    core.status_view:show_tooltip({style.text,T(item.kind)..' · '..T('Line')..' '..item.line..' · '..item.name})
  else core.status_view:remove_tooltip() end
  local title=select(1,metrics())
  if y<view.position.y+title and x>=view.position.x+view.size.x-58*SCALE then
    view.cursor='hand'
    core.status_view:show_tooltip({style.text,T(x>=view.position.x+view.size.x-30*SCALE and 'Close outline' or 'Refresh outline')})
  else view.cursor=inside(filter_rect(view),x,y) and 'ibeam' or index and 'hand' or 'arrow' end
end
function M.input(text)
  if M.focus~='filter' then M.focus='filter';M.anchor=M.caret end
  local first,last=math.min(M.anchor,M.caret),math.max(M.anchor,M.caret)
  text=text:gsub('[\r\n]','');if #M.filter-(last-first)+#text>240 then return end
  M.filter=M.filter:sub(1,first-1)..text..M.filter:sub(last);M.caret=first+#text;M.anchor=M.caret
  M.selected=1;M.rebuild();if M.view then M.view.scroll.to.y=0 end
end
function M.key(key)
  local mods=require('core.keymap').modkeys;local view=M.view
  if not view then return end
  if key=='f5' then M.refresh();return true end
  if mods.ctrl and key=='f' then M.focus='filter';M.anchor=1;M.caret=#M.filter+1;core.redraw=true;return true end
  if key=='escape' then
    if M.focus=='filter' and M.filter~='' then M.filter='';M.caret=1;M.anchor=1;M.rebuild()
    else M.focus='list';restore_source(view) end
    return true
  end
  if key=='tab' then M.focus=M.focus=='filter' and 'list' or 'filter';core.redraw=true;return true end
  if key=='return' or key=='keypad enter' then M.activate(M.selected);return true end
  if M.focus=='filter' then
    if mods.ctrl and key=='a' then M.anchor=1;M.caret=#M.filter+1
    elseif mods.ctrl and (key=='c' or key=='x') then
      system.set_clipboard(M.filter:sub(math.min(M.anchor,M.caret),math.max(M.anchor,M.caret)-1));if key=='x' then M.input('') end
    elseif mods.ctrl and key=='v' then M.input(system.get_clipboard() or '')
    elseif key=='left' or key=='right' or key=='home' or key=='end' then
      M.caret=key=='home' and 1 or key=='end' and #M.filter+1 or key=='left' and (M.caret>1 and (utf8.offset(M.filter,-1,M.caret) or 1) or 1) or (M.caret<=#M.filter and (utf8.offset(M.filter,2,M.caret) or #M.filter+1) or #M.filter+1)
      if not mods.shift then M.anchor=M.caret end
    elseif key=='backspace' or key=='delete' then
      if M.anchor==M.caret then M.anchor=key=='backspace' and (M.caret>1 and (utf8.offset(M.filter,-1,M.caret) or 1) or 1) or (M.caret<=#M.filter and (utf8.offset(M.filter,2,M.caret) or #M.filter+1) or #M.filter+1) end
      M.input('')
    elseif key~='up' and key~='down' then return false end
    if key~='up' and key~='down' then core.redraw=true;return true end
  end
  if key=='up' or key=='down' or key=='home' or key=='end' then
    M.focus='list';M.selected=key=='home' and 1 or key=='end' and math.max(1,#M.rows) or common.clamp(M.selected+(key=='up' and -1 or 1),1,math.max(1,#M.rows))
    M.reveal(view);core.redraw=true;return true
  end
end
local function wrap(text,width,font)
  local lines,line={},''
  for char in common.utf8_chars(text) do
    if font:get_width(line..char)>width and line~='' then lines[#lines+1]=line;line='' end
    line=line..char
  end
  lines[#lines+1]=line;return lines
end
function M.draw(view)
  local x,y,w,h=view.position.x,view.position.y,view.size.x,view.size.y
  if w<1 then return end
  view:draw_background(style.sidebar_background or style.background2)
  local title,source_height,_,status_y,header=metrics();local rh=view:row_height()
  core.push_clip_rect(x,y+header,w,math.max(0,h-header))
  local first=math.max(1,math.floor(view.scroll.y/rh)+1)
  for i=first,math.min(#M.rows,first+math.ceil(h/rh)) do
    local item=M.rows[i];local ry=y+header+(i-1)*rh-view.scroll.y
    if item==M.active or (core.active_view==view and M.focus~='filter' and M.selected==i) then
      renderer.draw_rect(x,ry,w,rh,style.ui_selection or style.line_highlight)
    elseif M.hovered==i then renderer.draw_rect(x,ry,w,rh,style.hover_background) end
    local indent=10*SCALE+math.min(8,item.depth)*6*SCALE
    local icon=item.kind=='Heading' and 'md-heading' or item.kind=='Class' and 'file-file-code' or 'code'
    visual.icon(icon,x+indent,ry+(rh-14*SCALE)/2,14*SCALE,style.accent)
    local lw=math.max(24*SCALE,style.small_font:get_width(tostring(item.line))+8*SCALE)
    visual.text(style.label_font,item.name,x+indent+20*SCALE,ry,math.max(0,w-indent-28*SCALE-lw),rh,style.text)
    visual.text(style.small_font,tostring(item.line),x+w-lw-6*SCALE,ry,lw,rh,style.dim,'right')
  end
  core.pop_clip_rect()
  core.push_clip_rect(x,y,w,math.min(h,header))
  visual.text(style.bold_font,T('Document outline'),x+10*SCALE,y,math.max(0,w-72*SCALE),title,style.text)
  visual.icon('refresh',x+w-53*SCALE,y+(title-14*SCALE)/2,14*SCALE,style.dim)
  visual.icon('close',x+w-25*SCALE,y+(title-16*SCALE)/2,16*SCALE,style.dim)
  local doc=M.source and M.source.doc
  visual.text(style.small_font,doc and (doc.abs_filename and common.basename(doc.abs_filename) or T('Untitled')) or '',x+10*SCALE,y+title,w-20*SCALE,source_height,style.dim)
  local rect=filter_rect(view);local focused=core.active_view==view and M.focus=='filter'
  visual.rounded(rect.x-1,rect.y-1,rect.w+2,rect.h+2,5*SCALE,focused and style.accent or style.divider)
  visual.rounded(rect.x,rect.y,rect.w,rect.h,4*SCALE,style.input_background)
  core.push_clip_rect(rect.x+6*SCALE,rect.y,math.max(0,rect.w-12*SCALE),rect.h)
  local offset=focused and math.max(0,style.font:get_width(M.filter:sub(1,M.caret-1))-rect.w+16*SCALE) or 0
  local tx=rect.x+7*SCALE-offset
  if focused and M.caret~=M.anchor then
    local first_col,last=math.min(M.caret,M.anchor),math.max(M.caret,M.anchor)
    renderer.draw_rect(tx+style.font:get_width(M.filter:sub(1,first_col-1)),rect.y+4*SCALE,style.font:get_width(M.filter:sub(first_col,last-1)),rect.h-8*SCALE,style.ui_selection or style.selection)
  end
  renderer.draw_text(style.font,M.filter=='' and T('Find a heading or symbol…') or M.filter,tx,rect.y+(rect.h-style.font:get_height())/2,M.filter=='' and style.dim or style.text)
  if focused then renderer.draw_rect(tx+style.font:get_width(M.filter:sub(1,M.caret-1)),rect.y+5*SCALE,1,rect.h-10*SCALE,style.accent) end
  core.pop_clip_rect()
  local message=M.filter~='' and #M.rows==0 and #M.entries>0 and 'No outline entries match.' or M.status
  local lines=wrap(T(message),math.max(1,w-20*SCALE),style.small_font)
  for i=1,math.min(2,#lines) do renderer.draw_text(style.small_font,lines[i],x+10*SCALE,y+status_y+(i-1)*(style.small_font:get_height()+2*SCALE),style.dim) end
  core.pop_clip_rect()
  view:draw_scrollbar();renderer.draw_rect(x+w-1,y,1,h,style.divider)
end
M.filter_rect=filter_rect
return M
