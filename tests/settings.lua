local core=require 'core'
local command=require 'core.command'
local settings=require 'litefront.settings'
local prefs=require 'litefront.preferences'
local fonts=require 'litefront.fonts'
local config=require 'core.config'
local style=require 'core.style'
local picker=require 'litefront.color_picker'
local root=os.getenv('SETTINGS_ROOT')
local function find(id)
  for _,c in ipairs(settings.layout().controls) do if c.id==id then return c end end
  error('Missing settings control '..id)
end
local function click(id)
  local s=settings.layout();local c=find(id)
  if c.body and (c.y<s.body.y or c.y+c.h>s.body.y+s.body.h) then
    s.scroll=require('litefront.colors').clamp(s.scroll+c.y-s.body.y,0,s.max_scroll);c=find(id)
  end
  core.on_event('mousepressed','left',c.x+c.w/2,c.y+c.h/2,1)
  core.on_event('mousereleased','left',c.x+c.w/2,c.y+c.h/2)
end
local function fill(id,value) click(id);core.on_event('textinput',value) end
local function choose(id,value)
  click(id)
  local d=settings.dropdown_layout()
  assert(d and not settings.active.suspended,'settings choice did not open an inline dropdown')
  local idx
  for i,item in ipairs(d.options) do if item.value==value then idx=i;break end end
  if not idx and value=='rubik' then for i,item in ipairs(d.options) do if item.value and item.value:find('Rubik-VariableFont_wght.ttf',1,true) then idx=i;break end end end
  assert(idx,'missing dropdown value '..tostring(value))
  d.offset=math.max(0,idx-1);d=settings.dropdown_layout();settings.draw()
  local y=d.y+4*SCALE+(idx-d.offset-.5)*d.row
  core.on_event('mousepressed','left',d.x+50*SCALE,y,1)
  core.on_event('mousereleased','left',d.x+50*SCALE,y)
  assert(settings.active and not settings.active.dropdown,'dropdown did not close after mouse selection')
end
if os.getenv('SETTINGS_PHASE')=='2' then
  assert(fonts.ui_size==18 and fonts.code_size==20 and fonts.selected.ui:find('Rubik',1,true),'font settings did not survive restart')
  assert(config.indent_size==4 and config.tab_type=='hard' and config.line_height==1.75,'editor settings did not survive restart')
  assert(not config.plugins.minimap.enabled and not config.plugins.lsp.show_diagnostics and not config.plugins.lsp.mouse_hover,'language/view settings did not survive restart')
  assert(config.plugins.autocomplete.min_len==3 and not prefs.values.color_swatches and not prefs.values.show_hidden,'settings data was not applied on startup')
  assert(not prefs.values.restore_folders and core.litefront_no_project,'disabled workspace recovery was ignored')
  assert(style.background[1]==0x27 and style.accent[1]==0x12 and style.accent[2]==0x34,'custom theme colors were not restored')
  assert(command.perform('litefront:settings'))
  settings.select('theme-editor');settings.reset()
  assert(not settings.active.draft.theme_colors.monokai,'reset did not clear draft overrides')
  click('cancel')
  assert(prefs.values.theme_colors.monokai.accent=='#123456','Cancel committed a theme reset')
  return
