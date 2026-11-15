#!/usr/bin/env python3
"""Generate Jotta Text desktop, native-window and in-app icons from icons/icon.svg.
Build-time requirements: rsvg-convert and Pillow. No runtime image dependencies.
"""
from pathlib import Path
import io
import shutil
import subprocess
from PIL import Image

ROOT=Path(__file__).resolve().parent.parent
SOURCE=ROOT/'icons/icon.svg'
APP_ID='io.github.joaojotta.JottaText'

def raster(size):
    data=subprocess.check_output(['rsvg-convert','--width',str(size),'--height',str(size),str(SOURCE)])
    return data,Image.open(io.BytesIO(data)).convert('RGBA')

def main():
    if not SOURCE.is_file():
        raise SystemExit('Missing application icon: icons/icon.svg')
    assets=ROOT/'profile/assets/app-icons'
    assets.mkdir(parents=True,exist_ok=True)
    shutil.copy2(SOURCE,assets/'jotta-text.svg')
    shutil.copy2(SOURCE,ROOT/'flatpak'/f'{APP_ID}.svg')
    for size in (32,48,64,128,256,512):
        png,image=raster(size)
        (assets/f'jotta-text-{size}.png').write_bytes(png)
        if size==256:
            image.save(ROOT/'vendor/lite-xl/resources/icons/icon.ico',format='ICO',sizes=[(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)])
        if size==64:
            raw=image.tobytes()
            lines=[', '.join(f'0x{value:02x}' for value in raw[i:i+16])+',' for i in range(0,len(raw),16)]
            (ROOT/'vendor/lite-xl/resources/icons/icon.inl').write_text(
                '// Generated from icons/icon.svg by tools/build-app-icons.py.\n'
                'static unsigned char icon_rgba[] = {\n'+ '\n'.join(lines)+'\n};\n'
                f'static unsigned int icon_rgba_len = {len(raw)};\n')
    # Lite XL renders rectangles/text only. Lossless pixel runs retain SVG glow,
    # colors and transparency in the welcome/header logos without a new renderer.
    output=['-- Generated from icons/icon.svg; do not edit.\nreturn {\n']
    for size in (20,40,100,200):
        _,image=raster(size)
        pixels=image.load()
        output.append(f'[{size}]={{\n')
        for y in range(size):
            x=0
            while x<size:
                color=pixels[x,y]
                end=x+1
                while end<size and pixels[end,y]==color: end+=1
                if color[3]:
                    output.append('{'+','.join(str(v) for v in (x,y,end-x,*color))+'},\n')
                x=end
        output.append('},\n')
    output.append('}\n')
    (ROOT/'profile/litefront/app-logo.lua').write_text(''.join(output))
    print('Generated Jotta Text app icons from icons/icon.svg')

if __name__=='__main__': main()
