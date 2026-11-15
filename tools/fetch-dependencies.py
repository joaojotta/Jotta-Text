#!/usr/bin/env python3
"""Build-time fetch only. Installed Jotta Text has no dependency installer."""
import argparse
import hashlib
import io
import json
import platform
import shutil
from pathlib import Path
import subprocess
import sys
import tarfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parent.parent
BASE = ROOT / 'vendor/litefront'
LOCK = json.loads((ROOT / 'tools/dependencies.lock.json').read_text(encoding='utf-8'))
NODE_ARCHITECTURES = {'x86_64': 'x64', 'AMD64': 'x64', 'aarch64': 'arm64', 'ARM64': 'arm64'}

def run(*args):
    subprocess.run(args, check=True, cwd=ROOT)

def npm_command(*arguments):
    """Run npm's JavaScript entry point, including MSYS2's non-executable shim."""
    executable=shutil.which('node.exe') or shutil.which('node')
    if not executable:
        raise SystemExit('Install Node.js and npm build prerequisites first')
    node=Path(executable).absolute()
    candidates=[]
    npm=shutil.which('npm')
    if npm:
        resolved=Path(npm).resolve()
        if resolved.name=='npm-cli.js':candidates.append(resolved)
    for directory in (node.parent,node.parent.parent):
        candidates.extend(directory/relative for relative in (
            'node_modules/npm/bin/npm-cli.js',
            'lib/node_modules/npm/bin/npm-cli.js',
            'share/nodejs/npm/bin/npm-cli.js'))
    cli=next((path for path in candidates if path.is_file()),None)
    if not cli:
        raise SystemExit('Cannot locate npm-cli.js beside Node.js. Install the Node.js/npm build tools.')
    return [str(node),str(cli),*arguments]

def checkout_pinned(dest, url, commit):
    """Fetch exactly one pinned commit with LF line endings on every platform.

    Initializing and fetching also works when a cache restore has already
    created a nonempty, source-free directory (subprojects/packagecache).
    """
    dest.mkdir(parents=True, exist_ok=True)
    run('git', 'init', str(dest))
    run('git', '-C', str(dest), 'fetch', '--depth=1', url, commit)
    run('git', '-C', str(dest), '-c', 'core.autocrlf=false', '-c', 'core.eol=lf', 'checkout', '--detach', 'FETCH_HEAD')

def git_output(dest, *arguments):
    return subprocess.check_output(['git', '-C', str(dest), *arguments], text=True).strip()

def fetch_engine(offline):
    upstream = ROOT / 'vendor/lite-xl'
    if not (upstream / 'data/core/init.lua').exists():
        if offline:
            raise SystemExit('Missing Lite XL source')
        revision = json.loads((ROOT / 'tools/lite-xl-files.json').read_text(encoding='utf-8'))['commit']
        checkout_pinned(upstream, 'https://github.com/lite-xl/lite-xl.git', revision)
    run(sys.executable, str(ROOT / 'tools/apply-lite-xl-patch.py'))

def fetch_repositories(offline):
    for repo in LOCK['repositories']:
        dest = BASE / repo['path']
        if not (dest / '.git').exists():
            if offline:
                raise SystemExit(f'Missing bundled source: {dest}')
            checkout_pinned(dest, repo['url'], repo['commit'])
        if git_output(dest, 'rev-parse', 'HEAD') != repo['commit']:
            raise SystemExit(f'Source revision mismatch: {dest}')
        # CI always builds pristine sources; a local edit here would ship from this machine only.
        modified = git_output(dest, 'status', '--porcelain', '--untracked-files=no')
        if modified:
            raise SystemExit(f'Local edits in bundled source {dest}:\n{modified}\n'
                             'Move them into tools/prepare-bundle.py, then restore the files with git checkout.')

def install_node_modules(offline):
    tooling = BASE / 'tooling'
    digest = hashlib.sha256((tooling / 'package-lock.json').read_bytes()).hexdigest()
    marker = tooling / 'node_modules/.litefront-lock'
    if marker.exists() and marker.read_text() == digest:
        return
    if offline and not (tooling / 'node_modules/.package-lock.json').exists():
        raise SystemExit('Missing bundled Node dependencies; run fetch-dependencies.py online first')
    if not offline:
        run(*npm_command('ci', '--prefix', str(tooling), '--ignore-scripts', '--no-audit', '--no-fund'))
    marker.write_text(digest)

def download_verified(archive):
    with urllib.request.urlopen(archive['url'], timeout=60) as response:
        data = response.read()
    if hashlib.sha256(data).hexdigest() != archive['sha256']:
        raise SystemExit('Node archive checksum mismatch')
    return data

def fetch_node_runtime(target, offline):
    arch = NODE_ARCHITECTURES.get(platform.machine())
    if not arch:
        raise SystemExit('Bundled runtime supports Linux x86_64 and aarch64')
    windows = target == 'windows'
    if windows and arch != 'x64':
        raise SystemExit('Windows portable builds currently support x86_64 only')
    node = BASE / ('node-windows' if windows else 'node')
    if (node / ('node.exe' if windows else 'node')).exists():
        return
    if offline:
        raise SystemExit('Missing bundled Node runtime')
    data = download_verified(LOCK['windows_node'] if windows else LOCK['node_archives'][arch])
    node.mkdir(exist_ok=True)
    version = LOCK['node_version']
    if windows:
        with zipfile.ZipFile(io.BytesIO(data)) as bundle:
            for name in ['node.exe', 'LICENSE']:
                (node / name).write_bytes(bundle.read(f'node-v{version}-win-x64/{name}'))
        return
    prefix = f'node-v{version}-linux-{arch}/'
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:xz') as tar:
        for suffix in ['bin/node', 'LICENSE']:
            target_file = node / Path(suffix).name
            target_file.write_bytes(tar.extractfile(tar.getmember(prefix + suffix)).read())
            if suffix == 'bin/node':
                target_file.chmod(0o755)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--offline', action='store_true')
    parser.add_argument('--target', choices=['linux', 'windows', 'web'], default='linux')
    args = parser.parse_args()
    fetch_engine(args.offline)
    fetch_repositories(args.offline)
    install_node_modules(args.offline)
    if args.target == 'web':
        print('Browser source dependencies ready')
        return
    run(sys.executable, str(ROOT / 'tools/fetch-github-cli.py'), '--target', args.target,
        *(['--offline'] if args.offline else []))
    fetch_node_runtime(args.target, args.offline)
    print('Bundled Windows dependencies ready' if args.target == 'windows' else 'Bundled dependencies ready')

if __name__ == '__main__':
    main()
