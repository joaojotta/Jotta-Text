-- Explicit runtime paths work without npm command shims on every desktop OS.
local M={}
M.node=DATADIR..'/litefront/node/node'..(PLATFORM=='Windows' and '.exe' or '')
M.dialog=EXEDIR..'/litefront-file-dialog'..(PLATFORM=='Windows' and '.exe' or '')
local entries={
  ['typescript-language-server']='typescript-language-server/lib/cli.mjs',
  ['vscode-html-language-server']='vscode-langservers-extracted/bin/vscode-html-language-server',
  ['vscode-css-language-server']='vscode-langservers-extracted/bin/vscode-css-language-server',
  ['vscode-json-language-server']='vscode-langservers-extracted/bin/vscode-json-language-server',
  ['emmet-language-server']='@olrtg/emmet-language-server/dist/index.js',
}
function M.tool(name,...)
  return {M.node,DATADIR..'/litefront/tooling/node_modules/'..assert(entries[name],'Unknown bundled tool'),...}
end
return M
