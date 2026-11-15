import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {execFileSync,spawn} from 'node:child_process';
import {once} from 'node:events';
import {fileURLToPath} from 'node:url';
import {run,githubRemote,parseStatus} from '../tools/github-trial.mjs';

async function fixture(callback){
  const parent=await fs.mkdtemp(path.join(os.tmpdir(),'Jotta Git trial '));
  const env={GIT_CONFIG_GLOBAL:path.join(parent,'empty-config'),GIT_CONFIG_NOSYSTEM:'1'};
  await fs.writeFile(env.GIT_CONFIG_GLOBAL,'');
  const git=(cwd,...args)=>execFileSync('git',args,{cwd,env:{...process.env,...env},encoding:'utf8',stdio:['pipe','pipe','pipe']}).trim();
  const root=path.join(parent,'working tree');await fs.mkdir(root);
  git(root,'init','--initial-branch=main');git(root,'config','user.name','Jotta Text Test');git(root,'config','user.email','test@example.invalid');
  git(root,'config','commit.gpgSign','false');git(root,'config','core.hooksPath',path.join(parent,'hooks'));
  await fs.mkdir(path.join(parent,'hooks'));
  const action=request=>run({root,...request},{allowLocal:true,env});
  try{await callback({parent,root,git,action,env});}finally{await fs.rm(parent,{recursive:true,force:true});}
}
test('only canonical GitHub HTTPS/SSH remotes become browser links',()=>{
  for(const value of ['https://github.com/joaojotta/jotta-edit.git','git@github.com:joaojotta/jotta-edit.git','ssh://git@github.com/joaojotta/jotta-edit']){
    assert.equal(githubRemote(value).url,'https://github.com/joaojotta/jotta-edit');
  }
  for(const value of ['http://github.com/u/repo','https://token@github.com/u/repo','https://github.com.evil/u/repo',
    'https://github.com/u/repo/tree/main','https://github.com:444/u/repo','ext::sh -c code','git@elsewhere:u/repo','https://github.com/u/repo\n','https://github.com/u/%2fsecret'])assert.equal(githubRemote(value),null,value);
});
test('NUL status parsing preserves rename paths, Unicode, spaces and conflicts',()=>{
  const result=parseStatus('## main...origin/main [ahead 1]\0R  new é.txt\0old.txt\0 M space name.css\0?? new\nline.txt\0UU conflict.js\0');
  assert.equal(result.files.length,4);assert.equal(result.files[0].originalPath,'old.txt');assert.equal(result.files[0].staged,true);
  assert.equal(result.files[2].path,'new\nline.txt');assert.equal(result.files[3].conflict,true);
});
test('a normal source folder has a friendly empty state and no mutation',()=>fixture(async({parent,env})=>{
  const folder=path.join(parent,'not a repository');await fs.mkdir(folder);
  assert.deepEqual(await run({action:'status',root:folder},{env}),{notRepository:true});
  assert.deepEqual(await fs.readdir(folder),[]);
}));
test('status/diff leave disk and index alone; commits include staged snapshots only',()=>fixture(async({root,git,action})=>{
  await fs.writeFile(path.join(root,'code.js'),'const x = 1;\n');git(root,'add','code.js');git(root,'commit','-m','Initial');
  await fs.writeFile(path.join(root,'code.js'),'const x = 2;\n');
  await fs.mkdir(path.join(root,'new folder'));await fs.writeFile(path.join(root,'new folder/é [name].txt'),'hello\n');
  const index=await fs.readFile(path.join(root,'.git/index'));
  const state=await action({action:'status'});assert.equal(state.files.length,2);assert.equal(state.stagedCount,0);
  assert.match((await action({action:'diff',path:'code.js'})).text,/\+const x = 2/);
  assert.deepEqual(await fs.readFile(path.join(root,'.git/index')),index);
  await action({action:'stage',path:'code.js'});const staged=await action({action:'status'});assert.equal(staged.stagedCount,1);
  await fs.writeFile(path.join(root,'code.js'),'const x = 3; // unsaved-to-index\n');
  await action({action:'commit',message:'Only staged source',expectedHead:staged.head,expectedIndex:staged.indexHash});
  assert.equal(git(root,'show','HEAD:code.js'),'const x = 2;');
  assert.equal(await fs.readFile(path.join(root,'code.js'),'utf8'),'const x = 3; // unsaved-to-index\n');
  assert.equal(git(root,'ls-files','new folder/é [name].txt'),'');
  await action({action:'stage',path:'new folder/é [name].txt'});await action({action:'unstage',path:'new folder/é [name].txt'});
  assert.equal(await fs.readFile(path.join(root,'new folder/é [name].txt'),'utf8'),'hello\n');
  await assert.rejects(action({action:'stage',path:'../outside'}),/Invalid repository path/);
}));
test('unborn repositories, literal pathspecs and stale-index checks preserve work',()=>fixture(async({root,git,action})=>{
  await fs.writeFile(path.join(root,'[abc].txt'),'literal');await fs.writeFile(path.join(root,'a.txt'),'other');
  await action({action:'stage',path:'[abc].txt'});let state=await action({action:'status'});
  assert.equal(state.head,null);assert.equal(state.stagedCount,1);assert.equal(git(root,'ls-files'),'[abc].txt');
  await action({action:'unstage',path:'[abc].txt'});assert.equal(git(root,'ls-files'),'');
  await action({action:'stage',path:'[abc].txt'});state=await action({action:'status'});
  await action({action:'stage',path:'a.txt'});
  await assert.rejects(action({action:'commit',message:'Stale',expectedHead:state.head,expectedIndex:state.indexHash}),/changed/);
  state=await action({action:'status'});await action({action:'commit',message:'First commit',expectedHead:state.head,expectedIndex:state.indexHash});
  assert(git(root,'rev-parse','HEAD'));
}));
test('clone, non-forced push and fetch work with disposable local remotes',()=>fixture(async({root,parent,git,action,env})=>{
  const remote=path.join(parent,'remote.git');await fs.mkdir(remote);git(remote,'init','--bare','--initial-branch=main');
  await fs.writeFile(path.join(root,'file.txt'),'first');git(root,'add','.');git(root,'commit','-m','First');git(root,'remote','add','origin',remote);
  let state=await action({action:'status'});
  await action({action:'push',expectedHead:state.head,expectedBranch:state.branch});assert.equal(git(remote,'rev-parse','main'),state.head);
  // The production CLI never accepts the allowLocal test context.
  await assert.rejects(run({action:'fetch',root},{env}),/GitHub origin/);
  const clone=await run({action:'clone',url:remote,parent,name:'second clone'},{allowLocal:true,env});
  assert.equal(await fs.readFile(path.join(clone.root,'file.txt'),'utf8'),'first');
  git(clone.root,'config','user.name','Other Test');git(clone.root,'config','user.email','other@example.invalid');
  await fs.writeFile(path.join(clone.root,'file.txt'),'remote change');git(clone.root,'add','.');git(clone.root,'commit','-m','Other');git(clone.root,'push','origin','HEAD');
  const remoteHead=git(remote,'rev-parse','main');
  await fs.writeFile(path.join(root,'local.txt'),'keep local');git(root,'add','local.txt');git(root,'commit','-m','Local');
  state=await action({action:'status'});
  await assert.rejects(action({action:'push',expectedHead:state.head,expectedBranch:state.branch}),/rejected|fetch first|non-fast-forward/i);
  assert.equal(git(remote,'rev-parse','main'),remoteHead);
  await action({action:'fetch'});assert.equal(git(root,'rev-parse','origin/main'),remoteHead);assert.equal(git(root,'rev-parse','HEAD'),state.head);
  assert.equal(await fs.readFile(path.join(root,'local.txt'),'utf8'),'keep local');
  await assert.rejects(run({action:'clone',url:remote,parent,name:'second clone'},{allowLocal:true,env}),/EEXIST/);
}));
test('linked worktrees work and configured commit hooks are respected',()=>fixture(async({root,parent,git,action,env})=>{
  await fs.writeFile(path.join(root,'file.txt'),'base');git(root,'add','.');git(root,'commit','-m','Base');
  const worktree=path.join(parent,'linked');git(root,'worktree','add','-b','side',worktree);
  assert.equal((await run({action:'status',root:worktree},{env})).branch,'side');
  if(process.platform!=='win32'){
    const hook=path.join(parent,'hooks/pre-commit');await fs.writeFile(hook,'#!/bin/sh\necho "Hook rejected this commit" >&2\nexit 1\n');await fs.chmod(hook,0o755);
    await fs.writeFile(path.join(root,'file.txt'),'changed');await action({action:'stage',path:'file.txt'});
    const state=await action({action:'status'});
    await assert.rejects(action({action:'commit',message:'Respect hooks',expectedHead:state.head,expectedIndex:state.indexHash}),/Hook rejected/);
    assert.equal(git(root,'rev-parse','HEAD'),state.head);
  }
}));
test('cancel protocol stops a running Git operation and its hook process',()=>fixture(async({root,parent,git,action,env})=>{
  if(process.platform==='win32')return;
  await fs.writeFile(path.join(root,'file.txt'),'source');await action({action:'stage',path:'file.txt'});
  const state=await action({action:'status'}),started=path.join(parent,'started'),finished=path.join(parent,'finished');
  const hook=path.join(parent,'hooks/pre-commit');
  await fs.writeFile(hook,`#!/bin/sh\necho yes > "${started}"\nsleep 2\necho no > "${finished}"\n`);await fs.chmod(hook,0o755);
  const child=spawn(process.execPath,[fileURLToPath(new URL('../tools/github-trial.mjs',import.meta.url))],{
    env:{...process.env,...env},stdio:['pipe','pipe','pipe']});
  const completion=once(child,'close');let output='';child.stdout.on('data',data=>output+=data);child.stderr.resume();
  try{
    child.stdin.write(JSON.stringify({action:'commit',root,message:'Cancel this operation',expectedHead:state.head,expectedIndex:state.indexHash})+'\n');
    const deadline=Date.now()+5000;
    while(Date.now()<deadline){try{await fs.access(started);break;}catch{}await new Promise(resolve=>setTimeout(resolve,20));}
    await fs.access(started);child.stdin.write('{"action":"cancel"}\n');
    const [code]=await completion;assert.equal(code,130,output);
    await new Promise(resolve=>setTimeout(resolve,2200));
    await assert.rejects(fs.access(finished));
    assert.equal((await action({action:'status'})).head,null,'cancelled hook still committed the source');
  }finally{if(child.exitCode===null)child.kill('SIGTERM');}
}));
