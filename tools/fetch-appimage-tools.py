#!/usr/bin/env python3
"""Fetch checksum-locked AppImage packaging tools into the local build cache."""
import argparse
import hashlib
import json
from pathlib import Path
import platform
import urllib.request
ROOT=Path(__file__).resolve().parent.parent
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--offline',action='store_true')
parser.add_argument('--arch',choices=['x86_64','aarch64'],default=platform.machine())
args=parser.parse_args()
lock=json.loads((ROOT/'tools/appimage-tools.lock.json').read_text())
if args.arch not in lock:parser.error('AppImage builds support x86_64 and aarch64 hosts')
cache=ROOT/'vendor/appimage-tools'/args.arch;cache.mkdir(parents=True,exist_ok=True)
for name,info in lock[args.arch].items():
    destination=cache/(name+('.AppImage' if name!='runtime' else ''))
    if destination.is_file() and hashlib.sha256(destination.read_bytes()).hexdigest()==info['sha256']:
        print(f'Verified cached {name} ({args.arch})');continue
    if args.offline:raise SystemExit(f'Missing verified {name}; run once without --offline to fetch packaging tools.')
    print(f'Fetching {name} ({args.arch}, {info["release"]})...')
    request=urllib.request.Request(info['url'],headers={'User-Agent':'JottaText-AppImage-build'})
    with urllib.request.urlopen(request,timeout=120) as response:data=response.read()
    if hashlib.sha256(data).hexdigest()!=info['sha256']:
        raise SystemExit(f'{name} checksum mismatch. No tool was executed. Check the official release before updating tools/appimage-tools.lock.json.')
    temporary=destination.with_suffix(destination.suffix+'.tmp');temporary.write_bytes(data);temporary.chmod(0o755);temporary.replace(destination)
    print(f'Verified {name}')
