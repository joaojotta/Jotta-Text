#!/usr/bin/env python3
"""Build the per-user Windows installer from the staged portable folder.

Usage: package-windows-installer.py PORTABLE_DIR
Set MAKENSIS to run a different makensis, for example "wine /path/makensis.exe".
"""
import hashlib
import os
from pathlib import Path, PurePosixPath
import shlex
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parent.parent
out=Path(sys.argv[1]).resolve()
version=(ROOT/'VERSION').read_text().strip()
setup=out.parent/f'JottaText-{version}-windows-x64-setup.exe'
stage=out.parent/'windows-installer'
shutil.rmtree(stage,ignore_errors=True)
stage.mkdir()

# user/ beside the exe would make the installed copy portable, keeping settings
# in the program folder; README.txt describes only the ZIP.
PORTABLE_ONLY={'user','README.txt'}
files=sorted(path.relative_to(out) for path in out.rglob('*')
             if path.is_file() and path.relative_to(out).parts[0] not in PORTABLE_ONLY)
if not files:raise SystemExit(f'No files to install in {out}')

# File names become NSIS strings, where a literal $ is written $$.
def windows(relative):return '\\'.join(PurePosixPath(relative).parts).replace('$','$$')
def quote(text):return f'"{text}"'
def target(directory):return '$INSTDIR'+(('\\'+windows(directory)) if directory.parts else '')

# Paths relative to the staging folder: makensis runs there, and the same
# script then works under Windows and under Wine.
source=windows(Path(os.path.relpath(out,stage)).as_posix())
directories={}
for relative in files:directories.setdefault(relative.parent,[]).append(relative)
install=[]
for directory,members in sorted(directories.items()):
    install.append(f'SetOutPath {quote(target(directory))}')
    install.extend(f'File {quote(source+chr(92)+windows(relative))}' for relative in members)
every_directory={parent for relative in files for parent in relative.parents if parent.parts}
uninstall=[f'Delete {quote(target(relative))}' for relative in files]
# Deepest first; RMDir without /r leaves folders holding files the user added.
uninstall.extend(f'RMDir {quote(target(directory))}'
                 for directory in sorted(every_directory,key=lambda item:(-len(item.parts),str(item))))
(stage/'install-files.nsh').write_text('\n'.join(install)+'\n',encoding='utf-8')
(stage/'uninstall-files.nsh').write_text('\n'.join(uninstall)+'\n',encoding='utf-8')
shutil.copy2(ROOT/'tools/windows-installer.nsi',stage/'installer.nsi')
shutil.copy2(ROOT/'vendor/lite-xl/resources/icons/icon.ico',stage/'app.ico')

size_kb=sum((out/relative).stat().st_size for relative in files)//1024
makensis=shlex.split(os.environ.get('MAKENSIS','makensis'))
setup.unlink(missing_ok=True)
subprocess.run([*makensis,'-V2','-WX','-INPUTCHARSET','UTF8',f'-DVERSION={version}',
                f'-DOUTFILE=..\\{setup.name}',f'-DSIZE_KB={size_kb}','installer.nsi'],cwd=stage,check=True)
if not setup.is_file():raise SystemExit(f'makensis did not write {setup.name}')
with setup.open('rb') as stream:digest=hashlib.file_digest(stream,'sha256').hexdigest()
# LF on every platform: sha256sum --check reads a CR as part of the filename.
Path(str(setup)+'.sha256').write_text(f'{digest}  {setup.name}\n',newline='\n')
print(f'Packaged {setup.name} with {len(files)} files')
