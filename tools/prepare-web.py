#!/usr/bin/env python3
"""Stage the browser shell and locally served browser-only tool libraries.

Every browser module is published with a .js extension. Browsers only run
module scripts served with a JavaScript MIME type, and many web servers
(Apache and nginx defaults on shared hosting among them) do not map .mjs, so
the page would load without its scripts. Sources keep .mjs for Node tooling.
"""
from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'dist/web'
MODULES = ROOT / 'vendor/litefront/tooling/node_modules'
# Relative module specifiers such as './files.mjs' or './lib/prettier/standalone.mjs'.
SPECIFIER = re.compile(r'''(['"])(\.{1,2}/[^'"\s]+)\.mjs\1''')


def as_js(name):
    return name[:-len('.mjs')] + '.js' if name.endswith('.mjs') else name


def publish_text(source, destination):
    """Copy a shell file, pointing relative module imports at their .js names."""
    text = source.read_bytes().decode('utf-8')
    text = SPECIFIER.sub(lambda match: f'{match[1]}{match[2]}.js{match[1]}', text)
    if source.suffix == '.html':
        text = text.replace('src="app.mjs"', 'src="app.js"')
    destination.write_bytes(text.encode('utf-8'))


def stage_shell():
    for path in (ROOT / 'web').iterdir():
        if path.suffix in ('.html', '.mjs', '.css'):
            publish_text(path, OUT / as_js(path.name))


def stage_libraries():
    lib = OUT / 'lib'
    shutil.rmtree(lib, ignore_errors=True)
    prettier = lib / 'prettier'
    (prettier / 'plugins').mkdir(parents=True)
    shutil.copy2(MODULES / 'prettier/standalone.mjs', prettier / 'standalone.js')
    for name in ['LICENSE', 'THIRD-PARTY-NOTICES.md']:
        shutil.copy2(MODULES / 'prettier' / name, prettier / name)
    # Only the ES module builds are imported; they replace the unused UMD .js builds.
    for plugin in sorted((MODULES / 'prettier/plugins').glob('*.mjs')):
        shutil.copy2(plugin, prettier / 'plugins' / as_js(plugin.name))
    # A UMD bundle loaded with import() for its side effect on globalThis.prettierPlugins.
    shutil.copy2(MODULES / '@prettier/plugin-php/standalone.js', lib / 'php.js')
    shutil.copy2(MODULES / '@prettier/plugin-php/LICENSE', lib / 'php-LICENSE')


def stage_assets():
    assets = OUT / 'assets'
    assets.mkdir(exist_ok=True)
    for source, name in [(ROOT / 'icons/icon.svg', 'icon.svg'), (ROOT / 'fonts/Rubik-VariableFont_wght.ttf', 'Rubik.ttf')]:
        shutil.copy2(source, assets / name)
    shutil.copy2(ROOT / 'profile/assets/NOTICE.md', assets / 'NOTICE.md')
    shutil.copytree(ROOT / 'profile/assets/licenses', assets / 'licenses', dirs_exist_ok=True)
    shutil.copy2(ROOT / 'vendor/lite-xl/LICENSE', assets / 'lite-xl-LICENSE.txt')
    shutil.copy2(ROOT / 'VERSION', OUT / 'VERSION')
    shutil.copy2(ROOT / 'web/README.md', OUT / 'README.md')
    # Browsers ignore this; Node tooling and tests then load the .js modules as ES modules.
    (OUT / 'package.json').write_text('{"type": "module", "private": true}\n')


def check_no_mjs():
    """Fail if anything published still is, or still imports, a .mjs module."""
    leftovers = [path for path in OUT.rglob('*.mjs')]
    for path in OUT.glob('*'):
        if path.suffix in ('.html', '.js') and path.name != 'lite-xl.js' and SPECIFIER.search(path.read_bytes().decode('utf-8')):
            leftovers.append(path)
    if leftovers:
        raise SystemExit('Browser package still references .mjs modules: ' + ', '.join(map(str, leftovers)))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for stale in [OUT / 'jottaxl.js', *OUT.glob('*.mjs')]:
        stale.unlink(missing_ok=True)
    stage_shell()
    stage_libraries()
    stage_assets()
    check_no_mjs()
    print('Browser shell and tool libraries staged in dist/web')


if __name__ == '__main__':
    main()
