#!/usr/bin/env python3
"""Assemble the immutable application data, disabling third-party extension loading."""
import argparse
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UPSTREAM = ROOT / 'vendor/lite-xl'
DEPS = ROOT / 'vendor/litefront'
IGNORE = shutil.ignore_patterns('.git', '__pycache__', 'screenshots', 'node_modules')
DESTINATION_NAMES = ('lite-xl', 'app-data', 'data')
VERSION_PATTERN = r'\d+\.\d+\.\d+'
SAVE_SESSION = ("  local ok,err=require('litefront.session').save()\n"
                "  if not ok then core.error('Could not preserve open documents: %s',err);return end\n")


def copy(source, dest):
    source, dest = Path(source), Path(dest)
    if source.is_dir():
        shutil.copytree(source, dest, dirs_exist_ok=True, ignore=IGNORE)
    else:
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, dest)


def read(path):
    # Explicit UTF-8 bytes: Windows would otherwise decode as cp1252 and write CRLF.
    return path.read_bytes().decode('utf-8')


def write(path, text):
    path.write_bytes(text.encode('utf-8'))


class Source:
    """One upstream file being patched. Every edit fails loudly if its anchor is gone."""

    def __init__(self, path):
        self.path = path
        self.text = read(path)

    def __enter__(self):
        return self

    def __exit__(self, error_type, *_):
        if error_type is None:
            write(self.path, self.text)

    def _missing(self, anchor):
        return RuntimeError(f'Upstream source changed; expected patch anchor missing in {self.path}: {anchor[:60]!r}')

    def replace(self, before, after, count=-1):
        if before not in self.text:
            raise self._missing(before)
        self.text = self.text.replace(before, after, count)

    def replace_span(self, begin_marker, end_marker, replacement, include_end=False):
        """Replace everything from begin_marker up to (or through) the next end_marker."""
        begin = self.text.find(begin_marker)
        end = self.text.find(end_marker, begin) if begin >= 0 else -1
        if end < 0:
            raise self._missing(begin_marker if begin < 0 else end_marker)
        if include_end:
            end += len(end_marker)
        self.text = self.text[:begin] + replacement + self.text[end:]

    def substitute(self, pattern, replacement):
        self.text, count = re.subn(pattern, replacement, self.text)
        if not count:
            raise self._missing(pattern)

    def append(self, text):
        self.text += text


def replace(path, before, after):
    with Source(path) as source:
        source.replace(before, after)


def check_destination(data):
    inside_source = ROOT in data.parents
    if (data.name not in DESTINATION_NAMES or data == ROOT
            or (inside_source and data.relative_to(ROOT).parts[0] != 'dist')):
        raise SystemExit('Bundle destination must be inside dist/ or outside the source tree')


def application_version():
    version = read(ROOT / 'VERSION').strip()
    if not re.fullmatch(VERSION_PATTERN, version):
        raise RuntimeError('Invalid application version')
    return version


def engine_version():
    match = re.search(r"^\s*version\s*:\s*'([^']+)'", read(UPSTREAM / 'meson.build'), re.MULTILINE)
    if not match:
        raise RuntimeError('Cannot read the Lite XL version from meson.build')
    return match.group(1)


def patch_start(data, target):
    """Set identity and stop the engine searching user directories for Lua or native modules."""
    with Source(data / 'core/start.lua') as start:
        if target == 'windows':
            # A user/ folder beside JottaText.exe keeps the portable ZIP
            # self-contained. The installed copy has none, so it keeps settings
            # in %APPDATA%\JottaText rather than Lite XL's %USERPROFILE%\.config\lite-xl.
            fallback = '       or os.getenv("LITE_USERDIR")\n'
            start.replace(fallback, fallback +
                          '       or (os.getenv("APPDATA") and (os.getenv("APPDATA") .. PATHSEP .. "JottaText"))\n')
        start.replace('@PROJECT_VERSION@', engine_version())
        start.append(f'\nAPP_NAME = "Jotta Text"\nAPP_VERSION = "{application_version()}"\n')
        start.replace("package.path = USERDIR .. '/?.lua;' .. package.path", '')
        start.replace("package.path = USERDIR .. '/?/init.lua;' .. package.path", '')
        start.replace_span('package.cpath =', '\npackage.native_plugins',
                           "package.cpath = DATADIR .. '/?.' .. suffix .. ';' .. DATADIR .. '/?/init.' .. suffix .. ';'\n")


