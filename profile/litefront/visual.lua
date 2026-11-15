-- Shared visual primitives and imported Jotta Edit assets (see assets/NOTICE.md).
local style=require 'core.style'
local common=require 'core.common'
local glyphs=require 'litefront.icon-map'
local palettes=require 'litefront.palettes'
local visual={mode='dark',syntax_theme='auto',ui_theme='auto',palettes=palettes}
local saved=io.open(USERDIR..'/appearance.txt','r')
if saved then
  local mode,id,icons,ui=saved:read('*l'),saved:read('*l'),saved:read('*l'),saved:read('*l');saved:close()
  if mode=='dark' or mode=='light' then visual.mode=mode end
  if palettes[id] then visual.syntax_theme=id end
  visual.icon_palette=icons
  if palettes[ui] then visual.ui_theme=ui;visual.mode=palettes[ui].mode end
end
function visual.save_appearance()
  local out,err=io.open(USERDIR..'/appearance.txt','w')
  if not out then require('core').error('Could not save appearance: %s',err);return end
  out:write(visual.mode,'\n',visual.syntax_theme,'\n',visual.icon_palette or 'auto','\n',visual.ui_theme or 'auto','\n');out:close()
end
function visual.file_color(icon)
  local key=icon:gsub('^file%-','')
  key=({folder='folder',file='file',code='txt',font='fonts'})[key] or key
  local id=visual.icon_palette or 'auto'
  if id=='auto' then id=visual.syntax_theme=='auto' and 'jotta-'..visual.mode or visual.syntax_theme end
  local all=require('litefront.icon-palettes')[visual.mode]
  local palette=all[id] or all['jotta-'..visual.mode]
  return visual.color(palette[key..'.svg'] or palette['file.svg'])
end
local fonts={}
function visual.document_view()
  local core=require 'core'
  local view=core.active_view
  if view==core.command_view then view=core.last_active_view end
  if view and view.doc and view~=core.command_view then return view end
end
function visual.color(hex)
  return {tonumber(hex:sub(2,3),16),tonumber(hex:sub(4,5),16),tonumber(hex:sub(6,7),16),tonumber(hex:sub(8,9),16) or 255}
end
function visual.rounded(x,y,w,h,r,color)
  if w<=0 or h<=0 then return end
  renderer.draw_rounded_rect(x,y,w,h,math.max(0,math.min(r,w/2,h/2)),color)
end

function visual.icon(name,x,y,size,color)
  local font_size=math.max(1,math.floor(size))
  if not fonts[font_size] then
    fonts[font_size]=renderer.font.load(DATADIR..'/litefront/assets/fonts/jotta-icons.ttf',font_size,{antialiasing='grayscale',hinting='full'})
  end
  renderer.draw_text(fonts[font_size],glyphs[name] or glyphs.file,x,y,color or style.dim)
end
local app_logo=require 'litefront.app-logo'
function visual.logo(x,y,size)
  local resolution=size<=30 and 20 or size<=60 and 40 or size<=150 and 100 or 200
  local ratio=size/resolution
  for _,run in ipairs(app_logo[resolution]) do
    renderer.draw_rect(x+run[1]*ratio,y+run[2]*ratio,run[3]*ratio,ratio,{run[4],run[5],run[6],run[7]})
  end
end

function visual.text(font,text,x,y,w,h,color,align)
  if w<=0 or h<=0 then return end
  local result=''
  if font:get_width(text)>w then
    for char in common.utf8_chars(text) do
      if font:get_width(result..char..'…')>w then break end
      result=result..char
    end
    text=result..'…'
  end
  common.draw_text(font,color or style.text,text,align,x,y,w,h)
