-- mod-version:3
local style=require 'core.style'
local function c(hex)
 return {tonumber(hex:sub(2,3),16),tonumber(hex:sub(4,5),16),tonumber(hex:sub(6,7),16),255}
end
style.background=c('#ffffff')
style.background2=c('#f5f5f6')
style.background3=c('#e9e9ed')
style.text=c('#27282d')
style.caret=c('#ffc107')
style.accent=c('#ffc107')
style.selection=c('#ffedb0')
style.line_highlight=c('#f0f0f2')
style.line_number=c('#a1a2a8')
style.line_number2=c('#27282d')
style.syntax['normal']=style.text
style.syntax.htmltag=c('#800000')
style.syntax.htmlattribute=c('#a31515')
style.syntax['comment']=c('#008000')
style.syntax['keyword']=c('#0000ff')
style.syntax['keyword2']=c('#267f99')
style.syntax['string']=c('#a31515')
style.syntax['number']=c('#098658')
style.syntax['function']=c('#795e26')
style.syntax['symbol']=c('#001080')
style.syntax['operator']=c('#27282d')

style.dim=c('#777983')
style.divider=c('#e1e2e5')
require('litefront.visual').theme_fonts('light')
