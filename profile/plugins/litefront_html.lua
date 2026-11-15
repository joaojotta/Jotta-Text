-- mod-version:3
-- Expand the HTML starter without waiting for a language-server response.
local core=require 'core'
local command=require 'core.command'
local keymap=require 'core.keymap'
local DocView=require 'core.docview'
local autocomplete=require 'plugins.autocomplete'
local snippets=require 'plugins.snippets'

local template=[[<!DOCTYPE html>
<html lang="${1:en}">
<head>
	<meta charset="UTF-8">
	<meta name="viewport" content="width=device-width, initial-scale=1.0">
	<title>${2:Document}</title>
</head>
<body>
	$0
</body>
</html>]]

local function can_expand()
  local view=core.active_view
  if not view:extends(DocView) then return false end
  local doc=view.doc
  if doc.syntax.name~='HTML' or #doc.selections~=4 then return false end
  local line,col,last_line,last_col=doc:get_selection()
  if line~=last_line or col~=last_col then return false end
  if not doc:get_text(line,1,line,col):match('^%s*!$') then return false end
  return true,doc,line,col
end

command.add(can_expand,{
  ['litefront:expand-html-template']=function(doc,line,col)
    autocomplete.close()
    doc:set_selection(line,col-1,line,col)
    local kind,size=doc:get_indent_info()
    local indent=kind=='hard' and '\t' or string.rep(' ',size)
    snippets.execute({format='lsp',template=template:gsub('\t',indent)},doc)
  end,
})
-- Keep HTML starter expansion first, then accept an open completion popup.
-- Closed popups fall through to snippet navigation, indentation and newlines.
keymap.add {
  ['tab']={'litefront:expand-html-template','autocomplete:complete'},
  ['return']='autocomplete:complete',
  ['keypad enter']='autocomplete:complete',
}
