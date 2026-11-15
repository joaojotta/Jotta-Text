-- mod-version:3
local T=require('litefront.i18n').t
local core=require 'core'
local command=require 'core.command'
local common=require 'core.common'
local visual=require 'litefront.visual'
local fonts=require 'litefront.fonts'
local function apply()
  visual.theme_fonts(visual.mode)
  core.redraw=true
end
local function resize(kind,delta,reset)
  local field=kind..'_size'
  fonts[field]=reset and 14 or common.clamp(fonts[field]+delta,8,kind=='ui' and 32 or 72)
  fonts.save();apply()
end
local function choose(kind)
  local items=fonts.list()
  table.insert(items,1,{text=T(kind=='ui' and 'Default — Rubik' or 'Default — JetBrains Mono'),info=T('Bundled font'),preview_path=DATADIR..'/litefront/assets/fonts/supplied/'..(kind=='ui' and 'Rubik-VariableFont_wght.ttf' or 'JetBrainsMono-VariableFont_wght.ttf')})
  core.command_view:enter(kind=='ui' and 'UI font' or 'Code editor font',{picker=true,typeahead=false,
    preview=function(item)
      if item then core.root_view:open_doc(core.open_doc(item.path or item.preview_path)) end
    end,
    suggest=function(text)
      local matches={}
      for _,item in ipairs(items) do
        if text=='' or common.fuzzy_match(item.text..' '..(item.info or ''),text) then matches[#matches+1]=item end
      end
      return matches
    end,
    submit=function(text,item)
      if not item then core.error('Select a font from the list');return end
      if item.path then
        local ok=pcall(renderer.font.load,item.path,14*SCALE)
        if not ok then core.error('Could not load font: %s',item.path);return end
      end
      fonts.selected[kind]=item.path
      fonts.save();apply()
    end,
  })
end
command.add(nil,{
  ['litefront:ui-font']=function() choose('ui') end,
  ['litefront:code-font']=function() choose('code') end,
  ['litefront:reset-fonts']=function() fonts.selected={};fonts.ui_size=14;fonts.code_size=14;fonts.save();apply() end,
  ['litefront:increase-ui-font']=function() resize('ui',1) end,
  ['litefront:decrease-ui-font']=function() resize('ui',-1) end,
  ['litefront:reset-ui-font-size']=function() resize('ui',0,true) end,
  ['litefront:increase-code-font']=function() resize('code',1) end,
  ['litefront:decrease-code-font']=function() resize('code',-1) end,
  ['litefront:reset-code-font-size']=function() resize('code',0,true) end,
})

require('core.keymap').add {
  ['ctrl+=']='litefront:increase-code-font',
  ['ctrl+-']='litefront:decrease-code-font',
  ['ctrl+0']='litefront:reset-code-font-size',
  ['ctrl+wheelup']='litefront:increase-code-font',
  ['ctrl+wheeldown']='litefront:decrease-code-font',
  ['ctrl+alt+=']='litefront:increase-ui-font',
  ['ctrl+alt+-']='litefront:decrease-ui-font',
  ['ctrl+alt+0']='litefront:reset-ui-font-size',
}
