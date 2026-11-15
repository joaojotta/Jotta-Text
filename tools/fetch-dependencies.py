#!/usr/bin/env python3
"""Build-time fetch only. Installed Jotta Text has no dependency installer."""
import argparse
import hashlib
import io
import json
import platform
from pathlib import Path
import subprocess
import sys
import tarfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parent.parent
BASE = ROOT / 'vendor/litefront'
LOCK = json.loads((ROOT / 'tools/dependencies.lock.json').read_text())

def run(*args):
    subprocess.run(args, check=True, cwd=ROOT)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--offline', action='store_true')
    parser.add_argument('--target', choices=['linux','windows','web'], default='linux')
    args = parser.parse_args()
    upstream = ROOT / 'vendor/lite-xl'
    if not (upstream / 'data/core/init.lua').exists():
        if args.offline:
            raise SystemExit('Missing Lite XL source')
        # A cache restore may already have created subprojects/packagecache.
        # Initializing/fetching also handles that nonempty, source-free directory.
        revision=json.loads((ROOT/'tools/lite-xl-files.json').read_text())['commit']
        run('git','init',str(upstream))
        run('git','-C',str(upstream),'fetch','--depth=1','https://github.com/lite-xl/lite-xl.git',revision)
        run('git','-C',str(upstream),'-c','core.autocrlf=false','-c','core.eol=lf','checkout','--detach','FETCH_HEAD')
    run(sys.executable,str(ROOT/'tools/apply-lite-xl-patch.py'))
    for repo in LOCK['repositories']:
        dest = BASE / repo['path']
        if not (dest / '.git').exists():
            if args.offline:
                raise SystemExit(f'Missing bundled source: {dest}')
            dest.mkdir(parents=True, exist_ok=True)
            run('git', 'init', str(dest))
            run('git', '-C', str(dest), 'remote', 'add', 'origin', repo['url'])
            run('git', '-C', str(dest), 'fetch', '--depth=1', 'origin', repo['commit'])
            run('git', '-C', str(dest), '-c', 'core.autocrlf=false', '-c', 'core.eol=lf', 'checkout', '--detach', 'FETCH_HEAD')
        actual = subprocess.check_output(['git', '-C', str(dest), 'rev-parse', 'HEAD'], text=True).strip()
        if actual != repo['commit']:
            raise SystemExit(f'Source revision mismatch: {dest}')
    tooling = BASE / 'tooling'
    digest = hashlib.sha256((tooling / 'package-lock.json').read_bytes()).hexdigest()
    marker = tooling / 'node_modules/.litefront-lock'
    if not marker.exists() or marker.read_text() != digest:
        if args.offline and not (tooling / 'node_modules/.package-lock.json').exists():
            raise SystemExit('Missing bundled Node dependencies; run fetch-dependencies.py online first')
        if not args.offline:
            run('npm', 'ci', '--prefix', str(tooling), '--ignore-scripts', '--no-audit', '--no-fund')
        marker.write_text(digest)
    if args.target=='web':
        print('Browser source dependencies ready')
        return
    run(sys.executable, str(ROOT/'tools/fetch-github-cli.py'), '--target', args.target,
        *(['--offline'] if args.offline else []))
    arch = {'x86_64': 'x64', 'AMD64':'x64', 'aarch64': 'arm64', 'ARM64':'arm64'}.get(platform.machine())
    if not arch:
        raise SystemExit('Bundled runtime supports Linux x86_64 and aarch64')
    if args.target=='windows' and arch!='x64':
        raise SystemExit('Windows portable builds currently support x86_64 only')
    node = BASE / ('node-windows' if args.target=='windows' else 'node')
    node_binary = 'node.exe' if args.target=='windows' else 'node'
    if not (node / node_binary).exists():
        if args.offline:
            raise SystemExit('Missing bundled Node runtime')
        archive = LOCK['windows_node'] if args.target=='windows' else LOCK['node_archives'][arch]
        data = urllib.request.urlopen(archive['url'], timeout=60).read()
        if hashlib.sha256(data).hexdigest() != archive['sha256']:
            raise SystemExit('Node archive checksum mismatch')
        node.mkdir(exist_ok=True)
        if args.target=='windows':
            with zipfile.ZipFile(io.BytesIO(data)) as archive:
                for name in ['node.exe','LICENSE']:
                    (node/name).write_bytes(archive.read(f"node-v{LOCK['node_version']}-win-x64/{name}"))
            print('Bundled Windows dependencies ready')
            return
        prefix = f"node-v{LOCK['node_version']}-linux-{arch}/"
        with tarfile.open(fileobj=io.BytesIO(data), mode='r:xz') as tar:
            for suffix in ['bin/node', 'LICENSE']:
                contents = tar.extractfile(tar.getmember(prefix + suffix)).read()
                target = node / Path(suffix).name
                target.write_bytes(contents)
                if suffix == 'bin/node':
                    target.chmod(0o755)
    print('Bundled dependencies ready')

if __name__ == '__main__':
    main()
