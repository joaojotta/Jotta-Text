#!/usr/bin/env python3
"""Exercise the actual optional UI and worker against a disposable repository."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parent.parent
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--flatpak-build',type=Path)
build=parser.parse_args().flatpak_build
source=build.resolve()/'files' if build else ROOT/'dist/native'
with tempfile.TemporaryDirectory(prefix='jotta-text-github-') as directory:
    temp=Path(directory);app=temp/'app';data=app/'share/lite-xl'
    shutil.copytree(source/'share/lite-xl',data,symlinks=True)
    (app/'bin').mkdir(parents=True)
    for name in ['lite-xl','litefront-file-dialog']:
        shutil.copy2(source/'bin'/name,app/'bin'/name)
    # A fake CLI exercises the real streaming login/UI without opening a browser
    # or reading/writing any actual GitHub credentials.
    helper=data/'litefront/github-cli'
    (helper/'gh').write_text('''#!/bin/sh
base="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
exec "$base/../node/node" "$base/fake.mjs" "$@"
''')
    (helper/'gh').chmod(0o755)
    (helper/'fake.mjs').write_text(r'''
import fs from 'node:fs/promises';import path from 'node:path';
const args=process.argv.slice(2);
const account={login:'jotta-test',id:42,name:'Jotta Test',email:null};
const repo={html_url:'https://github.com/jotta-test/project',permissions:{push:true},default_branch:'main'};
if(args[0]==='auth'&&args[1]==='login'){
  process.stderr.write('! First copy your one-time co');
  setTimeout(async()=>{process.stderr.write('de: TEST-1234\n');
    await fs.mkdir(process.env.GH_CONFIG_DIR,{recursive:true});
    await fs.writeFile(path.join(process.env.GH_CONFIG_DIR,'hosts.yml'),'test fixture only');},80);
}else if(args[0]==='api'){
  const endpoint=args.at(-1);
  console.log(JSON.stringify(endpoint==='user'?account:endpoint.startsWith('user/repos?')?
    Array.from({length:35},(_,i)=>({...repo,html_url:repo.html_url+(i===0?'':String(i))})):repo));
}else process.exit(1);
''')
    if build:
        shutil.copy2(source/'bin/git',app/'bin/git')
        shutil.copytree(source/'libexec/git-core',app/'libexec/git-core',symlinks=True)
        shutil.copytree(source/'share/git-core',app/'share/git-core',symlinks=True)
    project=temp/'project';project.mkdir();user=temp/'user';user.mkdir()
    env=dict(os.environ,GIT_CONFIG_GLOBAL=str(temp/'empty-config'),GIT_CONFIG_NOSYSTEM='1')
    (temp/'empty-config').write_text('')
    def git(*args):return subprocess.check_output(['git','-C',str(project),*args],env=env,stderr=subprocess.PIPE,text=True).strip()
    git('init','--initial-branch=main');git('config','user.name','Jotta Text Test');git('config','user.email','test@example.invalid')
    git('config','commit.gpgSign','false');git('config','core.hooksPath',str(temp/'no-hooks'))
    (project/'style.css').write_text('body { color: black; }\n');git('add','.');git('commit','-m','Initial')
    (project/'style.css').write_text('body { color: red; }\n');(project/'new é.txt').write_text('new source\n')
    init=data/'litefront/init.lua'
    init.write_text(init.read_text()+r'''
local core=require 'core'
core.add_thread(function()
 coroutine.yield(.25)
 local ok,err=xpcall(function()
'''+(ROOT/'tests/github-trial.lua').read_text()+r'''
 end,debug.traceback)
 local out=assert(io.open(USERDIR..'/result','w'));out:write(ok and 'PASS' or tostring(err))
 for _,item in ipairs(core.log_items) do if item.level=='ERROR' then out:write('\n'..item.text) end end
 out:close();core.quit(true)
end)
''')
    for phase in ['1','2']:
        (user/'result').unlink(missing_ok=True)
        runtime_env=dict(env,SDL_VIDEODRIVER='dummy',LITE_USERDIR=str(user),GITHUB_TEST_PHASE=phase)
        invocation=[str(app/'bin/lite-xl'),str(project)]
        if build:
            invocation=['flatpak','build','--runtime','--readonly',f'--filesystem={temp}',f'--bind-mount=/app={app}',
                *[f'--env={key}={runtime_env[key]}' for key in ['SDL_VIDEODRIVER','LITE_USERDIR','GITHUB_TEST_PHASE','GIT_CONFIG_GLOBAL','GIT_CONFIG_NOSYSTEM']],str(build.resolve()),'/app/bin/lite-xl',str(project)]
        result=subprocess.run(invocation,env=runtime_env,capture_output=True,text=True,timeout=35)
        assert result.returncode==0 and (user/'result').is_file(),(result.stdout,result.stderr)
        assert (user/'result').read_text()=='PASS',(user/'result').read_text()
        assert (project/'style.css').read_text()=='body { color: red; }\n','Git UI saved the unsaved buffer'
    assert git('show','HEAD:style.css')=='body { color: red; }'
    assert git('log','-1','--format=%s')=='Review saved changes'
    assert git('ls-files','new é.txt')=='','untracked diff staged a file'
    print('PASS: opt-in persistence, real Git status/stage/commit, keyboard and mouse input, unsaved buffer isolation, diff snapshots, Portuguese UI, disabling and restart')
