local config=require 'core.config'
local pt=require 'litefront.locales.pt-PT'
local M={}
function M.language() return config.litefront and config.litefront.ui_language or 'en' end
function M.t(message,...)
  if type(message)~='string' then return message end
  local result=M.language()=='pt-PT' and (pt[message] or message) or message
  if select('#',...)>0 then return string.format(result,...) end
  return result
end
function M.install()
  if M.installed then return end
  M.installed=true
  local core=require 'core'
  local custom_log=core.custom_log
  function core.custom_log(level,show,backtrace,message,...)
    return custom_log(level,show,backtrace,M.t(message),...)
  end
  local CommandView=require 'core.commandview'
  local enter=CommandView.enter
  function CommandView:enter(prompt,...) return enter(self,M.t(prompt),...) end
  local StatusView=require 'core.statusview'
  local tooltip=StatusView.show_tooltip
  function StatusView:show_tooltip(value,...)
    if type(value)=='table' then
      local translated={};for i,part in ipairs(value) do translated[i]=M.t(part) end;value=translated
    else value=M.t(value) end
    return tooltip(self,value,...)
  end
  local command=require 'core.command';local prettify=command.prettify_name
  function command.prettify_name(...)
    local text=prettify(...);local category,label=text:match('^(.-): (.+)$')
    return category and M.t(category)..': '..M.t(label) or M.t(text)
  end
end
return M
