-- Tabbed native Preferences window, adapted from Jotta Edit's settings dialog.
local T=require('litefront.i18n').t
local core=require 'core'
local style=require 'core.style'
local common=require 'core.common'
local command=require 'core.command'
local visual=require 'litefront.visual'
local prefs=require 'litefront.preferences'
local colors=require 'litefront.colors'
local M={active=nil,last_tab='editor'}
M.tabs={{'editor','Editor'},{'themes','Themes'},{'theme-editor','Theme Editor'},{'explorer','Explorer'},
  {'languages','Language Servers'},{'shortcuts','Shortcuts'},{'general','General'}}
if JOTTA_WEB then table.remove(M.tabs,5) end
local numbers={ui_size={8,32,1},code_size={8,72,1},indent_size={1,8,1},line_height={1.1,2.2,.05},line_limit={40,240,1},explorer_width={140,600,10},completion_chars={1,8,1}}
function M.close() M.active=nil;core.redraw=true end
function M.open()
  if M.active then return end
  if require('litefront.color_picker').active or require('litefront.dialogs').active then return end
  command.perform('litefront-menu:close');command.perform('litefront:close-editor-actions')
  local menu=package.loaded['plugins.contextmenu'];if menu then menu:hide() end
  M.active={draft=prefs.snapshot(),tab=M.last_tab,scroll=0,focus='tab-'..M.last_tab,search='',mouse_x=core.root_view.mouse.x,mouse_y=core.root_view.mouse.y}
  core.redraw=true
end
function M.apply()
  local state=M.active;if not state or state.invalid then return end
  local ok,err=prefs.save(state.draft)
  if not ok then core.error('Could not save preferences: %s',err);return end
  M.close()
end
function M.select(tab)
  local state=M.active;state.dropdown=nil;state.selector_wheel=nil;state.tab=tab;M.last_tab=tab;state.scroll=0;state.edit=nil;state.invalid=nil;state.focus='tab-'..tab;core.redraw=true
end
local section_keys={editor={'ui_size','code_size','ui_font','code_font','indent_size','tab_type','line_height','line_limit','word_wrap','minimap','highlight_line','cursor_blink','scroll_past_end','color_swatches'},
  themes={'mode','syntax_theme','ui_theme','icon_palette'},explorer={'explorer_visible','explorer_width','show_hidden'},languages={'diagnostics','hover','completion_chars'},general={'ui_language','restore_folders','github_trial'}}
function M.reset()
  local state=M.active;local defaults=prefs.copy(prefs.defaults)
  defaults.ui_size=14;defaults.code_size=14;defaults.mode='dark';defaults.syntax_theme='auto';defaults.icon_palette='auto'
  if state.tab=='editor' then state.draft._indent_changed=true end
  if state.tab=='theme-editor' then
    for _,entry in ipairs(prefs.color_fields) do
      local key=prefs.color_key(state.draft,entry[1]);local fields=state.draft.theme_colors[key]
      if fields then fields[entry[1]]=nil;if not next(fields) then state.draft.theme_colors[key]=nil end end
    end
  else for _,key in ipairs(section_keys[state.tab] or {}) do state.draft[key]=defaults[key] end end
  state.toggle_animations=nil;state.dropdown=nil;state.edit=nil;state.invalid=nil;core.redraw=true
end
local function label_for(id,value)
  if id=='ui_language' then return value=='pt-PT' and 'Português (Portugal)' or 'English' end
  if id=='ui_font' then return value and common.basename(value) or 'Rubik (bundled)' end
  if id=='code_font' then return value and common.basename(value) or 'JetBrains Mono (bundled)' end
  if id=='ui_theme' then return value=='auto' and 'Follow editor theme' or visual.palettes[value].label end
  if id=='syntax_theme' then return value=='auto' and 'Follow interface (Jotta)' or visual.palettes[value].label end
  if id=='icon_palette' then for _,item in ipairs(require 'litefront.icon-palette-choices') do if item.id==value then return item.label end end end
  if id=='mode' then return value=='dark' and 'Dark' or 'Light' end
  if id=='tab_type' then return value=='soft' and 'Spaces' or 'Tabs' end
  return tostring(value or '')
