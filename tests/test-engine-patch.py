#!/usr/bin/env python3
"""Apply the real engine patch with Windows checkout settings and CRLF input."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT=Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='jotta-text-patch-') as directory:
    for crlf in (False,True):
        checkout=Path(directory)/('windows-patch' if crlf else 'lf-patch')
        tools=checkout/'tools';tools.mkdir(parents=True)
        for name in ('apply-lite-xl-patch.py','lite-xl-files.json','lite-xl.patch'):
            shutil.copy2(ROOT/'tools'/name,tools/name)
        if crlf:
            patch=tools/'lite-xl.patch'
            patch.write_bytes(patch.read_bytes().replace(b'\r\n',b'\n').replace(b'\n',b'\r\n'))
        source=checkout/'vendor/lite-xl'
        subprocess.run(['git','clone','--quiet','--shared','--no-checkout',str(ROOT/'vendor/lite-xl'),str(source)],check=True)
        subprocess.run(['git','-C',str(source),'config','core.autocrlf','true'],check=True)
        subprocess.run(['git','-C',str(source),'-c','core.autocrlf=false','-c','core.eol=lf','checkout','--quiet','--detach','HEAD'],check=True)
        # The helper verifies every baseline and patched file against the manifest.
        for _ in range(2):  # the second run checks idempotence
            subprocess.run([sys.executable,str(tools/'apply-lite-xl-patch.py')],check=True)
        print('PASS: engine patch application/idempotence with', 'CRLF input' if crlf else 'LF input', 'and Windows Git settings')
