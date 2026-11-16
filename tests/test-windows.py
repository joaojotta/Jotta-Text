#!/usr/bin/env python3
"""Verify the Windows ZIP and installer independently of the MSYS2 build environment."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
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
SETTINGS_KEY=r'HKCU\Software\JottaText'
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

# MSYS2's Python writes Windows paths with forward slashes (C:/Users/...). NSIS
# rejects those as an install folder and falls back to its default, so always
# hand Windows programs backslashes.
def windows_path(path):
    text=str(path).replace('/','\\')
    return 'Z:'+text if wine else text

def run(command,timeout,**changes):
    # errors='replace': console tools print in the OEM code page, not UTF-8.
    return subprocess.run([*prefix,*map(str,command)],env=dict(env,**changes),capture_output=True,text=True,
                          errors='replace',timeout=timeout)

def inject_harness(app):
    init=app/'data/litefront/init.lua'
    init.write_text(init.read_text()+HARNESS)

def run_editor(app,userdir,phase,**changes):
    result_file=userdir/'test-result'
    result_file.unlink(missing_ok=True)
    try:result=run([app/'JottaText.exe'],60,JOTTA_TEST_PHASE=phase,**changes)
    except subprocess.TimeoutExpired as error:
        # A startup error waits in a message box; its text is also in error.txt.
        log=userdir/'error.txt'
        raise AssertionError(('editor did not exit',str(userdir),sorted(p.name for p in userdir.glob('*')) if userdir.is_dir() else 'no settings folder',
                              log.read_text(errors='replace') if log.is_file() else 'no error.txt')) from error
    assert result.returncode==0 and result_file.is_file(),(result.returncode,result.stdout,result.stderr)
    assert result_file.read_text()=='PASS',result_file.read_text()

def registry_value(key,name):
    # reg export writes UTF-16, unlike reg query's code-page console output, so
    # Unicode install paths survive.
    exported=temp/'registry.reg'
    exported.unlink(missing_ok=True)
    if run(['reg','export',key,windows_path(exported),'/y'],30).returncode!=0:return None
    prefix_text=f'"{name}"="'
    for line in exported.read_text(encoding='utf-16').splitlines():
        if line.startswith(prefix_text) and line.endswith('"'):
            return line[len(prefix_text):-1].replace('\\"','"').replace('\\\\','\\')
    return None

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
    if wine:
        # Wine replaces APPDATA with its prefix's own folder; use that one.
        appdata_value=registry_value(r'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders','AppData')
        appdata=Path(subprocess.run(['winepath','-u',appdata_value],env=env,capture_output=True,text=True,check=True).stdout.strip())
        settings=dict(JOTTA_TEST_USERDIR=appdata_value+'\\JottaText')
    else:
        appdata=temp/'Definições'
        # The app appends \JottaText to APPDATA exactly as given, short names included.
        settings=dict(APPDATA=windows_path(appdata),JOTTA_TEST_USERDIR=windows_path(appdata/'JottaText'))
    userdir=appdata/'JottaText'
    shortcut=start_menu_shortcut()

    # NSIS reads /D= and _?= raw: they must be unquoted even with spaces, which
    # subprocess and Wine cannot pass. Pre-set the folder the installer offers
    # (its InstallDirRegKey) instead, and run the uninstaller as users do.
    result=run(['reg','add',SETTINGS_KEY,'/v','InstallDir','/t','REG_SZ','/d',windows_path(target),'/f'],30)
    assert result.returncode==0,(result.stdout,result.stderr)

    def install():
        result=run([setup,'/S'],600)
        assert result.returncode==0,(result.returncode,result.stdout,result.stderr)
        # Exactly the ZIP's program files: no portable user/ folder, and nothing
        # left behind by the previous version or by running it.
        installed,expected=set(installed_files(target)),{*shipped,'Uninstall.exe'}
        assert installed==expected,('installed files differ from the ZIP',
            'missing:',sorted(expected-installed)[:20],'unexpected:',sorted(installed-expected)[:20])
        assert registry_value(UNINSTALL_KEY,'DisplayVersion')==version
        assert same_path(registry_value(UNINSTALL_KEY,'InstallLocation'),target)
        assert shortcut.is_file(),f'missing Start menu shortcut {shortcut}'
        node=run([target/'data/litefront/node/node.exe','--version'],60)
        assert node.returncode==0 and node.stdout.startswith('v24.'),(node.stdout,node.stderr)
        inject_harness(target)

    install()
    # No settings folder yet: the first start must create it (and its parents).
    assert not userdir.exists()
    run_editor(target,userdir,'1',**settings)
    install()  # Upgrade in place: unsaved documents must survive it.
    run_editor(target,userdir,'2',**settings)
    result=run([target/'Uninstall.exe','/S'],60)
    assert result.returncode==0,(result.returncode,result.stdout,result.stderr)
    # The uninstaller continues from a copy in %TEMP% so it can delete itself.
    deadline=time.monotonic()+300
    while (target.exists() or registry_value(UNINSTALL_KEY,'DisplayName') is not None) and time.monotonic()<deadline:
        time.sleep(1)
    assert not target.exists(),('uninstall left files behind',installed_files(target)[:20])
    assert registry_value(UNINSTALL_KEY,'DisplayName') is None,'uninstall entry remains'
    assert registry_value(SETTINGS_KEY,'InstallDir') is None,'install folder setting remains'
    assert not shortcut.exists(),'Start menu shortcut remains'
    assert (userdir/'documents.lua').is_file(),'uninstalling removed settings and recovery by default'
    print('PASS: installer checksum, per-user install to a Unicode/space path, settings in %APPDATA%, upgrade keeps recovery, clean uninstall')

with tempfile.TemporaryDirectory(prefix='Jotta portátil test ') as directory:
    temp=Path(directory)
    env=dict(os.environ)
    env.setdefault('SDL_VIDEODRIVER','dummy')
    prefix=[]
    if wine:
        env.update(WINEPREFIX=str(temp/'wine-prefix'),WINEDEBUG='-all',WINEDLLOVERRIDES='mscoree,mshtml=')
        prefix=[wine]
        subprocess.run([wine,'wineboot','-u'],env=env,capture_output=True,timeout=60)
    else:env['PATH']=str(Path(os.environ['SystemRoot'])/'System32')
    test_portable(temp/'portable')
    if not args.portable_only:test_installer(temp/'installer')