def patch_core(data):
    """Load only the built-in profile, start without a project and preserve sessions."""
    with Source(data / 'core/init.lua') as core:
        core.replace_span('function core.load_user_directory()', 'function core.remove_project_directory',
                          """function core.load_user_directory()
  return core.try(function()
    common.mkdirp(USERDIR)
    dofile(DATADIR .. '/litefront/init.lua')
  end)
end


""")
        core.replace_span('function core.load_project_module()', 'function core.reload_module',
                          """function core.load_project_module()
  return true
end


""")
        core.replace('ipairs {DATADIR, USERDIR}', 'ipairs {DATADIR}')
        core.replace('and "Lite XL" or title .. " - Lite XL"', 'and "Jotta Text" or title .. " - Jotta Text"')
        core.replace('  local project_dir = core.recent_projects[1] or "."',
                     """  -- A plain application launch shows welcome without indexing cwd or recents.
  core.litefront_no_project = true
  core.project_files = {}
  local project_dir = USERDIR .. '/empty-workspace'
  local workspace_info = system.get_file_info(project_dir)
  if workspace_info then
    assert(workspace_info.type == 'dir', 'Startup workspace is not a directory: ' .. project_dir)
  else
    assert(common.mkdirp(project_dir))
  end""")
        core.replace('      project_dir_explicit = true',
                     '      project_dir_explicit = true\n      core.litefront_no_project = false')
        core.replace('    core.root_view:close_all_docviews()\n    reload_customizations()',
                     '    core.litefront_no_project = false\n    core.root_view:close_all_docviews()\n    reload_customizations()')
        core.replace('  core.add_project_directory(project_dir_abs)\n',
                     '  if not core.litefront_no_project then core.add_project_directory(project_dir_abs) end\n')
        # add_project_directory already reports incomplete indexing; do not warn a second time.
        core.replace_span('  -- We assume we have just a single project directory here.',
                          '  for _, filename in ipairs(files) do', '')
        core.replace('    core.log("Opening project %q from directory %s", pname, pdir)',
                     """    if core.litefront_no_project then
      core.log_quiet('Jotta Text ready; open a file or folder.')
    else
      core.log("Opening project %q from directory %s", pname, pdir)
    end""")
        # Restore after startup files; persist before shutdown without discarding buffers.
        core.replace('function core.run()\n',
                     "function core.run()\n  require('litefront.session').restore()\n"
                     "  require('litefront.session').start_recovery()\n")
        core.replace('function core.quit(force)\n', 'function core.quit(force)\n' + SAVE_SESSION + '  force=true\n')
        core.replace('function core.restart()\n', 'function core.restart()\n' + SAVE_SESSION)
        core.replace('quit_with_function(function() core.restart_request = true end)',
                     'quit_with_function(function() core.restart_request = true end, true)')


def copy_application(data):
    copy(ROOT / 'profile/litefront', data / 'litefront')
    copy(ROOT / 'profile/assets', data / 'litefront/assets')
    copy(ROOT / 'fonts', data / 'litefront/assets/fonts/supplied')
    copy(ROOT / 'profile/init.lua', data / 'litefront/init.lua')
    copy(ROOT / 'VERSION', data / 'litefront/VERSION')
    copy(ROOT / 'CHANGELOG.md', data / 'litefront/CHANGELOG.md')
    copy(ROOT / 'profile/colors', data / 'colors')
    copy(ROOT / 'profile/plugins', data / 'plugins')


def patch_builtin_plugins(data):
    # A delayed disk reload must re-check edits made since the reload was scheduled.
    replace(data / 'plugins/autoreload.lua', '    reload_doc(doc)\n  end)',
            '    if doc:is_dirty() then doc.deferred_reload = true else reload_doc(doc) end\n  end)')
    with Source(data / 'plugins/language_html.lua') as html:
        html.replace('files = { "%.html?$" },', 'files = { "%.[hH][tT][mM][lL]?$", "%.[xX][hH][tT][mM][lL]$" },')
        html.replace('type = "function"', 'type = "htmltag"')
        html.replace('type = "keyword"', 'type = "htmlattribute"')
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


