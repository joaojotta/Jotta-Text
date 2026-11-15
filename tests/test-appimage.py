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
diagnostics = ROOT / 'dist/test-results/appimage'
diagnostics.mkdir(parents=True, exist_ok=True)
digest = Path(str(image) + '.sha256').read_text().split()[0]
assert hashlib.sha256(image.read_bytes()).hexdigest() == digest, 'AppImage checksum mismatch'

def stop_runtime(process):
    # The runtime can exit before its editor child. Wait for live group members
    # before deleting extracted fonts/data or collecting their final error output.
    def running():
        process.poll()
        for status in Path('/proc').glob('[0-9]*/stat'):
            try:
                fields=status.read_text().rsplit(')',1)[1].split()
                if fields[0]!='Z' and int(fields[2])==process.pid:
                    return True
            except (OSError,ValueError,IndexError):
                continue
        return False
    try:
        os.killpg(process.pid,signal.SIGTERM)
        deadline=time.monotonic()+10
        while running() and time.monotonic()<deadline:
            time.sleep(.1)
        if running():
            os.killpg(process.pid,signal.SIGKILL)
    except ProcessLookupError:
        pass
    process.wait(timeout=10)

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
    snapshot = temp / 'config/litefront/documents.lua'
    error_log = temp / 'config/litefront/error.txt'
    recovered = False
    # A cold extraction expands hundreds of MB on CI. File-backed output also
    # prevents a verbose runtime or loader from blocking on a full pipe.
    with (diagnostics/'stdout.log').open('wb') as output, (diagnostics/'stderr.log').open('wb') as errors:
        process = subprocess.Popen([str(image), str(project / 'format.js')], env=env,
                                   stdout=output, stderr=errors, start_new_session=True)
        try:
            deadline = time.monotonic() + 60
            while time.monotonic() < deadline:
                if snapshot.is_file() and str(project / 'format.js') in snapshot.read_text():
                    recovered = True
                    break
                if process.poll() is not None or error_log.exists():
                    break
                time.sleep(.1)
        finally:
            stop_runtime(process)
    stdout = (diagnostics/'stdout.log').read_text(errors='replace')[-20000:]
    stderr = (diagnostics/'stderr.log').read_text(errors='replace')[-20000:]
    report = error_log.read_text(errors='replace') if error_log.is_file() else ''
    (diagnostics/'error.txt').write_text(report)
    assert recovered, ('Unmodified AppImage did not open its document and write recovery data'
                       f'\nExit code: {process.returncode}\nstdout:\n{stdout}\nstderr:\n{stderr}\nerror.txt:\n{report}')
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
