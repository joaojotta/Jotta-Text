#!/usr/bin/env python3
"""Bundle the official, checksum-pinned GitHub CLI for desktop browser sign-in."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import platform
import tarfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parent.parent
LOCK = json.loads((ROOT / 'tools/github-cli.lock.json').read_text())

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target', choices=['linux', 'windows'], default='linux')
    parser.add_argument('--offline', action='store_true')
    args = parser.parse_args()
    arch = {'x86_64': 'x64', 'AMD64': 'x64', 'aarch64': 'arm64', 'ARM64': 'arm64'}.get(platform.machine())
    info = LOCK['archives'].get(f'{args.target}-{arch}')
    if not info:
        raise SystemExit('GitHub sign-in supports Linux x86_64/arm64 and Windows x64')
    out = ROOT / 'vendor/litefront' / ('github-cli-windows' if args.target == 'windows' else 'github-cli')
    binary = out / ('gh.exe' if args.target == 'windows' else 'gh')
    marker = out / 'checksum.json'
    if binary.is_file() and marker.is_file():
        saved = json.loads(marker.read_text())
        if saved.get('archive') == info['sha256'] and saved.get('binary') == hashlib.sha256(binary.read_bytes()).hexdigest():
            print('Verified bundled GitHub CLI')
            return
    if args.offline:
        raise SystemExit('Missing verified GitHub CLI; run fetch-github-cli.py online once')
    url = f"https://github.com/cli/cli/releases/download/v{LOCK['version']}/{info['name']}"
    data = urllib.request.urlopen(url, timeout=90).read()
    if hashlib.sha256(data).hexdigest() != info['sha256']:
        raise SystemExit('GitHub CLI archive checksum mismatch')
    if args.target == 'windows':
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            contents = archive.read('bin/gh.exe')
            license_text = archive.read('LICENSE')
    else:
        with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as archive:
            def extract(suffix):
                members = [item for item in archive.getmembers() if item.isfile() and item.name.endswith('/' + suffix)]
                if len(members) != 1:
                    raise SystemExit(f'Unexpected GitHub CLI archive layout: {suffix}')
                return archive.extractfile(members[0]).read()
            contents, license_text = extract('bin/gh'), extract('LICENSE')
    out.mkdir(parents=True, exist_ok=True)
    binary.write_bytes(contents)
    binary.chmod(0o755)
    (out / 'LICENSE').write_bytes(license_text)
    (out / 'VERSION').write_text(LOCK['version'] + '\n')
    marker.write_text(json.dumps({'archive': info['sha256'], 'binary': hashlib.sha256(contents).hexdigest()}) + '\n')
    print(f"Bundled official GitHub CLI {LOCK['version']} ({args.target}-{arch})")

if __name__ == '__main__':
    main()
