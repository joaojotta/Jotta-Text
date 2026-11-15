#!/usr/bin/env python3
"""Assemble the immutable application data, disabling third-party extension loading."""
import argparse
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEPS = ROOT / 'vendor/litefront'
IGNORE = shutil.ignore_patterns('.git', '__pycache__', 'screenshots', 'node_modules')

def copy(source, dest):
    source, dest = Path(source), Path(dest)
    if source.is_dir():
        shutil.copytree(source, dest, dirs_exist_ok=True, ignore=IGNORE)
    else:
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, dest)

def replace(path, before, after):
    text = path.read_text()
    if before not in text:
        raise RuntimeError(f'Upstream source changed; expected patch missing in {path}')
    path.write_text(text.replace(before, after))

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('destination', type=Path)
    parser.add_argument('--target', choices=['linux','windows','web'], default='linux')
    args = parser.parse_args()
    data = args.destination.resolve()
    if data.name not in ('lite-xl', 'app-data', 'data') or data == ROOT or ROOT in data.parents and data.relative_to(ROOT).parts[0] not in ('dist',):
        raise SystemExit('Bundle destination must be inside dist/ or outside the source tree')
    if data.exists():
        shutil.rmtree(data)
    copy(ROOT / 'vendor/lite-xl/data', data)
    replace(data / 'core/start.lua', '@PROJECT_VERSION@', '2.1.7')
    version=(ROOT / 'VERSION').read_text().strip()
    if not re.fullmatch(r'\d+\.\d+(?:\.\d+)?',version):
        raise RuntimeError('Invalid application version')
    start=data / 'core/start.lua'
    start.write_text(start.read_text()+f'\nAPP_NAME = \"Jotta Text\"\nAPP_VERSION = \"{version}\"\n')
    # User directories store sessions only. Neither Lua nor native modules are searched there.
    start = data / 'core/start.lua'
    text = start.read_text()
    text = text.replace("package.path = USERDIR .. '/?.lua;' .. package.path", '')
    text = text.replace("package.path = USERDIR .. '/?/init.lua;' .. package.path", '')
    begin = text.index('package.cpath =')
    end = text.index('\npackage.native_plugins', begin)
    text = text[:begin] + "package.cpath = DATADIR .. '/?.' .. suffix .. ';' .. DATADIR .. '/?/init.' .. suffix .. ';'\n" + text[end:]
    start.write_text(text)
    core = data / 'core/init.lua'
    text = core.read_text()
    begin = text.index('function core.load_user_directory()')
    end = text.index('function core.remove_project_directory', begin)
    text = text[:begin] + """function core.load_user_directory()
  return core.try(function()
    common.mkdirp(USERDIR)
    dofile(DATADIR .. '/litefront/init.lua')
  end)
end


""" + text[end:]
    begin = text.index('function core.load_project_module()')
    end = text.index('function core.reload_module', begin)
    text = text[:begin] + """function core.load_project_module()
  return true
end


""" + text[end:]
    text = text.replace('ipairs {DATADIR, USERDIR}', 'ipairs {DATADIR}')
    text = text.replace('and "Lite XL" or title .. " - Lite XL"', 'and "Jotta Text" or title .. " - Jotta Text"')
    text = text.replace('  local project_dir = core.recent_projects[1] or "."', """  -- A plain application launch shows welcome without indexing cwd or recents.
  core.litefront_no_project = true
  core.project_files = {}
  local project_dir = USERDIR .. '/empty-workspace'
  local workspace_info = system.get_file_info(project_dir)
  if workspace_info then
    assert(workspace_info.type == 'dir', 'Startup workspace is not a directory: ' .. project_dir)
  else
    assert(common.mkdirp(project_dir))
  end""")
    text = text.replace('      project_dir_explicit = true',
                        '      project_dir_explicit = true\n      core.litefront_no_project = false')
    text = text.replace('    core.root_view:close_all_docviews()\n    reload_customizations()',
                        '    core.litefront_no_project = false\n    core.root_view:close_all_docviews()\n    reload_customizations()')
    text = text.replace('  core.add_project_directory(project_dir_abs)\n',
                        '  if not core.litefront_no_project then core.add_project_directory(project_dir_abs) end\n')
    begin = text.index('  -- We assume we have just a single project directory here.')
    end = text.index('  for _, filename in ipairs(files) do', begin)
    # add_project_directory already reports incomplete indexing; do not warn a second time.
    text = text[:begin] + text[end:]
    text = text.replace('    core.log("Opening project %q from directory %s", pname, pdir)', """    if core.litefront_no_project then
      core.log_quiet('Jotta Text ready; open a file or folder.')
    else
      core.log("Opening project %q from directory %s", pname, pdir)
    end""")
    # Restore after startup files; persist before shutdown without discarding buffers.
    text = text.replace('function core.run()\n', "function core.run()\n  require('litefront.session').restore()\n  require('litefront.session').start_recovery()\n")
    text = text.replace('function core.quit(force)\n', "function core.quit(force)\n  local ok,err=require('litefront.session').save()\n  if not ok then core.error('Could not preserve open documents: %s',err);return end\n  force=true\n")
    text = text.replace('function core.restart()\n', "function core.restart()\n  local ok,err=require('litefront.session').save()\n  if not ok then core.error('Could not preserve open documents: %s',err);return end\n")
    text = text.replace('quit_with_function(function() core.restart_request = true end)', 'quit_with_function(function() core.restart_request = true end, true)')
    core.write_text(text)
    # A delayed disk reload must re-check edits made since the reload was scheduled.
    replace(data / 'plugins/autoreload.lua', '    reload_doc(doc)\n  end)',
            '    if doc:is_dirty() then doc.deferred_reload = true else reload_doc(doc) end\n  end)')
    copy(ROOT / 'profile/litefront', data / 'litefront')
    copy(ROOT / 'profile/assets', data / 'litefront/assets')
    copy(ROOT / 'fonts', data / 'litefront/assets/fonts/supplied')
    copy(ROOT / 'profile/init.lua', data / 'litefront/init.lua')
    copy(ROOT / 'VERSION', data / 'litefront/VERSION')
    copy(ROOT / 'CHANGELOG.md', data / 'litefront/CHANGELOG.md')
    replace(data / 'plugins/language_html.lua', 'files = { "%.html?$" },',
            'files = { "%.[hH][tT][mM][lL]?$", "%.[xX][hH][tT][mM][lL]$" },')
    replace(data / 'plugins/language_html.lua', 'type = "function"', 'type = "htmltag"')
    replace(data / 'plugins/language_html.lua', 'type = "keyword"', 'type = "htmlattribute"')
    copy(ROOT / 'profile/colors', data / 'colors')
    copy(ROOT / 'profile/plugins', data / 'plugins')
    wrap_anchor = """local function get_line_col_from_index_and_x(docview, idx, x)
  local doc = docview.doc
  local line, col = get_idx_line_col(docview, idx)
  if idx < 1 then return 1, 1 end"""
    replace(data / 'plugins/linewrapping.lua', wrap_anchor, wrap_anchor + """
  local colors = package.loaded['litefront.color_inline']
  if colors and #colors.hits(doc, line) > 0 then
    local first, last, indent = colors.segment(docview, line, col)
    return line, colors.column(docview, line, x, first, last, indent)
  end""")
    replace(data / 'plugins/projectsearch.lua', 'local dv = core.root_view:open_doc(core.open_doc(res.file))',
            "local dv = require('plugins.litefront_media').open_text(res.file)")
    copy(DEPS / 'features/lsp', data / 'plugins/lsp')
    copy(DEPS / 'libraries/widget', data / 'libraries/widget')
    copy(DEPS / 'sources/LiteMark/litemark', data / 'plugins/litemark')
    for name in ['json', 'snippets', 'lsp_snippets']:
        copy(DEPS / f'sources/snippets/{name}.lua', data / f'plugins/{name}.lua')
    for name in ['php', 'ts', 'json', 'jsx', 'tsx', 'sass', 'yaml', 'sh']:
        copy(DEPS / f'sources/languages/plugins/language_{name}.lua', data / f'plugins/language_{name}.lua')
    copy(DEPS / 'sources/languages/plugins/minimap.lua', data / 'plugins/minimap.lua')
    replace(data / 'plugins/minimap.lua', 'function MiniMap:is_minimap_enabled()\n',
            'function MiniMap:is_minimap_enabled()\n  if self.dv.size.x < 500 * SCALE then return false end\n')
    replace(data / 'plugins/litemark/init.lua', 'USERDIR .. "/plugins/litemark"', 'DATADIR .. "/plugins/litemark"')
    # Preview shares application colors/fonts and invalidates all cached appearance.
    markdown_layout = data / 'plugins/litemark/mdlayout.lua'
    code = markdown_layout.read_text()
    begin = code.index('local NoteColors = {')
    end = code.index('\n}\n', begin) + len('\n}')
    code = code[:begin] + "local NoteColors = require('litefront.markdown_theme').colors" + code[end:]
    begin = code.index('local function load_assets(config)')
    end = code.index('-- SYNTAX HELPERS', begin)
    code = code[:begin] + """local function load_assets(config)
  local assets = require('litefront.markdown_theme').assets()
  for key, scale in pairs(SCALES) do L[key] = math.floor(assets.size * scale) end
  NoteFonts = assets.fonts
end

""" + code[end:]
    code = code.replace('color = style.background2,', 'color = style.ui_background or style.background,')
    code = code.replace('math.floor(config.plugins.litemark.fonts.size)', 'math.floor(NoteFonts.REGULAR:get_size())')
    markdown_layout.write_text(code)
    markdown_view = data / 'plugins/litemark/init.lua'
    replace(markdown_view, 'local theme_changed = (self._layout_bg ~= style.background2)',
            "local appearance = require('litefront.markdown_theme').signature()\n  local theme_changed = (self._layout_appearance ~= appearance)")
    replace(markdown_view, 'self._layout_bg = style.background2', 'self._layout_appearance = appearance')
    replace(markdown_view, 'self:draw_background(style.background2)', 'self:draw_background(style.ui_background or style.background)')
    replace(markdown_view, 'local border_color = style.syntax["keyword"]', 'local border_color = style.divider')
    replace(data / 'plugins/lsp/listbox.lua', ', style.background)', ', style.ui_background or style.background)')
    replace(data / 'plugins/autocomplete.lua', ', style.background)', ', style.ui_background or style.background)')
    lsp = data / 'plugins/lsp/init.lua'
    replace(lsp, 'USERDIR .. "/plugins/lsp/fonts/symbols.ttf"', 'DATADIR .. "/plugins/lsp/fonts/symbols.ttf"')
    # Separate LSP identities let untitled buffers keep their normal Save dialog.
    code = lsp.read_text()
    code = re.sub(r'\b((?:\w+\.)*(?:doc|docu)|self)\.filename\b', r'document_filename(\1)', code)
    code = code.replace('doc.abs_filename', '(doc.abs_filename or doc.litefront_lsp_filename)')
    code = code.replace('local LineWrapping\n', """local function document_filename(doc)
  return doc.filename or doc.litefront_lsp_filename
end
local LineWrapping
""")
    code = code.replace('  if not file_info then\n',
                        '  if not file_info and doc.litefront_lsp_filename then file_info = {size = #table.concat(doc.lines), type = "file"} end\n  if not file_info then\n', 1)
    code = code.replace('      lsp.open_document(self)\n    end)\n  else',
                        '      lsp.start_server(document_filename(self), core.project_dir)\n      lsp.open_document(self)\n    end)\n  else', 1)
    lsp.write_text(code)
    server = data / 'plugins/lsp/server.lua'
    replace(server, 'string.match(doc.abs_filename, l.pattern)',
            'string.match(doc.abs_filename or doc.litefront_lsp_filename, l.pattern)')
    replace(server, 'util.file_extension(doc.filename)',
            'util.file_extension(doc.filename or doc.litefront_lsp_filename)')
    replace(data / 'plugins/lsp/util.lua', 'doc.abs_filename == abs_filename',
            '(doc.abs_filename or doc.litefront_lsp_filename) == abs_filename')
    replace(data / 'plugins/autocomplete.lua', 'local filename = doc and doc.filename or ""',
            'local filename = doc and (doc.filename or doc.litefront_lsp_filename) or ""')
    # Keep declarative JSON language settings; do not execute workspace or user Lua.
    replace(lsp, 'if util.file_exists(path .. "/.lite_lsp.lua") then', 'if false then')
    if args.target != 'web':
        copy(DEPS / ('node-windows' if args.target=='windows' else 'node'), data / 'litefront/node')
        copy(DEPS / ('github-cli-windows' if args.target=='windows' else 'github-cli'), data / 'litefront/github-cli')
        tooling = data / 'litefront/tooling'
        shutil.copytree(DEPS / 'tooling/node_modules', tooling / 'node_modules', symlinks=args.target!='windows',
                        ignore=shutil.ignore_patterns('.bin') if args.target=='windows' else None)
        copy(DEPS / 'tooling/package.json', tooling / 'package.json')
        copy(DEPS / 'tooling/package-lock.json', tooling / 'package-lock.json')
    copy(ROOT / 'tools/preview.mjs', data / 'litefront/preview.mjs')
    copy(ROOT / 'tools/format.mjs', data / 'litefront/format.mjs')
    copy(ROOT / 'tools/outline.mjs', data / 'litefront/outline.mjs')
    if args.target!='web':
        copy(ROOT / 'tools/github-trial.mjs',data / 'litefront/github-trial.mjs')
        copy(ROOT / 'tools/github-setup.mjs',data / 'litefront/github-setup.mjs')
    copy(ROOT / 'tools/markdown-pdf.mjs', data / 'litefront/markdown-pdf.mjs')
    # Keep licenses in every distributable.
    licenses = data / 'litefront/licenses'
    copy(ROOT / 'vendor/lite-xl/LICENSE', licenses / 'lite-xl.txt')
    copy(ROOT / 'vendor/lite-xl/src/thirdparty/stb-LICENSE', licenses / 'stb.txt')
    for source, name in [('features/lsp','lsp'),('libraries/widget','widget'),('sources/LiteMark','litemark'),('sources/languages','language-definitions'),('sources/snippets','snippets')]:
        copy(DEPS / source / 'LICENSE', licenses / (name + '.txt'))
    copy(ROOT / 'tools/dependencies.lock.json', data / 'litefront/dependencies.lock.json')
    print(f'Built-in application data prepared: {data}')

if __name__ == '__main__':
    main()
