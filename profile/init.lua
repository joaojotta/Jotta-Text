-- Application-owned defaults. Loaded from the immutable Jotta Text bundle.
local core = require 'core'
local config = require 'core.config'
if core._litefront_initialized then return end
core._litefront_initialized = true
config.indent_size=2
config.tab_type='soft'
config.line_limit=100
config.max_project_files=50000
-- Dependency trees and generated output are not project source files.
for _,pattern in ipairs({'^vendor/','^dist/','^build/','^%.flatpak%-builder/','^%.venv/','^venv/','^coverage/','^%.next/','^%.nuxt/'}) do
  config.ignore_files[#config.ignore_files+1]=pattern
end
config.line_height=1.55
config.tab_close_button=true
config.plugins.workspace=false -- Document recovery is owned by Jotta Text.
config.plugins.treeview=false
config.plugins.toolbarview=false
config.plugins.minimap={width=92,draw_background=false,avoid_small_docs=false,highlight_width=0,gutter_width=3}
config.plugins.scale=false -- Independent UI/code font sizing is owned by Jotta Text.
config.plugins.lsp={mouse_hover=true,show_diagnostics=true,autostart_server=true}
config.plugins.autocomplete={min_len=2}
require('litefront.preferences').apply_config()
require('litefront.i18n').install()
core.reload_module('colors.litefront_'..require('litefront.visual').mode)
local bundle=DATADIR..'/litefront'
local tool=require('litefront.runtime').tool
require 'litefront.dialogs'
require 'plugins.language_html'
if JOTTA_WEB then
  config.plugins.lsp=false
  config.plugins.litefront_ycompletion=false
  require('litefront.browser').install()
  return
end
local lsp=require 'plugins.lsp'
lsp.add_server {
  name='litefront_typescript',
  language={
    {id='javascript',pattern='%.js$'}, {id='javascript',pattern='%.mjs$'},
    {id='javascript',pattern='%.cjs$'}, {id='javascriptreact',pattern='%.jsx$'},
    {id='typescript',pattern='%.ts$'}, {id='typescriptreact',pattern='%.tsx$'},
  },
  file_patterns={'%.js$','%.jsx$','%.ts$','%.tsx$','%.mjs$','%.cjs$'},
  command=tool('typescript-language-server','--stdio'),
}
local lspconfig=require 'plugins.lsp.config'
lspconfig.vscode_html_ls.setup {command=tool('vscode-html-language-server','--stdio'),
  init_options={embeddedLanguages={css=true,javascript=true}},
  settings={css={completion={completePropertyWithSemicolon=true,triggerPropertyValueCompletion=true}}},
  file_patterns={'%.[hH][tT][mM][lL]?$','%.[xX][hH][tT][mM][lL]$'}}
lspconfig.vscode_css_ls.setup {
  command=tool('vscode-css-language-server','--stdio'),
  settings={css={validate=true,lint={unknownProperties='warning'},completion={completePropertyWithSemicolon=true,triggerPropertyValueCompletion=true}}},
}
lspconfig.vscode_json_ls.setup {command=tool('vscode-json-language-server','--stdio')}
lsp.add_server {
  name='litefront_emmet',
  language={
    {id='html',pattern='%.[hH][tT][mM][lL]?$'}, {id='html',pattern='%.[xX][hH][tT][mM][lL]$'}, {id='css',pattern='%.css$'},
    {id='javascriptreact',pattern='%.jsx$'}, {id='typescriptreact',pattern='%.tsx$'},
  },
  file_patterns={'%.[hH][tT][mM][lL]?$','%.[xX][hH][tT][mM][lL]$','%.css$','%.jsx$','%.tsx$'},
  command=tool('emmet-language-server','--stdio'),
}