end
local function options_for(id)
  local state=M.active
  state.option_cache=state.option_cache or {}
  if state.option_cache[id] then return state.option_cache[id] end
  local options={}
  if id=='ui_language' then
    options={{text='English',value='en'},{text='Português (Portugal)',value='pt-PT'}}
  elseif id=='ui_font' or id=='code_font' then
    options=require('litefront.fonts').list();table.insert(options,1,{text=id=='ui_font' and 'Rubik (bundled)' or 'JetBrains Mono (bundled)'})
    for _,item in ipairs(options) do item.value=item.path end
  elseif id=='syntax_theme' or id=='ui_theme' then
    options={{text=id=='ui_theme' and 'Follow editor theme' or 'Follow interface (Jotta)',value='auto'}}
    local palettes={};for key,palette in pairs(visual.palettes) do palettes[#palettes+1]={text=palette.label,value=key} end
    table.sort(palettes,function(a,b) return a.text<b.text end);for _,item in ipairs(palettes) do options[#options+1]=item end
  elseif id=='icon_palette' then
    for _,item in ipairs(require 'litefront.icon-palette-choices') do options[#options+1]={text=item.label,value=item.id} end
  elseif id=='mode' then options={{text='Dark',value='dark'},{text='Light',value='light'}}
  elseif id=='tab_type' then options={{text='Spaces',value='soft'},{text='Tabs',value='hard'}} end
  for _,item in ipairs(options) do item.text=T(item.text) end
  state.option_cache[id]=options
  return options
end
function M.choose(id)
  local state=M.active;state.edit=nil;state.invalid=nil
  if state.dropdown and state.dropdown.id==id then state.dropdown=nil;core.redraw=true;return end
  local options=options_for(id)
  local index=1
  for i,item in ipairs(options) do if item.value==state.draft[id] then index=i;break end end
  state.dropdown={id=id,options=options,index=index,offset=math.max(0,index-4),query=''}
  core.redraw=true
end
local function set_choice(id,item)
  local s=M.active
  s.draft[id]=item.value
  if id=='tab_type' then s.draft._indent_changed=true end
  if id=='mode' then s.draft.ui_theme='jotta-'..item.value end
  if id=='syntax_theme' and s.draft.ui_theme=='auto' and visual.palettes[item.value] then s.draft.mode=visual.palettes[item.value].mode end
  if id=='ui_theme' then
    local palette=visual.palettes[item.value] or visual.palettes[s.draft.syntax_theme]
    if palette then s.draft.mode=palette.mode end
  end
  s.preview_fonts=nil;core.redraw=true
end
local function commit_dropdown()
  local s=M.active;local d=s.dropdown;local item=d.options[d.index]
  if item then set_choice(d.id,item) end
  s.dropdown=nil;core.redraw=true
end
local function step_choice(id,delta,boundary)
  local s=M.active;local options=options_for(id)
  if #options==0 then return end
  local index=1
  for i,item in ipairs(options) do if item.value==s.draft[id] then index=i;break end end
  local target=boundary=='home' and 1 or boundary=='end' and #options or colors.clamp(index+delta,1,#options)
  if target~=index or boundary=='home' or boundary=='end' then set_choice(id,options[target]) end
end

function M.dropdown_layout()
  local s=M.active;local d=s and s.dropdown;if not d then return end
  local anchor
  for _,c in ipairs(s.controls) do if c.id==d.id then anchor=c;break end end
  if not anchor then s.dropdown=nil;return end
  d.row=32*SCALE
  local below=core.root_view.size.y-anchor.y-anchor.h-12*SCALE
  local above=anchor.y-12*SCALE
  local room=math.max(below,above)
  d.visible=math.max(1,math.min(8,#d.options,math.floor((room-8*SCALE)/d.row)))
  d.h=d.visible*d.row+8*SCALE;d.w=anchor.w;d.x=anchor.x
  d.y=below>=d.h and anchor.y+anchor.h+4*SCALE or math.max(4*SCALE,anchor.y-d.h-4*SCALE)
  d.offset=colors.clamp(d.offset,0,math.max(0,#d.options-d.visible))
  if #d.options>d.visible then
    local track=d.h-8*SCALE;local height=math.max(20*SCALE,track*d.visible/#d.options)
    d.thumb={x=d.x+d.w-10*SCALE,y=d.y+4*SCALE+(track-height)*d.offset/(#d.options-d.visible),w=6*SCALE,h=height}
  else d.thumb=nil end
  return d
end
function M.wheel(dy)
  local s=M.layout();local d=M.dropdown_layout()
  if d then
    d.offset=colors.clamp(math.floor(d.offset-dy*3+.5),0,math.max(0,#d.options-d.visible))
  else
    local c=s.mouse_x and M.at(s.mouse_x,s.mouse_y)
    if c and c.kind=='select' then
      -- Accumulate touchpad fractions without stealing focus or scrolling the panel.
      if not s.selector_wheel or s.selector_wheel.id~=c.id then s.selector_wheel={id=c.id,amount=0,bounds=c} end
      local wheel=s.selector_wheel;wheel.amount=wheel.amount-dy
      local steps=wheel.amount>0 and math.floor(wheel.amount+1e-9) or math.ceil(wheel.amount-1e-9)
      wheel.amount=wheel.amount-steps
      if steps~=0 then step_choice(c.id,steps) end
    else
      s.selector_wheel=nil
      s.scroll=colors.clamp(s.scroll-dy*40*SCALE,0,s.max_scroll)
    end
  end
  core.redraw=true
end

function M.edit_color(field)
  local state=M.active;state.suspended=true;state.edit=nil;state.invalid=nil
  require('litefront.color_picker').open_external(prefs.theme_color(state.draft,field),function(hex)
    local theme=prefs.color_key(state.draft,field)
    state.draft.theme_colors[theme]=state.draft.theme_colors[theme] or {};state.draft.theme_colors[theme][field]=hex
  end,function() state.suspended=false;core.redraw=true end)
end
local function specimen(state)
  local d=state.draft
  local key=table.concat({d.ui_font or '',d.code_font or '',d.ui_size,d.code_size,SCALE},':')
  if state.preview_fonts and state.preview_fonts.key==key then return state.preview_fonts end
  local bundle=DATADIR..'/litefront/assets/fonts/supplied/'
  local function load(path,size,ui)
    local ok,font=pcall(renderer.font.load,path,size*SCALE,{weight=400,kerning=ui,antialiasing='grayscale',hinting='slight'})
    return ok and font or (ui and style.font or style.code_font)
  end
  state.preview_fonts={key=key,ui=load(d.ui_font or bundle..'Rubik-VariableFont_wght.ttf',d.ui_size,true),code=load(d.code_font or bundle..'JetBrainsMono-VariableFont_wght.ttf',d.code_size,false)}
  return state.preview_fonts
end
function M.layout()
  local s=M.active;if not s then return end
  local w=math.max(1,math.min(960*SCALE,core.root_view.size.x-24*SCALE))
  local h=math.max(1,math.min(780*SCALE,core.root_view.size.y-24*SCALE))
  local x=colors.clamp(s.x or (core.root_view.size.x-w)/2,0,math.max(0,core.root_view.size.x-w))
  local y=colors.clamp(s.y or (core.root_view.size.y-h)/2,0,math.max(0,core.root_view.size.y-h))
  s.panel={x=x,y=y,w=w,h=h};s.controls={};local list=s.controls
  local function add(kind,id,cx,cy,cw,ch,label,value,body)
    local c={kind=kind,id=id,x=cx,y=cy,w=cw,h=ch,label=T(label),value=value,body=body};list[#list+1]=c;return c
  end
  local tx,ty=18*SCALE,64*SCALE
  for _,tab in ipairs(M.tabs) do
    local tw=style.font:get_width(T(tab[2]))+24*SCALE
    if tx+tw>w-18*SCALE and tx>18*SCALE then tx=18*SCALE;ty=ty+36*SCALE end
    add('tab','tab-'..tab[1],x+tx,y+ty,tw-3*SCALE,32*SCALE,tab[2],tab[1]);tx=tx+tw
  end
  s.body={x=x+18*SCALE,y=y+ty+44*SCALE,w=w-42*SCALE,h=math.max(1,h-ty-104*SCALE)}
  local yy=4*SCALE;local cw=s.body.w;local d=s.draft
  local function body(kind,id,cx,cy,bw,bh,label,value) return add(kind,id,s.body.x+cx,s.body.y+cy-s.scroll,bw,bh,label,value,true) end
  local function note(text) body('note','note-'..yy,0,yy,cw,28*SCALE,text);yy=yy+32*SCALE end
  local function heading(text) body('heading','heading-'..yy,0,yy,cw,30*SCALE,text);yy=yy+38*SCALE end
  local function row(kind,id,label,description)
    local rx=cw*.49;local rw=cw-rx
    body('label','label-'..id,0,yy,cw*.46,25*SCALE,label)
    if description then body('note','description-'..id,0,yy+24*SCALE,cw*.46,24*SCALE,description) end
    if kind=='number' then
      local bw=30*SCALE;local nw=math.min(100*SCALE,math.max(40*SCALE,rw-2*bw-8*SCALE))
      body('step',id..'-minus',rx,yy,bw,30*SCALE,'−',{id=id,delta=-numbers[id][3]})
      body('number',id,rx+bw+4*SCALE,yy,nw,30*SCALE,tostring(d[id]))
      body('step',id..'-plus',rx+bw+nw+8*SCALE,yy,bw,30*SCALE,'+',{id=id,delta=numbers[id][3]})
    elseif kind=='toggle' then body('toggle',id,rx,yy,rw,30*SCALE,d[id] and 'On' or 'Off',d[id])
    else body(kind,id,rx,yy,rw,32*SCALE,label_for(id,d[id])) end
    yy=yy+(description and 62 or 46)*SCALE
  end
  if s.tab=='editor' then
    heading('Fonts and typography')
    row('select','code_font','Code editor font');row('number','code_size','Code font size')
    row('select','ui_font','Interface font');row('number','ui_size','Interface font size')
    body('font-preview','font-preview',0,yy,cw,110*SCALE,'Font preview');yy=yy+124*SCALE
    heading('Editing')
    row('select','tab_type','Indentation','Applies to open and new documents.')
    row('number','indent_size','Indent / tab width');row('number','line_height','Line spacing')
    row('number','line_limit','Preferred line width')
    for _,item in ipairs({{'word_wrap','Word wrap'},{'minimap','Document minimap'},{'highlight_line','Highlight current line'},
      {'cursor_blink','Blink cursor'},{'scroll_past_end','Scroll past end'},{'color_swatches','Inline color squares'}}) do row('toggle',item[1],item[2]) end
  elseif s.tab=='themes' then
    heading('Color schemes')
    row('select','mode','Interface mode');row('select','syntax_theme','Editor color scheme');row('select','ui_theme','UI color scheme');row('select','icon_palette','Explorer icon palette')
    body('theme-preview','theme-preview',0,yy,cw,120*SCALE,'Theme preview');yy=yy+132*SCALE
    note('Editor and UI color schemes can be selected independently.')
    note('Theme Editor lets you customize the selected theme.')
  elseif s.tab=='theme-editor' then
    heading(T('Customize %s',T(label_for('syntax_theme',d.syntax_theme))))
    note('Editor and UI overrides are stored with their own color schemes.')
    note('Changes are saved for this theme when you choose Apply.')
    local columns=cw>600*SCALE and 2 or 1;local colw=cw/columns
    for i,field in ipairs(prefs.color_fields) do
      local cx=((i-1)%columns)*colw;local cy=yy+math.floor((i-1)/columns)*50*SCALE
      body('label','color-label-'..field[1],cx,cy,colw-160*SCALE,34*SCALE,field[2])
      body('color',field[1],cx+math.max(90*SCALE,colw-150*SCALE),cy,140*SCALE,32*SCALE,prefs.theme_color(d,field[1]))
    end
    yy=yy+math.ceil(#prefs.color_fields/columns)*50*SCALE
  elseif s.tab=='explorer' then
    heading('Files and folders')
    row('toggle','explorer_visible','Show explorer');row('number','explorer_width','Explorer width')
    row('toggle','show_hidden','Show hidden files');row('select','icon_palette','Explorer icon palette')
    note('Expanded folders and selection are remembered with your session.')
  elseif s.tab=='languages' then
    heading('Language tools')
    note('Bundled HTML, CSS, JSON, JavaScript and TypeScript support.')
    row('toggle','diagnostics','Show diagnostics');row('toggle','hover','Show hover information')
    row('number','completion_chars','Completion trigger length','Characters typed before suggestions appear.')
  elseif s.tab=='shortcuts' then
    heading('Keyboard shortcuts')
    body('text','shortcut_search',0,yy,cw,32*SCALE,s.search=='' and 'Filter shortcuts…' or s.search);yy=yy+44*SCALE
    local shortcuts={}
    for name,keys in pairs(require('core.keymap').reverse_map) do
      if type(name)=='string' and #keys>0 then
        local label=command.prettify_name(name);local binding=table.concat(keys,' / ')
        if s.search=='' or common.fuzzy_match(label..' '..binding,s.search) then shortcuts[#shortcuts+1]={label=label,binding=binding} end
      end
    end
    table.sort(shortcuts,function(a,b) return a.label<b.label end)
    for _,item in ipairs(shortcuts) do
      body('label','shortcut-'..yy,0,yy,cw*.54,30*SCALE,item.label)
      body('note','binding-'..yy,cw*.56,yy,cw*.44,30*SCALE,item.binding);yy=yy+34*SCALE
    end
    if #shortcuts==0 then note('No matching shortcuts.') end
  else
    heading('Interface')
    row('select','ui_language','UI language')
    heading('Session')
    row('toggle','restore_folders','Remember open folders','Restore the last workspace on startup.')
    note('Open files and unsaved edits are recovered automatically.')
    if not JOTTA_WEB then
      heading('Experimental features')
      row('toggle','github_trial','GitHub trial','Sign in, connect a folder and sync with GitHub.')
      note('Disable this option to hide GitHub. Your connections are kept.')
    end
    heading('Jotta Text '..APP_VERSION)
    note('Changes take effect when you choose Apply.')
    note('Cancel closes this window without changing your preferences.')
  end
  s.max_scroll=math.max(0,yy+12*SCALE-s.body.h)
  local old=s.scroll;s.scroll=colors.clamp(s.scroll,0,s.max_scroll)
  for _,c in ipairs(list) do if c.body then c.y=c.y+old-s.scroll end end
  add('close','close',x+w-38*SCALE,y+12*SCALE,26*SCALE,28*SCALE,'×')
  add('button','reset',x+18*SCALE,y+h-42*SCALE,160*SCALE,30*SCALE,'Reset section')
  add('button','cancel',x+w-208*SCALE,y+h-42*SCALE,88*SCALE,30*SCALE,'Cancel')
  add('button','apply',x+w-108*SCALE,y+h-42*SCALE,90*SCALE,30*SCALE,'Apply')
  if s.max_scroll>0 then
    local th=math.max(24*SCALE,s.body.h*s.body.h/(yy+12*SCALE))
    add('track','track',x+w-12*SCALE,s.body.y,7*SCALE,s.body.h)
    add('thumb','thumb',x+w-12*SCALE,s.body.y+(s.body.h-th)*s.scroll/s.max_scroll,7*SCALE,th)
  end
  return s
end
local function inside(c,x,y) return x>=c.x and x<c.x+c.w and y>=c.y and y<c.y+c.h end
function M.at(x,y)
  local s=M.layout()
  for i=#s.controls,1,-1 do local c=s.controls[i];if inside(c,x,y) and (not c.body or inside(s.body,x,y)) then return c end end
end
local function edit(id)
  local s=M.active;s.focus=id;s.invalid=nil
  local value=id=='shortcut_search' and s.search or tostring(s.draft[id])
  s.edit={id=id,text=value,caret=#value+1,anchor=1}
end
-- Use elapsed time so the transition lasts 100ms regardless of frame rate.
function M.toggle_position(id,now)
  local s=M.active;local a=s.toggle_animations and s.toggle_animations[id]
  if not a then return s.draft[id] and 1 or 0 end
  local t=colors.clamp(((now or system.get_time())-a.time)/.1,0,1)
  return a.from+(a.to-a.from)*t
end
function M.update(now)
  local s=M.active;if not s or not s.toggle_animations then return end
  now=now or system.get_time()
  for id,a in pairs(s.toggle_animations) do
    if now-a.time>=.1 then s.toggle_animations[id]=nil end
    core.redraw=true
  end
end
function M.activate(c)
  local s=M.active
  if c.id=='close' or c.id=='cancel' then M.close();return end
  if c.id=='apply' then M.apply();return end
  if c.id=='reset' then M.reset();return end
  s.edit=nil;s.invalid=nil;s.focus=c.id
  if c.kind=='tab' then M.select(c.value)
  elseif c.kind=='select' then M.choose(c.id)
  elseif c.kind=='toggle' then
    local now=system.get_time();local from=M.toggle_position(c.id,now)
    s.draft[c.id]=not s.draft[c.id]
    s.toggle_animations=s.toggle_animations or {}
    s.toggle_animations[c.id]={time=now,from=from,to=s.draft[c.id] and 1 or 0}
  elseif c.kind=='number' or c.kind=='text' then edit(c.id)
  elseif c.kind=='step' then
    local v=c.value;if v.id=='indent_size' then s.draft._indent_changed=true end;local range=numbers[v.id];s.draft[v.id]=colors.clamp(math.floor((s.draft[v.id]+v.delta)*100+.5)/100,range[1],range[2]);s.preview_fonts=nil
  elseif c.kind=='color' then M.edit_color(c.id) end
  core.redraw=true
end
function M.click(button,x,y)
  if button~='left' then return end
  local s=M.layout();s.mouse_x,s.mouse_y=x,y;local d=M.dropdown_layout()
  if d then
    if d.thumb and inside(d.thumb,x,y) then s.drag={kind='dropdown',dy=y-d.thumb.y};return end
    if inside(d,x,y) then
      if d.thumb and x>=d.thumb.x-3*SCALE then
        d.offset=colors.clamp(d.offset+(y<d.thumb.y and -1 or 1)*d.visible,0,#d.options-d.visible)
      else
        local index=d.offset+math.floor((y-d.y-4*SCALE)/d.row)+1
        if index>d.offset and index<=math.min(#d.options,d.offset+d.visible) then d.index=index;commit_dropdown() end
      end
      core.redraw=true;return
    end
    s.dropdown=nil
    local c=M.at(x,y);if c and c.id==d.id then core.redraw=true;return end
  end
  local c=M.at(x,y)
  if c and c.kind=='thumb' then s.drag={kind='scroll',dy=y-c.y,height=c.h}
  elseif c and c.kind=='track' then
    local thumb;for _,item in ipairs(s.controls) do if item.kind=='thumb' then thumb=item end end
    s.scroll=colors.clamp(s.scroll+(y<thumb.y and -1 or 1)*s.body.h,0,s.max_scroll)
  elseif c and c.kind~='label' and c.kind~='note' and c.kind~='heading' and c.kind~='theme-preview' and c.kind~='font-preview' then M.activate(c)
  elseif y<s.body.y-36*SCALE and inside(s.panel,x,y) then s.drag={kind='window',dx=x-s.panel.x,dy=y-s.panel.y} end
  core.redraw=true
end
function M.move(x,y)
  local s=M.active;if not s then return end
  s.mouse_x,s.mouse_y=x,y
  if s.selector_wheel and not inside(s.selector_wheel.bounds,x,y) then s.selector_wheel=nil end
  local d=M.dropdown_layout()
  if d and s.drag and s.drag.kind=='dropdown' then
    local track=d.h-8*SCALE-d.thumb.h
    d.offset=colors.clamp(math.floor((y-d.y-4*SCALE-s.drag.dy)/math.max(1,track)*(#d.options-d.visible)+.5),0,#d.options-d.visible)
    core.redraw=true;return
  end
  if d and inside(d,x,y) and (not d.thumb or x<d.thumb.x-3*SCALE) then
    local index=d.offset+math.floor((y-d.y-4*SCALE)/d.row)+1
    if index>d.offset and index<=math.min(#d.options,d.offset+d.visible) then d.index=index;core.redraw=true end
  end
  if not s.drag then return end
  if s.drag.kind=='window' then s.x=x-s.drag.dx;s.y=y-s.drag.dy
  else s.scroll=colors.clamp((y-s.body.y-s.drag.dy)/math.max(1,s.body.h-s.drag.height)*s.max_scroll,0,s.max_scroll) end
  core.redraw=true
end
function M.input(text)
  local s=M.active
  local d=s and s.dropdown
  if d then
    if system.get_time()-(d.typed_at or 0)>1 then d.query='' end
    d.typed_at=system.get_time();d.query=d.query..text:lower()
    for i,item in ipairs(d.options) do if item.text:lower():sub(1,#d.query)==d.query then
      d.index=i;d.offset=math.max(0,i-1);break
    end end
    core.redraw=true;return
  end
  local e=s and s.edit;if not e then return end
  local first,last=math.min(e.caret,e.anchor),math.max(e.caret,e.anchor)
  text=text:gsub('[\r\n]','');if #e.text-(last-first)+#text>200 then return end
  e.text=e.text:sub(1,first-1)..text..e.text:sub(last);e.caret=first+#text;e.anchor=e.caret
  if e.id=='shortcut_search' then s.search=e.text;s.scroll=0
  else
    local value=tonumber(e.text);local range=numbers[e.id]
    if e.id=='indent_size' then s.draft._indent_changed=true end
    if value and value>=range[1] and value<=range[2] and (range[3]~=1 or value%1==0) then s.draft[e.id]=value;s.invalid=nil;s.preview_fonts=nil
    else s.invalid=e.id end
  end
  core.redraw=true
end
function M.key(key)
  local s=M.active;local mods=require('core.keymap').modkeys
  local d=M.dropdown_layout()
  if d then
    if key=='escape' or key=='tab' then s.dropdown=nil
    elseif key=='return' or key=='keypad enter' or key=='space' then commit_dropdown()
    else
      local delta=({up=-1,left=-1,down=1,right=1,pageup=-d.visible,pagedown=d.visible})[key]
      if delta then d.index=colors.clamp(d.index+delta,1,#d.options)
      elseif key=='home' then d.index=1 elseif key=='end' then d.index=#d.options end
      d.offset=colors.clamp(d.offset,math.max(0,d.index-d.visible),d.index-1)
    end
    core.redraw=true;return
  end
  if key=='escape' then M.close();return end
  if mods.ctrl and key=='s' then M.apply();return end
  if s.edit then
    local e=s.edit
    if mods.ctrl and key=='a' then e.anchor=1;e.caret=#e.text+1
    elseif mods.ctrl and (key=='c' or key=='x') then
      system.set_clipboard(e.text:sub(math.min(e.anchor,e.caret),math.max(e.anchor,e.caret)-1));if key=='x' then M.input('') end
    elseif mods.ctrl and key=='v' then M.input(system.get_clipboard() or '')
    elseif key=='left' or key=='right' or key=='home' or key=='end' then
      e.caret=key=='home' and 1 or key=='end' and #e.text+1 or key=='left' and (e.caret>1 and (utf8.offset(e.text,-1,e.caret) or 1) or 1) or (e.caret<=#e.text and (utf8.offset(e.text,2,e.caret) or #e.text+1) or #e.text+1)
      if not mods.shift then e.anchor=e.caret end
    elseif key=='backspace' or key=='delete' then
      if e.anchor==e.caret then e.anchor=key=='backspace' and (e.caret>1 and (utf8.offset(e.text,-1,e.caret) or 1) or 1) or (e.caret<=#e.text and (utf8.offset(e.text,2,e.caret) or #e.text+1) or #e.text+1) end
      M.input('')
    elseif key=='return' or key=='keypad enter' then M.apply() end
    if key~='tab' then core.redraw=true;return end
  end
  local delta=({left=-1,up=-1,right=1,down=1})[key]
  if not mods.ctrl and not mods.alt and (delta or key=='home' or key=='end') then
    for _,c in ipairs(M.layout().controls) do
      if c.id==s.focus and c.kind=='select' then step_choice(c.id,delta or 0,key);return end
    end
  end
  if key=='tab' then
    local list={}
    for _,c in ipairs(M.layout().controls) do if ({tab=true,select=true,toggle=true,number=true,text=true,color=true,button=true,close=true})[c.kind] then list[#list+1]=c end end
    local idx=0;for i,c in ipairs(list) do if c.id==s.focus then idx=i end end
    if idx==0 and mods.shift then idx=1 end
    local c=list[(idx+(mods.shift and -2 or 0))%#list+1];s.edit=nil;s.invalid=nil;s.focus=c.id
    if c.body then s.scroll=colors.clamp(s.scroll+math.min(0,c.y-s.body.y)+math.max(0,c.y+c.h-s.body.y-s.body.h),0,s.max_scroll) end
    if c.kind=='number' or c.kind=='text' then edit(c.id) end
  elseif s.focus and s.focus:match('^tab%-') and (key=='left' or key=='right' or key=='home' or key=='end') then
    local idx=1;for i,tab in ipairs(M.tabs) do if tab[1]==s.tab then idx=i end end
    idx=key=='home' and 1 or key=='end' and #M.tabs or (idx+(key=='left' and -2 or 0))%#M.tabs+1;M.select(M.tabs[idx][1])
  elseif key=='return' or key=='space' then
    for _,c in ipairs(M.layout().controls) do if c.id==s.focus then M.activate(c);break end end
  end
  core.redraw=true
end
local function draw_field(s,c)
  local editing=s.edit and s.edit.id==c.id
  local text=editing and s.edit.text or c.label
  visual.rounded(c.x-1,c.y-1,c.w+2,c.h+2,4*SCALE,s.invalid==c.id and {224,90,90,255} or s.focus==c.id and style.accent or style.divider)
  visual.rounded(c.x,c.y,c.w,c.h,3*SCALE,style.input_background)
  core.push_clip_rect(c.x+5*SCALE,c.y,c.w-10*SCALE,c.h)
  local offset=editing and math.max(0,style.font:get_width(text:sub(1,s.edit.caret-1))-c.w+16*SCALE) or 0
  local x=c.x+7*SCALE-offset
  if editing and s.edit.caret~=s.edit.anchor then
    local first,last=math.min(s.edit.caret,s.edit.anchor),math.max(s.edit.caret,s.edit.anchor)
    renderer.draw_rect(x+style.font:get_width(text:sub(1,first-1)),c.y+4*SCALE,style.font:get_width(text:sub(first,last-1)),c.h-8*SCALE,style.ui_selection or style.selection)
  end
  renderer.draw_text(style.font,text,x,c.y+(c.h-style.font:get_height())/2,style.text)
  if editing then renderer.draw_rect(x+style.font:get_width(text:sub(1,s.edit.caret-1)),c.y+5*SCALE,1,c.h-10*SCALE,style.caret) end
  core.pop_clip_rect()
end
function M.draw()
  local s=M.active;if not s or s.suspended or require('litefront.dialogs').active then return end
  M.layout();local p=s.panel
  renderer.draw_rect(0,0,core.root_view.size.x,core.root_view.size.y,{0,0,0,110})
  visual.rounded(p.x-1,p.y-1,p.w+2,p.h+2,8*SCALE,style.divider);visual.rounded(p.x,p.y,p.w,p.h,8*SCALE,style.background2)
  visual.text(style.bold_font,T('Preferences'),p.x+20*SCALE,p.y+8*SCALE,p.w-70*SCALE,28*SCALE,style.text)
  visual.text(style.small_font,T('Editor and window settings'),p.x+20*SCALE,p.y+34*SCALE,p.w-70*SCALE,22*SCALE,style.dim)
  local function paint(c)
    if c.kind=='label' or c.kind=='note' or c.kind=='heading' then visual.text(c.kind=='heading' and style.bold_font or c.kind=='note' and style.small_font or style.font,c.label,c.x,c.y,c.w,c.h,c.kind=='note' and style.dim or style.text)
    elseif c.kind=='number' or c.kind=='text' then draw_field(s,c)
    elseif c.kind=='select' then
      local focused=s.focus==c.id or s.dropdown and s.dropdown.id==c.id
      visual.rounded(c.x-1,c.y-1,c.w+2,c.h+2,6*SCALE,focused and style.accent or style.divider)
      visual.rounded(c.x,c.y,c.w,c.h,5*SCALE,style.input_background)
      core.push_clip_rect(c.x+10*SCALE,c.y,c.w-38*SCALE,c.h)
      visual.text(style.font,c.label,c.x+10*SCALE,c.y,c.w-38*SCALE,c.h,style.text)
      core.pop_clip_rect()
      visual.text(style.font,s.dropdown and s.dropdown.id==c.id and '▴' or '▾',c.x+c.w-26*SCALE,c.y,20*SCALE,c.h,style.dim,'center')
    elseif c.kind=='toggle' then
      local x,y,w,h=c.x,c.y+(c.h-24*SCALE)/2,44*SCALE,24*SCALE
      if s.focus==c.id then
        visual.rounded(x-3*SCALE,y-3*SCALE,w+6*SCALE,h+6*SCALE,15*SCALE,style.accent)
        visual.rounded(x-2*SCALE,y-2*SCALE,w+4*SCALE,h+4*SCALE,14*SCALE,style.background2)
      end
      local position=M.toggle_position(c.id)
      visual.rounded(x,y,w,h,12*SCALE,common.lerp(style.dim,style.accent,position))
      visual.rounded(x+SCALE,y+SCALE,w-2*SCALE,h-2*SCALE,11*SCALE,common.lerp(style.input_background,style.accent,position))
      local thumb_x=x+(3+20*position)*SCALE
      visual.rounded(thumb_x,y+3*SCALE,18*SCALE,18*SCALE,9*SCALE,common.lerp(style.text,style.accent_text,position))
      visual.text(style.font,c.label,c.x+54*SCALE,c.y,c.w-54*SCALE,c.h,style.text)
    elseif c.kind=='color' then
      require('litefront.color_inline').swatch(c.x,c.y+4*SCALE,24*SCALE,colors.parse(c.label))
      visual.text(style.small_font,c.label,c.x+32*SCALE,c.y,c.w-32*SCALE,c.h,style.text)
    elseif c.kind=='font-preview' then
      visual.rounded(c.x,c.y,c.w,c.h,5*SCALE,style.background2)
      renderer.draw_rect(c.x,c.y+52*SCALE,c.w,c.h-52*SCALE,style.background)
      local fonts=specimen(s)
      core.push_clip_rect(c.x,c.y,c.w,c.h)
      renderer.draw_text(fonts.ui,T('Interface font')..' — Aa Bb 0123',c.x+12*SCALE,c.y+10*SCALE,style.text)
      renderer.draw_text(fonts.code,'const greeting = "Hello";',c.x+12*SCALE,c.y+58*SCALE,style.text)
      core.pop_clip_rect()
    elseif c.kind=='theme-preview' then
      renderer.draw_rect(c.x,c.y,c.w,c.h,visual.color(prefs.theme_color(s.draft,'background')))
      local x=c.x+12*SCALE;local y=c.y+14*SCALE
      for _,token in ipairs({{'keyword','const '},{'symbol','greeting '},{'operator','= '},{'string','"Hello"'},{'operator',';'}}) do
        x=renderer.draw_text(style.code_font,token[2],x,y,visual.color(prefs.theme_color(s.draft,'syntax.'..token[1])))
      end
      renderer.draw_text(style.code_font,'// Theme preview',c.x+12*SCALE,y+32*SCALE,visual.color(prefs.theme_color(s.draft,'syntax.comment')))
      renderer.draw_text(style.code_font,'print(greeting, 42);',c.x+12*SCALE,y+64*SCALE,visual.color(prefs.theme_color(s.draft,'syntax.normal')))
    elseif c.kind=='close' then visual.icon('close',c.x+5*SCALE,c.y+6*SCALE,16*SCALE,style.dim)
    elseif c.kind=='track' or c.kind=='thumb' then visual.rounded(c.x,c.y,c.w,c.h,3*SCALE,c.kind=='thumb' and style.dim or style.background3)
    else
      local selected=c.kind=='tab' and c.value==s.tab or c.id=='apply'
      if s.focus==c.id and not selected then visual.rounded(c.x-1,c.y-1,c.w+2,c.h+2,7*SCALE,style.accent) end
      visual.rounded(c.x,c.y,c.w,c.h,6*SCALE,selected and not s.invalid and style.accent or style.hover_background)
      visual.text(style.font,c.label,c.x+6*SCALE,c.y,c.w-12*SCALE,c.h,selected and not s.invalid and style.accent_text or style.text,'center')
    end
  end
  core.push_clip_rect(s.body.x,s.body.y,s.body.w,s.body.h)
  for _,c in ipairs(s.controls) do if c.body and c.y+c.h>s.body.y and c.y<s.body.y+s.body.h then paint(c) end end
  core.pop_clip_rect()
  renderer.draw_rect(p.x,p.y+p.h-56*SCALE,p.w,1,style.divider)
  for _,c in ipairs(s.controls) do if not c.body then paint(c) end end
  local d=M.dropdown_layout()
  if d then
    visual.rounded(d.x+2*SCALE,d.y+3*SCALE,d.w,d.h,6*SCALE,{0,0,0,80})
    visual.rounded(d.x-1,d.y-1,d.w+2,d.h+2,6*SCALE,style.divider)
    visual.rounded(d.x,d.y,d.w,d.h,5*SCALE,style.input_background)
    core.push_clip_rect(d.x+4*SCALE,d.y+4*SCALE,d.w-18*SCALE,d.h-8*SCALE)
    for i=d.offset+1,math.min(#d.options,d.offset+d.visible) do
      local item=d.options[i];local y=d.y+4*SCALE+(i-d.offset-1)*d.row
      if i==d.index then visual.rounded(d.x+4*SCALE,y,d.w-18*SCALE,d.row,4*SCALE,style.ui_selection or style.selection) end
      visual.text(style.font,item.value==s.draft[d.id] and '✓' or '',d.x+7*SCALE,y,20*SCALE,d.row,style.accent,'center')
      visual.text(style.font,item.text,d.x+32*SCALE,y,d.w-50*SCALE,d.row,style.text)
    end
    core.pop_clip_rect()
    if d.thumb then visual.rounded(d.thumb.x,d.thumb.y,d.thumb.w,d.thumb.h,3*SCALE,style.dim) end
  end
end
return M
