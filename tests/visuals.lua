local core=require 'core'
local command=require 'core.command'
local style=require 'core.style'
local visual=require 'litefront.visual'
local visuals=require 'plugins.litefront_visuals'
local paths=style.font:get_path()
if type(paths)=='table' then paths=table.concat(paths,';') end
assert(paths:find('supplied/Rubik-VariableFont_wght.ttf',1,true),'supplied full Rubik font not active')
-- Exercise real variable weights, copy/resize and proportional/monospaced metrics.
local face=DATADIR..'/litefront/assets/fonts/supplied/Rubik-VariableFont_wght.ttf'
local function rubik(size,weight,kern)
  return renderer.font.load(face,size*SCALE,{hinting='slight',antialiasing='grayscale',kerning=kern,weight=weight})
end
local unkerned,kerned=rubik(32,400,false),rubik(32,400,true)
assert(kerned:get_width('AVATAR To')<unkerned:get_width('AVATAR To'),'supplied Rubik GPOS kerning missing')
local painted=renderer.draw_text(kerned,'AVATAR To',10.4,10,style.text)
assert(math.abs(painted-10.4-kerned:get_width('AVATAR To'))<.01,'kerning measurement and drawing disagree')
local regular,semibold=rubik(20,400,true),rubik(20,600,true)
assert(math.abs(regular:get_width('Menu Settings')-semibold:get_width('Menu Settings'))>.1,'variable UI weights did not change glyph metrics')
local copy=semibold:copy(20*SCALE)
local copy_width,original_width=copy:get_width('Menu Settings'),semibold:get_width('Menu Settings')
assert(math.abs(copy_width-original_width)<.01,'copy lost variable font weight: '..copy_width..' / '..original_width)
assert(rubik(13.75,400,true):get_width('Fractional size')>rubik(13.25,400,true):get_width('Fractional size'),'font size was rounded to whole pixels')
assert(style.code_font:get_path():find('supplied/JetBrainsMono-VariableFont_wght.ttf',1,true),'supplied JetBrains Mono font not active')
assert(math.abs(style.code_font:get_width('iiii')-style.code_font:get_width('WWWW'))<.01,'code font is not monospaced')
assert(math.abs(style.code_font:get_width('To')-style.code_font:get_width('T')-style.code_font:get_width('o'))<.01,'code font kerning changed caret spacing')
local count=0
for _ in pairs(visual.palettes) do count=count+1 end
assert(count==21,'imported syntax palettes missing')
assert(visuals.rail.size.x==36*SCALE,'action rail has wrong width')
assert(package.loaded['plugins.minimap'],'bundled minimap missing')
assert(command.perform('minimap:toggle-visibility'))
assert(command.perform('minimap:toggle-visibility'))
assert(not package.loaded['plugins.treeview'],'legacy treeview unexpectedly loaded')
local Node=require 'core.node'
local previous_view=core.active_view
local node=Node()
core.set_active_view(previous_view)
node.size.x,node.size.y=420*SCALE,600*SCALE
node.position.x,node.position.y=0,0
node.views={}
for i=1,12 do node.views[i]={get_name=function() return 'file' end} end
node.active_view=node.views[12];node.tab_offset=1
node:scroll_tabs_to_visible()
assert(node.tab_offset>1 and node.tab_offset<=12,'tab scrolling broke')
assert(node:target_tab_width()<=140*SCALE,'tabs expand beyond reference width')
node.views={node.views[1],node.views[2],node.views[3]}
node.active_view=node.views[3];node.tab_offset=3;node.size.x=1200*SCALE
node:scroll_tabs_to_visible()
assert(node.tab_offset==1 and node:get_visible_tabs_number()==3,'tabs did not reappear after widening the pane')
assert(command.perform('litefront:syntax-theme'))
local state=core.command_view.state
local selected
for _,label in ipairs(state.suggest('Monokai')) do if label=='Monokai-inspired' then selected=label end end
assert(selected,'imported syntax theme chooser not searchable')
state.submit(selected,{text=selected})
core.command_view:exit(false)
assert(visual.syntax_theme=='monokai' and style.background[1]==0x27,'syntax palette was not applied')
assert(style.background2[1]==0x34 and style.accent[1]==0xa6,'imported palette did not theme the workbench')
local preferences=assert(io.open(USERDIR..'/appearance.txt','r'))
assert(preferences:read('*a'):find('monokai',1,true),'theme choice was not persisted');preferences:close()
assert(command.perform('litefront:icon-palette'))
local icon_state=core.command_view.state
icon_state.submit('Material Icons-inspired',{text='Material Icons-inspired'})
core.command_view:exit(false)
assert(visual.icon_palette=='material','imported icon palette was not selectable')
local icon_color=visual.file_color('file-html5')
assert(icon_color[1] and icon_color[4]==255,'imported icon color is invalid')
command.perform('litefront:theme-dark')
assert(visual.syntax_theme=='auto','interface theme did not restore its syntax palette')
assert(command.perform('litefront:select-language'))
core.root_view:update()
assert(visual.document_view()==core.last_active_view,'palette status does not retain the document context')
assert(core.command_view.position.y<core.root_view.size.y/2,'selector still appears at the bottom')
assert(core.command_view.size.x<=630*SCALE,'floating selector is too wide')
local document=core.last_active_view.doc
core.command_view:set_text('HTML')
core.command_view:update_suggestions()
core.root_view:update()
local px,py=core.command_view.position.x,core.command_view.position.y
core.root_view:on_mouse_pressed('left',px+100*SCALE,py+72*SCALE,2)
core.root_view:on_mouse_released('left',px+100*SCALE,py+72*SCALE)
assert(document.syntax.name=='HTML','floating selector result click failed')
require('plugins.litefront_workspace').set_language(document,nil)
-- The tab toolbar creates a new document in its own editor pane.
local pane=core.root_view:get_active_node_default()
local old=#pane.views
local button=visuals.toolbar(pane)[1]
core.root_view:on_mouse_pressed('left',button.x+button.w/2,button.y+button.h/2,1)
assert(#pane.views==old+1 and core.active_view.doc,'tab toolbar New File failed')
assert(core.status_view:get_item('litefront:breadcrumb'),'breadcrumb missing')
assert(core.status_view:get_item('litefront:encoding'),'encoding indicator missing')
assert(core.status_view:get_item('litefront:theme-toggle'),'theme switch missing')

core.root_view:update()
local view=core.active_view
core.root_view:on_mouse_pressed('right',view.position.x+60*SCALE,view.position.y+60*SCALE,1)
assert(not visuals.actions.show_context_menu,'editor actions intercepted the normal right-click menu')
local context=package.loaded['plugins.contextmenu']
assert(context.show_context_menu,'normal editor context menu did not open')
context:hide()

-- Font preferences use installed font files and survive theme changes.
local fonts=require 'litefront.fonts'
assert(#fonts.list()>0,'font chooser has no fonts')
assert(style.code_font:get_path():find('JetBrainsMono'),'default code font missing')
assert(command.perform('litefront:ui-font'))
assert(#core.command_view.suggestions>1,'font chooser missing installed fonts')
local choice=core.command_view.suggestions[2]
core.command_view.state.submit(choice.text,choice)
core.command_view:exit(false)
assert(fonts.selected.ui==choice.path,'font choice was not applied')
visual.theme_fonts('light')
assert(style.font:get_path()==choice.path,'theme reset custom font')
assert(command.perform('litefront:reset-fonts'))
visual.theme_fonts('dark')

-- UI and editor font sizes are independent, persisted, and stable across themes.
local function size(font) return font:get_size() end
local ui,code=size(style.font),size(style.code_font)
local display_scale=SCALE
assert(command.perform('litefront:increase-ui-font'))
assert(size(style.font)>ui and size(style.code_font)==code,'UI font zoom changed code size')
assert(SCALE==display_scale,'font zoom changed global display scale')
local bigger_ui=size(style.font)
assert(command.perform('litefront:increase-code-font'))
assert(size(style.code_font)>code and size(style.font)==bigger_ui,'code font zoom changed UI size')
local saved_ui,saved_code=fonts.ui_size,fonts.code_size
local saved=dofile(DATADIR..'/litefront/fonts.lua')
assert(saved.ui_size==saved_ui and saved.code_size==saved_code,'font sizes were not persisted')
visual.theme_fonts('light')
assert(size(style.font)==bigger_ui and size(style.code_font)>code,'theme reset font sizes')
assert(command.perform('litefront:reset-ui-font-size'))
assert(size(style.font)==ui and fonts.code_size==saved_code,'UI size reset changed code size')
assert(command.perform('litefront:decrease-code-font'))
assert(size(style.code_font)==code,'code font decrease did not restore original size')
-- Read the legacy two-line preference format without losing selected font paths.
local old=assert(io.open(USERDIR..'/fonts.txt','w'))
old:write('/legacy/ui.ttf\n/legacy/code.ttf\n');old:close()
local legacy=dofile(DATADIR..'/litefront/fonts.lua')
assert(legacy.ui_size==14 and legacy.code_size==14 and legacy.selected.ui=='/legacy/ui.ttf','legacy preferences did not migrate')
fonts.save()
visual.theme_fonts('dark')
local version=assert(io.open(DATADIR..'/litefront/VERSION','r'))
assert(APP_NAME=='Jotta Text' and APP_VERSION==version:read('*l'),'application identity/version missing');version:close()
assert(core.compose_window_title('note.md')=='note.md - Jotta Text','native title still uses old app name')

-- Minimap top padding participates in both drawing and scrollbar hit testing.
local DocView=require 'core.docview'
local MiniMap=require 'plugins.minimap'
local map_view=DocView(core.open_doc())
map_view.size.x,map_view.size.y=800*SCALE,400*SCALE
local minimap=map_view.v_scrollbar
assert(minimap:is(MiniMap),'document is missing minimap')
minimap:update()
minimap:set_size(0,50*SCALE,800*SCALE,400*SCALE,10000*SCALE)
assert(minimap.rect.y==56*SCALE and minimap.rect.h<=394*SCALE,'minimap inset missing from geometry')
minimap.enabled=false
minimap:set_size(0,50*SCALE,800*SCALE,400*SCALE,10000*SCALE)
assert(minimap.rect.y==50*SCALE,'ordinary scrollbar inherited minimap margin')

-- Pickers scroll independently of selection and search, with draggable scrollbars.
for _,name in ipairs({'litefront:ui-font','litefront:code-font','litefront:syntax-theme','litefront:icon-palette'}) do
  assert(command.perform(name))
  assert(core.command_view.state.picker and not core.command_view.state.typeahead,'settings chooser did not use a mouse picker')
  core.command_view:exit(false)
end
local cv=core.command_view
local chosen,cancelled
local items={}
for i=1,80 do items[i]=string.format('Option %02d',i) end
cv:enter('Picker test',{picker=true,typeahead=false,
  suggest=function(text) return text=='' and items or {} end,
  submit=function(_,item) chosen=item.text end,
  cancel=function() cancelled=true end,
})
core.root_view:update()
local x,y,w=cv.position.x,cv.position.y,cv.size.x
local top=y+56*SCALE
local idx=cv.suggestion_idx
core.root_view:on_mouse_wheel(-2,0)
assert(cv.suggestions_offset>1 and cv.suggestion_idx==idx and cv:get_text()=='','mouse wheel changed selection or search instead of scrolling')
local offset=cv.suggestions_offset
core.root_view:draw()
assert(cv.suggestions_offset==offset,'drawing snapped scrolled list back to selection')
core.root_view:on_mouse_moved(x+30*SCALE,top+17*SCALE,0,0)
assert(cv.litefront_hover==offset,'hover did not follow the visible row')
core.root_view:on_mouse_pressed('left',x+30*SCALE,top+17*SCALE,1)
core.root_view:on_mouse_released('left',x+30*SCALE,top+17*SCALE)
assert(core.active_view==cv and cv.suggestion_idx==offset and not chosen,'single click should select without applying')
-- The track pages down; dragging the thumb reaches the last entries.
core.root_view:on_mouse_pressed('left',x+w-10*SCALE,top+5*SCALE,1)
core.root_view:on_mouse_released('left',x+w-10*SCALE,top+5*SCALE)
core.root_view:on_mouse_wheel(100,0)
core.root_view:on_mouse_pressed('left',x+w-10*SCALE,top+4*SCALE,1)
assert(cv.litefront_scroll_drag,'scrollbar thumb could not be grabbed')
core.root_view:on_mouse_moved(x+w-10*SCALE,core.root_view.size.y,0,500*SCALE)
core.root_view:on_mouse_released('left',x+w-10*SCALE,core.root_view.size.y)
assert(cv.suggestions_offset>60 and not cv.litefront_scroll_drag,'scrollbar drag did not reach the bottom or release')
local target=cv.suggestions[cv.suggestions_offset].text
core.root_view:on_mouse_pressed('left',x+30*SCALE,top+17*SCALE,2)
core.root_view:on_mouse_released('left',x+30*SCALE,top+17*SCALE)
assert(chosen==target and core.active_view~=cv,'double click did not apply the visible option')
-- Filtering resets scroll; a keyboard choice leaves the search intact.
cv:enter('Picker test',{picker=true,typeahead=false,suggest=function(text) return text=='' and items or {'Filtered A','Filtered B'} end})
core.root_view:update()
core.root_view:on_mouse_wheel(-5,0)
cv:set_text('Filter');cv:update_suggestions()
assert(cv.suggestions_offset==1,'filtering retained an invalid scroll offset')
cv:move_suggestion_idx(1)
assert(cv.suggestion_idx==2 and cv:get_text()=='Filter','keyboard selection overwrote search text')
cv:exit(false)

-- Choose and Cancel work with the mouse, including a filtered empty list.
local function open_buttons()
  chosen=nil;cancelled=nil
  cv:enter('Buttons',{picker=true,typeahead=false,
    suggest=function(text) return text=='' and {'One','Two'} or {} end,
    submit=function(_,item) chosen=item.text end,
    cancel=function() cancelled=true end,
  })
  core.root_view:update()
  return cv.position.x,cv.position.y,cv.size.x
end
x,y,w=open_buttons()
local fy=y+(52+2*34+8)*SCALE
core.root_view:on_mouse_pressed('left',x+30*SCALE,y+(56+34+17)*SCALE,1)
core.root_view:on_mouse_released('left',x+30*SCALE,y+(56+34+17)*SCALE)
core.root_view:on_mouse_pressed('left',x+w-56*SCALE,fy+22*SCALE,1)
core.root_view:on_mouse_released('left',x+w-56*SCALE,fy+22*SCALE)
assert(chosen=='Two' and not cancelled,'Choose did not apply the selected row')
x,y,w=open_buttons()
fy=y+(52+2*34+8)*SCALE
core.root_view:on_mouse_pressed('left',x+w-145*SCALE,fy+22*SCALE,1)
core.root_view:on_mouse_released('left',x+w-145*SCALE,fy+22*SCALE)
assert(cancelled and not chosen and core.active_view~=cv,'Cancel applied a selection')
x,y,w=open_buttons()
cv:set_text('No matching option');cv:update_suggestions();core.root_view:draw()
assert(#cv.suggestions==0 and cv.suggestions_offset==1,'empty filter retained stale results')
cv:submit()
assert(core.active_view==cv and not chosen,'empty picker applied an invalid selection')
core.root_view:on_mouse_pressed('left',x+w-22*SCALE,y-17*SCALE,1)
core.root_view:on_mouse_released('left',x+w-22*SCALE,y-17*SCALE)
assert(cancelled and core.active_view~=cv,'close button did not dismiss empty picker')