def copy_bundled_plugins(data):
    copy(DEPS / 'features/lsp', data / 'plugins/lsp')
    copy(DEPS / 'libraries/widget', data / 'libraries/widget')
    copy(DEPS / 'sources/LiteMark/litemark', data / 'plugins/litemark')
    for name in ['json', 'snippets', 'lsp_snippets']:
        copy(DEPS / f'sources/snippets/{name}.lua', data / f'plugins/{name}.lua')
    for name in ['php', 'ts', 'json', 'jsx', 'tsx', 'sass', 'yaml', 'sh']:
        copy(DEPS / f'sources/languages/plugins/language_{name}.lua', data / f'plugins/language_{name}.lua')
    copy(DEPS / 'sources/languages/plugins/minimap.lua', data / 'plugins/minimap.lua')


def patch_minimap(data):
    with Source(data / 'plugins/minimap.lua') as minimap:
        minimap.replace('function MiniMap:is_minimap_enabled()\n',
                        'function MiniMap:is_minimap_enabled()\n  if self.dv.size.x < 500 * SCALE then return false end\n')
        # Reserve a small top inset for both rendering and pointer/drag geometry.
        disabled = '  if not self:is_minimap_enabled() then return MiniMap.super.set_size(self, x, y, w, h, scrollable) end\n'
        minimap.replace(disabled, disabled + '  local margin=math.min(6*SCALE,math.max(0,h))\n  y=y+margin\n  h=math.max(0,h-margin)\n')
        minimap.replace('renderer.draw_rect(x, y, w, self.dv.size.y, style.minimap_background or style.background)',
                        'renderer.draw_rect(x, y, w, math.max(0,self.dv.size.y-6*SCALE), style.minimap_background or style.background)')


def patch_markdown(data):
    # Preview shares application colors/fonts and invalidates all cached appearance.
    with Source(data / 'plugins/litemark/mdlayout.lua') as layout:
        layout.replace_span('local NoteColors = {', '\n}', "local NoteColors = require('litefront.markdown_theme').colors",
                            include_end=True)
        layout.replace_span('local function load_assets(config)', '-- SYNTAX HELPERS', """local function load_assets(config)
  local assets = require('litefront.markdown_theme').assets()
  for key, scale in pairs(SCALES) do L[key] = math.floor(assets.size * scale) end
  NoteFonts = assets.fonts
end

""")
        layout.replace('color = style.background2,', 'color = style.ui_background or style.background,')
        layout.replace('math.floor(config.plugins.litemark.fonts.size)', 'math.floor(NoteFonts.REGULAR:get_size())')
    with Source(data / 'plugins/litemark/init.lua') as view:
        view.replace('USERDIR .. "/plugins/litemark"', 'DATADIR .. "/plugins/litemark"')
        view.replace('local theme_changed = (self._layout_bg ~= style.background2)',
                     "local appearance = require('litefront.markdown_theme').signature()\n"
                     '  local theme_changed = (self._layout_appearance ~= appearance)')
        view.replace('self._layout_bg = style.background2', 'self._layout_appearance = appearance')
        view.replace('self:draw_background(style.background2)', 'self:draw_background(style.ui_background or style.background)')
        view.replace('local border_color = style.syntax["keyword"]', 'local border_color = style.divider')
        # Project notes keep their autosave; Markdown preview renders the unsaved buffer.
        view.replace('  if editor.doc:is_dirty() then editor.doc:save() end\n',
                     '  if editor._litemark_kind == "project" and editor.doc.abs_filename and editor.doc:is_dirty() then\n'
                     '    editor.doc:save()\n  end\n')
        # Preview any Markdown-syntax document (including untitled ones) and reuse an open preview.
        view.replace('    local active = core.active_view\n',
                     '    local active = require("litefront.visual").document_view()\n')
        view.replace('    local filename = active.doc.filename\n    if filename and filename:match("%.md$") then\n',
                     '    if active.doc.syntax and active.doc.syntax.name == "Markdown" then\n'
                     '      local existing\n'
                     '      walk_views(function(view)\n'
                     '        if view.doc == active.doc and view:is(NoteReadView) then existing=view;return true end\n'
                     '      end)\n'
                     '      if existing then core.set_active_view(existing);return end\n')
        view.replace('    and view.doc.filename\n    and view.doc.filename:match("%.md$")\n',
                     '    and view.doc.syntax\n    and view.doc.syntax.name == "Markdown"\n')


