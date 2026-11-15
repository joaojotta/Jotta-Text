#!/usr/bin/env python3
"""Exercise real bundled language servers and the editor's completion popup."""
from pathlib import Path
import os,shutil,subprocess,tempfile,argparse
ROOT=Path(__file__).resolve().parent.parent
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--flatpak-build',type=Path)
build=parser.parse_args().flatpak_build
source=build.resolve()/'files' if build else ROOT/'dist/native'
with tempfile.TemporaryDirectory(prefix='litefront-completion-test-') as directory:
    root=Path(directory);app=root/'app';data=app/'share/lite-xl'
    shutil.copytree(source/'share/lite-xl',data,symlinks=True)
    (app/'bin').mkdir()
    for name in ['lite-xl','litefront-file-dialog']:shutil.copy2(source/'bin'/name,app/'bin'/name)
    project=root/'project';project.mkdir()
    (project/'saved.js').write_text('console.\n')
    (project/'starter.html').write_text('!\n')
    user=root/'user'
    init=data/'litefront/init.lua';init.write_text(init.read_text()+'\n'+(ROOT/'tests/completion.lua').read_text())
    env=dict(os.environ,SDL_VIDEODRIVER='dummy',LITE_USERDIR=str(user),LITEFRONT_COMPLETION_PROJECT=str(project))
    invocation=[str(app/'bin/lite-xl')]
    if build:
        invocation=['flatpak','build','--runtime','--readonly',f'--filesystem={root}',f'--bind-mount=/app={app}',
            *[f'--env={key}={env[key]}' for key in ['SDL_VIDEODRIVER','LITE_USERDIR','LITEFRONT_COMPLETION_PROJECT']],str(build.resolve()),'/app/bin/lite-xl']
    result=subprocess.run(invocation,cwd=project,env=env,capture_output=True,text=True,timeout=70)
    report=user/'completion-test.txt'
    assert result.returncode==0 and report.exists(),result.stderr+result.stdout
    assert report.read_text()=='PASS\n',report.read_text()
    print('PASS: Tab/Enter/keypad completion acceptance, normal indentation/newlines, HTML starter tabstops, embedded CSS properties/values in style blocks and attributes, automatic/saved/untitled completion, JavaScript boundaries and no hidden saved buffers')
