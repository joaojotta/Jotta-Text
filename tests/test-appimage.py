#!/usr/bin/env python3
"""Check the real AppImage, then exercise a relocated, disposable extraction."""
import argparse
import hashlib
import os
from pathlib import Path
import platform
import re
import shutil
import signal
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
VERSION = (ROOT / 'VERSION').read_text().strip()
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('image', nargs='?', type=Path,
                    default=ROOT / f'dist/JottaText-{VERSION}-{platform.machine()}.AppImage')
image = parser.parse_args().image.resolve()
digest = Path(str(image) + '.sha256').read_text().split()[0]
assert hashlib.sha256(image.read_bytes()).hexdigest() == digest, 'AppImage checksum mismatch'

with tempfile.TemporaryDirectory(prefix='Jotta Text AppImage test ') as directory:
    temp = Path(directory)
    project = temp / 'project with spaces'
    project.mkdir()
    (project / 'format.js').write_text('const answer=42')
    (project / 'start.html').write_text('<!DOCTYPE html><html><body>Test</body></html>')
    (project / 'start.css').write_text('body { color: red; }')
    (project / 'nested').mkdir()
    (project / 'nested/note.md').write_text('# Nested file\n')
    env = dict(os.environ, SDL_VIDEODRIVER='dummy', XDG_CONFIG_HOME=str(temp / 'config'),
               APPIMAGE_EXTRACT_AND_RUN='1', TMPDIR=str(temp))
    env.pop('LD_LIBRARY_PATH', None)
    # Launch the unchanged image through its real runtime, without requiring FUSE.
    process = subprocess.Popen([str(image), str(project / 'format.js')], env=env,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
    snapshot = temp / 'config/litefront/documents.lua'
    try:
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline and process.poll() is None:
            if snapshot.is_file() and str(project / 'format.js') in snapshot.read_text():
                break
            time.sleep(.1)
        else:
            raise AssertionError('Unmodified AppImage did not open its document and write recovery data')
    finally:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
        stdout, stderr = process.communicate(timeout=10)
    assert (project / 'format.js').read_text() == 'const answer=42', 'AppImage changed the source file'
    assert not (temp / 'config/litefront/error.txt').exists(), (stdout, stderr)

    # Moving the extraction to a path containing spaces catches absolute RPATHs
    # and launchers that accidentally depend on the build directory.
    subprocess.run([str(image), '--appimage-extract'], cwd=temp, env=env,
                   stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, check=True, timeout=45)
    app = temp / 'relocated application'
    (temp / 'squashfs-root').rename(app)
    data = app / 'usr/share/lite-xl'
    assert (data / 'litefront/VERSION').read_text().strip() == VERSION
    assert (app / '.DirIcon').is_file(), 'Desktop integration icon is missing'
    assert (app / 'io.github.joaojotta.JottaText.desktop').is_file()
    assert (data / 'litefront/assets/fonts/supplied/Rubik-VariableFont_wght.ttf').is_file()
    assert (data / 'litefront/assets/fonts/supplied/JetBrainsMono-VariableFont_wght.ttf').is_file()
    for link in app.rglob('*'):
        if link.is_symlink():
            assert link.resolve().is_relative_to(app), f'External bundle symlink: {link}'
            assert link.exists(), f'Broken bundle symlink: {link}'
    executables = [app / 'usr/bin/lite-xl', app / 'usr/bin/litefront-file-dialog',
                   data / 'litefront/node/node']
    libraries = list((app / 'usr/lib').glob('*.so*'))
    glibc_versions = set()
    for binary in [*executables, *libraries]:
        dependencies = subprocess.run(['ldd', str(binary)], env=env, capture_output=True, text=True, check=True).stdout
        assert 'not found' not in dependencies, (binary, dependencies)
        for name, location in re.findall(r'(\S+)\s+=>\s+(/[^\n]+?)\s+\(0x', dependencies):
            if name.startswith(('libharfbuzz', 'libfreetype', 'libfontconfig', 'libstdc++', 'libgcc_s')):
                assert Path(location).resolve().is_relative_to(app), f'{name} escaped the bundle: {location}'
        dynamic = subprocess.run(['readelf', '-d', str(binary)], capture_output=True, text=True, check=True).stdout
        assert str(ROOT) not in dynamic, f'Build directory leaked into runtime paths: {binary}'
        versions = subprocess.run(['readelf', '--version-info', str(binary)], capture_output=True, text=True, check=True).stdout
        glibc_versions.update(re.findall(r'\bGLIBC_(\d+\.\d+(?:\.\d+)?)\b', versions))
    minimum_glibc = max(glibc_versions, key=lambda value: tuple(map(int, value.split('.'))))
    node = subprocess.run([str(executables[-1]), '--version'], env=env, capture_output=True, text=True, check=True)
    assert node.stdout.startswith('v'), node

    # Only this disposable extracted copy receives the existing editor smoke
    # harness. The shipped image remains unchanged.
    for name in ['workspace', 'dialogs-html', 'explorer', 'markdown', 'visuals']:
        shutil.copy2(ROOT / f'tests/{name}.lua', data / f'litefront/{name}-test.lua')
    init = data / 'litefront/init.lua'
    init.write_text(r'''
local core=require 'core'
core.add_thread(function()
  coroutine.yield(10)
  local out=assert(io.open(USERDIR..'/smoke-result.txt','w'))
  for _,item in ipairs(core.log_items) do out:write(item.level..': '..item.text..'\n'..(item.info or '')..'\n') end
  out:close();core.quit(true)
end)
''' + init.read_text() + '\n' + (ROOT / 'tests/smoke.lua').read_text())
    env['XDG_CONFIG_HOME'] = str(temp / 'smoke config')
    result = subprocess.run([str(app / 'AppRun'), str(project), str(project / 'format.js'),
                             str(project / 'start.css'), str(project / 'start.html')],
                            env=env, capture_output=True, text=True, timeout=20)
    report = temp / 'smoke config/litefront/smoke-result.txt'
    assert result.returncode == 0 and report.is_file(), (result.stdout, result.stderr)
    text = report.read_text()
    failures = [line for line in text.splitlines() if line.startswith(('ERROR:', 'WARN:'))]
    assert not failures, '\n'.join(failures)
    assert 'SMOKE COMPLETE' in text, text
    assert (project / 'format.js').read_text() == 'const answer=42'
    print(f'PASS: checksum, FUSE-free startup, document recovery, relocation, libraries, bundled Node, '
          f'fonts, formatter, Markdown, dialogs and editor smoke tests (requires glibc >= {minimum_glibc})')
