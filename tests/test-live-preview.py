#!/usr/bin/env python3
"""Exercise real editor changes through the preview IPC and HTTP server."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
from urllib.request import urlopen
ROOT=Path(__file__).resolve().parent.parent
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--flatpak-build',type=Path)
options=parser.parse_args()
build=options.flatpak_build.resolve() if options.flatpak_build else None
source=build/'files' if build else ROOT/'dist/native'
with tempfile.TemporaryDirectory(prefix='jotta-text-live-preview-') as directory:
    temp=Path(directory);app=temp/'app';data=app/'share/lite-xl'
    shutil.copytree(source/'share/lite-xl',data,symlinks=True)
    (app/'bin').mkdir(parents=True);shutil.copy2(source/'bin/lite-xl',app/'bin/lite-xl')
    user=temp/'user';user.mkdir();project=temp/'project';project.mkdir()
    originals={'index.html':'<h1>Saved HTML</h1>\n','style.css':'body { color: black; }\n','app.js':'console.log("saved")\n'}
    for name,text in originals.items():(project/name).write_text(text)
    init=data/'litefront/init.lua'
    init.write_text(init.read_text()+r'''
local core=require 'core'
core.add_thread(function()
 coroutine.yield(.2)
 local ok,err=pcall(function()
'''+(ROOT/'tests/live-preview.lua').read_text()+r'''
 end)
 if not ok then local out=io.open(USERDIR..'/result','w');out:write(tostring(err));out:close();core.quit() end
end)
''')
    env=dict(os.environ,SDL_VIDEODRIVER='dummy',LITE_USERDIR=str(user),LITEFRONT_PREVIEW_PORT='0',LITEFRONT_PREVIEW_BROWSER='/usr/bin/true')
    invocation=[str(app/'bin/lite-xl'),str(project)]
    if build:
        invocation=['flatpak','build','--runtime','--readonly','--share=network',f'--filesystem={temp}',f'--bind-mount=/app={app}',
            *[f'--env={key}={env[key]}' for key in ['SDL_VIDEODRIVER','LITE_USERDIR','LITEFRONT_PREVIEW_PORT','LITEFRONT_PREVIEW_BROWSER']],str(build),'/app/bin/lite-xl',str(project)]
    child=subprocess.Popen(invocation,env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    def wait_for(test,timeout=8):
        deadline=time.monotonic()+timeout
        while time.monotonic()<deadline:
            if child.poll() is not None:
                output,errors=child.communicate()
                raise AssertionError((user/'result').read_text() if (user/'result').exists() else output+errors)
            try:
                value=test()
                if value:return value
            except (OSError,ValueError):pass
            time.sleep(.04)
        raise AssertionError('Timed out waiting for preview update')
    def read(url):
        with urlopen(url,timeout=2) as response:return response.read().decode()
    def action(name):
        (user/'action').write_text(name)
        wait_for(lambda:(user/'ack').exists() and (user/'ack').read_text()==name)
    try:
        url=wait_for(lambda:(user/'url').read_text() if (user/'url').exists() else None)
        origin=url.split('/',3)[:3];base='/'.join(origin)
        assert 'Initial unsaved é' in read(url)
        assert read(base+'/style.css').strip()=='body { color: red; }'
        assert 'initial unsaved' in read(base+'/app.js')
        old=read(base+'/__litefront_status')
        action('edit')
        wait_for(lambda:'Changed while typing' in read(url))
        assert read(base+'/style.css').strip()=='body { color: green; }'
        assert 'changed while typing' in read(base+'/app.js')
        assert read(base+'/__litefront_status')!=old
        action('discard-css')
        wait_for(lambda:read(base+'/style.css')==originals['style.css'])
        action('undo')
        expected=(user/'expected-undo').read_text()
        wait_for(lambda:read(url).split('<script data-litefront-reload>')[0]==expected)
        action('untitled');untitled=(user/'untitled-url').read_text()
        wait_for(lambda:'Untitled HTML' in read(untitled))
        action('edit-untitled');wait_for(lambda:'Untitled live update' in read(untitled))
        assert {name:(project/name).read_text() for name in originals}==originals,'preview saved source files'
        assert sorted(p.name for p in project.iterdir())==sorted(originals),'preview wrote hidden project files'
        (user/'action').write_text('quit');child.wait(timeout=10)
        assert child.returncode==0 and (user/'result').read_text()=='PASS'
        print('PASS: real unsaved HTML/CSS/JS edits, reload versions, discarded buffers, undo, untitled HTML and unchanged source files')
    finally:
        if child.poll() is None:child.terminate();child.wait(timeout=5)