end
function visual.apply_palette(id)
  local palette=palettes[id]
  if not palette then return end
  local c=visual.color
  local function blend(a,b,t)
    a,b=c(a),c(b)
    return {math.floor(a[1]*(1-t)+b[1]*t+.5),math.floor(a[2]*(1-t)+b[2]*t+.5),math.floor(a[3]*(1-t)+b[3]*t+.5),255}
  end
  style.background=c(palette.background)
  local ui_id=visual.ui_theme~='auto' and visual.ui_theme or id
  local interface=require('litefront.interface-palettes')[ui_id]
  local fields={ui_background='bg',background2='surface',background3='surface-alt',sidebar_background='sidebar',text='ink',dim='muted',divider='line',accent='accent',title_background='title',input_background='surface-alt',accent_text='accent-text'}
  for field,key in pairs(fields) do style[field]=c(interface[key]) end
  style.ui_selection=blend(interface.surface,interface.accent,.25)
  style.background3=c(interface.raised or interface['surface-alt'])
  style.hover_background=interface.active and c(interface.active) or blend(interface.surface,interface.ink,.12)
  style.selection=palette.inheritSyntax and c(palette.mode=='light' and '#ffedb0' or '#484229') or blend(palette.background,palette.accent,.25)
  style.line_highlight=palette.inheritSyntax and c(palette.mode=='light' and '#f0f0f2' or '#292a2e') or blend(palette.background,palette.widget,.5)
  local map={normal='foreground',comment='comment',keyword='keyword',keyword2='type',literal='keyword',string='string',number='number',['function']='function',symbol='variable',operator='operator',htmltag='tag',htmlattribute='attribute'}
  for token,field in pairs(map) do style.syntax[token]=c(palette[field] or palette.foreground) end
  style.caret=c(palette.accent or '#ffc107')
  style.line_number=c(palette.mode=='light' and '#92939c' or '#666873')
  style.line_number2=c(palette.foreground)
end
function visual.theme_fonts(mode)
  visual.mode=mode
  local preferences=require 'litefront.fonts'
  local function font(weight,size)
    size=size*preferences.ui_size/14
    local custom=require('litefront.fonts').selected.ui
    if custom then
      local ok, loaded=pcall(renderer.font.load,custom,size*SCALE,{antialiasing='grayscale',hinting='slight',kerning=true,weight=weight})
      if ok then return loaded end
    end
    return renderer.font.load(DATADIR..'/litefront/assets/fonts/supplied/Rubik-VariableFont_wght.ttf',
      size*SCALE,{antialiasing='grayscale',hinting='slight',kerning=true,weight=weight})
  end
  style.font=font(400,14)
  style.small_font=font(400,12)
  style.label_font=font(400,13)
  style.bold_font=font(600,14)
  style.big_font=font(600,24)
  style.code_font=renderer.font.load(DATADIR..'/litefront/assets/fonts/supplied/JetBrainsMono-VariableFont_wght.ttf',preferences.code_size*SCALE,{antialiasing='grayscale',hinting='slight',kerning=false,weight=400})
  local custom=require('litefront.fonts').selected.code
  if custom then
    local ok, loaded=pcall(renderer.font.load,custom,preferences.code_size*SCALE,{antialiasing='grayscale',hinting='slight',kerning=false,weight=400})
    if ok then style.code_font=loaded end
  end
  style.padding={x=10*SCALE,y=5*SCALE}
  style.tab_width=140*SCALE
  style.scrollbar_size=5*SCALE
  style.expanded_scrollbar_size=10*SCALE
  style.sidebar_background=style.background2
  style.accent_text=visual.color('#1b1b1b')
  style.title_background=visual.color(mode=='dark' and '#202125' or '#eeeef0')
  style.input_background=visual.color(mode=='dark' and '#292a2e' or '#f0f0f2')
  style.hover_background=visual.color(mode=='dark' and '#34353a' or '#e9e9ed')
  visual.apply_palette(visual.syntax_theme=='auto' and 'jotta-'..mode or visual.syntax_theme)
  require('litefront.preferences').apply_colors(visual)
end
return visual
