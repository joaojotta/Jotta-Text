-- CSS properties/custom properties and HTML attributes include hyphens.
local M={}
function M.partial(doc,line,col,fallback)
  local name=doc.syntax and doc.syntax.name:lower()
  if name~='css' and name~='scss' and name~='sass' and name~='less' and name~='html' then return fallback end
  local prefix=doc.lines[line]:sub(1,col-1)
  local word=prefix:match('[%w_%-]+$')
  if not word or not word:find('-',1,true) then return fallback end
  if name=='html' then
    -- Preserve subtraction/word boundaries in embedded script code. The
    -- highlighter supplies the incoming state; tokenize only up to the caret.
    local tokenizer=require 'core.tokenizer'
    local incoming=doc.highlighter:get_line(line).init_state or ''
    local _,state=tokenizer.tokenize(doc.syntax,prefix,incoming)
    local current=tokenizer.extract_subsyntaxes(doc.syntax,state)[1]
    if current.name~='CSS' and current.name~='HTML' then return fallback end
  end
  return word
end
return M
