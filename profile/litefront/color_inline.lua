local core=require 'core'
local common=require 'core.common'
local style=require 'core.style'
local colors=require 'litefront.colors'
local DocView=require 'core.docview'
local wrapping=require 'plugins.linewrapping'
local M={}
local cache=setmetatable({},{__mode='k'})
local extensions={css=true,scss=true,sass=true,less=true,html=true,htm=true,xhtml=true,php=true,js=true,mjs=true,cjs=true,jsx=true,ts=true,tsx=true,json=true,jsonc=true,vue=true,svelte=true}
function M.hits(doc,line)
  if require('core.config').litefront and not require('core.config').litefront.color_swatches then return {} end
  local filename=doc.abs_filename
  local language=doc.syntax and doc.syntax.name:lower() or ''
  if filename and not extensions[filename:lower():match('%.([^./]+)$')] and not ({css=true,html=true,javascript=true,typescript=true,json=true,php=true,scss=true,sass=true,less=true})[language] then return {} end
  local text=doc.lines[line]
  if not text then return {} end
  local lines=cache[doc];if not lines then lines={};cache[doc]=lines end
  if not lines[line] or lines[line].text~=text then lines[line]={text=text,hits=colors.find(text)} end
  return lines[line].hits
end
function M.gap(font) return math.floor(font:get_height()*.8)+6*SCALE end
function M.swatch(x,y,size,color)
  renderer.draw_rect(x-1,y-1,size+2,size+2,style.divider)
  local tile=math.max(2,math.floor(size/3))
  for row=0,math.ceil(size/tile)-1 do for col=0,math.ceil(size/tile)-1 do
    renderer.draw_rect(x+col*tile,y+row*tile,math.min(tile,size-col*tile),math.min(tile,size-row*tile),(row+col)%2==0 and {220,220,220,255} or {150,150,150,255})
  end end
  renderer.draw_rect(x,y,size,size,colors.rgba(color))
end
local function eligible(view) return view~=core.command_view and view:extends(DocView) end
local function segment(view,line,col,line_end)
  local start,finish,indent=1,#view.doc.lines[line],0
  if view.wrapped_settings then
    local idx=view.wrapped_line_to_idx[line]
    if idx then
      while view.wrapped_lines[idx*2+1]==line and (view.wrapped_lines[idx*2+2]<col or (not line_end and view.wrapped_lines[idx*2+2]==col)) do idx=idx+1 end
      start=view.wrapped_lines[idx*2]
      if view.wrapped_lines[idx*2+1]==line then finish=view.wrapped_lines[idx*2+2] end
      if start>1 then indent=view.wrapped_line_offsets[line] or 0 end
    end
  end
  return start,finish,indent
end
local function glyphs(view,line,start,finish,callback)
  local position=1
  local _,tab=view.doc:get_indent_info()
  for _,kind,text in view.doc.highlighter:each_token(line) do
    local font=style.syntax_fonts[kind] or view:get_font();font:set_tab_size(tab)
    if position+#text>start and position<finish then
      for char in common.utf8_chars(text) do
        if position>=start and position<finish then if callback(position,char,font,style.syntax[kind] or style.text)==false then return end end
        position=position+#char
      end
    else position=position+#text end
    if position>=finish then return end
  end
end
local old_col=DocView.get_col_x_offset
function DocView:get_col_x_offset(line,col,line_end)
  local offset=old_col(self,line,col,line_end)
  if not eligible(self) then return offset end
  local start,finish=segment(self,line,col,line_end)
  for _,hit in ipairs(M.hits(self.doc,line)) do
    if hit.start>=start and hit.start<finish and (hit.start<col or (hit.start==col and not line_end)) then offset=offset+M.gap(self:get_font()) end
  end
  return offset
end
local function column(view,line,x,start,finish,indent)
  local cursor=indent or 0
  local by_col={}
  for _,hit in ipairs(M.hits(view.doc,line)) do by_col[hit.start]=true end
  local answer=finish
  glyphs(view,line,start,finish,function(col,char,font)
    if by_col[col] then
      local gap=M.gap(view:get_font())
      if x<cursor+gap then answer=col;return false end
      cursor=cursor+gap
    end
    local width=font:get_width(char)
    if x<cursor+width/2 then answer=col;return false end
    cursor=cursor+width
  end)
  return answer
end
local old_inverse=DocView.get_x_offset_col
function DocView:get_x_offset_col(line,x)
  if not eligible(self) or #M.hits(self.doc,line)==0 then return old_inverse(self,line,x) end
  local first,last,indent=segment(self,line,1)
  return column(self,line,x,first,last,indent)
