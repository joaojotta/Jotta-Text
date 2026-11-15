#!/usr/bin/env python3
"""Stage patched sources with Lite XL's Windows UTF-8 Lua support."""
from pathlib import Path
import shutil
import subprocess

ROOT=Path(__file__).resolve().parent.parent
source=ROOT/'dist/windows-source'
shutil.rmtree(source,ignore_errors=True)
shutil.copytree(ROOT/'vendor/lite-xl',source,ignore=shutil.ignore_patterns('.git','.wraplock','__pycache__'))
lua=source/'subprojects/lua-5.4.4'
if not lua.is_dir():
    raise SystemExit('Run meson subprojects download --sourcedir vendor/lite-xl first.')
if not (lua/'src/utf8_wrappers.c').is_file():
    patch=(source/'resources/windows/001-lua-unicode.diff').read_text()
    patch=''.join(line.replace('\\','/') if line.startswith(('diff ','--- ','+++ ')) else line for line in patch.splitlines(keepends=True))
    # Send literal LF bytes: Windows text-mode pipes would translate the patch
    # to CRLF even when the source checkout uses LF.
    subprocess.run(['patch','-p1','--binary','--batch','--forward'],cwd=lua,input=patch.encode('utf-8'),check=True)
# Recovery/settings replace their previous snapshot atomically on Windows too.
wrapper=lua/'src/utf8_wrappers.c'
text=wrapper.read_text()
text=text.replace('return _wrename(oldpath_w, newpath_w);', '''if (MoveFileExW(oldpath_w, newpath_w, MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)) return 0;
    DWORD failure=GetLastError();
    errno=(failure==ERROR_FILE_NOT_FOUND || failure==ERROR_PATH_NOT_FOUND)?ENOENT:
      failure==ERROR_ALREADY_EXISTS?EEXIST:failure==ERROR_DISK_FULL?ENOSPC:EACCES;
    return -1;''')
wrapper.write_text(text)
manifest=source/'resources/windows/lite-xl.exe.manifest.in'
text=manifest.read_text().replace('LiteXL.LiteXL.LiteXL','JottaText.JottaText')
text=text.replace('@PROJECT_ASSEMBLY_VERSION@',(ROOT/'VERSION').read_text().strip()+'.0')
manifest.write_text(text)
