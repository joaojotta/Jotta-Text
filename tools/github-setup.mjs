// Browser sign-in and a remembered local-folder/GitHub-repository connection.
// GitHub CLI owns credentials; only account metadata crosses the UI protocol.
import {spawn} from 'node:child_process';
import fs from 'node:fs/promises';
import path from 'node:path';

export const setupActions=new Set(['setup-state','login','logout','repositories','connect','sync']);
export function redactError(value){
  return String(value).replace(/(https?:\/\/)[^/\s@]+@/gi,'$1[redacted]@')
    .replace(/\b(?:gh[pousr]_[A-Za-z0-9_]+|github_pat_[A-Za-z0-9_]+)\b/g,'[redacted]').slice(0,5000);
}
export function helperSetting(binary){
  const quoted="'"+binary.replaceAll('\\','/').replaceAll("'","'\\''")+"'";
  return `credential.https://github.com.helper=!${quoted} auth git-credential`;
}
export async function runSetup(request,context){
  const {git,env,gh,active,testing,remoteInfo}=context;
  const userdir=request.userdir||env.LITE_USERDIR;
  if(typeof userdir!=='string'||!path.isAbsolute(userdir))throw new Error('Application settings directory is unavailable');
  await fs.mkdir(userdir,{recursive:true,mode:0o700});
  const saved=path.join(userdir,'github-connection.json');
  async function sourceFolder(root){
    const settings=await fs.realpath(userdir);
    const contains=(parent,child)=>{const relative=path.relative(parent,child);return relative===''||(!relative.startsWith('..'+path.sep)&&relative!=='..'&&!path.isAbsolute(relative));};
    if(contains(root,settings)||contains(settings,root))throw new Error('Choose a source folder separate from the application settings so login data stays private.');
  }
  async function load(){try{return JSON.parse(await fs.readFile(saved,'utf8'));}catch(error){if(error.code==='ENOENT')return null;throw error;}}
  async function remember(connection){
    const temporary=saved+`.${process.pid}.tmp`;
    try{await fs.writeFile(temporary,JSON.stringify(connection)+'\n',{mode:0o600});await fs.rename(temporary,saved);}
    finally{await fs.rm(temporary,{force:true});}
  }
  function cli(args,{timeout=30000,progress=false,input=''}={}){
    return new Promise((resolve,reject)=>{
      const child=spawn(gh,[...(testing.ghArgs||[]),...args],{cwd:userdir,env,windowsHide:true,detached:process.platform!=='win32',stdio:['pipe','pipe','pipe']});
      active.add(child);let stdout='',stderr='',failure,codeSent=false;
      const timer=setTimeout(()=>{failure=new Error('GitHub request timed out. Please try again.');child.kill('SIGTERM');},timeout);
      child.stdin.on('error',()=>{});child.stdin.end(input);
      const collect=which=>chunk=>{
        if(which==='out')stdout+=chunk.toString('utf8');else stderr+=chunk.toString('utf8');
        if(stdout.length+stderr.length>2*1024*1024){failure=new Error('GitHub response is too large');child.kill('SIGTERM');}
        if(progress&&!codeSent){
          const code=stderr.match(/one-time code:\s*([A-Z0-9]{4}-[A-Z0-9]{4})\b/);
          if(code){codeSent=true;testing.progress?.({event:'auth-code',code:code[1],url:'https://github.com/login/device'});}
        }
      };
      child.stdout.on('data',collect('out'));child.stderr.on('data',collect('err'));
      child.on('error',error=>{clearTimeout(timer);active.delete(child);reject(new Error(error.code==='ENOENT'?'The bundled GitHub sign-in helper is missing. Rebuild or update Jotta Text.':redactError(error.message)));});
      child.on('close',code=>{
        clearTimeout(timer);active.delete(child);
        if(failure)reject(failure);
        else if(code!==0)reject(new Error(redactError(stderr)||'Sign in to GitHub to continue.'));
        else resolve({stdout,stderr});
      });
    });
  }
  async function api(endpoint){
    if(testing.api)return testing.api(endpoint);
    return JSON.parse((await cli(['api','--hostname','github.com',endpoint])).stdout);
  }
  async function account(){
    const user=await api('user');
    if(!/^[a-z\d][a-z\d-]{0,38}$/i.test(user.login)||!Number.isSafeInteger(user.id))throw new Error('GitHub returned an invalid account');
    return {login:user.login,id:user.id,name:user.name||user.login,email:user.email||`${user.id}+${user.login}@users.noreply.github.com`};
  }
  const action=request.action;
  if(action==='setup-state'){
    let user=null,authError=null;
    try{await fs.access(path.join(env.GH_CONFIG_DIR,'hosts.yml'));user=await account();}
    catch(error){if(error.code!=='ENOENT')authError=redactError(error.message);}
    return {account:user,authError,connection:await load()};
  }
  if(action==='login'){
    await fs.mkdir(env.GH_CONFIG_DIR,{recursive:true,mode:0o700});
    const result=await cli(['auth','login','--hostname','github.com','--git-protocol','https','--web','--scopes','workflow'],{timeout:900000,progress:true});
    const config=path.join(env.GH_CONFIG_DIR,'hosts.yml');
    try{await fs.chmod(config,0o600);}catch(error){if(error.code!=='ENOENT')throw error;}
    return {account:await account(),storage:result.stderr.includes('saved in plain text')?'private-file':'credential-store'};
  }
  if(action==='logout'){
    const login=request.login;
    if(typeof login!=='string'||!/^[a-z\d][a-z\d-]{0,38}$/i.test(login))throw new Error('Choose the account to sign out');
    await cli(['auth','logout','--hostname','github.com','--user',login],{input:'y\n'});
    return {signedOut:true};
  }
  if(action==='repositories'){
    const page=Number.isSafeInteger(request.page)&&request.page>0&&request.page<=100?request.page:1;
    const result=await api(`user/repos?per_page=100&sort=updated&affiliation=owner,collaborator,organization_member&page=${page}`);
    if(!Array.isArray(result))throw new Error('GitHub could not list your repositories');
    return {page,more:result.length===100,repositories:result.filter(repo=>repo.permissions?.push&&!repo.archived&&!repo.disabled).map(repo=>{
      const info=remoteInfo(repo.html_url);return info?{name:info.owner+'/'+info.repo,url:info.url,private:!!repo.private}:null;
    }).filter(Boolean)};
  }
  if(action==='connect'){
    const info=remoteInfo(request.repo);
    if(!info)throw new Error('Choose a GitHub repository');
    if(typeof request.root!=='string'||!request.root)throw new Error('Choose a local folder');
    const root=await fs.realpath(request.root);
    if(!(await fs.stat(root)).isDirectory())throw new Error('Choose a local folder');
    await sourceFolder(root);
    const user=await account();
    const metadata=await api(`repos/${info.owner}/${info.repo}`);
    if(!metadata.permissions?.push||metadata.archived||metadata.disabled)throw new Error('Choose a repository you can push to');
    const url=testing.allowLocal&&testing.remote?testing.remote:info.url+'.git';
    const cmd=(args,options={})=>git(args,{cwd:root,...options});
    const location=await cmd(['rev-parse','--show-toplevel'],{optional:true});
    if(location.code===0){
      const actual=await fs.realpath(location.stdout.trim());
      if(actual!==root)throw new Error('This folder belongs to a parent repository. Choose its root folder instead.');
      const existing=await cmd(['remote','get-url','--all','origin'],{optional:true});
      const push=await cmd(['remote','get-url','--push','--all','origin'],{optional:true});
      const matches=value=>value===url||remoteInfo(value)?.url===info.url;
      if(existing.code===0&&(!matches(existing.stdout.trim())||!matches(push.stdout.trim())))throw new Error('This folder is already linked to another repository. Choose that repository or a different folder.');
      if(existing.code!==0)await cmd(['remote','add','origin',url]);
      else{
        // This connection uses the browser account, including older SSH clones.
        if(existing.stdout.trim()!==url)await cmd(['remote','set-url','origin',url]);
        const explicitPush=await cmd(['config','--get-all','remote.origin.pushurl'],{optional:true});
        if(explicitPush.code===0&&explicitPush.stdout.trim()!==url)await cmd(['remote','set-url','--push','origin',url]);
      }
    }else{
      if(!/not a git repository|must be run in a work tree/i.test(location.stderr))throw new Error(redactError(location.stderr));
      const refs=await cmd(['ls-remote','--heads','--tags','--',url],{timeout:120000});
      if(refs.stdout.trim()){
        if((await fs.readdir(root)).length)throw new Error('The repository already contains files. Choose an empty local folder to download it, or an empty GitHub repository to upload this folder.');
        await cmd(['clone','--no-recurse-submodules','--origin','origin','--',url,'.'],{timeout:120000});
      }else{
        await cmd(['init','--initial-branch=main']);
        await cmd(['remote','add','origin',url]);
      }
    }
    // Keep existing author/signing/hook settings; fill missing identity locally.
    for(const [key,value] of [['user.name',user.name],['user.email',user.email]]){
      const current=await cmd(['config','--get',key],{optional:true});
      if(!current.stdout.trim())await cmd(['config','--local',key,value]);
    }
    const connection={root,repo:info.url,account:user.login};await remember(connection);
    return {connection};
  }
  if(action==='sync'){
    if(request.hasUnsaved)throw new Error('Save open documents before syncing.');
    const connection=await load();
    if(!connection||typeof request.root!=='string'||await fs.realpath(request.root)!==connection.root||request.repo!==connection.repo)throw new Error('Connect this folder and repository before syncing.');
    await sourceFolder(connection.root);
    const cmd=(args,options={})=>git(args,{cwd:connection.root,...options});
    const location=await cmd(['rev-parse','--show-toplevel']);
    if(await fs.realpath(location.stdout.trim())!==connection.root)throw new Error('The connected folder is no longer a repository root. Reconnect it.');
    const remote=(await cmd(['remote','get-url','--push','--all','origin'])).stdout.trim();
    const fetchRemote=(await cmd(['remote','get-url','--all','origin'])).stdout.trim();
    const matches=value=>remoteInfo(value)?.url===connection.repo||(testing.allowLocal&&value===testing.remote);
    if(!matches(remote)||!matches(fetchRemote))throw new Error('The repository destination changed. Reconnect before syncing.');
    const current=(await cmd(['symbolic-ref','--quiet','--short','HEAD'],{optional:true})).stdout.trim();
    if(!current)throw new Error('Check out a branch before syncing.');
    const headResult=await cmd(['rev-parse','--verify','HEAD'],{optional:true});
    const head=headResult.code===0?headResult.stdout.trim():null;
    if((request.expectedHead??null)!==head||request.expectedBranch!==current)throw new Error('The branch changed. Refresh before syncing.');
    const pending=(await cmd(['status','--porcelain=v1','-z','--untracked-files=all','--ignore-submodules=dirty'])).stdout;
    if((await cmd(['diff','--name-only','--diff-filter=U'])).stdout.trim())throw new Error('Resolve the merge conflicts in Changes before syncing.');
    await cmd(['fetch','--no-tags','origin'],{timeout:120000});
    const upstream=await cmd(['rev-parse','--verify',`refs/remotes/origin/${current}`],{optional:true});
    let downloaded=false,committed=false;
    if(upstream.code===0){
      if(!head)throw new Error('The remote branch already has commits. Use an empty local folder to download it first.');
      const counts=(await cmd(['rev-list','--left-right','--count',`HEAD...refs/remotes/origin/${current}`])).stdout.trim().split(/\s+/).map(Number);
      if(counts[1]>0){
        if(counts[0]>0)throw new Error('Local and remote histories have diverged. Resolve them in Changes or Git before syncing.');
        if(pending||request.hasUnsaved)throw new Error('There are incoming changes. Save open documents and commit local changes in Changes before syncing.');
        await cmd(['merge','--ff-only',`refs/remotes/origin/${current}`],{timeout:120000});downloaded=true;
      }
    }
    if(pending){
      await cmd(['add','--all','--','.']);
      const changed=await cmd(['diff','--cached','--quiet','--exit-code'],{optional:true});
      if(changed.code!==0){
        const message=(typeof request.message==='string'&&request.message.trim())||'Update from Jotta Text';
        if(message.length>4096||message.includes('\0'))throw new Error('Enter a shorter commit message');
        await cmd(['commit','--file=-'],{input:message+'\n',timeout:120000});committed=true;
      }
    }
    const final=await cmd(['rev-parse','--verify','HEAD'],{optional:true});
    if(final.code!==0)return {message:'No saved changes to sync.',committed:false,downloaded:false};
    // Recheck the branch and destination after hooks/fetch and before pushing.
    if((await cmd(['symbolic-ref','--quiet','--short','HEAD'])).stdout.trim()!==current||
       (await cmd(['remote','get-url','--push','--all','origin'])).stdout.trim()!==remote)throw new Error('The branch or destination changed. Refresh before pushing.');
    try{await cmd(['push','--porcelain','--set-upstream','origin',`HEAD:refs/heads/${current}`],{timeout:120000});}
    catch(error){throw new Error((committed?'Changes were committed locally; push failed. ':'')+redactError(error.message));}
    return {message:'Folder synced with GitHub.',committed,downloaded};
  }
  throw new Error('Unknown GitHub setup action');
}