def patch_completion(data):
    replace(data / 'plugins/lsp/listbox.lua', ', style.background)', ', style.ui_background or style.background)')
    with Source(data / 'plugins/autocomplete.lua') as autocomplete:
        autocomplete.replace(', style.background)', ', style.ui_background or style.background)')
        autocomplete.replace(
            '  return doc:get_text(line1, col1, line2, col2)\nend\n\nlocal function get_active_view()',
            "  return require('litefront.completion_context').partial(doc, line2, col2, doc:get_text(line1, col1, line2, col2))\n"
            'end\n\nlocal function get_active_view()')
        autocomplete.replace('local filename = doc and doc.filename or ""',
                             'local filename = doc and (doc.filename or doc.litefront_lsp_filename) or ""')


def patch_lsp(data):
    with Source(data / 'plugins/lsp/init.lua') as lsp:
        lsp.replace('USERDIR .. "/plugins/lsp/fonts/symbols.ttf"', 'DATADIR .. "/plugins/lsp/fonts/symbols.ttf"')
        # Separate LSP identities let untitled buffers keep their normal Save dialog.
        lsp.substitute(r'\b((?:\w+\.)*(?:doc|docu)|self)\.filename\b', r'document_filename(\1)')
        lsp.replace('local LineWrapping\n', """local function document_filename(doc)
  return doc.filename or doc.litefront_lsp_filename
end
local LineWrapping
""")
        lsp.replace('  if not file_info then\n',
                    '  if not file_info and doc.litefront_lsp_filename then'
                    ' file_info = {size = #table.concat(doc.lines), type = "file"} end\n  if not file_info then\n', 1)
        lsp.replace('      lsp.open_document(self)\n    end)\n  else',
                    '      lsp.start_server(document_filename(self), core.project_dir)\n'
                    '      lsp.open_document(self)\n    end)\n  else', 1)
        lsp.replace('if cline ~= line or cchar ~= col then',
                    'if core.active_view.doc ~= doc or cline ~= line or cchar ~= col then')
        # Inline color swatches own the pointer: suppress LSP hover popups over them.
        lsp.replace('  if not av:extends(DocView) then return end\n',
                    "  if not av:extends(DocView) then return end\n"
                    "  if require('litefront.color_inline').at(av,x,y) then return end\n")
        lsp.replace('        callback = function(server, response)\n          if response.result and response.result.contents then\n',
                    '        callback = function(server, response)\n'
                    '          if not in_tab and lsp.hover_position.color_suppressed then return end\n'
                    '          if response.result and response.result.contents then\n')
        lsp.replace('  root_view_on_mouse_moved(self, x, y, dx, dy)\n\n',
                    """  root_view_on_mouse_moved(self, x, y, dx, dy)

  local node=self.root_node:get_child_overlapping_point(x,y)
  local view=node and node.active_view
  local color=view and view:extends(DocView) and require('litefront.color_inline').at(view,x,y)
  lsp.hover_position.color_suppressed=not not color
  if color then
    lsp.hover_timer:stop();lsp.hover_timer:reset()
    lsp.hover_position.triggered=false;lsp.hover_position.utf8_range=nil
    listbox.hide()
    return
  end
""")
        # A shared Emmet server can open a document before a newly started CSS/HTML
        # server. Wait for each didOpen to be written, not just initialization: LSP
        # notifications and requests have separate queues and can otherwise race.
        lsp.replace('function lsp.open_document(doc)\n', """local function mark_document_open(doc, server, path)
  local filename = document_filename(doc)
  if not filename or core.project_absolute_path(filename) ~= path then return end
  doc.lsp_open = true
  doc.litefront_lsp_open_servers = doc.litefront_lsp_open_servers or setmetatable({}, { __mode = 'k' })
  doc.litefront_lsp_open_servers[server] = path
end

function lsp.open_document(doc)
""")
        lsp.replace('callback = function() doc.lsp_open = true end',
                    'callback = function(server) mark_document_open(doc, server, doc_path) end')
        lsp.replace('              doc.lsp_open = true\n              log(server,',
                    '              mark_document_open(doc, server, doc_path)\n              log(server,')
        lsp.replace('      else\n        doc.lsp_open = true\n      end\n    end\n  end\nend',
                    '      else\n        mark_document_open(doc, server, doc_path)\n      end\n    end\n  end\nend')
        # Keep declarative JSON language settings; do not execute workspace or user Lua.
        lsp.replace('if util.file_exists(path .. "/.lite_lsp.lua") then', 'if false then')
    with Source(data / 'plugins/lsp/server.lua') as server:
        server.replace('string.match(doc.abs_filename, l.pattern)',
                       'string.match(doc.abs_filename or doc.litefront_lsp_filename, l.pattern)')
        server.replace('util.file_extension(doc.filename)',
                       'util.file_extension(doc.filename or doc.litefront_lsp_filename)')
    replace(data / 'plugins/lsp/util.lua', 'doc.abs_filename == abs_filename',
            '(doc.abs_filename or doc.litefront_lsp_filename) == abs_filename')


