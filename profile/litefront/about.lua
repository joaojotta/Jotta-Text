-- Branded About card; uses the application's modal queue and input handling.
local T=require('litefront.i18n').t
local core=require 'core'
local style=require 'core.style'
local visual=require 'litefront.visual'
local M={}
function M.details()
  return 'Jotta Text v'..APP_VERSION..'\n'..T('A focused editor for code, Markdown and web projects.')..'\n'..
    T('Built on Lite XL %s',VERSION)..'\n'..T('Platform: %s (%s)',PLATFORM,ARCH)..'\n'..
    T('Interface inspired by Jotta Edit.')..'\n'..T('Typography: Rubik and JetBrains Mono.')
end
function M.draw(item,root)
  local pad=24*SCALE
  local w=math.max(1,math.min(520*SCALE,root.size.x-24*SCALE))
  local h=math.max(1,math.min(590*SCALE,root.size.y-24*SCALE))
  local x,y=(root.size.x-w)/2,(root.size.y-h)/2
  local lh=style.font:get_height()+8*SCALE
  local small=style.small_font:get_height()+6*SCALE
  if not M.heading or M.base_font~=style.bold_font or M.scale~=SCALE then
    M.base_font=style.bold_font;M.scale=SCALE
    M.heading=style.bold_font:copy(math.max(28*SCALE,style.bold_font:get_size()*1.6))
  end
  renderer.draw_rect(0,0,root.size.x,root.size.y,{0,0,0,145})
  visual.rounded(x-6*SCALE,y+8*SCALE,w+12*SCALE,h+8*SCALE,16*SCALE,{0,0,0,55})
  visual.rounded(x-1,y-1,w+2,h+2,13*SCALE,style.divider)
  visual.rounded(x,y,w,h,12*SCALE,style.background2)
  local top=y+36*SCALE;local available=math.max(1,h-112*SCALE)
  local content=192*SCALE+M.heading:get_height()+lh*2+small*5
  item.max_offset=math.max(0,math.ceil((content-available)/(32*SCALE)))
  item.offset=math.min(item.offset,item.max_offset)
  core.push_clip_rect(x+pad,top,w-pad*2,available)
  local cy=top-item.offset*32*SCALE
  local function text(font,label,height,color)
    visual.text(font,T(label),x+pad,cy,w-pad*2,height,color or style.text,'center');cy=cy+height
  end
  visual.rounded(x+w/2-48*SCALE,cy,96*SCALE,96*SCALE,22*SCALE,style.background3)
  visual.logo(x+w/2-36*SCALE,cy+12*SCALE,72*SCALE);cy=cy+112*SCALE
  text(M.heading,'Jotta Text',M.heading:get_height()+8*SCALE)
  local badge=T('Version %s',APP_VERSION)
  local bw=style.small_font:get_width(badge)+28*SCALE
  visual.rounded(x+(w-bw)/2,cy+4*SCALE,bw,small+8*SCALE,(small+8*SCALE)/2,style.accent)
  visual.text(style.small_font,badge,x+(w-bw)/2,cy+4*SCALE,bw,small+8*SCALE,style.accent_text,'center')
  cy=cy+small+28*SCALE
  text(style.font,'A focused editor for code,',lh,style.text)
  text(style.font,'Markdown and web projects.',lh,style.text)
  cy=cy+16*SCALE
  renderer.draw_rect(x+pad+20*SCALE,cy,w-2*pad-40*SCALE,1,style.divider);cy=cy+16*SCALE
  text(style.small_font,T('Built on Lite XL %s',VERSION),small,style.dim)
  text(style.small_font,PLATFORM..' · '..ARCH,small,style.dim)
  cy=cy+12*SCALE
  text(style.small_font,'Interface inspired by Jotta Edit',small,style.dim)
  text(style.small_font,'Rubik UI · JetBrains Mono editor',small,style.dim)
  core.pop_clip_rect()
  if item.max_offset>0 then
    local th=math.max(24*SCALE,available*available/content)
    local ty=top+(available-th)*item.offset/item.max_offset
    visual.rounded(x+w-10*SCALE,ty,4*SCALE,th,2*SCALE,style.dim)
  end
  renderer.draw_rect(x+pad,y+h-62*SCALE,w-2*pad,1,style.divider)
  item.buttons={}
  local by=y+h-48*SCALE;local close_w=math.min(88*SCALE,w*.3)
  local copy_w=math.min(140*SCALE,w*.45)
  for i,b in ipairs({{x=x+pad,w=copy_w},{x=x+w-pad-close_w,w=close_w}}) do
    local selected=i==item.selected
    if selected then visual.rounded(b.x-2*SCALE,by-2*SCALE,b.w+4*SCALE,36*SCALE,8*SCALE,style.accent) end
    visual.rounded(b.x,by,b.w,32*SCALE,6*SCALE,i==2 and style.accent or style.background3)
    visual.text(style.font,T(i==1 and item.copied and 'Copied!' or item.options[i].text),b.x,by,b.w,32*SCALE,i==2 and style.accent_text or style.text,'center')
    item.buttons[i]={x=b.x,y=by,w=b.w,h=32*SCALE}
  end
end
return M
