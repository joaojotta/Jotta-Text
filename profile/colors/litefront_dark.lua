-- mod-version:3
local style = require 'core.style'
local function c(hex)
  return {tonumber(hex:sub(2,3),16),tonumber(hex:sub(4,5),16),tonumber(hex:sub(6,7),16),255}
end
style.background=c('#1f2023')
style.background2=c('#242529')
style.background3=c('#303137')
style.text=c('#d8d8df')
style.caret=c('#ffc107')
style.accent=c('#ffc107')
style.selection=c('#484229')
style.line_highlight=c('#292a2e')
style.line_number=c('#666873')
style.line_number2=c('#d8d8df')
style.syntax['normal']=style.text
style.syntax.htmltag=c('#569cd6')
style.syntax.htmlattribute=c('#9cdcfe')
style.syntax['comment']=c('#6a9955')
style.syntax['keyword']=c('#569cd6')
style.syntax['keyword2']=c('#4ec9b0')
style.syntax['string']=c('#ce9178')
style.syntax['number']=c('#b5cea8')
style.syntax['function']=c('#dcdcaa')
style.syntax['symbol']=c('#9cdcfe')
style.syntax['operator']=c('#d8d8df')

style.dim=c('#8b8d96')
style.divider=c('#35363b')
require('litefront.visual').theme_fonts('dark')
