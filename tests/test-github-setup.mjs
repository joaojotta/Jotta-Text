import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {run} from '../tools/github-trial.mjs';
import {helperSetting,redactError} from '../tools/github-setup.mjs';

async function fixture(callback){
  const parent=await fs.mkdtemp(path.join(os.tmpdir(),'Jotta setup é '));
  const root=path.join(parent,'local project'),userdir=path.join(parent,'app settings'),remote=path.join(parent,'remote.git');
  await fs.mkdir(root);await fs.mkdir(userdir);
  const env={GIT_CONFIG_GLOBAL:path.join(parent,'empty-config'),GIT_CONFIG_NOSYSTEM:'1'};
  await fs.writeFile(env.GIT_CONFIG_GLOBAL,'');
  const git=(cwd,...args)=>execFileSync('git',args,{cwd,env:{...process.env,...env},encoding:'utf8',stdio:['pipe','pipe','pipe']}).trim();
  git(parent,'init','--bare','--initial-branch=main',remote);
  const repo='https://github.com/test-owner/project';
  const user={login:'test-owner',id:42,name:'Test Author',email:null};
  const metadata={html_url:repo,permissions:{push:true},default_branch:'main'};
  const options={allowLocal:true,remote,env,api:async endpoint=>{
    if(endpoint==='user')return user;
    if(endpoint==='repos/test-owner/project')return metadata;
    if(endpoint.startsWith('user/repos?'))return [metadata,{html_url:repo+'-readonly',permissions:{push:false}},
      {html_url:repo+'-archived',permissions:{push:true},archived:true}];
    throw new Error('Unexpected GitHub API request');
  }};
  const action=request=>run({root,userdir,repo,...request},options);
  try{await callback({parent,root,userdir,remote,repo,git,action,options,user});}
  finally{await fs.rm(parent,{recursive:true,force:true});}
}
test('connect, sync, ignore rules, remembered pairing and safe retry use a local remote',()=>fixture(async({root,remote,userdir,repo,git,action})=>{
  await fs.writeFile(path.join(root,'.gitignore'),'secret.txt\n');
  await fs.writeFile(path.join(root,'secret.txt'),'private local material');
  await fs.writeFile(path.join(root,'index.html'),'<h1>Saved source</h1>');
  const result=await action({action:'connect'});assert.equal(result.connection.repo,repo);
  git(root,'config','commit.gpgSign','false');
  assert.equal(git(root,'config','user.email'),'42+test-owner@users.noreply.github.com');
  let state=await action({action:'status'});
  await assert.rejects(action({action:'sync',expectedHead:state.head,expectedBranch:state.branch,hasUnsaved:true}),/Save open documents/);
  assert.equal(git(root,'ls-files'),'');
  const synced=await action({action:'sync',expectedHead:state.head,expectedBranch:state.branch});
  assert.equal(synced.committed,true);assert.equal(git(remote,'show','main:index.html'),'<h1>Saved source</h1>');
  assert.throws(()=>git(remote,'show','main:secret.txt'));
  assert.throws(()=>git(root,'config','credential.helper'));
  const saved=JSON.parse(await fs.readFile(path.join(userdir,'github-connection.json'),'utf8'));
  assert.deepEqual(saved,{root,repo,account:'test-owner'});
  state=await action({action:'status'});const count=git(root,'rev-list','--count','HEAD');
  assert.equal((await action({action:'sync',expectedHead:state.head,expectedBranch:state.branch})).committed,false);
  assert.equal(git(root,'rev-list','--count','HEAD'),count);
}));
test('repository selection omits read-only/archived repos and login data stays outside the project',()=>fixture(async({root,userdir,action,options,parent})=>{
  const repos=await action({action:'repositories'});assert.equal(repos.repositories.length,1);
  assert.equal(repos.repositories[0].name,'test-owner/project');
  const script=path.join(parent,'fake-gh.mjs');
  await fs.writeFile(script,`import fs from 'node:fs/promises';import path from 'node:path';
    process.stderr.write('! First copy your one-time co');
    setTimeout(async()=>{process.stderr.write('de: ABCD-1234\\nOpen this URL to continue in your web browser: https://github.com/login/device\\n');
      await fs.mkdir(process.env.GH_CONFIG_DIR,{recursive:true});
      await fs.writeFile(path.join(process.env.GH_CONFIG_DIR,'hosts.yml'),'test fixture only');
      process.stderr.write('Authentication credentials saved in plain text\\n');},30);`);
  const events=[];options.gh=process.execPath;options.ghArgs=[script];options.progress=event=>events.push(event);
  const login=await action({action:'login'});
  assert.equal(login.account.login,'test-owner');assert.equal(login.storage,'private-file');
  assert.deepEqual(events,[{event:'auth-code',code:'ABCD-1234',url:'https://github.com/login/device'}]);
  assert.equal(JSON.stringify(login).includes('hosts.yml'),false);
  if(process.platform!=='win32')assert.equal((await fs.stat(path.join(userdir,'github-auth/hosts.yml'))).mode&0o777,0o600);
  assert.deepEqual(await fs.readdir(root),[]);
  assert.equal((await action({action:'setup-state'})).account.id,42);
}));
test('connecting a populated remote downloads only into an empty folder',()=>fixture(async({parent,root,remote,git,action})=>{
  const seed=path.join(parent,'seed');git(parent,'clone',remote,seed);
  git(seed,'config','user.name','Other');git(seed,'config','user.email','other@example.invalid');git(seed,'config','commit.gpgSign','false');
  await fs.writeFile(path.join(seed,'note.txt'),'remote source');git(seed,'add','.');git(seed,'commit','-m','Seed');git(seed,'push','origin','main');
  await fs.writeFile(path.join(root,'keep.txt'),'local source');
  await assert.rejects(action({action:'connect'}),/already contains files/);
  assert.equal(await fs.readFile(path.join(root,'keep.txt'),'utf8'),'local source');
  assert.deepEqual(await fs.readdir(root),['keep.txt']);
  await fs.rm(path.join(root,'keep.txt'));await action({action:'connect'});
  assert.equal(await fs.readFile(path.join(root,'note.txt'),'utf8'),'remote source');
}));
test('sync downloads fast-forward updates and stops on dirty or divergent histories',()=>fixture(async({parent,root,remote,git,action})=>{
  await action({action:'connect'});git(root,'config','commit.gpgSign','false');
  await fs.writeFile(path.join(root,'base.txt'),'base');let state=await action({action:'status'});
  await action({action:'sync',expectedHead:state.head,expectedBranch:state.branch});
  const second=path.join(parent,'second');git(parent,'clone',remote,second);
  git(second,'config','user.name','Other');git(second,'config','user.email','other@example.invalid');git(second,'config','commit.gpgSign','false');
  await fs.writeFile(path.join(second,'incoming.txt'),'incoming');git(second,'add','.');git(second,'commit','-m','Incoming');git(second,'push');
  await fs.writeFile(path.join(root,'local.txt'),'keep local');state=await action({action:'status'});
  await assert.rejects(action({action:'sync',expectedHead:state.head,expectedBranch:state.branch}),/incoming changes/);
  assert.equal(await fs.readFile(path.join(root,'local.txt'),'utf8'),'keep local');
  await fs.rm(path.join(root,'local.txt'));state=await action({action:'status'});
  assert.equal((await action({action:'sync',expectedHead:state.head,expectedBranch:state.branch})).downloaded,true);
  assert.equal(await fs.readFile(path.join(root,'incoming.txt'),'utf8'),'incoming');
  await fs.writeFile(path.join(second,'remote2.txt'),'remote');git(second,'add','.');git(second,'commit','-m','Remote again');git(second,'push');
  await fs.writeFile(path.join(root,'local2.txt'),'local');git(root,'add','.');git(root,'commit','-m','Local branch');state=await action({action:'status'});
  const remoteHead=git(remote,'rev-parse','main');
  await assert.rejects(action({action:'sync',expectedHead:state.head,expectedBranch:state.branch}),/diverged/);
  assert.equal(git(remote,'rev-parse','main'),remoteHead);assert.equal(git(root,'rev-parse','HEAD'),state.head);
}));
test('connecting/syncing never replaces a different origin or accepts a parent repository',()=>fixture(async({root,parent,repo,git,action})=>{
  await action({action:'connect'});const original=git(root,'remote','get-url','origin');
  await assert.rejects(action({action:'connect',repo:'https://github.com/test-owner/another'}),/Unexpected GitHub API/);
  assert.equal(git(root,'remote','get-url','origin'),original);
  const nested=path.join(root,'nested');await fs.mkdir(nested);
  await assert.rejects(action({action:'connect',root:nested}),/parent repository/);
  git(root,'remote','set-url','origin','https://github.com/someone/else.git');
  await assert.rejects(action({action:'sync',expectedHead:null,expectedBranch:'main'}),/destination changed/);
  assert.equal(git(root,'remote','get-url','origin'),'https://github.com/someone/else.git');
}));
test('credential helper paths are shell-quoted and errors redact credential strings',()=>{
  const value=helperSetting("/a folder/João's tools/gh");
  assert.equal(value,"credential.https://github.com.helper=!'/a folder/João'\\''s tools/gh' auth git-credential");
  assert.equal(redactError('https://secret@github.com/u/r gho_PRIVATE github_pat_PRIVATE'),'https://[redacted]@github.com/u/r [redacted] [redacted]');
});
test('app login settings cannot be connected as a source folder',()=>fixture(async({userdir,parent,action})=>{
  await assert.rejects(action({action:'connect',root:userdir}),/settings so login data stays private/);
  await assert.rejects(action({action:'connect',root:parent}),/settings so login data stays private/);
}));
test('a matching SSH origin is connected with the browser HTTPS transport',()=>fixture(async({root,git,action,options})=>{
  git(root,'init','--initial-branch=main');
  git(root,'remote','add','origin','git@github.com:test-owner/project.git');
  options.allowLocal=false;
  await action({action:'connect'});
  assert.equal(git(root,'remote','get-url','origin'),'https://github.com/test-owner/project.git');
}));
