-- Markdown preview shares the editor's active appearance and font preferences.
local style=require 'core.style'
local M={}
M.colors={
  text=function() return style.text end,
  header=function() return style.accent end,
  code=function() return style.syntax.normal or style.text end,
  bullet=function() return style.accent end,
  rule=function() return style.divider end,
  header_rule=function() return style.divider end,
  code_bg=function() return style.background end,
  dim=function() return style.dim end,
}
function M.signature()
  local parts={tostring(style.font),tostring(style.code_font),tostring(style.font:get_size()),tostring(style.code_font:get_size()),tostring(SCALE)}
  local function add(color)
    for _,value in ipairs(color or {}) do parts[#parts+1]=tostring(value) end
    parts[#parts+1]=';'
  end
  for _,key in ipairs({'background','ui_background','background2','text','accent','dim','divider'}) do add(style[key]) end
  local keys={}
  for key in pairs(style.syntax) do keys[#keys+1]=key end
  table.sort(keys)
  for _,key in ipairs(keys) do parts[#parts+1]=key;add(style.syntax[key]) end
  return table.concat(parts,':')
end
local cached_key,cached
function M.assets()
  local key=M.signature()
  if key==cached_key then return cached end
  local size=style.font:get_size()
  local span=require('plugins.litemark.mdparse').TOKENS.SPAN
  local function body(font_size,weight,italic)
    if italic and not require('litefront.fonts').selected.ui then
      return renderer.font.load(DATADIR..'/litefront/assets/fonts/supplied/Rubik-Italic-VariableFont_wght.ttf',font_size,
        {weight=weight,kerning=true,antialiasing='grayscale',hinting='slight'})
    end
    return style.font:copy(font_size,{weight=weight,italic=italic,kerning=true})
  end
  local fonts={REGULAR=style.font,BOLD=body(size,600,false),ITALIC=body(size,400,true),
    CODE=style.code_font,HEADER={}}
  for level,offset in ipairs({10,6,4,2,0,0}) do
    local heading_size=size+offset*SCALE
    fonts.HEADER[level]={[span.NONE]=body(heading_size,600,false),[span.BOLD]=body(heading_size,700,false),
      [span.ITALIC]=body(heading_size,600,true),[span.CODE]=style.code_font}
  end
  cached={size=size,fonts=fonts}
  cached_key=key
  return cached
end
return M
