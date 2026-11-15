#!/usr/bin/env python3
"""Verify the Windows ZIP independently of the MSYS2 build environment."""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile
import argparse
ROOT=Path(__file__).resolve().parent.parent
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--wine',action='store_true',help='Test a cross-built ZIP using an isolated Wine prefix')
args=parser.parse_args()
wine=shutil.which('wine') if args.wine else None
if os.name!='nt' and not wine:raise SystemExit('Run this test on Windows, or pass --wine with Wine installed.')
version=(ROOT/'VERSION').read_text().strip()
archive=ROOT/f'dist/JottaText-{version}-windows-x64-portable.zip'
with archive.open('rb') as stream:digest=hashlib.file_digest(stream,'sha256').hexdigest()
assert digest==Path(str(archive)+'.sha256').read_text().split()[0]
checksum=Path(str(archive)+'.sha256').read_bytes()
assert checksum==f'{digest}  {archive.name}\n'.encode(),('checksum file must be one LF-terminated line',checksum)
with tempfile.TemporaryDirectory(prefix='Jotta portátil test ') as directory:
    temp=Path(directory)
    with zipfile.ZipFile(archive) as zipped:zipped.extractall(temp)
    app=temp/archive.stem;data=app/'data';user=app/'user'
    assert (app/'JottaText.exe').read_bytes()[:2]==b'MZ'
    assert (app/'litefront-file-dialog.exe').is_file()
    assert (data/'litefront/VERSION').read_text().strip()==version
    env=dict(os.environ,SDL_VIDEODRIVER='dummy')
    prefix=[]
    if wine:
        env.update(WINEPREFIX=str(temp/'wine-prefix'),WINEDEBUG='-all',WINEDLLOVERRIDES='mscoree,mshtml=')
        prefix=[wine]
        subprocess.run([wine,'wineboot','-u'],env=env,capture_output=True,timeout=60)
    else:env['PATH']=str(Path(os.environ['SystemRoot'])/'System32')
    node=subprocess.run([*prefix,str(data/'litefront/node/node.exe'),'--version'],env=env,capture_output=True,text=True,timeout=30)
    assert node.returncode==0 and node.stdout.startswith('v24.'),(node.stdout,node.stderr)
    # The injected harness lives only in this disposable extraction.
    init=data/'litefront/init.lua'
    init.write_text(init.read_text()+r'''
local core=require 'core'
core.add_thread(function()
 coroutine.yield(.5)
 local ok,err=xpcall(function()
  assert(PLATFORM=='Windows')
  assert(USERDIR:gsub('\\','/'):lower()==(EXEDIR..'/user'):gsub('\\','/'):lower(),'settings escaped the portable folder')
  local style=require 'core.style'
  assert(style.font:get_path():find('Rubik',1,true))
  assert(style.code_font:get_path():find('JetBrainsMono',1,true))
  local phase=os.getenv('JOTTA_TEST_PHASE')
  if phase=='1' then
    local doc=core.open_doc();core.root_view:open_doc(doc)
    require('plugins.litefront_workspace').set_language(doc,require('core.syntax').get('example.js'))
    doc:text_input('const portable=42')
    assert(require('core.command').perform('litefront:format-prettier'))
    local deadline=system.get_time()+15
    while table.concat(doc.lines)~='const portable = 42;\n' and system.get_time()<deadline do coroutine.yield(.05) end
    assert(table.concat(doc.lines)=='const portable = 42;\n','bundled formatter failed')
    assert(not doc.filename and doc:is_dirty(),'formatter saved an untitled document')
    assert(require('litefront.session').save())
    doc:text_input('// latest change')
    assert(require('litefront.session').save(),'Windows could not replace its previous recovery snapshot')
  else
    local restored=false
    for _,doc in ipairs(core.docs) do if table.concat(doc.lines):find('// latest change',1,true) then restored=true end end
    assert(restored,'portable restart did not restore unsaved edits')
  end
  for _,item in ipairs(core.log_items) do assert(item.level~='ERROR',item.text) end
 end,debug.traceback)
 local out=assert(io.open(USERDIR..'/test-result','w'));out:write(ok and 'PASS' or tostring(err));out:close()
 core.quit(true)
end)
''')
    for phase in ['1','2']:
        (user/'test-result').unlink(missing_ok=True)
        env['JOTTA_TEST_PHASE']=phase
        result=subprocess.run([*prefix,str(app/'JottaText.exe')],cwd=temp,env=env,capture_output=True,text=True,timeout=30)
        assert result.returncode==0 and (user/'test-result').is_file(),(result.returncode,result.stdout,result.stderr)
        assert (user/'test-result').read_text()=='PASS',(user/'test-result').read_text()
    print('PASS: portable ZIP checksum, isolated DLL loading, Unicode/space paths, fonts, bundled Node, untitled formatting and recovery across restarts')
