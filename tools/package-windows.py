#!/usr/bin/env python3
"""Collect PE import dependencies, notices and a clean portable ZIP."""
import hashlib
from pathlib import Path
import re
import shutil
import subprocess
import sys
import zipfile

out,prefix=map(lambda value:Path(value).resolve(),sys.argv[1:])
# Imports supplied by Windows 10/11 itself. Unknown missing DLLs fail the build.
system=set('advapi32 avrt bcrypt cabinet cfgmgr32 comctl32 comdlg32 crypt32 cryptbase d2d1 d3d11 d3d12 dcomp dbghelp dnsapi dsound dwmapi dwrite dxgi dxva2 gdi32 gdiplus glu32 hid imm32 iphlpapi kernel32 ksuser mf mfplat mfreadwrite mfuuid mmdevapi mpr msimg32 msvcrt mswsock ncrypt netapi32 normaliz ntdll ole32 oleacc oleaut32 opengl32 powrprof propsys psapi rpcrt4 secur32 setupapi shell32 shlwapi strmiids ucrtbase user32 userenv usp10 uxtheme version win32u windowscodecs winhttp wininet winmm winspool wintrust wldap32 ws2_32 wtsapi32'.split())
available={path.name.lower():path for path in (prefix/'bin').glob('*.dll')}
system.update(['bcryptprimitives'])
visited=set()

def collect(binary,destination):
    key=(binary.name.lower(),str(destination))
    if key in visited:return
    visited.add(key)
    text=subprocess.check_output(['objdump','-p',str(binary)],text=True)
    for name in re.findall(r'DLL Name:\s*(\S+)',text):
        low=name.lower()
        if low.removesuffix('.dll') in system or low.startswith(('api-ms-win-','ext-ms-win-')):continue
        source=available.get(low)
        if source is None:raise SystemExit(f'Unresolved runtime dependency: {name}, required by {binary.name}')
        target=destination/source.name
        if not target.is_file():shutil.copy2(source,target)
        collect(source,destination)

for binary in list(out.rglob('*.exe')):collect(binary,binary.parent)
licenses=prefix/'share/licenses'
if licenses.is_dir():shutil.copytree(licenses,out/'data/litefront/licenses/windows-libraries',dirs_exist_ok=True)
(out/'user/README.txt').write_text('Jotta Text stores settings, open folders and unsaved document recovery here.\nKeep this directory when upgrading. No user Lua or plugins are executed.\n')
(out/'README.txt').write_text('Jotta Text portable for Windows 10/11 x64\n\nExtract the entire ZIP to a writable folder and run JottaText.exe.\nNo installation, administrator access or separately installed Node is needed.\nSettings and recovered documents are in user/. Back it up before replacing\nthis folder during upgrades. Your source projects remain in their own folders.\n')
archive=Path(str(out)+'.zip')
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as zipped:
    for path in sorted(out.rglob('*')):
        if path.is_file():zipped.write(path,path.relative_to(out.parent))
with archive.open('rb') as stream:digest=hashlib.file_digest(stream,'sha256').hexdigest()
Path(str(archive)+'.sha256').write_text(f'{digest}  {archive.name}\n')
print(f'Packaged {archive.name} with {len(visited)} checked PE dependency trees')
