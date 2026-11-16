import {importFiles,downloadName,relativePath,WORKSPACE} from './files.mjs';
import {previewHTML} from './preview.mjs';
const $=id=>document.getElementById(id),pending=new Map(),events=[];
let nextId=1,ready=false,storageAvailable=true,syncing=Promise.resolve(),picking=false,generation=0;
const worker=new Worker(new URL('./worker.mjs',import.meta.url),{type:'module'});
worker.onmessage=({data})=>{if(pending.has(data.id))pending.set(data.id,data);};
worker.onerror=event=>{
  for(const [id,item]of pending)if(item.worker)pending.set(id,{error:event.message||'Browser worker could not start'});
};
const finish=(id,result)=>{if(pending.has(id))pending.set(id,{result});};
const fail=(id,error)=>{if(pending.has(id))pending.set(id,{error:String(error.message||error)});};
const fs=()=>globalThis.Module.FS;
// The notice over the editor appears only while loading, on failure, or when
// browser storage cannot keep the workspace. Clicking a warning dismisses it.
function notice(text){$('status').textContent=text;$('status').hidden=false;}
$('status').onclick=()=>{if(ready)$('status').hidden=true;};
// data-storage on <body> is 'unsaved', 'saving', 'saved' or 'unavailable'.
const storageState=state=>{document.body.dataset.storage=state;};
function sync(){
  if(!storageAvailable)return Promise.resolve(false);
  syncing=syncing.catch(()=>{}).then(()=>new Promise((resolve,reject)=>{
    const snapshotGeneration=generation;
    storageState('saving');
    fs().syncfs(false,error=>{
      if(error){storageAvailable=false;storageState('unavailable');notice('Browser storage failed. Download files to keep a copy.');resolve(false);}
      else{if(snapshotGeneration===generation)storageState('saved');resolve(true);}
    });
  }));
  return syncing;
}
function download(bytes,name,type='application/octet-stream'){
  const url=URL.createObjectURL(new Blob([bytes],{type})),link=document.createElement('a');
  link.href=url;link.download=name;document.body.append(link);link.click();link.remove();
  setTimeout(()=>URL.revokeObjectURL(url),30000);
}
async function pick(folder){
  if(picking)throw new Error('A file picker is already open');
  picking=true;
  const input=$(folder?'folder-picker':'file-picker');input.value='';
  try{
    const files=await new Promise(resolve=>{
      const changed=()=>{cleanup();resolve([...input.files]);},cancelled=()=>{cleanup();resolve([]);};
      const cleanup=()=>{input.removeEventListener('change',changed);input.removeEventListener('cancel',cancelled);};
      input.addEventListener('change',changed,{once:true});input.addEventListener('cancel',cancelled,{once:true});input.click();
    });
    if(!files.length)return null;
    const paths=await importFiles(fs(),files);await sync();
    return folder?WORKSPACE+'/'+relativePath(files[0].webkitRelativePath).split('/')[0]:paths;
  }finally{picking=false;}
}
async function saveName(payload){
  const dialog=$('save-dialog'),input=dialog.querySelector('input');
  if(dialog.open)throw new Error('A save dialog is already open');
  input.value=payload.name||'untitled.txt';dialog.returnValue='cancel';dialog.showModal();input.focus();input.select();
  const selected=await new Promise(resolve=>dialog.addEventListener('close',()=>resolve(dialog.returnValue==='save'?input.value:null),{once:true}));
  if(selected===null)return null;
  const name=relativePath(selected);
  const initial=payload.initial?.startsWith(WORKSPACE+'/')?payload.initial:WORKSPACE;
  const path=initial+'/'+name;
  if(fs().analyzePath(path).exists&&!confirm(`Replace ${name} in this browser workspace?`))return null;
  fs().mkdirTree(path.slice(0,path.lastIndexOf('/')));return path;
}
function preview(payload,show=true,print=false){
  if(!show&&$('preview-panel').hidden)return;
  $('preview-panel').hidden=false;
  let html=previewHTML(fs(),payload.html,payload.filename,payload.files);
  if(print)html+='<script>addEventListener("load",()=>{setTimeout(()=>window.print(),100)})<\/script>';
  $('preview-frame').srcdoc=html;
  resize();
}
async function handle(kind,payload){
  if(kind==='dirty'){generation++;if(storageAvailable)storageState('unsaved');return true;}
  if(kind==='theme'){
    for(const key of ['bg','panel','line','ink','accent'])document.documentElement.style.setProperty('--'+key,payload[key]);
    document.documentElement.style.colorScheme=payload.mode;return true;
  }
  if(kind==='dialog'){
    if(payload.mode==='save')return saveName(payload);
    const result=await pick(payload.mode==='folder');
    if(Array.isArray(result)){
      for(const path of result.slice(1))events.push({kind:'file',path});
      return result[0]||null;
    }
    return result;
  }
  if(kind==='download'){download(fs().readFile(payload.path),downloadName(payload.path));return true;}
  if(kind==='sync'){await sync();return true;}
  if(kind==='preview'||kind==='preview-update'||kind==='print'){preview(payload,kind!=='preview-update',kind==='print');return true;}
  if(kind==='ready'){
    ready=true;globalThis.JottaBrowserReady=true;document.body.classList.add('ready');
    if(storageAvailable){storageState('saved');$('status').hidden=true;}
    else{storageState('unavailable');notice('Browser storage is unavailable. Download files before closing this tab.');}
    requestAnimationFrame(resize);$('canvas').focus();return true;
  }
  throw new Error('Unknown browser request: '+kind);
}
globalThis.JottaBrowser={
  request(kind,payload){
    const id=nextId++;pending.set(id,{});
    if(kind==='format'||kind==='outline'){
      pending.set(id,{worker:true});worker.postMessage({id,kind,payload});
    }else Promise.resolve().then(()=>handle(kind,payload)).then(result=>finish(id,result),error=>fail(id,error));
    return id;
  },
  poll(id){
    if(id===0)return events.shift();
    const result=pending.get(id);
    if(!result||(!('result'in result)&&!('error'in result)))return undefined;
    pending.delete(id);return result;
  },
  cancel(id){pending.delete(id);},
};
function resize(){
  if(!ready)return;
  const canvas=$('canvas'),width=Math.max(240,canvas.clientWidth),height=Math.max(180,canvas.clientHeight);
  globalThis.Module._jotta_web_resize(width,height);
}
new ResizeObserver(resize).observe($('canvas'));
// The editor syncs to IndexedDB every two seconds; without storage nothing
// survives the tab. Ask before closing while edits are not yet stored.
addEventListener('beforeunload',event=>{
  if(ready&&(storageAvailable?document.body.dataset.storage!=='saved':generation>0))event.preventDefault();
});
$('close-preview').onclick=()=>{$('preview-panel').hidden=true;resize();};
document.addEventListener('keydown',event=>{
  if((event.ctrlKey||event.metaKey)&&['s','o','n'].includes(event.key.toLowerCase())&&!$('save-dialog').open)event.preventDefault();
});
// SDL installs document-level keyboard listeners. Native DOM dialogs keep their
// own keyboard/default actions and must not forward filename typing to Lua.
for(const type of ['keydown','keyup','keypress','input','textInput']){
  document.addEventListener(type,event=>{if($('save-dialog').open)event.stopImmediatePropagation();},true);
}
globalThis.Module={
  canvas:$('canvas'),thisProgram:'/app/jotta-text',arguments:[],
  print:text=>console.log(text),printErr:text=>console.error(text),
  setStatus:text=>{if(!ready&&text)notice(text);},
  onAbort:reason=>{notice('Jotta Text could not start: '+reason);},
  preRun:[()=>{
    const module=globalThis.Module,FS=module.FS;
    module.ENV.HOME='/persist';module.ENV.LITE_USERDIR='/persist/user';
    module.addRunDependency('jotta-text-storage');
    FS.mkdirTree('/persist');
    let started=false;
    const start=error=>{
      if(started)return;
      started=true;
      if(error){storageAvailable=false;console.error(error);}
      FS.mkdirTree('/persist/user');FS.mkdirTree(WORKSPACE);FS.chdir(WORKSPACE);
      module.removeRunDependency('jotta-text-storage');
    };
    // A blocked or damaged IndexedDB can leave syncfs pending forever; start without it.
    setTimeout(()=>start(new Error('Browser storage did not respond within 10 seconds')),10000);
    try{
      FS.mount(module.IDBFS,{},'/persist');
      FS.syncfs(true,start);
    }catch(error){start(error);}
  }],
};
const engine=document.createElement('script');engine.src=new URL('./jotta-text.js',import.meta.url).href;
engine.onerror=()=>{notice('Editor engine missing. Build with scripts/build-web.sh and serve dist/web over HTTP.');};
document.body.append(engine);
