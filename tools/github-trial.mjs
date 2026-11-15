// Removable desktop Git/GitHub trial. JSON requests over stdin; no shell or token storage.
import {spawn} from 'node:child_process';
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {createInterface} from 'node:readline';
import {fileURLToPath} from 'node:url';

export function githubRemote(value){
  if(typeof value!=='string'||/[\s\x00-\x1f\x7f]/.test(value))return null;
  let owner,repo,transport;
  const scp=/^git@github\.com:([^/]+)\/([^/]+)\/?$/i.exec(value);
  if(scp){[,owner,repo]=scp;transport='ssh';}
  else{
    let url;try{url=new URL(value);}catch{return null;}
    if(url.hostname.toLowerCase()!=='github.com'||url.search||url.hash||url.password)return null;
    if(url.protocol==='https:'&&(!url.username)&&(!url.port||url.port==='443'))transport='https';
    else if(url.protocol==='ssh:'&&url.username==='git'&&(!url.port||url.port==='22'))transport='ssh';
    else return null;
    const pieces=url.pathname.replace(/^\//,'').replace(/\/$/,'').split('/');
    if(pieces.length!==2)return null;[owner,repo]=pieces;
  }
  repo=repo.replace(/\.git$/i,'');
  if(!/^[a-z\d][a-z\d-]{0,38}$/i.test(owner)||!(/^[a-z\d_.-]{1,100}$/i.test(repo))||['.','..'].includes(repo))return null;
  return {owner,repo,transport,url:`https://github.com/${owner}/${repo}`};
}
export function parseStatus(text){
  const records=text.split('\0'),files=[];let header='';
  for(let i=0;i<records.length;i++){
    const value=records[i];if(!value)continue;
    if(value.startsWith('## ')){header=value.slice(3);continue;}
    if(value.length<4)continue;
    const file={index:value[0],working:value[1],path:value.slice(3)};
    if(/[RC]/.test(file.index+file.working))file.originalPath=records[++i];
    file.staged=![' ','?','!'].includes(file.index);
    file.conflict=['DD','AU','UD','UA','DU','AA','UU'].includes(value.slice(0,2));files.push(file);
  }
  return {header,files};
}
const active=new Set();
function stop(child){
  if(!child||child.exitCode!==null)return;
  try{
    if(process.platform==='win32'){
      spawn(path.join(process.env.SystemRoot||'C:\\Windows','System32/taskkill.exe'),['/PID',String(child.pid),'/T','/F'],{stdio:'ignore',windowsHide:true});
    }else process.kill(-child.pid,'SIGTERM');
  }catch{try{child.kill();}catch{}}
}
function redact(text){return String(text).replace(/(https?:\/\/)[^/\s@]+@/gi,'$1[redacted]@').slice(0,5000);}
function safePath(value){
  if(typeof value!=='string'||!value||value.includes('\0')||value.includes('\\')||value.startsWith('/')||/^[a-z]:/i.test(value)||value.split('/').some(x=>x==='..'||x==='.'||!x))throw new Error('Invalid repository path');
  return value;
}
export async function run(request,testing={}){
  const directoryName=path.dirname(fileURLToPath(import.meta.url));
  const bundled=process.platform==='win32'?path.resolve(directoryName,'../../git/bin/git.exe'):
    path.resolve(directoryName,'../../../bin/git');
  let git=process.env.LITEFRONT_GIT||'git';let bundledGit=false;
  if(!process.env.LITEFRONT_GIT&&path.basename(directoryName)==='litefront'){
    try{await fs.access(bundled);git=bundled;bundledGit=true;}catch{}
  }
  const env={...process.env,...testing.env,GIT_TERMINAL_PROMPT:'0',GCM_INTERACTIVE:'Never',GIT_OPTIONAL_LOCKS:'0',
    GIT_ASKPASS:'',SSH_ASKPASS:'',SSH_ASKPASS_REQUIRE:'never',GIT_PAGER:'cat',LC_ALL:'C',
    GIT_SSH_COMMAND:process.env.GIT_SSH_COMMAND||'ssh -oBatchMode=yes -oStrictHostKeyChecking=yes'};
  if(bundledGit){
    env.GIT_EXEC_PATH=path.resolve(path.dirname(bundled),'../libexec/git-core');
    env.GIT_TEMPLATE_DIR=path.resolve(path.dirname(bundled),'../share/git-core/templates');
  }
  // Repository location must come from the selected workspace, not shell state.
  for(const key of ['GIT_DIR','GIT_WORK_TREE','GIT_INDEX_FILE','GIT_COMMON_DIR','GIT_OBJECT_DIRECTORY','GIT_ALTERNATE_OBJECT_DIRECTORIES','GIT_NAMESPACE'])delete env[key];
  const prefix=['--no-pager','--literal-pathspecs','-c','color.ui=false','-c','core.quotepath=false',
    '-c','core.fsmonitor=false','-c','core.untrackedCache=false'];
  function command(args,{cwd,input,limit=4*1024*1024,timeout=20000,optional=false}={}){
    return new Promise((resolve,reject)=>{
      const child=spawn(git,[...prefix,...args],{cwd,env,windowsHide:true,detached:process.platform!=='win32',stdio:['pipe','pipe','pipe']});
      active.add(child);const output=[],errors=[];let bytes=0,failure;
      const timer=setTimeout(()=>{failure=new Error('Git operation timed out. Refresh the repository before trying again.');stop(child);},timeout);
      const collect=list=>data=>{bytes+=data.length;if(bytes>limit){if(!failure){failure=new Error('Git output exceeded the trial limit. Use Git outside the app for this repository.');stop(child);}}else list.push(data);};
      child.stdout.on('data',collect(output));child.stderr.on('data',collect(errors));child.stdin.on('error',()=>{});
      child.on('error',error=>{clearTimeout(timer);active.delete(child);reject(new Error(error.code==='ENOENT'?'Git is not available. Install Git, then restart Jotta Text.':redact(error.message)));});
      child.on('close',code=>{
        clearTimeout(timer);active.delete(child);
        const stdout=Buffer.concat(output).toString('utf8'),stderr=Buffer.concat(errors).toString('utf8');
        if(failure)reject(failure);
        else if(code!==0&&!optional)reject(new Error(redact(stderr||stdout)||'Git operation failed'));
        else resolve({stdout,stderr,code});
      });
      child.stdin.end(input||'');
    });
  }
  const action=request.action;
  if(action==='clone'){
    const remote=githubRemote(request.url);
    if(!remote&&!testing.allowLocal)throw new Error('Use a GitHub HTTPS or SSH repository URL without embedded credentials.');
    const parent=await fs.realpath(request.parent);
    if(!(await fs.stat(parent)).isDirectory())throw new Error('Choose a destination folder');
    const name=request.name||remote?.repo;
    if(typeof name!=='string'||!(/^[\p{L}\p{N}_. -]{1,100}$/u.test(name))||['.','..'].includes(name)||name.endsWith('.')||name.endsWith(' '))throw new Error('Choose a valid new folder name');
    const destination=path.join(parent,name);await fs.mkdir(destination);
    try{
      await command(['clone','--no-recurse-submodules','--origin','origin','--',request.url,destination],{cwd:parent,timeout:120000});
      return {root:destination};
    }catch(error){try{await fs.rmdir(destination);}catch{}throw error;}
  }
  if(typeof request.root!=='string'||!request.root)throw new Error('Open a repository folder first');
  const directory=await fs.realpath(request.root);
  const location=await command(['rev-parse','--show-toplevel'],{cwd:directory,optional:true});
  if(location.code!==0){
    if(action==='status'&&/not a git repository|must be run in a work tree/i.test(location.stderr))return {notRepository:true};
    throw new Error(redact(location.stderr)||'Open a repository working folder first');
  }
  const root=location.stdout.replace(/\r?\n$/,'');
  const cmd=(args,options={})=>command(args,{cwd:root,...options});
  const head=async()=>{const result=await cmd(['rev-parse','--verify','HEAD'],{optional:true});return result.code===0?result.stdout.trim():null;};
  const indexHash=async()=>crypto.createHash('sha256').update((await cmd(['ls-files','--stage','-z'])).stdout).digest('hex');
  const branch=async()=>{const result=await cmd(['symbolic-ref','--quiet','--short','HEAD'],{optional:true});return result.code===0?result.stdout.trim():null;};
  const origin=async(push=false)=>{
    const result=await cmd(['remote','get-url',...(push?['--push']:[]),'--all','origin'],{optional:true});
    const urls=result.code===0?result.stdout.replace(/\r?\n$/,'').split(/\r?\n/):[];
    return {urls,github:urls.length===1?githubRemote(urls[0]):null};
  };
  if(action==='status'){
    const result=await cmd(['status','--porcelain=v1','-z','--branch','--untracked-files=all','--ignore-submodules=dirty']);
    const parsed=parseStatus(result.stdout),remote=await origin(),pushRemote=await origin(true);
    return {root,branch:await branch(),head:await head(),indexHash:await indexHash(),github:remote.github,pushGithub:pushRemote.github,
      canPush:!!pushRemote.github,header:parsed.header,stagedCount:parsed.files.filter(x=>x.staged).length,
      fileCount:parsed.files.length,files:parsed.files.slice(0,1000),limited:parsed.files.length>1000};
  }
  if(action==='diff'){
    const name=safePath(request.path);
    const tracked=await cmd(['ls-files','--error-unmatch','--',name],{optional:true});
    if(tracked.code!==0&&!request.staged){
      const absolute=path.join(root,name),stat=await fs.lstat(absolute);
      if(stat.isSymbolicLink())return {text:`Untracked symbolic link: ${name}\n→ ${await fs.readlink(absolute)}\n`};
      if(!stat.isFile())return {text:'Untracked directory. Stage individual files or use Git outside the app.\n'};
      if(stat.size>256*1024)return {text:'Untracked file is larger than the 256 KiB diff limit.\n'};
      const bytes=await fs.readFile(absolute);
      return {text:bytes.includes(0)?`Binary untracked file: ${name}\n`:`--- /dev/null\n+++ b/${name}\n`+bytes.toString('utf8').split('\n').map(line=>'+'+line).join('\n')};
    }
    return {text:(await cmd(['diff','--no-ext-diff','--no-textconv','--no-color',...(request.staged?['--cached']:[]),'--',name],{limit:1024*1024})).stdout||'No changes in this view.\n'};
  }
  if(action==='stage'||action==='unstage'){
    const paths=[safePath(request.path)];if(request.originalPath)paths.push(safePath(request.originalPath));
    if(action==='stage')await cmd(['add','--',...paths]);
    else if(await head())await cmd(['reset','--quiet','HEAD','--',...paths]);
    else await cmd(['rm','--cached','-f','--ignore-unmatch','--',...paths]);
    return {changed:true};
  }
  if(action==='commit'){
    const message=typeof request.message==='string'?request.message.trim():'';
    if(!message||message.length>4096||message.includes('\0'))throw new Error('Enter a commit message (up to 4,096 characters)');
    if((request.expectedHead??null)!==await head()||request.expectedIndex!==await indexHash())throw new Error('The branch or staged files changed. Refresh and review them before committing.');
    const changed=await cmd(['diff','--cached','--quiet','--exit-code'],{optional:true});
    if(changed.code===0)throw new Error('Stage files before committing');
    const result=await cmd(['commit','--file=-'],{input:message+'\n',timeout:120000});
    return {head:await head(),summary:result.stdout.trim()};
  }
  if(action==='fetch'||action==='push'){
    const remote=await origin(action==='push');
    if(remote.urls.length!==1||(!remote.github&&!testing.allowLocal))throw new Error('This trial requires a single GitHub origin URL without embedded credentials.');
    if(action==='fetch')await cmd(['fetch','--no-tags','origin'],{timeout:120000});
    else{
      if(!testing.allowLocal&&request.expectedRemote!==remote.github.url)throw new Error('The push destination changed. Refresh before pushing.');
      const currentBranch=await branch();
      if(!currentBranch)throw new Error('Check out a branch before pushing');
      if(!request.expectedHead||request.expectedHead!==await head()||request.expectedBranch!==currentBranch)throw new Error('The branch changed. Refresh before pushing.');
      await cmd(['push','--porcelain','--set-upstream','origin',`HEAD:refs/heads/${currentBranch}`],{timeout:120000});
    }
    return {changed:true};
  }
  if(action==='link'){
    const remote=await origin();if(!remote.github)throw new Error('The origin remote is not a supported GitHub URL');
    let url=remote.github.url;
    if(request.page==='issues'||request.page==='pulls')url+='/'+request.page;
    return {url};
  }
  throw new Error('Unknown GitHub trial action');
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  const cancel=()=>{for(const child of active)stop(child);process.exit(130);};
  for(const signal of ['SIGINT','SIGTERM'])process.on(signal,cancel);
  const input=createInterface({input:process.stdin,crlfDelay:Infinity});
  let started=false;
  input.on('line',async line=>{
    try{
      if(Buffer.byteLength(line)>128*1024)throw new Error('GitHub request is too large');
      const request=JSON.parse(line);if(request.action==='cancel'){cancel();return;}
      if(started)return;started=true;
      const result=await run(request);process.stdout.write(JSON.stringify({ok:true,result}),()=>process.exit(0));
    }catch(error){for(const child of active)stop(child);process.stdout.write(JSON.stringify({ok:false,error:redact(error.message)}),()=>process.exit(0));}
  });
}
