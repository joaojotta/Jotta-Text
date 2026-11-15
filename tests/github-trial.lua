local command=require 'core.command'
local prefs=require 'litefront.preferences'
local function wait_for(predicate,message)
 local deadline=system.get_time()+12
 while system.get_time()<deadline do if predicate() then return end;coroutine.yield(.03) end
 error(message)
end
assert(not prefs.values.github_trial,'trial did not default to disabled or retain the disabled setting')
assert(not package.loaded['litefront.github.view'],'trial loaded before being enabled')
assert(not command.perform('litefront:github-trial'),'disabled trial command ran')
local function menu_has_trial()
 command.perform('litefront-menu:tools')
 local found=false
 for _,item in ipairs(require('plugins.litefront_shell').popup.items) do if item.command=='litefront:github-trial' then found=true end end
 command.perform('litefront-menu:close');return found
end
assert(not menu_has_trial(),'disabled trial remained in the Tools menu')
if os.getenv('GITHUB_TEST_PHASE')=='2' then return end
local settings=require 'litefront.settings'
settings.open();settings.select('general');settings.layout()
local toggle
for _,control in ipairs(settings.active.controls) do if control.id=='github_trial' then toggle=control end end
assert(toggle and toggle.kind=='toggle','General settings is missing the trial switch')
settings.activate(toggle);settings.apply();assert(prefs.values.github_trial)
assert(menu_has_trial(),'enabled trial did not appear in Tools')
local source=core.open_doc(core.project_dir..'/style.css');core.root_view:open_doc(source)
source:text_input('/* unsaved editor change */')
local buffer=table.concat(source.lines)
assert(command.perform('litefront:github-trial'))
local view=require 'litefront.github.view';local service=require 'litefront.github.service'
wait_for(function() return view.active and view.active.data and not service.job end,'Git status did not load')
assert(view.active.data.branch=='main' and view.active.data.fileCount==2,'wrong branch or file list')
view.draw()
core.on_event('mousewheel',.15,0);view.draw()
assert(view.active.scroll==math.floor(view.active.scroll),'fractional mouse wheel produced a fractional row index')
local function choose(name)
 for i,item in ipairs(view.active.data.files) do if item.path==name then view.active.selected=i;return end end
 error('Changed file missing: '..name)
end
choose('style.css');view.action('stage')
wait_for(function() return not service.job and view.active.data.stagedCount==1 end,'file did not stage')
-- Feed key/text/release events through core.step, so modal keyboard return values
-- cannot silently suppress filename/commit characters or edit the document.
view.active.focus='message'
local events={}
for char in ('Review saved changes'):gmatch('.') do
 events[#events+1]={'keypressed',char:lower()};events[#events+1]={'textinput',char};events[#events+1]={'keyreleased',char:lower()}
end
local poll=system.poll_event;local index=0
system.poll_event=function() index=index+1;local item=events[index];if item then return table.unpack(item) end end
core.step();system.poll_event=poll
assert(view.active.inputs.message.text=='Review saved changes','modal keyboard dropped commit-message characters')
assert(table.concat(source.lines)==buffer,'Git panel typing changed the source buffer')
local state=view.layout();local message
for _,control in ipairs(state.controls) do if control.id=='message' then message=control end end
view.click('left',message.x+8*SCALE,message.y+10*SCALE,1)
assert(state.inputs.message.caret==1,'mouse did not position the commit-message caret')
state.drag=nil
local commit
for _,control in ipairs(view.layout().controls) do if control.id=='commit' then commit=control end end
assert(not commit.disabled,'commit button stayed disabled after staging and typing')
view.click('left',commit.x+10*SCALE,commit.y+10*SCALE,1)
wait_for(function() return not service.job and view.active.data.stagedCount==0 end,'staged commit did not finish')
assert(table.concat(source.lines)==buffer and source:is_dirty(),'commit saved or rewrote the source buffer')
choose('new é.txt');view.action('diff')
wait_for(function() return not service.job and not view.active end,'diff snapshot did not open')
assert(core.active_view.doc and table.concat(core.active_view.doc.lines):find('+new source',1,true),'diff did not show untracked content')
assert(not core.active_view.doc.filename,'diff snapshot acquired a real filename')
assert(command.perform('litefront:github-trial'))
wait_for(function() return view.active and view.active.data and not service.job end,'trial did not reopen')
view.action('clone');assert(view.active.mode=='clone');view.draw();view.action('back')
prefs.values.ui_language='pt-PT';prefs.apply_config()
local texts={};local draw=renderer.draw_text
renderer.draw_text=function(font,text,...) texts[text]=true;return draw(font,text,...) end
view.draw();renderer.draw_text=draw
assert(texts['Teste do GitHub'],'trial title is not localized')
view.close();prefs.values.ui_language='en';prefs.apply_config()
settings.open();settings.select('general');settings.layout()
for _,control in ipairs(settings.active.controls) do if control.id=='github_trial' then settings.activate(control);break end end
settings.apply();assert(not prefs.values.github_trial and not command.perform('litefront:github-trial'),'trial did not disable immediately')
assert(not menu_has_trial(),'disabled trial remained in the Tools menu')
