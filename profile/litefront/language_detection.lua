-- Content hints use a bounded sample; strings/comments are masked for code tests.
local M={}
local function code_only(text)
  -- Preserve newlines and byte positions, but never inspect markers inside strings.
  local out={};local i=1
  local function blank(value) return (value:gsub('[^\n]',' ')) end
  while i<=#text do
    local c=text:sub(i,i);local pair=text:sub(i,i+1)
    if c=='"' or c=="'" or c=='`' then
      local j=i+1
      while j<=#text do
        if text:sub(j,j)=='\\' then j=j+2
        elseif text:sub(j,j)==c then j=j+1;break else j=j+1 end
      end
      out[#out+1]=blank(text:sub(i,j-1));i=j
    elseif pair=='//' or pair=='--' then
      local j=text:find('\n',i+2,true) or #text+1;out[#out+1]=blank(text:sub(i,j-1));i=j
    elseif pair=='/*' then
      local j=text:find('*/',i+2,true);j=j and j+2 or #text+1
      out[#out+1]=blank(text:sub(i,j-1));i=j
    else out[#out+1]=c;i=i+1 end
  end
  return table.concat(out)
end
function M.filename(text)
  local head=text:sub(1,8192):gsub('^\239\187\191','')
  local lower=head:lower();local code=code_only(head)
  if code:lower():find('<%?php[%s]') or code:find('<%?=') then return 'document.php' end
  if lower:match('^%s*<%?xml') then return 'document.xml' end
  if lower:match('^%s*<!doctype%s+html[%s>]') or lower:match('^%s*<html[%s>]')
    or lower:match('^%s*</?[%a][%w:-]*[^>]*>') or lower:match('^%s*<!%-%-') then return 'document.html' end
  -- Recognize a JSON prefix even when the complete document exceeds the sample.
  if head:match('^%s*{%s*"[^"\n]+"%s*:') or head:match('^%s*%[%s*[%[{"]')
    or head:match('^%s*%[%s*%-?%d') or head:match('^%s*%[%s*true') or head:match('^%s*%[%s*false')
    or head:match('^%s*%[%s*null') or head:match('^%s*%[%s*%]') or head:match('^%s*{%s*}') then return 'document.json' end
  if head:match('^%s*#![^\n]*python') or code:match('^%s*def%s+[%w_]+%s*%(')
    or code:match('^%s*from%s+[%w_.]+%s+import%s') or code:match('^%s*import%s+[%w_.]+%s*\n') then return 'document.py' end
  if head:match('^%s*#![^\n]*sh') then return 'document.sh' end
  if code:match('^%s*local%s+[%w_]+%s*=') or code:match('^%s*local%s+function%s') then return 'document.lua' end
  if code:match('^%s*interface%s+[%w_]+%s*{') or code:match('^%s*type%s+[%w_]+%s*=')
    or code:match('^%s*export%s+interface%s')
    or code:match('^%s*const%s+[%w_$]+%s*:%s*[%w_%[{]')
    or code:match('^%s*let%s+[%w_$]+%s*:%s*[%w_%[{]')
    or code:match('^%s*var%s+[%w_$]+%s*:%s*[%w_%[{]')
    or code:match('%([%w_$]+%s*:%s*[%w_%[%]]+') then return 'document.ts' end
  if code:match('^%s*const%s+[%w_$]+') or code:match('^%s*let%s+[%w_$]+')
    or code:match('^%s*var%s+[%w_$]+') or code:match('^%s*function%s+[%w_$]*%s*%(')
    or code:match('^%s*import%s+') or code:match('^%s*export%s+') then return 'document.js' end
  -- A CSS selector is one token (or a selector list/pseudo selector), not prose.
  local selector=code:match('^%s*([^{}]+){%s*[%w_%-]+%s*:%s*[^{}]+[;}]')
  if selector then
    selector=selector:match('^%s*(.-)%s*$')
    if selector:match('^[a-z][a-z0-9_%-]*$') or selector=='*' or selector:find('[.#:%[%]>+~,]') then return 'document.css' end
  end
  if code:match('^%s*@[%w%-]+%s+[^;{]+[;{]') then return 'document.css' end
  if head:match('^%s*#+%s+%S') or head:match('^%s*```[%w]*\n') then return 'document.md' end
end
return M
