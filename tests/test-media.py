#!/usr/bin/env python3
"""Exercise image/font tabs, binary isolation and recovery in the actual editor."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import shlex
import subprocess
import tempfile
from PIL import Image
ROOT=Path(__file__).resolve().parent.parent
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--flatpak-build',type=Path)
options=parser.parse_args()
build=options.flatpak_build.resolve() if options.flatpak_build else None
source=build/'files' if build else ROOT/'dist/native'
with tempfile.TemporaryDirectory(prefix='jotta-text-media-') as directory:
    temp=Path(directory);app=temp/'app';data=app/'share/lite-xl'
    shutil.copytree(source/'share/lite-xl',data,symlinks=True)
    (app/'bin').mkdir(parents=True)
    shutil.copy2(source/'bin/lite-xl',app/'bin/lite-xl')
    user=temp/'user';user.mkdir()
    project=temp/'media';project.mkdir()
    image=Image.new('RGBA',(32,24),(240,80,20,120))
    for ext,fmt in [('png','PNG'),('gif','GIF'),('bmp','BMP'),('webp','WEBP'),('ico','ICO'),('tiff','TIFF')]:image.save(project/f'sample.{ext}',format=fmt)
    image.convert('RGB').save(project/'sample.jpg')
    (project/'sample.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 24"><rect x="2" y="2" width="28" height="20" fill="#f05014" fill-opacity=".5"/></svg>')
    shutil.copy2(ROOT/'fonts/Rubik-VariableFont_wght.ttf',project/'Rubik.ttf')
    (project/'broken.png').write_bytes(b'not an image')
    (project/'broken.ttf').write_bytes(b'not a font')
    (project/'note.txt').write_text('Source document\n')
    digest=lambda:{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in project.iterdir()}
    before=digest()
    if not build:
        flags=shlex.split(subprocess.check_output(['pkg-config','--cflags','--libs','sdl2','librsvg-2.0','libwebp','libtiff-4'],text=True))
        check=temp/'check-image'
        subprocess.run(['cc','-O2','-I'+str(ROOT/'vendor/lite-xl/src'),str(ROOT/'tests/image-renderer.c'),str(ROOT/'vendor/lite-xl/src/image.c'),'-o',str(check),*flags,'-lm'],check=True,capture_output=True,text=True)
        subprocess.run([str(check),str(project/'sample.png')],check=True,capture_output=True,text=True)

    init=data/'litefront/init.lua'
    init.write_text(init.read_text()+r'''
local core=require 'core'
core.add_thread(function()
 coroutine.yield(0.25)
 local ok,err=pcall(function()
'''+(ROOT/'tests/media.lua').read_text()+r'''
 end)
 local out=assert(io.open(USERDIR..'/result','w'))
 out:write(ok and 'PASS' or tostring(err))
 if not ok then for _,item in ipairs(core.log_items) do out:write('\n'..item.level..': '..item.text) end end
 out:close();core.quit()
end)
''')
    for phase in ['1','2','3']:
        env=dict(os.environ,SDL_VIDEODRIVER='dummy',LITE_USERDIR=str(user),MEDIA_ROOT=str(project),MEDIA_PHASE=phase)
        invocation=[str(app/'bin/lite-xl')]
        if build:
            invocation=['flatpak','build','--runtime','--readonly',f'--filesystem={temp}',f'--bind-mount=/app={app}',
                *[f'--env={key}={env[key]}' for key in ['SDL_VIDEODRIVER','LITE_USERDIR','MEDIA_ROOT','MEDIA_PHASE']],str(build),'/app/bin/lite-xl']
        (user/'result').unlink(missing_ok=True)
        result=subprocess.run(invocation,env=env,capture_output=True,text=True,timeout=15)
        assert result.returncode==0,(result.stderr,result.stdout)
        assert (user/'result').read_text()=='PASS',(user/'result').read_text()
        assert digest()==before,'preview modified a source file'
    print('PASS: image formats, font specimens, zoom/pan, theme changes, invalid files, binary isolation and session recovery')
