-- Font preferences are plain data, never executable user configuration.
local M={selected={},ui_size=14,code_size=14}
local file=io.open(USERDIR..'/fonts.txt','r')
if file then
  M.selected.ui=file:read('*l'); M.selected.code=file:read('*l')
  M.ui_size=math.max(8,math.min(32,tonumber(file:read('*l')) or 14))
  M.code_size=math.max(8,math.min(72,tonumber(file:read('*l')) or 14))
  file:close()
  for key,value in pairs(M.selected) do if value=='' then M.selected[key]=nil end end
end
function M.save()
  local out,err=io.open(USERDIR..'/fonts.txt','w')
  if not out then require('core').error('Could not save font preferences: %s',err);return end
  out:write(M.selected.ui or '', '\n', M.selected.code or '', '\n',M.ui_size,'\n',M.code_size,'\n');out:close()
end
function M.list()
  local system=require 'system'
  local result,seen={},{}
  local function scan(dir)
    if seen[dir] then return end
    seen[dir]=true
    for _,name in ipairs(system.list_dir(dir) or {}) do
      local path=dir..'/'..name
      local info=system.get_file_info(path)
      if info and info.type=='dir' then scan(path)
      elseif name:lower():match('%.ttf$') or name:lower():match('%.otf$') or name:lower():match('%.ttc$') then
        result[#result+1]={text=name,info=path,path=path}
      end
    end
  end
  local home=os.getenv('HOME') or ''
  for _,dir in ipairs({DATADIR..'/fonts',DATADIR..'/litefront/assets/fonts','/usr/share/fonts','/usr/local/share/fonts',home..'/.fonts',(os.getenv('XDG_DATA_HOME') or home..'/.local/share')..'/fonts','/run/host/fonts','/run/host/user-fonts'}) do scan(dir) end
  if PLATFORM=='Windows' then
    scan((os.getenv('WINDIR') or 'C:/Windows')..'/Fonts')
    if os.getenv('LOCALAPPDATA') then scan(os.getenv('LOCALAPPDATA')..'/Microsoft/Windows/Fonts') end
  end
  table.sort(result,function(a,b) return a.path<b.path end)
  return result
end
return M