def copy_runtime_tools(data, target):
    windows = target == 'windows'
    if target != 'web':
        copy(DEPS / ('node-windows' if windows else 'node'), data / 'litefront/node')
        copy(DEPS / ('github-cli-windows' if windows else 'github-cli'), data / 'litefront/github-cli')
        tooling = data / 'litefront/tooling'
        shutil.copytree(DEPS / 'tooling/node_modules', tooling / 'node_modules', symlinks=not windows,
                        ignore=shutil.ignore_patterns('.bin') if windows else None)
        copy(DEPS / 'tooling/package.json', tooling / 'package.json')
        copy(DEPS / 'tooling/package-lock.json', tooling / 'package-lock.json')
    scripts = ['preview', 'format', 'outline', 'markdown-pdf']
    if target != 'web':
        scripts += ['github-trial', 'github-setup']
    for name in scripts:
        copy(ROOT / f'tools/{name}.mjs', data / f'litefront/{name}.mjs')


def copy_licenses(data):
    """Keep licenses in every distributable."""
    licenses = data / 'litefront/licenses'
    copy(UPSTREAM / 'LICENSE', licenses / 'lite-xl.txt')
    copy(ROOT / 'tools/lua-LICENSE.txt', licenses / 'lua.txt')
    copy(UPSTREAM / 'src/thirdparty/stb-LICENSE', licenses / 'stb.txt')
    for source, name in [('features/lsp', 'lsp'), ('libraries/widget', 'widget'), ('sources/LiteMark', 'litemark'),
                         ('sources/languages', 'language-definitions'), ('sources/snippets', 'snippets')]:
        copy(DEPS / source / 'LICENSE', licenses / (name + '.txt'))
    copy(ROOT / 'tools/dependencies.lock.json', data / 'litefront/dependencies.lock.json')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('destination', type=Path)
    parser.add_argument('--target', choices=['linux', 'windows', 'web'], default='linux')
    args = parser.parse_args()
    data = args.destination.resolve()
    check_destination(data)
    if data.exists():
        shutil.rmtree(data)
    copy(UPSTREAM / 'data', data)
    patch_start(data, args.target)
    patch_core(data)
    copy_application(data)
    patch_builtin_plugins(data)
    copy_bundled_plugins(data)
    patch_minimap(data)
    patch_markdown(data)
    patch_completion(data)
    patch_lsp(data)
    copy_runtime_tools(data, args.target)
    copy_licenses(data)
    print(f'Built-in application data prepared: {data}')


if __name__ == '__main__':
    main()
