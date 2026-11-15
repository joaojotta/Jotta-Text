local core=require 'core'
local command=require 'core.command'
local settings=require 'litefront.settings'
local visual=require 'litefront.visual'
local prefs=require 'litefront.preferences'
local function find(id)
  for _,c in ipairs(settings.layout().controls) do if c.id==id then return c end end
  error('missing control '..id)
end
local function hover(id)
  local c=find(id)
  core.on_event('mousemoved',c.x+c.w/2,c.y+c.h/2,0,0)
  return c
end
if os.getenv('SETTINGS_PHASE')=='2' then
  assert(prefs.values.ui_language=='pt-PT','wheel-selected preference did not persist')
  return
end
local doc=core.open_doc(os.getenv('SETTINGS_ROOT')..'/style.css');core.root_view:open_doc(doc)
local before=table.concat(doc.lines)
command.perform('litefront:settings');settings.select('themes')
-- Tab focuses a closed selector; arrow keys update it without opening the menu.
for _=1,12 do
  core.on_event('keypressed','tab');if settings.active.focus=='mode' then break end
end
assert(settings.active.focus=='mode','Tab did not reach first selector')
core.on_event('keypressed','right')
assert(settings.active.draft.mode=='light' and not settings.active.dropdown,'focused arrow did not change the closed selector')
assert(visual.mode=='dark','selector arrows applied settings before Apply')
core.on_event('keypressed','left');assert(settings.active.draft.mode=='dark','Left did not select the previous value')
settings.active.focus='syntax_theme'
core.on_event('keypressed','down');local next_theme=settings.active.draft.syntax_theme
assert(next_theme~='auto','Down did not select the next editor theme')
core.on_event('keypressed','up');assert(settings.active.draft.syntax_theme=='auto','Up did not restore previous editor theme')
core.on_event('keypressed','end');assert(settings.active.draft.syntax_theme~='auto','End did not reach last theme')
core.on_event('keypressed','home');assert(settings.active.draft.syntax_theme=='auto','Home did not reach first theme')
core.on_event('keypressed','up');assert(settings.active.draft.syntax_theme=='auto','selector wrapped beyond its first item')
-- A wheel acts on the hovered selector, even when another control has focus.
settings.active.focus='ui_theme';core.on_event('keypressed','home');settings.active.focus='syntax_theme'
local scroll=settings.active.scroll;local focus=settings.active.focus
hover('ui_theme');core.on_event('mousewheel',-1,0)
assert(settings.active.draft.ui_theme~='auto' and settings.active.draft.syntax_theme=='auto','wheel changed the focused selector instead of the hovered selector')
assert(settings.active.scroll==scroll and settings.active.focus==focus,'selector wheel scrolled the panel or stole focus')
core.on_event('mousewheel',1,0);assert(settings.active.draft.ui_theme=='auto','wheel direction did not reverse the choice')
core.on_event('mousewheel',-.5,0);assert(settings.active.draft.ui_theme=='auto','fractional wheel moved prematurely')
core.on_event('mousewheel',-.5,0);assert(settings.active.draft.ui_theme~='auto','touchpad fractions were not accumulated')
-- An open menu keeps its wheel scrolling behavior and keyboard selection.
settings.active.focus='syntax_theme';core.on_event('keypressed','return')
local d=settings.dropdown_layout();local original=settings.active.draft.syntax_theme
core.on_event('mousewheel',-2,0)
assert(d.offset>0 and settings.active.draft.syntax_theme==original,'open dropdown wheel committed a value')
core.on_event('keypressed','right');assert(d.index==2,'open dropdown did not accept Right')
core.on_event('keypressed','left');assert(d.index==1,'open dropdown did not accept Left')
core.on_event('keypressed','escape');assert(settings.active and not settings.active.dropdown,'Escape closed settings instead of its dropdown')
-- Font selection uses the same behavior, and wheel events elsewhere scroll the panel.
settings.select('editor');settings.active.focus='code_font'
core.on_event('keypressed','down');assert(settings.active.draft.code_font,'font selector did not support Down')
core.on_event('keypressed','home');assert(not settings.active.draft.code_font,'font selector did not restore bundled default')
hover('code_font');core.on_event('mousewheel',-1,0)
assert(settings.active.draft.code_font and settings.active.scroll==0,'font wheel did not change the selector')
local body=settings.active.body
core.on_event('mousemoved',body.x+2,body.y+5,0,0)
core.on_event('mousewheel',-3,0);assert(settings.active.scroll>0,'wheel outside a selector did not scroll settings')
settings.close();assert(visual.syntax_theme=='auto','Cancel committed selector changes')
-- Non-theme selectors also work and keep their stable persisted IDs.
settings.open();settings.select('general');hover('ui_language')
core.on_event('mousewheel',-1,0)
assert(settings.active.draft.ui_language=='pt-PT' and prefs.values.ui_language=='en','language wheel ignored staging')
settings.apply();assert(prefs.values.ui_language=='pt-PT','Apply did not commit wheel-selected preference')
assert(table.concat(doc.lines)==before and not doc:is_dirty(),'selector changes edited source content')
