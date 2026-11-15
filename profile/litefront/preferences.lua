-- Application settings are validated JSON data, never executable configuration.
local config=require 'core.config'
local json=require 'plugins.json'
local M={}
M.defaults={indent_size=2,tab_type='soft',line_height=1.55,line_limit=100,word_wrap=false,minimap=true,
  highlight_line=true,cursor_blink=true,scroll_past_end=true,color_swatches=true,show_hidden=true,
  explorer_visible=true,explorer_width=240,diagnostics=true,hover=true,completion_chars=2,restore_folders=true,ui_language='en',ui_theme='auto',theme_colors={},github_trial=false}
M.color_fields={{'background','Editor background'},{'ui_background','Workspace background'},{'background2','Panels and dialogs'},{'background3','Raised surfaces'},
  {'sidebar_background','Explorer background'},{'title_background','Title bar'},{'input_background','Inputs'},
  {'text','Interface text'},{'dim','Secondary text'},{'divider','Borders'},{'accent','Accent'},{'selection','Selection'},
  {'syntax.normal','Code text'},{'syntax.comment','Comments'},{'syntax.keyword','Keywords'},{'syntax.keyword2','Types'},
  {'syntax.string','Strings'},{'syntax.number','Numbers'},{'syntax.function','Functions'},{'syntax.symbol','Variables'},
  {'syntax.htmltag','HTML tags'},{'syntax.htmlattribute','HTML attributes'},{'syntax.operator','Operators'}}
local allowed={};for _,field in ipairs(M.color_fields) do allowed[field[1]]=true end
local ranges={indent_size={1,8},line_height={1.1,2.2},line_limit={40,240},explorer_width={140,600},completion_chars={1,8}}
local path=USERDIR..'/preferences.json'
function M.copy(value)
  if type(value)~='table' then return value end
  local result={};for key,item in pairs(value) do result[key]=M.copy(item) end;return result
