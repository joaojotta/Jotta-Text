-- Removable modal Git/GitHub trial; repository data comes from the background worker.
local core=require 'core'
local style=require 'core.style'
local common=require 'core.common'
local visual=require 'litefront.visual'
local service=require 'litefront.github.service'
local T=require('litefront.i18n').t
local M={active=nil}
local function clean(text) return tostring(text or ''):gsub('[%c]',' ') end
local function field(text) return {text=text or '',caret=#(text or '')+1,anchor=#(text or '')+1} end
local function inside(item,x,y) return x>=item.x and x<item.x+item.w and y>=item.y and y<item.y+item.h end
local function enabled() return not JOTTA_WEB and require('litefront.preferences').values.github_trial end
function M.close()
  if service.job then service.cancel() end
  M.active=nil;core.redraw=true
end
local function submit(request,callback)
  local state=M.active;if not state or service.job then return end
  state.error=nil;state.message='Working…'
  service.run(request,function(result,err)
    if M.active~=state then return end
    state.message=nil
    if err then
      state.error=err;require('litefront.dialogs').show(T('GitHub trial'),err);return
    end
    callback(result);core.redraw=true
  end)
  core.redraw=true
end
function M.refresh()
  local state=M.active;if not state then return end
  if not state.root then state.message='Open a repository folder, or clone one.';return end
  local selected=state.data and state.data.files[state.selected or 1]
  submit({action='status',root=state.root},function(data)
    if data.notRepository then state.data=nil;state.message='Open a repository folder, or clone one.';return end
    state.root=data.root;state.data=data;state.selected=1;state.scroll=0
    if selected then for i,file in ipairs(data.files) do if file.path==selected.path then state.selected=i;break end end end
  end)
end
function M.open()
  if not enabled() then return end
  if require('litefront.settings').active or require('litefront.color_picker').active or require('litefront.dialogs').active then return end
  require('core.command').perform('litefront-menu:close')
  M.active={root=not core.litefront_no_project and core.project_dir or nil,selected=1,scroll=0,mode='repository',
    inputs={message=field(),url=field(),parent=field((PLATFORM=='Windows' and os.getenv('USERPROFILE') or os.getenv('HOME')) or core.project_dir)},focus='message'}
  M.refresh()
end
local function selected()
  local state=M.active;return state and state.data and state.data.files[state.selected or 1]
end
function M.action(id)
  local state=M.active;if not state then return end
  if id=='close' then M.close();return end
  if service.job then return end
  if id=='refresh' then M.refresh();return end
  if id=='clone' then state.mode='clone';state.focus='url';return end
  if id=='back' then state.mode='repository';return end
  if id=='browse' then
    require('plugins.litefront_files').dialog('folder',state.inputs.parent.text,nil,function(path)
      if M.active==state then state.inputs.parent=field(path);core.redraw=true end
    end);return
  end
  if id=='clone-now' then
    submit({action='clone',url=state.inputs.url.text,parent=state.inputs.parent.text},function(result)
      state.root=result.root;state.mode='repository';M.refresh()
      core.confirm_close_docs(core.docs,function() core.open_folder_project(result.root) end)
    end);return
  end
  local data=state.data;if not data then return end
  if id=='github' or id=='issues' or id=='pulls' then
    submit({action='link',root=state.root,page=id},function(result)
      local ok,err=pcall(process.start,{require('litefront.runtime').dialog,'github-uri',result.url})
      if not ok then state.error=tostring(err);require('litefront.dialogs').show(T('GitHub trial'),tostring(err)) end
    end);return
  end
  if id=='fetch' or id=='push' then
    submit({action=id,root=state.root,expectedHead=data.head,expectedBranch=data.branch,expectedRemote=data.pushGithub and data.pushGithub.url},function() M.refresh() end);return
  end
  if id=='commit' then
    submit({action='commit',root=state.root,message=state.inputs.message.text,expectedHead=data.head,expectedIndex=data.indexHash},function()
      state.inputs.message=field();M.refresh()
    end);return
  end
  local item=selected();if not item then return end
  if id=='stage' or id=='unstage' then
    submit({action=id,root=state.root,path=item.path,originalPath=item.originalPath},function() M.refresh() end)
  elseif id=='diff' or id=='staged-diff' then
    submit({action='diff',root=state.root,path=item.path,staged=id=='staged-diff'},function(result)
      M.active=nil
      local doc=core.open_doc();core.root_view:open_doc(doc);doc:text_input(result.text);doc:clean()
      require('plugins.litefront_workspace').set_language(doc,require('core.syntax').get('changes.diff'))
      function doc:get_name() return T('Git diff: %s',clean(item.path)) end
      doc:set_selection(1,1)
    end)
  end
end
function M.layout()
  local s=M.active;if not s then return end
  local root=core.root_view;local w=math.max(1,math.min(940*SCALE,root.size.x-24*SCALE))
  local h=math.max(1,math.min(620*SCALE,root.size.y-24*SCALE))
  local x=common.clamp(s.x or (root.size.x-w)/2,0,math.max(0,root.size.x-w))
  local y=common.clamp(s.y or (root.size.y-h)/2,0,math.max(0,root.size.y-h))
  s.panel={x=x,y=y,w=w,h=h};s.controls={}
  local function control(kind,id,cx,cy,cw,ch,label,disabled)
    local c={kind=kind,id=id,x=x+cx,y=y+cy,w=cw,h=ch,label=label,disabled=disabled};s.controls[#s.controls+1]=c;return c
  end
  local busy=service.job~=nil
  control('button','close',w-42*SCALE,12*SCALE,28*SCALE,28*SCALE,busy and '×' or '×')
  if s.mode=='clone' then
    control('button','back',18*SCALE,58*SCALE,110*SCALE,32*SCALE,'Back',busy)
    control('label','url-label',18*SCALE,108*SCALE,w-36*SCALE,24*SCALE,'GitHub HTTPS or SSH URL')
    control('input','url',18*SCALE,138*SCALE,w-36*SCALE,34*SCALE,nil,busy)
    control('label','parent-label',18*SCALE,192*SCALE,w-36*SCALE,24*SCALE,'Destination parent folder')
    control('input','parent',18*SCALE,222*SCALE,math.max(20,w-152*SCALE),34*SCALE,nil,busy)
    control('button','browse',w-124*SCALE,222*SCALE,106*SCALE,34*SCALE,'Browse…',busy)
    control('label','clone-note',18*SCALE,276*SCALE,w-36*SCALE,52*SCALE,'A new folder named after the repository will be created.')
    control('button','clone-now',18*SCALE,h-62*SCALE,180*SCALE,34*SCALE,'Clone repository',busy or s.inputs.url.text=='' or s.inputs.parent.text=='')
    return s
  end
  local bx,by=18*SCALE,62*SCALE
  for _,button in ipairs({{'refresh','Refresh'},{'clone','Clone…'},{'fetch','Fetch'},{'push','Push'},
    {'github','GitHub'},{'issues','Issues'},{'pulls','Pull requests'}}) do
    local bw=style.font:get_width(T(button[2]))+24*SCALE
    if bx+bw>w-18*SCALE then bx=18*SCALE;by=by+40*SCALE end
    local data=s.data
    local unavailable=button[1]~='refresh' and button[1]~='clone' and (not data or not data.github)
    if button[1]=='push' then unavailable=not data or not data.canPush or not data.branch or not data.head end
    control('button',button[1],bx,by,bw,32*SCALE,button[2],busy or unavailable);bx=bx+bw+7*SCALE
  end
  by=by+44*SCALE
  control('label','repository',18*SCALE,by,w-36*SCALE,26*SCALE,s.data and
    ((s.data.github and s.data.github.owner..'/'..s.data.github.repo or T('Local repository'))..'  ·  '..clean(s.data.header)) or s.message or 'Open a repository folder, or clone one.')
  control('label','saved-note',18*SCALE,by+28*SCALE,w-36*SCALE,24*SCALE,'Git uses saved files. Unsaved editor changes are not included.')
  local top=by+62*SCALE
  if s.data and s.data.pushGithub and s.data.branch then
    control('label','push-target',18*SCALE,by+54*SCALE,w-36*SCALE,24*SCALE,T('Push target: %s · %s',s.data.pushGithub.url,s.data.branch))
    top=top+26*SCALE
  end
  local bottom=h-154*SCALE
  s.list={x=x+18*SCALE,y=y+top,w=w-36*SCALE,h=math.max(24*SCALE,bottom-top),row=30*SCALE}
  s.visible=math.max(1,math.floor(s.list.h/s.list.row));local count=s.data and #s.data.files or 0
  s.scroll=common.clamp(math.floor(s.scroll),0,math.max(0,count-s.visible))
  for index=s.scroll+1,math.min(count,s.scroll+s.visible) do
    local item=s.data.files[index]
    control('file',tostring(index),18*SCALE,top+(index-s.scroll-1)*s.list.row,w-50*SCALE,s.list.row,
      (item.index or ' ')..(item.working or ' ')..'   '..clean(item.path),busy)
  end
  if count>s.visible then
    local thumb=s.list.h*s.visible/count
    s.scrollbar={x=s.list.x+s.list.w-9*SCALE,y=s.list.y+(s.list.h-thumb)*s.scroll/(count-s.visible),w=7*SCALE,h=thumb}
  else s.scrollbar=nil end
  local item=selected();bx=18*SCALE
  for _,button in ipairs({{'stage','Stage file'},{'unstage','Unstage file'},{'diff','Working diff'},{'staged-diff','Staged diff'}}) do
    local bw=style.small_font:get_width(T(button[2]))+20*SCALE
    control('button',button[1],bx,h-140*SCALE,bw,29*SCALE,button[2],busy or not item);bx=bx+bw+6*SCALE
  end
  control('label','message-label',18*SCALE,h-102*SCALE,w-36*SCALE,22*SCALE,'Commit message')
  control('input','message',18*SCALE,h-76*SCALE,math.max(20,w-236*SCALE),34*SCALE,nil,busy)
  control('button','commit',w-206*SCALE,h-76*SCALE,188*SCALE,34*SCALE,T('Commit staged (%d)',s.data and s.data.stagedCount or 0),
    busy or not s.data or s.data.stagedCount==0 or not s.inputs.message.text:match('%S'))
  return s
end
local function caret_at(c,e,x)
  local offset=math.max(0,style.font:get_width(e.text:sub(1,e.caret-1))-c.w+20*SCALE)
  local relative=x-c.x-8*SCALE+offset
  local column=1
  for _,code in utf8.codes(e.text) do
    local next_column=utf8.offset(e.text,2,column) or #e.text+1
    if style.font:get_width(e.text:sub(1,next_column-1))>relative then return column end
    column=next_column
  end
  return #e.text+1
end
function M.click(button,x,y,clicks)
  if button~='left' then return end
  local s=M.layout();s.drag=nil
  if s.scrollbar and inside(s.scrollbar,x,y) then s.drag={kind='scroll',offset=y-s.scrollbar.y};return end
  for _,c in ipairs(s.controls) do if inside(c,x,y) then
    if c.disabled then return end
    if c.kind=='button' then M.action(c.id)
    elseif c.kind=='file' then s.selected=tonumber(c.id);s.focus=nil
      if clicks and clicks>=2 then M.action('diff') end
    elseif c.kind=='input' then
      s.focus=c.id;local e=s.inputs[c.id];e.caret=caret_at(c,e,x);e.anchor=clicks and clicks>=2 and 1 or e.caret
      if clicks and clicks>=2 then e.caret=#e.text+1 end
      s.drag={kind='input',control=c}
    end
    core.redraw=true;return
  end end
  if y<s.panel.y+50*SCALE and inside(s.panel,x,y) then s.drag={kind='window',dx=x-s.panel.x,dy=y-s.panel.y} end
end
function M.move(x,y)
  local s=M.active;local drag=s and s.drag;if not drag then return end
  if drag.kind=='window' then s.x=x-drag.dx;s.y=y-drag.dy
  elseif drag.kind=='input' then local e=s.inputs[drag.control.id];e.caret=caret_at(drag.control,e,x)
  elseif drag.kind=='scroll' then
    local count=s.data and #s.data.files or 0
    s.scroll=math.floor(common.clamp((y-s.list.y-drag.offset)/math.max(1,s.list.h-s.scrollbar.h),0,1)*math.max(0,count-s.visible)+.5)
  end
  core.redraw=true
end
function M.input(text)
  local s=M.active;if not s or service.job or not s.focus then return end
  local e=s.inputs[s.focus];if not e then return end
  text=text:gsub('[\r\n\0]',' ')
  local first,last=math.min(e.caret,e.anchor),math.max(e.caret,e.anchor)
  local value=e.text:sub(1,first-1)..text..e.text:sub(last)
  if #value>4096 then return end
  e.text=value;e.caret=first+#text;e.anchor=e.caret;core.redraw=true
end
function M.key(key)
  local s=M.active;local mods=require('core.keymap').modkeys
  if key=='escape' then M.close();return end
  if service.job then return end
  if key=='f5' then M.refresh();return end
  if key=='tab' then s.focus=s.mode=='clone' and (s.focus=='url' and 'parent' or 'url') or 'message';return end
  if mods.ctrl and (key=='return' or key=='keypad enter') then M.action(s.mode=='clone' and 'clone-now' or 'commit');return end
  local e=s.focus and s.inputs[s.focus]
  if e then
    if mods.ctrl and key=='a' then e.anchor=1;e.caret=#e.text+1
    elseif mods.ctrl and key=='v' then M.input(system.get_clipboard() or '')
    elseif mods.ctrl and (key=='c' or key=='x') then
      system.set_clipboard(e.text:sub(math.min(e.caret,e.anchor),math.max(e.caret,e.anchor)-1));if key=='x' then M.input('') end
    elseif key=='backspace' or key=='delete' then
      if e.anchor==e.caret then e.anchor=key=='backspace' and (e.caret>1 and utf8.offset(e.text,-1,e.caret) or 1) or (e.caret<=#e.text and utf8.offset(e.text,2,e.caret) or #e.text+1) end
      M.input('')
    elseif key=='left' or key=='right' or key=='home' or key=='end' then
      e.caret=key=='home' and 1 or key=='end' and #e.text+1 or key=='left' and (e.caret>1 and utf8.offset(e.text,-1,e.caret) or 1) or (e.caret<=#e.text and utf8.offset(e.text,2,e.caret) or #e.text+1)
      if not mods.shift then e.anchor=e.caret end
    end
  elseif s.data and (key=='up' or key=='down') then
    s.selected=common.clamp(s.selected+(key=='up' and -1 or 1),1,math.max(1,#s.data.files))
    s.scroll=common.clamp(s.scroll,math.max(0,s.selected-(s.visible or 1)),math.max(0,s.selected-1))
  elseif key=='return' and selected() then M.action('diff') end
  core.redraw=true
end
function M.draw()
  if not M.active then return end
  if require('litefront.dialogs').active then return end
  if not enabled() then M.close();return end
  local s=M.layout();local p=s.panel
  renderer.draw_rect(0,0,core.root_view.size.x,core.root_view.size.y,{0,0,0,135})
  visual.rounded(p.x-1,p.y-1,p.w+2,p.h+2,9*SCALE,style.divider)
  visual.rounded(p.x,p.y,p.w,p.h,8*SCALE,style.background2)
  core.push_clip_rect(p.x,p.y,p.w,p.h)
  visual.text(style.bold_font,T('GitHub trial'),p.x+18*SCALE,p.y+15*SCALE,p.w-80*SCALE,30*SCALE,style.text)
  for _,c in ipairs(s.controls) do
    if c.kind=='button' then
      visual.rounded(c.x,c.y,c.w,c.h,5*SCALE,c.disabled and style.background2 or style.background3)
      common.draw_text(style.small_font,c.disabled and style.dim or style.text,T(c.label),'center',c.x,c.y,c.w,c.h)
    elseif c.kind=='input' then
      local e=s.inputs[c.id]
      visual.rounded(c.x-1,c.y-1,c.w+2,c.h+2,5*SCALE,s.focus==c.id and style.accent or style.divider)
      visual.rounded(c.x,c.y,c.w,c.h,4*SCALE,style.input_background)
      core.push_clip_rect(c.x+5*SCALE,c.y,c.w-10*SCALE,c.h)
      local offset=math.max(0,style.font:get_width(e.text:sub(1,e.caret-1))-c.w+20*SCALE);local x=c.x+8*SCALE-offset
      local first,last=math.min(e.caret,e.anchor),math.max(e.caret,e.anchor)
      if s.focus==c.id and first~=last then renderer.draw_rect(x+style.font:get_width(e.text:sub(1,first-1)),c.y+4*SCALE,
        style.font:get_width(e.text:sub(first,last-1)),c.h-8*SCALE,style.ui_selection or style.selection) end
      renderer.draw_text(style.font,e.text,x,c.y+(c.h-style.font:get_height())/2,style.text)
      if s.focus==c.id then renderer.draw_rect(x+style.font:get_width(e.text:sub(1,e.caret-1)),c.y+5*SCALE,1,c.h-10*SCALE,style.caret) end
      core.pop_clip_rect()
    elseif c.kind=='file' then
      if tonumber(c.id)==s.selected then visual.rounded(c.x,c.y,c.w,c.h,4*SCALE,style.ui_selection or style.selection) end
      visual.text(style.code_font,c.label,c.x+6*SCALE,c.y,c.w-12*SCALE,c.h,style.text)
    else visual.text(style.small_font,T(c.label),c.x,c.y,c.w,c.h,style.dim) end
  end
  if s.scrollbar then local c=s.scrollbar;visual.rounded(c.x,c.y,c.w,c.h,3*SCALE,style.dim) end
  if s.mode=='repository' and s.data and #s.data.files==0 then
    visual.text(style.font,T('Working tree clean'),s.list.x+8*SCALE,s.list.y+12*SCALE,s.list.w-16*SCALE,30*SCALE,style.dim)
  end
  local message=s.message or (s.data and s.data.limited and T('Showing the first 1,000 changed paths.')) or ''
  visual.text(style.small_font,T(message),p.x+18*SCALE,p.y+p.h-31*SCALE,p.w-36*SCALE,22*SCALE,style.dim)
  core.pop_clip_rect()
end
return M
