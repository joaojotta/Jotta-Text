local core=require 'core'
local visual=require 'litefront.visual'
local common=require 'core.common'
local M={}
local function docview()
  local view=visual.document_view()
  if view and view.doc.syntax and view.doc.syntax.name=='Markdown' then return view end
end
local function insert(text)
  local view=docview()
  if view then view.doc:text_input(text) end
end
local function lines(prefix)
  local view=docview()
  if not view then return end
  local doc=view.doc
  local changed={}
  for _,l1,c1,l2,c2 in doc:get_selections(true,true) do
    if l2>l1 and c2==1 then l2=l2-1 end
    for line=l2,l1,-1 do
      if not changed[line] then
        changed[line]=true
        local old=doc.lines[line]:gsub('\n$','')
        local value=type(prefix)=='function' and prefix(old,line-l1+1) or prefix..old
        doc:replace_cursor(1,line,1,line,#old+1,function() return value end)
      end
    end
  end
end
local function heading()
  local view=docview()
  if not view then return end
  core.command_view:enter('Heading level',{picker=true,typeahead=false,
    suggest=function() return {'Heading 1','Heading 2','Heading 3','Heading 4','Heading 5','Heading 6'} end,
    submit=function(_,item)
      if not item then return end
      core.set_active_view(view)
      local level=tonumber(item.text:match('%d'))
      lines(function(text) return string.rep('#',level)..' '..text:gsub('^#+%s+','') end)
    end,
  })
end
local function export(pdf)
  local view=docview()
  if not view then return end
  if JOTTA_WEB and pdf then
    return require('litefront.browser').print_markdown(view.doc)
  end
  -- Snapshot before showing the asynchronous destination dialog.
  local source=view.doc.abs_filename
  local html=require('litefront.markdown_html').document(table.concat(view.doc.lines),source,false)
  local extension=pdf and '.pdf' or '.html'
  require('plugins.litefront_files').dialog('save',source and common.dirname(source) or core.project_dir,
    source and common.basename(source):gsub('%.[^.]+$','')..extension or 'Untitled'..extension,function(path)
      if path==source then core.error('Choose a different path to preserve the Markdown source');return end
      local input=pdf and core.temp_filename('.html') or path
      local file,err=io.open(input,'w')
      if not file then core.error('Could not export Markdown: %s',err);return end
      local written,write_error=file:write(html)
      local closed,close_error=file:close()
      if not written or not closed then core.error('Could not export Markdown: %s',write_error or close_error);return end
      if not pdf then
        if JOTTA_WEB then require('litefront.browser').download(path) end
        core.log('Markdown exported: %s',path);return
      end
      local bundle=DATADIR..'/litefront'
      local ok,child=pcall(process.start,{require('litefront.runtime').node,bundle..'/markdown-pdf.mjs',input,path,source and common.dirname(source) or ''})
      if not ok then os.remove(input);core.error('Could not export PDF: %s',child);return end
      core.add_thread(function()
        local errors={}
        while child:running() do
          local message=child:read_stderr()
          if message and message~='' then errors[#errors+1]=message end
          coroutine.yield(0.05)
        end
        local message=child:read_stderr()
        if message then errors[#errors+1]=message end
        os.remove(input)
        if child:returncode()~=0 then core.error('Could not export PDF: %s',table.concat(errors))
        else core.log('Markdown PDF exported: %s',path) end
      end)
    end)
end
function M.actions(wrap)
  local result={}
  local function action(id,label,glyph,fn,width)
    result[#result+1]={name='litefront:md-'..id,label=label,glyph=glyph,icon=not id:match('^export%-') and 'md-'..id or nil,fn=fn,width=width}
  end
  action('heading','Heading','H',heading)
  action('bold','Bold','B',function() wrap('**','**','bold') end)
  action('italic','Italic','I',function() wrap('*','*','italic') end)
  action('underline','Underline','U',function() wrap('<u>','</u>','text') end)
  action('strike','Strikethrough','S̶',function() wrap('~~','~~','text') end)
  action('subscript','Subscript','X₂',function() wrap('<sub>','</sub>','text') end)
  action('superscript','Superscript','X²',function() wrap('<sup>','</sup>','text') end)
  action('link','Link','↗',function() wrap('[','](https://example.org)','text') end)
  action('image','Image','▧',function() wrap('![','](image.png)','alt text') end)
  action('code','Inline Code','<>',function() wrap('`','`','code') end)
  action('code-block','Code Block','‹›',function() wrap('\n```\n','\n```\n','code') end)
  action('quote','Blockquote','❞',function() lines('> ') end)
  action('list','Bullet List','≡',function() lines('- ') end)
  action('ordered-list','Numbered List','1.',function() lines(function(text,i) return i..'. '..text end) end)
  action('task-list','Task List','☑',function() lines('- [ ] ') end)
  action('rule','Horizontal Rule','—',function() insert('\n\n---\n\n') end)
  action('table','Table','▦',function() insert('\n| Heading | Heading |\n| --- | --- |\n| Cell | Cell |\n') end)
  action('braces','Braces','{}',function() wrap('{','}','text') end)
  action('preview','Markdown Preview','◉',function()
    if not docview() then core.error('Choose Markdown as the document language to preview it');return end
    require('core.command').perform('litemark:view current markdown')
  end)
  action('export-html','Export HTML','HTML',function() export(false) end,46)
  action('export-pdf','Export PDF','PDF',function() export(true) end,38)
  return result
end
return M
