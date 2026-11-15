-- Standalone HTML export for the editor's Markdown authoring tools.
local M={}
local function escape(text)
  return (text:gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;'):gsub('"','&quot;'))
end
local function inline(text)
  local tokens={}
  local function hold(html) tokens[#tokens+1]=html;return '\1'..#tokens..'\2' end
  local function url(value)
    if value:match('^%s*[Jj][Aa][Vv][Aa][Ss][Cc][Rr][Ii][Pp][Tt]:') or value:match('^%s*[Dd][Aa][Tt][Aa]:') then return '#' end
    return escape(value)
  end
  text=text:gsub('`([^`]+)`',function(code) return hold('<code>'..escape(code)..'</code>') end)
  text=text:gsub('!%[([^%]]*)%]%(([^%)]+)%)',function(alt,src) return hold('<img alt="'..escape(alt)..'" src="'..url(src)..'">') end)
  text=text:gsub('%[([^%]]+)%]%(([^%)]+)%)',function(label,href) return hold('<a href="'..url(href)..'">'..escape(label)..'</a>') end)
  for _,tag in ipairs({'u','sub','sup'}) do
    text=text:gsub('<'..tag..'>(.-)</'..tag..'>',function(value) return hold('<'..tag..'>'..escape(value)..'</'..tag..'>') end)
  end
  text=escape(text)
  text=text:gsub('%*%*(.-)%*%*','<strong>%1</strong>'):gsub('%*([^*]+)%*','<em>%1</em>'):gsub('_([^_]+)_','<em>%1</em>'):gsub('~~(.-)~~','<del>%1</del>')
  return (text:gsub('\1(%d+)\2',function(i) return tokens[tonumber(i)] end))
end
function M.render(text)
  local rows={}
  for line in (text..'\n'):gmatch('(.-)\n') do rows[#rows+1]=line:gsub('\r$','') end
  local out,i={},1
  local function add(value) out[#out+1]=value end
  local function cells(line,tag)
    line=line:gsub('^%s*|',''):gsub('|%s*$','')
    local result={}
    for cell in (line..'|'):gmatch('(.-)|') do result[#result+1]='<'..tag..'>'..inline(cell)..'</'..tag..'>' end
    return '<tr>'..table.concat(result)..'</tr>'
  end
  while i<=#rows do
    local line=rows[i]
    if line:match('^```') then
      local code={};i=i+1
      while i<=#rows and not rows[i]:match('^```') do code[#code+1]=rows[i];i=i+1 end
      add('<pre><code>'..escape(table.concat(code,'\n'))..'</code></pre>')
    elseif rows[i+1] and line:find('|',1,true) and rows[i+1]:match('^%s*|?%s*:?[%-]+') and rows[i+1]:find('|',1,true) then
      add('<table><thead>'..cells(line,'th')..'</thead><tbody>');i=i+2
      while rows[i] and rows[i]:find('|',1,true) and rows[i]~='' do add(cells(rows[i],'td'));i=i+1 end
      add('</tbody></table>');i=i-1
    elseif line:match('^#+%s') then
      local hashes,content=line:match('^(#+)%s+(.*)');local level=math.min(6,#hashes)
      add('<h'..level..'>'..inline(content)..'</h'..level..'>')
    elseif line:match('^%s*%-%-%-+%s*$') then add('<hr>')
    elseif line:match('^%s*>') then add('<blockquote>'..inline(line:gsub('^%s*>%s?',''))..'</blockquote>')
    elseif line:match('^%s*[%-%*%+]%s') or line:match('^%s*%d+%.%s') then
      local ordered=line:match('^%s*%d+%.%s')
      local tag=ordered and 'ol' or 'ul'
      add('<'..tag..'>')
      while i<=#rows do
        local content=rows[i]:match(ordered and '^%s*%d+%.%s+(.*)' or '^%s*[%-%*%+]%s+(.*)')
        if not content then break end
        local check,rest=content:match('^%[([ xX])%]%s+(.*)')
        add('<li>'..(check and '<input type="checkbox" disabled'..(check~=' ' and ' checked' or '')..'> '..inline(rest) or inline(content))..'</li>')
        i=i+1
      end
      add('</'..tag..'>');i=i-1
    elseif line:match('%S') then add('<p>'..inline(line)..'</p>') end
    i=i+1
  end
  return table.concat(out,'\n')
end
function M.document(text,filename)
  local base=''
  if filename then
    local dir=require('core.common').dirname(filename)..'/'
    local uri='file://'..dir:gsub('[^%w%-%._~/]',function(c) return string.format('%%%02X',c:byte()) end)
    base='<base href="'..escape(uri)..'">'
  end
  return '<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">'..base..'<title>Markdown export</title><style>body{font:16px/1.6 system-ui,sans-serif;max-width:850px;margin:40px auto;padding:0 24px;color:#222}pre,code{font-family:monospace;background:#f3f3f3}pre{padding:16px;overflow:auto}blockquote{border-left:3px solid #aaa;margin-left:0;padding-left:16px}table{border-collapse:collapse}td,th{border:1px solid #bbb;padding:6px 12px}img{max-width:100%}@media print{button{display:none}body{margin:0;max-width:none}pre{white-space:pre-wrap}}</style></head><body>'..M.render(text)..'</body></html>'
end
return M
