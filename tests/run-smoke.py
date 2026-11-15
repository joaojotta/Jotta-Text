#!/usr/bin/env python3
"""Exercise the actual editor with a dummy SDL display and disposable user/project files."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / 'dist/native'
with tempfile.TemporaryDirectory(prefix='litefront-smoke-') as directory:
    temp = Path(directory)
    data = temp / 'share/lite-xl'
    shutil.copytree(APP / 'share/lite-xl', data, symlinks=True)
    (temp / 'bin').mkdir()
    for name in ['lite-xl','litefront-file-dialog']:
        shutil.copy2(APP / 'bin' / name, temp / 'bin' / name)
    user, project = temp / 'user', temp / 'project'
    (user / 'plugins').mkdir(parents=True)
    project.mkdir()
    (user / 'init.lua').write_text('_G.LITEFRONT_USER_INIT_LOADED=true\n')
    (user / 'plugins/stale.lua').write_text('-- mod-version:4\n_G.LITEFRONT_USER_EXTENSION_LOADED=true\n')
    (project / '.lite_project.lua').write_text('_G.LITEFRONT_PROJECT_EXTENSION_LOADED=true\n')
    (project / 'format.js').write_text('const answer=42')
    (project / 'start.html').write_text('<!DOCTYPE html><html><body>Test</body></html>')
    (project / 'nested').mkdir()
    (project / 'nested' / 'note.md').write_text('# Nested file\n')
    (project / 'start.css').write_text('body { color: red; }')
    shutil.copy2(ROOT / 'tests/workspace.lua',data / 'litefront/workspace-test.lua')
    shutil.copy2(ROOT / 'tests/dialogs-html.lua',data / 'litefront/dialogs-html-test.lua')
    shutil.copy2(ROOT / 'tests/explorer.lua',data / 'litefront/explorer-test.lua')
    shutil.copy2(ROOT / 'tests/markdown.lua',data / 'litefront/markdown-test.lua')
    shutil.copy2(ROOT / 'tests/visuals.lua',data / 'litefront/visuals-test.lua')
    init = data / 'litefront/init.lua'
    init.write_text('''
local core=require 'core'
core.add_thread(function()
  coroutine.yield(10)
  local out=io.open(USERDIR..'/smoke-result.txt','w')
  for _,item in ipairs(core.log_items) do out:write(item.level..': '..item.text..'\\n'..(item.info or '')..'\\n') end
  out:close();core.quit(true)
end)
''' + init.read_text() + '\n' + (ROOT / 'tests/smoke.lua').read_text())
    env = dict(os.environ, SDL_VIDEODRIVER='dummy', LITE_USERDIR=str(user))
    result = subprocess.run([str(temp / 'bin/lite-xl'), str(project),str(project/'format.js'),str(project/'start.css'),str(project/'start.html')], env=env,
                            capture_output=True, text=True, timeout=15)
    report = user / 'smoke-result.txt'
    if result.returncode or not report.exists():
        raise SystemExit(f'Smoke test failed: {result.stderr}\n{result.stdout}')
    text = report.read_text()
    failures = [line for line in text.splitlines() if line.startswith(('ERROR:', 'WARN:')) or 'Version mismatch' in line]
    if failures:
        raise SystemExit('\n'.join(failures))
    assert 'SMOKE COMPLETE' in text
    print('PASS: actual editor startup, bundled features, disabled extensions, menus, themes, formatter, Markdown preview, tabs, language selection, native save/cancel, HTML detection, warning/error dialogs, imported visuals and floating selectors')
