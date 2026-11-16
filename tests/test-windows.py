#!/usr/bin/env python3
"""Verify the Windows ZIP and installer independently of the MSYS2 build environment."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile
ROOT=Path(__file__).resolve().parent.parent
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--wine',action='store_true',help='Test cross-built packages using an isolated Wine prefix')
parser.add_argument('--dist',type=Path,default=ROOT/'dist',help='Directory holding the packages (default: dist/)')
parser.add_argument('--portable-only',action='store_true',help='Skip the installer, for builds without makensis')
args=parser.parse_args()
wine=shutil.which('wine') if args.wine else None
if os.name!='nt' and not wine:raise SystemExit('Run this test on Windows, or pass --wine with Wine installed.')
version=(ROOT/'VERSION').read_text().strip()
archive=args.dist/f'JottaText-{version}-windows-x64-portable.zip'
setup=args.dist/f'JottaText-{version}-windows-x64-setup.exe'
UNINSTALL_KEY=r'HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\JottaText'
PORTABLE_ONLY={'user','README.txt'}

# Appended to data/litefront/init.lua of a disposable copy. JOTTA_TEST_USERDIR
# is where this package must keep settings (default: the portable user/ folder);
# phase 1 leaves an unsaved edit that phase 2 must recover.
HARNESS=r'''
local core=require 'core'
core.add_thread(function()
 coroutine.yield(.5)
 local ok,err=xpcall(function()
  assert(PLATFORM=='Windows')
  local function same(path)return path:gsub('\\','/'):lower() end
  assert(same(USERDIR)==same(os.getenv('JOTTA_TEST_USERDIR') or (EXEDIR..'/user')),'settings are in '..USERDIR)
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
    assert(restored,'restart did not restore unsaved edits')
  end
  for _,item in ipairs(core.log_items) do assert(item.level~='ERROR',item.text) end
 end,debug.traceback)
 local out=assert(io.open(USERDIR..'/test-result','w'));out:write(ok and 'PASS' or tostring(err));out:close()
 core.quit(true)
end)
'''

def check_checksum(package):
    with package.open('rb') as stream:digest=hashlib.file_digest(stream,'sha256').hexdigest()
    checksum=Path(str(package)+'.sha256').read_bytes()
    assert checksum==f'{digest}  {package.name}\n'.encode(),('checksum file must be one LF-terminated line',checksum)

def windows_path(path):return 'Z:'+str(path).replace('/','\\') if wine else str(path)

def run(command,timeout,**changes):
    return subprocess.run([*prefix,*map(str,command)],env=dict(env,**changes),capture_output=True,text=True,timeout=timeout)

def inject_harness(app):
    init=app/'data/litefront/init.lua'
    init.write_text(init.read_text()+HARNESS)

def run_editor(app,userdir,phase,**changes):
    result_file=userdir/'test-result'
    result_file.unlink(missing_ok=True)
    result=run([app/'JottaText.exe'],30,JOTTA_TEST_PHASE=phase,**changes)
    assert result.returncode==0 and result_file.is_file(),(result.returncode,result.stdout,result.stderr)
    assert result_file.read_text()=='PASS',result_file.read_text()

def registry_value(key,name):
    result=run(['reg','query',key,'/v',name],30)
    if result.returncode!=0:return None
    line=next(line for line in result.stdout.splitlines() if line.strip().startswith(name))
    return line.split('REG_',1)[1].split(None,1)[1].strip()

def start_menu_shortcut():
    programs=registry_value(r'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders','Programs')
    if wine:programs=subprocess.run(['winepath','-u',programs],env=env,capture_output=True,text=True,check=True).stdout.strip()
    return Path(programs)/'Jotta Text.lnk'

def same_path(windows_value,path):
    # Windows runners use 8.3 temp names (RUNNER~1), so resolve before comparing.
    if wine:return windows_value.lower()==windows_path(path).lower()
    return Path(windows_value).resolve()==path.resolve()

def installed_files(directory):
    return sorted(path.relative_to(directory).as_posix() for path in directory.rglob('*') if path.is_file())

def test_portable(temp):
    check_checksum(archive)
    with zipfile.ZipFile(archive) as zipped:zipped.extractall(temp)
    app=temp/archive.stem;data=app/'data'
    assert (app/'JottaText.exe').read_bytes()[:2]==b'MZ'
    assert (app/'litefront-file-dialog.exe').is_file()
    assert (data/'litefront/VERSION').read_text().strip()==version
    node=run([data/'litefront/node/node.exe','--version'],30)
    assert node.returncode==0 and node.stdout.startswith('v24.'),(node.stdout,node.stderr)
    inject_harness(app)
    for phase in ['1','2']:run_editor(app,app/'user',phase)
    print('PASS: portable ZIP checksum, isolated DLL loading, Unicode/space paths, fonts, bundled Node, untitled formatting and recovery across restarts')

def test_installer(temp):
    check_checksum(setup)
    assert setup.read_bytes()[:2]==b'MZ'
    with zipfile.ZipFile(archive) as zipped:
        shipped=sorted(name.split('/',1)[1] for name in zipped.namelist()
                       if not name.endswith('/') and name.split('/')[1] not in PORTABLE_ONLY)
    target=temp/'Programas do utilizador'/'Jotta Text'
    appdata=temp/'Definições'
    userdir=appdata/'JottaText'
    shortcut=start_menu_shortcut()

    def install():
        result=run([setup,'/S',f'/D={windows_path(target)}'],600)
        assert result.returncode==0,(result.returncode,result.stdout,result.stderr)
        # Exactly the ZIP's program files: no portable user/ folder, and nothing
        # left behind by the previous version or by running it.
        assert installed_files(target)==sorted([*shipped,'Uninstall.exe']),'installed files differ from the ZIP'
        assert registry_value(UNINSTALL_KEY,'DisplayVersion')==version
        assert same_path(registry_value(UNINSTALL_KEY,'InstallLocation'),target)
        assert shortcut.is_file(),f'missing Start menu shortcut {shortcut}'
        inject_harness(target)

    install()
    # The app appends \JottaText to APPDATA exactly as given, short names included.
    settings=dict(APPDATA=windows_path(appdata),JOTTA_TEST_USERDIR=windows_path(userdir))
    run_editor(target,userdir,'1',**settings)
    install()  # Upgrade in place: unsaved documents must survive it.
    run_editor(target,userdir,'2',**settings)
    result=run([target/'Uninstall.exe','/S',f'_?={windows_path(target)}'],300)
    assert result.returncode==0,(result.returncode,result.stdout,result.stderr)
    # _?= runs the uninstaller in place, so it cannot delete itself.
    assert installed_files(target)==['Uninstall.exe'],installed_files(target)
    assert registry_value(UNINSTALL_KEY,'DisplayName') is None,'uninstall entry remains'
    assert not shortcut.exists(),'Start menu shortcut remains'
    assert (userdir/'documents.lua').is_file(),'uninstalling removed settings and recovery by default'
    print('PASS: installer checksum, per-user install to a Unicode/space path, settings in %APPDATA%, upgrade keeps recovery, clean uninstall')

with tempfile.TemporaryDirectory(prefix='Jotta portátil test ') as directory:
    temp=Path(directory)
    env=dict(os.environ,SDL_VIDEODRIVER='dummy')
    prefix=[]
    if wine:
        env.update(WINEPREFIX=str(temp/'wine-prefix'),WINEDEBUG='-all',WINEDLLOVERRIDES='mscoree,mshtml=')
        prefix=[wine]
        subprocess.run([wine,'wineboot','-u'],env=env,capture_output=True,timeout=60)
    else:env['PATH']=str(Path(os.environ['SystemRoot'])/'System32')
    test_portable(temp/'portable')
    if not args.portable_only:test_installer(temp/'installer')
