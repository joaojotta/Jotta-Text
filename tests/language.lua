local core=require 'core'
local prefs=require 'litefront.preferences'
local settings=require 'litefront.settings'
local command=require 'core.command'
local i18n=require 'litefront.i18n'
local dialogs=require 'litefront.dialogs'
local root=os.getenv('SETTINGS_ROOT')
local function control(id)
  for _,c in ipairs(settings.layout().controls) do if c.id==id then return c end end
  error('missing control '..id)
end
local function choose_language(value)
  settings.select('general');settings.activate(control('ui_language'))
  local d=settings.dropdown_layout()
  for i,item in ipairs(d.options) do if item.value==value then d.index=i end end
  settings.key('return')
end
if os.getenv('SETTINGS_PHASE')=='2' then
  assert(i18n.language()=='pt-PT','UI language was not restored')
  settings.open();choose_language('en');settings.apply()
  assert(i18n.t('File')=='File','English was not restored live')
  command.perform('litefront-menu:file')
  assert(require('plugins.litefront_shell').popup.items[1].text=='New File','menu retained previous language')
  command.perform('litefront-menu:close')
  return
end
local doc=core.open_doc(root..'/style.css');core.root_view:open_doc(doc)
local original=table.concat(doc.lines);local revision=doc:get_change_id()
doc.indent_info.type='hard';doc.indent_info.size=3;doc.indent_info.confirmed=true
settings.open();choose_language('pt-PT')
assert(i18n.language()=='en','draft language applied before Apply')
settings.apply()
assert(i18n.t('File')=='Ficheiro' and i18n.t('Save')=='Guardar','Portuguese catalog not active')
local kind,size=doc:get_indent_info()
assert(kind=='hard' and size==3,'language settings overwrote detected indentation')
assert(table.concat(doc.lines)==original and doc:get_change_id()==revision,'language setting edited document content')
command.perform('litefront-menu:file')
local popup=require('plugins.litefront_shell').popup
assert(popup.items[1].text=='Novo ficheiro' and popup.items[1].command=='core:new-doc','menu translation broke command identity')
command.perform('litefront-menu:close')
settings.open();settings.select('editor');settings.draw()
assert(control('label-code_font').label=='Tipo de letra do editor','settings labels not translated')
choose_language('en');settings.close()
assert(i18n.language()=='pt-PT','Cancel applied pending language')
settings.open();settings.select('editor')
settings.layout();settings.choose('tab_type');local d=settings.dropdown_layout()
for i,item in ipairs(d.options) do if item.value=='soft' then d.index=i end end
settings.key('return');settings.apply()
kind,size=doc:get_indent_info()
assert(kind=='soft' and size==prefs.values.indent_size,'explicitly reselecting default indent did not apply to existing files')
-- UI is translated at render boundaries; callbacks keep canonical option text.
dialogs.show('Unsaved Changes','Keep this document?',{{text='Save',default_yes=true},{text='Cancel',default_no=true}})
local strings={};local draw_text=renderer.draw_text
renderer.draw_text=function(font,text,...) strings[text]=true;return draw_text(font,text,...) end
core.root_view:draw()
renderer.draw_text=draw_text
assert(strings['Alterações não guardadas'] and strings['Guardar'] and strings['Cancelar'],'dialog rendering was not translated')
assert(dialogs.active.options[1].text=='Save','translation changed callback values')
dialogs.choose(2)
dialogs.show_about();require('litefront.about').draw(dialogs.active,core.root_view)
assert(require('litefront.about').details():find('Baseado no Lite XL',1,true),'About details not translated')
dialogs.choose(2)
assert(table.concat(doc.lines)==original and not doc:is_dirty(),'UI localization dirtied source files')