end
local doc=core.open_doc(root..'/style.css');local view=core.root_view:open_doc(doc)
local source=table.concat(doc.lines);local revision=doc:get_change_id()
assert(command.perform('litefront:settings'))
assert(#settings.tabs==7,'settings sections missing')
-- Verify elapsed timing and rapid reversal without wall-clock sleeps.
local real_time=system.get_time;local now=10
system.get_time=function() return now end
local initial=settings.active.draft.word_wrap
assert(not settings.changed(),'Apply was enabled before any change')
local start=initial and 1 or 0;local target=1-start
settings.activate(find('word_wrap'))
assert(settings.changed(),'a change did not enable Apply')
assert(settings.active.draft.word_wrap~=initial and settings.toggle_position('word_wrap')==start,'toggle did not stage immediately from its initial position')
now=10.05;local middle=settings.toggle_position('word_wrap')
assert(math.abs(middle-.5)<.00001,'toggle did not reach midpoint at 50ms')
core.redraw=false;settings.update();assert(core.redraw,'transition did not request another frame')
settings.activate(find('word_wrap'))
assert(math.abs(settings.toggle_position('word_wrap')-middle)<.00001,'rapid reversal jumped')
assert(not settings.changed(),'undoing a change left Apply enabled')
now=10.151;settings.update()
assert(settings.toggle_position('word_wrap')==start,'toggle did not finish after 100ms')
now=11;settings.activate(find('word_wrap'));now=11.101;settings.update()
assert(settings.toggle_position('word_wrap')==target and not settings.active.toggle_animations.word_wrap,'completed transition was not cleaned up')
settings.activate(find('word_wrap'));now=12;settings.update()
core.redraw=false;settings.update();assert(not core.redraw,'idle toggles kept requesting frames')
system.get_time=real_time

settings.draw()
fill('ui_size','28')
assert(settings.active.draft.ui_size==28 and fonts.ui_size==14,'draft font size applied before Apply')
click('minimap');assert(config.plugins.minimap.enabled,'draft toggle applied before Apply')
click('cancel');assert(not settings.active and fonts.ui_size==14 and config.plugins.minimap.enabled,'Cancel changed live preferences')
assert(command.perform('litefront:settings'))
settings.select('editor')
local panel=settings.layout().panel;local x,y=panel.x,panel.y
core.on_event('mousepressed','left',x+100*SCALE,y+20*SCALE,1)
core.on_event('mousemoved',x+110*SCALE,y+30*SCALE,10*SCALE,10*SCALE)
core.on_event('mousereleased','left',x+110*SCALE,y+30*SCALE)
assert(settings.layout().panel.x==x+10*SCALE and settings.active.panel.y==y+10*SCALE,'settings header did not drag')
core.on_event('mousewheel',-3,0);assert(settings.active.scroll>0,'settings did not scroll')
fill('ui_size','999');assert(settings.active.invalid=='ui_size','invalid numeric preference accepted')
click('apply');assert(settings.active and fonts.ui_size==14,'invalid preferences were applied')
fill('ui_size','18');fill('code_size','20')
choose('ui_font','rubik');assert(not fonts.selected.ui,'font chooser committed a draft font')
click('code_font')
local drop=settings.dropdown_layout();assert(drop and drop.thumb,'long font dropdown has no scrollbar')
local offset=drop.offset
core.on_event('mousewheel',-2,0);assert(settings.active.dropdown.offset>=offset,'font dropdown did not scroll')
core.on_event('keypressed','end');assert(drop.index==#drop.options,'dropdown End did not select last item')
core.on_event('keypressed','home');assert(drop.index==1 and drop.offset==0,'dropdown Home did not reveal first item')
core.on_event('textinput','Rubik');assert(drop.options[drop.index].text:lower():sub(1,5)=='rubik','dropdown type-to-select failed: '..drop.options[drop.index].text..' query='..drop.query)
settings.dropdown_layout()
local thumb=drop.thumb
core.on_event('mousepressed','left',thumb.x+thumb.w/2,thumb.y+thumb.h/2,1)
core.on_event('mousemoved',thumb.x+thumb.w/2,drop.y+drop.h-4*SCALE,0,100*SCALE)
core.on_event('mousereleased','left',thumb.x+thumb.w/2,drop.y+drop.h-4*SCALE)
assert(drop.offset==#drop.options-drop.visible,'dropdown scrollbar did not drag to the end')
core.on_event('keypressed','escape');assert(settings.active and not settings.active.dropdown,'Escape did not dismiss only the dropdown')
click('code_font');local before=settings.active.draft.code_font
core.on_event('mousepressed','left',settings.active.panel.x+5*SCALE,settings.active.panel.y+5*SCALE,1)
core.on_event('mousereleased','left',0,0)
assert(not settings.active.dropdown and settings.active.draft.code_font==before,'outside click committed a dropdown choice')
fill('indent_size','4');choose('tab_type','hard');fill('line_height','1.75')
click('word_wrap');click('minimap');click('color_swatches')
settings.select('themes');choose('syntax_theme','monokai')
assert(style.background[1]~=0x27,'draft theme applied before Apply')
settings.select('theme-editor');click('accent')
assert(settings.active.suspended and picker.active.external,'theme editor did not open custom color picker')
picker.set_color(require('litefront.colors').parse('#123456'))
local apply
for _,c in ipairs(picker.layout().controls) do if c.id=='apply' then apply=c end end
core.on_event('mousepressed','left',apply.x+apply.w/2,apply.y+apply.h/2,1)
core.on_event('mousereleased','left',apply.x+apply.w/2,apply.y+apply.h/2)
assert(not settings.active.suspended and not picker.active,'color picker did not return to settings')
assert(not picker.suppress_release,'nested color picker leaked mouse capture')
assert(settings.active.draft.theme_colors.monokai.accent=='#123456' and style.accent[1]~=0x12,'theme color was not staged')
settings.select('explorer');fill('explorer_width','310');click('show_hidden')
settings.select('languages');click('diagnostics');click('hover');fill('completion_chars','3')
settings.select('shortcuts');fill('shortcut_search','settings');settings.draw()
local found=false;for _,c in ipairs(settings.layout().controls) do if c.label=='Litefront: Settings' or (c.label and c.label:lower():find('settings',1,true) and c.id:find('shortcut%-')) then found=true end end
assert(found,'shortcut filtering did not find the settings shortcut')
settings.select('general');click('restore_folders')
assert(table.concat(doc.lines)==source and doc:get_change_id()==revision and not doc:is_dirty(),'preferences modified an open document')
assert(settings.changed(),'staged changes did not enable Apply')
click('apply')
assert(settings.active and settings.active.tab=='general','Apply closed the settings window or changed its tab')
assert(not settings.changed(),'Apply stayed enabled after applying')
assert(settings.active.draft.ui_size==18 and settings.active.draft.explorer_width==310,'the open window did not keep the applied values')
click('cancel')
assert(not settings.active,'Cancel did not close the settings window after Apply')
assert(fonts.ui_size==18 and fonts.code_size==20,'Apply did not update fonts')
assert(config.indent_size==4 and config.tab_type=='hard' and config.line_height==1.75,'Apply did not update editor settings')
local indent_kind,indent_size=doc:get_indent_info()
assert(indent_kind=='hard' and indent_size==4,'Apply did not update indentation on the open file')
assert(not config.plugins.minimap.enabled and view.wrapped_settings,'Apply did not update minimap/wrapping')
assert(not config.plugins.lsp.show_diagnostics and not config.plugins.lsp.mouse_hover and config.plugins.autocomplete.min_len==3,'Apply did not update language tools')
assert(style.background[1]==0x27 and style.accent[1]==0x12,'Apply did not update theme and custom colors')
local explorer=require 'plugins.litefront_explorer'
assert(explorer.width==310*SCALE,'Apply did not update explorer width')
for _,row in ipairs(explorer.rows) do assert(row.name~='.hidden.css','hidden files preference did not filter explorer') end
assert(#require('litefront.color_inline').hits(doc,1)==0,'inline swatch preference was ignored')
assert(table.concat(doc.lines)==source and not doc:is_dirty(),'Apply changed the document text')