end
local function valid_colors(value)
  local result={}
  for theme,fields in pairs(type(value)=='table' and value or {}) do
    if type(theme)=='string' and type(fields)=='table' then
      local record={}
      for field,color in pairs(fields) do
        if allowed[field] and type(color)=='string' and color:match('^#%x+$') and (#color==7 or #color==9) then record[field]=color end
      end
      result[theme]=record
    end
  end
  return result
end
local function validate(data)
  local result=M.copy(M.defaults)
  for key,default in pairs(M.defaults) do
    local value=data[key]
    if key=='ui_theme' and (value=='auto' or require('litefront.palettes')[value]) then result[key]=value
    elseif key=='ui_language' and (value=='en' or value=='pt-PT') then result[key]=value
    elseif key=='theme_colors' then result[key]=valid_colors(value)
    elseif type(default)=='boolean' and type(value)=='boolean' then result[key]=value
    elseif ranges[key] and type(value)=='number' and value==value and value>=ranges[key][1] and value<=ranges[key][2] then result[key]=key=='line_height' and value or math.floor(value)
    elseif key=='tab_type' and (value=='soft' or value=='hard') then result[key]=value end
  end
  return result
end
M.values=M.copy(M.defaults)
local input=io.open(path,'r')
if input then
  local ok,data=pcall(json.decode,input:read('*a'));input:close()
  if ok and type(data)=='table' then M.values=validate(data) end
end
function M.apply_config()
  local v=M.values
  config.indent_size=v.indent_size;config.tab_type=v.tab_type;config.line_height=v.line_height;config.line_limit=v.line_limit
  config.highlight_current_line=v.highlight_line;config.disable_blink=not v.cursor_blink;config.scroll_past_end=v.scroll_past_end
  config.plugins.minimap=config.plugins.minimap or {};config.plugins.minimap.enabled=v.minimap
  config.plugins.linewrapping=config.plugins.linewrapping or {};config.plugins.linewrapping.enable_by_default=v.word_wrap
  config.plugins.autocomplete=config.plugins.autocomplete or {};config.plugins.autocomplete.min_len=v.completion_chars
  config.plugins.lsp=config.plugins.lsp or {};config.plugins.lsp.show_diagnostics=v.diagnostics;config.plugins.lsp.mouse_hover=v.hover
  config.litefront=v
end
function M.theme_key(draft) return draft.syntax_theme=='auto' and 'jotta-'..draft.mode or draft.syntax_theme end
function M.ui_key(draft) return draft.ui_theme and draft.ui_theme~='auto' and draft.ui_theme or M.theme_key(draft) end
function M.color_key(draft,field)
  return (field=='background' or field=='selection' or field:sub(1,7)=='syntax.') and M.theme_key(draft) or M.ui_key(draft)
end
function M.apply_colors(visual)
  local style=require 'core.style'
  for _,entry in ipairs(M.color_fields) do
    local field=entry[1];local fields=M.values.theme_colors[M.color_key(visual,field)]
    local hex=fields and fields[field]
    if hex then
      if field:sub(1,7)=='syntax.' then style.syntax[field:sub(8)]=visual.color(hex)
      else style[field]=visual.color(hex);if field=='accent' and M.ui_key(visual)==M.theme_key(visual) then style.caret=visual.color(hex) end end
    end
  end
end
function M.snapshot()
  local d=M.copy(M.values)
  local fonts=require 'litefront.fonts';local visual=require 'litefront.visual';local explorer=require 'plugins.litefront_explorer'
  d.ui_size=fonts.ui_size;d.code_size=fonts.code_size;d.ui_font=fonts.selected.ui;d.code_font=fonts.selected.code
  d.mode=visual.mode;d.syntax_theme=visual.syntax_theme;d.ui_theme=visual.ui_theme or 'auto';d.icon_palette=visual.icon_palette or 'auto'
  d.explorer_visible=explorer.visible;d.explorer_width=explorer.width/SCALE
  d.minimap=config.plugins.minimap.enabled
  return d
end
local token_fields={normal='foreground',keyword='keyword',keyword2='type',string='string',number='number',comment='comment',
  ['function']='function',symbol='variable',operator='operator',htmltag='tag',htmlattribute='attribute'}
function M.theme_color(draft,field)
  local key=M.color_key(draft,field)
  local override=draft.theme_colors[key] and draft.theme_colors[key][field]
  if override then return override end
  local palette=require('litefront.palettes')[M.theme_key(draft)] or require('litefront.palettes')['jotta-'..draft.mode]
  if field:sub(1,7)=='syntax.' then return palette[token_fields[field:sub(8)]] or palette.foreground end
  if field=='background' then return palette.background end
  local interface=require('litefront.interface-palettes')[M.ui_key(draft)]
  local mappings={ui_background='bg',background2='surface',background3='surface-alt',sidebar_background='sidebar',title_background='title',input_background='surface-alt',text='ink',dim='muted',divider='line',accent='accent'}
  if field=='background3' and interface.raised then return interface.raised end
  if mappings[field] then return interface[mappings[field]] end
  if field=='selection' then
    if palette.inheritSyntax then return palette.mode=='light' and '#ffedb0' or '#484229' end
    local parse=require('litefront.colors').parse;local a,b=parse(palette.background),parse(palette.accent)
    return require('litefront.colors').format({r=math.floor(a.r*.75+b.r*.25+.5),g=math.floor(a.g*.75+b.g*.25+.5),b=math.floor(a.b*.75+b.b*.25+.5),a=1})
  end
  return palette.foreground
end
function M.save(draft)
  for _,kind in ipairs({'ui','code'}) do
    local size=draft[kind..'_size']
    if type(size)~='number' or size~=size or size<8 or size>(kind=='ui' and 32 or 72) then return nil,'Invalid '..kind..' font size' end
    local path=draft[kind..'_font']
    if path then
      local ok,err=pcall(renderer.font.load,path,size*SCALE)
      if not ok then return nil,'Could not load font: '..tostring(err) end
    end
  end
  local values=validate(draft)
  local out,err=io.open(path..'.tmp','w');if not out then return nil,err end
  local written,message=out:write(json.encode(values));local closed,close_error=out:close()
  if not written or not closed then return nil,message or close_error end
  local renamed,rename_error=os.rename(path..'.tmp',path);if not renamed then return nil,rename_error end
  local indent_changed=M.values.tab_type~=values.tab_type or M.values.indent_size~=values.indent_size or draft._indent_changed
  local wrap_changed=M.values.word_wrap~=values.word_wrap
  M.values=values;M.apply_config()
  local fonts=require 'litefront.fonts'
  fonts.ui_size=draft.ui_size;fonts.code_size=draft.code_size;fonts.selected.ui=draft.ui_font;fonts.selected.code=draft.code_font;fonts.save()
  local visual=require 'litefront.visual'
  visual.mode=draft.mode;visual.syntax_theme=draft.syntax_theme;visual.ui_theme=values.ui_theme;visual.icon_palette=draft.icon_palette
  visual.save_appearance();require('core').reload_module('colors.litefront_'..visual.mode)
  local explorer=require 'plugins.litefront_explorer'
  explorer.visible=draft.explorer_visible;explorer.width=draft.explorer_width*SCALE;explorer:refresh()
  local core=require 'core'
  for _,doc in ipairs(indent_changed and core.docs or {}) do
    doc.indent_info=doc.indent_info or {}
    doc.indent_info.type=values.tab_type;doc.indent_info.size=values.indent_size;doc.indent_info.confirmed=true
  end
  local DocView=require 'core.docview';local wrapping=require 'plugins.linewrapping'
  for _,view in ipairs(core.root_view.root_node:get_children()) do
    if view:extends(DocView) and view~=core.command_view then
      local enabled=view.wrapping_enabled or view.wrapped_settings~=nil
      if wrap_changed then enabled=draft.word_wrap end
      view.wrapping_enabled=enabled;view.wrapped_settings=nil
      if enabled then wrapping.update_docview_breaks(view) else wrapping.reconstruct_breaks(view,view:get_font(),math.huge) end
    end
  end
  core.redraw=true;return true
end
return M
