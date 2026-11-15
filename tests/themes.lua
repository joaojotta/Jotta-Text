local core=require 'core'
local visual=require 'litefront.visual'
local prefs=require 'litefront.preferences'
local settings=require 'litefront.settings'
local style=require 'core.style'
local ui=require 'litefront.interface-palettes'
local function color(actual,expected,message)
  local value=visual.color(expected)
  for i=1,4 do assert(actual[i]==value[i],message..' channel '..i..': '..actual[i]..' vs '..value[i]) end
end
if os.getenv('SETTINGS_PHASE')=='2' then
  assert(visual.syntax_theme=='monokai' and visual.ui_theme=='github-light' and visual.mode=='light','independent schemes did not survive restart')
  color(style.background,visual.palettes.monokai.background,'restored editor background')
  color(style.background2,ui['github-light'].surface,'restored UI surface')
  color(style.accent,'#123456','restored UI override')
  color(style.syntax.keyword,'#fedcba','restored editor override')
  return
end
local file=assert(io.open(DATADIR..'/litefront/assets/reference/Jotta-Edit-theme-catalog.json'))
local imported=require('plugins.json').decode(file:read('*a'));file:close()
local editor_count,ui_count=0,0
for id,palette in pairs(imported.editor) do
  editor_count=editor_count+1
  for field,value in pairs(palette) do assert(visual.palettes[id][field]==value,'editor import mismatch: '..id..'/'..field) end
  visual.syntax_theme=id;visual.ui_theme='jotta-light';visual.mode='light';visual.apply_palette(id)
  color(style.background,palette.background,'editor scheme '..id)
  color(style.syntax.keyword,palette.keyword,'editor keyword '..id)
  color(style.background2,ui['jotta-light'].surface,'editor changed independent UI')
end
for id,colors in pairs(imported.ui) do
  ui_count=ui_count+1
  for field,value in pairs(colors) do assert(ui[id][field]==value,'UI import mismatch: '..id..'/'..field) end
  visual.syntax_theme='monokai';visual.ui_theme=id;visual.mode=colors.mode;visual.apply_palette('monokai')
  color(style.background,visual.palettes.monokai.background,'UI changed independent editor')
  for field,key in pairs({ui_background='bg',background2='surface',input_background='surface-alt',sidebar_background='sidebar',title_background='title',text='ink',dim='muted',divider='line',accent='accent',accent_text='accent-text'}) do
    color(style[field],colors[key],'UI scheme '..id..'/'..field)
  end
end
assert(editor_count==21 and ui_count==21,'theme import is incomplete')
local doc=core.open_doc(os.getenv('SETTINGS_ROOT')..'/style.css');core.root_view:open_doc(doc)
local before=table.concat(doc.lines)
visual.syntax_theme='monokai';visual.ui_theme='auto';visual.mode='dark';core.reload_module('colors.litefront_dark')
settings.open();settings.select('themes');settings.layout();settings.choose('ui_theme')
local menu=settings.dropdown_layout();assert(#menu.options==22,'UI dropdown missing choices')
for i,item in ipairs(menu.options) do if item.value=='github-light' then menu.index=i end end
settings.key('return')
assert(settings.active.draft.ui_theme=='github-light' and settings.active.draft.syntax_theme=='monokai','UI selection changed draft editor')
assert(visual.ui_theme=='auto','draft UI scheme applied before Apply')
settings.active.draft.theme_colors['github-light']={accent='#123456'}
settings.active.draft.theme_colors.monokai={['syntax.keyword']='#fedcba'}
settings.apply()
assert(visual.syntax_theme=='monokai' and visual.ui_theme=='github-light' and visual.mode=='light','independent choices were not applied')
color(style.background,visual.palettes.monokai.background,'applied editor background')
color(style.background2,ui['github-light'].surface,'applied UI background')
color(style.accent,'#123456','scoped UI override')
color(style.caret,visual.palettes.monokai.accent,'UI override changed the independent editor caret')
color(style.syntax.keyword,'#fedcba','scoped editor override')
assert(require('litefront.markdown_theme').colors.code_bg()==style.background,'mixed-theme Markdown code background mismatched')
-- Command input stays readable against its UI surface in a mixed theme.
core.command_view:enter('Find Text',{text='readable UI',suggest=function() return {} end})
local draw_text=renderer.draw_text;local input_color
renderer.draw_text=function(font,text,x,y,color)
  if text=='readable UI' then input_color=color end
  return draw_text(font,text,x,y,color)
end
core.command_view:draw_line_text(1,10,10);renderer.draw_text=draw_text
assert(input_color==style.text,'command input used editor colors on a UI background')
core.command_view:exit(false)
settings.open();settings.select('theme-editor');settings.draw()
assert(prefs.color_key(settings.active.draft,'accent')=='github-light','UI customization uses editor scheme key')
assert(prefs.color_key(settings.active.draft,'syntax.keyword')=='monokai','editor customization uses UI scheme key')
settings.reset();settings.close()
assert(prefs.values.theme_colors['github-light'].accent=='#123456','Cancel committed pending UI reset')
assert(table.concat(doc.lines)==before and not doc:is_dirty(),'scheme selection changed source text')