end
local old_resolve=DocView.resolve_screen_position
function DocView:resolve_screen_position(x,y)
  if not self.wrapped_settings or not eligible(self) then return old_resolve(self,x,y) end
  local ox,oy=self:get_line_screen_position(1)
  local idx=math.max(1,math.min(#self.wrapped_lines/2,math.floor((y-oy)/self:get_line_height())+1))
  local line,start=self.wrapped_lines[idx*2-1],self.wrapped_lines[idx*2]
  if #M.hits(self.doc,line)==0 then return old_resolve(self,x,y) end
  local first,last,indent=segment(self,line,start)
  return line,column(self,line,x-ox,first,last,indent)
end
function M.rect(view,line,hit)
  local x,y=view:get_line_screen_position(line,hit.start)
  local gap=M.gap(view:get_font());local size=gap-6*SCALE
  return {x=x-gap+2*SCALE,y=y+(view:get_line_height()-size)/2,w=size,h=size,hit=hit,line=line}
end
-- Hit-test both the decoration and its source value for hover suppression.
function M.at(view,x,y)
  if not eligible(view) or x<view.position.x or x>=view.position.x+view.size.x
    or y<view.position.y or y>=view.position.y+view.size.y then return end
  local line,col=view:resolve_screen_position(x,y)
  for _,hit in ipairs(M.hits(view.doc,line)) do
    local r=M.rect(view,line,hit)
    if (x>=r.x-2*SCALE and x<r.x+r.w+2*SCALE and y>=r.y and y<r.y+r.h)
      or (col>=hit.start and col<hit.finish) then return hit,line end
  end
end
local old_draw=DocView.draw_line_text
function DocView:draw_line_text(line,x,y)
  local hits=eligible(self) and M.hits(self.doc,line) or {}
  if #hits==0 then return old_draw(self,line,x,y) end
  local starts={[1]=true};local count=0;local columns={}
  if self.wrapped_settings then
    local idx=self.wrapped_line_to_idx[line]
    while idx and self.wrapped_lines[idx*2-1]==line do
      local col=self.wrapped_lines[idx*2];starts[col]=true;columns[#columns+1]=col;count=count+1;idx=idx+1
    end
  end
  local first,last,first_row=1,#self.doc.lines[line],1
  if count>0 then
    first_row=math.max(1,math.min(count,math.floor((self.position.y-y)/self:get_line_height())+1))
    local final_row=math.max(first_row,math.min(count,math.ceil((self.position.y+self.size.y-y)/self:get_line_height())+1))
    first=columns[first_row];last=columns[final_row+1] or last
  end
  local by_col={};for _,hit in ipairs(hits) do by_col[hit.start]=hit end
  local tx=x+(first_row>1 and (self.wrapped_line_offsets[line] or 0) or 0)
  local ty=y+self:get_line_text_y_offset()+(first_row-1)*self:get_line_height()
  glyphs(self,line,first,last,function(col,char,font,color)
    if not self.wrapped_settings and tx>self.position.x+self.size.x then return false end
    if col>first and starts[col] then tx=x+(self.wrapped_line_offsets[line] or 0);ty=ty+self:get_line_height() end
    if by_col[col] then
      local rect=M.rect(self,line,by_col[col]);M.swatch(rect.x,rect.y,rect.w,by_col[col].color)
      tx=tx+M.gap(self:get_font())
    end
    tx=renderer.draw_text(font,char,tx,ty,color)
  end)
  return self:get_line_height()*math.max(1,count)
end
local old_breaks=wrapping.compute_line_breaks
function wrapping.compute_line_breaks(doc,font,line,width,mode)
  local hits=M.hits(doc,line)
  if #hits==0 then return old_breaks(doc,font,line,width,mode) end
  local by_col={};for _,hit in ipairs(hits) do by_col[hit.start]=true end
  local splits={1};local x,position,space,last_width=0,1,nil,0
  local leading=doc.lines[line]:match('^%s+') or ''
  local indent=require('core.config').plugins.linewrapping.indent and font:get_width(leading) or 0
  for char in common.utf8_chars(doc.lines[line]) do
    local w=font:get_width(char)+(by_col[position] and M.gap(font) or 0)
    x=x+w
    if x>width then
      if mode=='word' and space then splits[#splits+1]=space+1;x=w+indent+(x-last_width)
      elseif position>splits[#splits] then splits[#splits+1]=position;x=w+indent end
      space=nil
    elseif char==' ' then space=position;last_width=x end
    position=position+#char
  end
  return splits,indent
end
M.segment=segment;M.column=column
return M
