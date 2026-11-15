#!/usr/bin/env python3
"""Exercise real bundled language servers and the editor's completion popup."""
from pathlib import Path
import os,shutil,subprocess,tempfile
ROOT=Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='litefront-completion-test-') as directory:
    root=Path(directory);app=root/'app';data=app/'share/lite-xl'
    shutil.copytree(ROOT/'dist/native/share/lite-xl',data,symlinks=True)
    (app/'bin').mkdir()
    for name in ['lite-xl','litefront-file-dialog']:shutil.copy2(ROOT/'dist/native/bin'/name,app/'bin'/name)
    project=root/'project';project.mkdir()
    (project/'saved.js').write_text('console.\n')
    (project/'starter.html').write_text('!\n')
    user=root/'user'
    init=data/'litefront/init.lua';init.write_text(init.read_text()+'\n'+(ROOT/'tests/completion.lua').read_text())
    result=subprocess.run([str(app/'bin/lite-xl')],cwd=project,
        env=dict(os.environ,SDL_VIDEODRIVER='dummy',LITE_USERDIR=str(user),LITEFRONT_COMPLETION_PROJECT=str(project)),
        capture_output=True,text=True,timeout=55)
    report=user/'completion-test.txt'
    assert result.returncode==0 and report.exists(),result.stderr+result.stdout
    assert report.read_text()=='PASS\n',report.read_text()
    print('PASS: HTML ! + Tab template and tabstops, saved/untitled files, normal Tab fallback; real JavaScript, HTML, CSS and TypeScript completion; no hidden saved buffers or project indexing')
