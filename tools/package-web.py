#!/usr/bin/env python3
import hashlib
from pathlib import Path
import shutil
import zipfile
ROOT=Path(__file__).resolve().parent.parent
source=ROOT/'dist/web-build/src'
# Keep Emscripten's original output basename: its JS locates .wasm/.data by name.
for suffix in ['js','wasm','data']:
    path=source/f'lite-xl.{suffix}'
    if not path.is_file():raise SystemExit(f'Expected Emscripten output is missing: {path}')
    shutil.copy2(path,ROOT/'dist/web'/path.name)
(ROOT/'dist/web/jotta-text.js').write_text("// Compatibility entry point; Emscripten assets retain their generated names.\n"+
    "var script=document.createElement('script');script.src=new URL('lite-xl.js',document.currentScript.src).href;document.head.append(script);\n")
archive=ROOT/f"dist/JottaText-{(ROOT/'VERSION').read_text().strip()}-web.zip"
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as zipped:
    for path in sorted((ROOT/'dist/web').rglob('*')):
        if path.is_file():zipped.write(path,path.relative_to(ROOT/'dist/web'))
with archive.open('rb') as stream:digest=hashlib.file_digest(stream,'sha256').hexdigest()
Path(str(archive)+'.sha256').write_text(f'{digest}  {archive.name}\n')
print(f'Built {archive.name}')
