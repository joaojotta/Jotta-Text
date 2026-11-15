-- CSS color parsing/conversion adapted from Jotta Edit; see assets/NOTICE.md.
local M={}
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function round(v) return math.floor(v+.5) end
M.clamp=clamp
function M.hsl(h,s,l,a)
  h=(h%360)/60;s=clamp(s,0,100)/100;l=clamp(l,0,100)/100
  local c=(1-math.abs(2*l-1))*s;local x=c*(1-math.abs(h%2-1));local m=l-c/2
  local r,g,b
  if h<1 then r,g,b=c,x,0 elseif h<2 then r,g,b=x,c,0 elseif h<3 then r,g,b=0,c,x
  elseif h<4 then r,g,b=0,x,c elseif h<5 then r,g,b=x,0,c else r,g,b=c,0,x end
  return {r=round((r+m)*255),g=round((g+m)*255),b=round((b+m)*255),a=a or 1,kind='hsl'}
end
function M.to_hsl(c)
  local r,g,b=c.r/255,c.g/255,c.b/255
  local high,low=math.max(r,g,b),math.min(r,g,b);local d=high-low;local l=(high+low)/2
  local h,s=0,0
  if d>0 then
    s=d/(1-math.abs(2*l-1))
    if high==r then h=((g-b)/d)%6 elseif high==g then h=(b-r)/d+2 else h=(r-g)/d+4 end
    h=(h*60)%360
  end
  return {h=round(h),s=round(s*100),l=round(l*100)}
end
function M.to_cmyk(c)
  local k=1-math.max(c.r,c.g,c.b)/255
  if k>=1-1e-9 then return {c=0,m=0,y=0,k=100} end
  return {c=round((1-c.r/255-k)/(1-k)*100),m=round((1-c.g/255-k)/(1-k)*100),y=round((1-c.b/255-k)/(1-k)*100),k=round(k*100)}
end
function M.cmyk(c,m,y,k,a)
  return {r=round(255*(1-clamp(c,0,100)/100)*(1-clamp(k,0,100)/100)),
    g=round(255*(1-clamp(m,0,100)/100)*(1-clamp(k,0,100)/100)),
    b=round(255*(1-clamp(y,0,100)/100)*(1-clamp(k,0,100)/100)),a=a or 1,kind='hex'}
end
function M.parse(text)
  if type(text)~='string' then return end
  text=text:match('^%s*(.-)%s*$')
  local hex=text:match('^#(%x+)$')
  if hex then
    if #hex~=3 and #hex~=4 and #hex~=6 and #hex~=8 then return end
    if #hex<=4 then hex=hex:gsub('.',function(c) return c..c end) end
    return {r=tonumber(hex:sub(1,2),16),g=tonumber(hex:sub(3,4),16),b=tonumber(hex:sub(5,6),16),a=#hex==8 and tonumber(hex:sub(7,8),16)/255 or 1,kind='hex'}
  end
  local name,args=text:lower():match('^(%a+)%((.-)%)$')
  if name~='rgb' and name~='rgba' and name~='hsl' and name~='hsla' then return end
  local values={}
  if args:find(',',1,true) then
    if args:find('/',1,true) then return end
    for value in (args..','):gmatch('(.-),') do
      value=value:match('^%s*(.-)%s*$');if value=='' then return end
      values[#values+1]=value
    end
  else
    if select(2,args:gsub('/',''))>1 then return end
    args=args:gsub('%s*/%s*',' / ')
    local slash
    for value in args:gmatch('%S+') do
      if value=='/' then if #values~=3 then return end;slash=true
      else if #values>=3 and not slash then return end;values[#values+1]=value end
    end
    if slash and #values~=4 then return end
  end
  if #values<3 or #values>4 then return end
  local alpha=1
  if values[4] then
    local percent=values[4]:match('^(.-)%%$');alpha=tonumber(percent or values[4]);if percent and alpha then alpha=alpha/100 end
    if not alpha or alpha<0 or alpha>1 then return end
  end
  if name:sub(1,3)=='rgb' then
    local rgb={}
    for i=1,3 do
      local percent=values[i]:match('^(.-)%%$');local value=tonumber(percent or values[i])
      if not value or value<0 or value>(percent and 100 or 255) then return end
      rgb[i]=round(percent and value*255/100 or value)
    end
    return {r=rgb[1],g=rgb[2],b=rgb[3],a=alpha,kind='rgba'}
  end
  local hue=tonumber((values[1]:gsub('deg$','')))
  local sat=tonumber(values[2]:match('^(.-)%%$'));local light=tonumber(values[3]:match('^(.-)%%$'))
  if not hue or hue==math.huge or hue==-math.huge or not sat or not light or sat<0 or sat>100 or light<0 or light>100 then return end
  return M.hsl(hue,sat,light,alpha)
end
local function decimal(v) return tostring(round(v*100)/100):gsub('%.0$','') end
function M.format(c,kind)
  local a=clamp(c.a or 1,0,1)
  if kind=='rgba' then return string.format('rgba(%d, %d, %d, %s)',round(c.r),round(c.g),round(c.b),decimal(a)) end
  if kind=='hsl' then
    local h=M.to_hsl(c)
    return string.format('%s(%d, %d%%, %d%%%s)',a<1 and 'hsla' or 'hsl',h.h,h.s,h.l,a<1 and ', '..decimal(a) or '')
  end
  return string.format('#%02x%02x%02x%s',round(c.r),round(c.g),round(c.b),a<1 and string.format('%02x',round(a*255)) or '')
end
function M.rgba(c) return {c.r,c.g,c.b,round((c.a or 1)*255)} end
function M.find(text)
  local hits={};local position=1
  while position<=#text and #hits<350 do
    local hs,he=text:find('#%x+',position)
    local fs,fe,name=text:find('(%a+)%(',position)
    while fs and name:lower()~='rgb' and name:lower()~='rgba' and name:lower()~='hsl' and name:lower()~='hsla' do fs,fe,name=text:find('(%a+)%(',fe+1) end
    local first,last
    if hs and (not fs or hs<fs) then first,last=hs,he
    elseif fs then
      first=fs;last=text:find(')',fe+1,true)
      if not last or last-fe>100 then position=fe+1;first=nil end
    else break end
    if first then
      local value=text:sub(first,last)
      local color=M.parse(value)
      local preceding=text:sub(first-1,first-1)
      local following=text:sub(last+1,last+1)
      if color and not following:match('[%w_]') and (value:sub(1,1)=='#' or not preceding:match('[%w_]')) then
        hits[#hits+1]={start=first,finish=last+1,text=value,color=color}
      end
      position=last+1
    end
  end
  return hits
end
M.presets={'#ffc107','#ff9800','#f44336','#ec4899','#9333ea','#6366f1','#2196f3','#06b6d4','#10b981','#84cc16','#ffffff','#d1d5db','#9ca3af','#6b7280','#4b5563','#374151','#1f2937','#111827','#60a5fa','#fca5a5'}
return M
