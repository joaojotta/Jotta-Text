// Local static preview with private editor-buffer updates over stdin.
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawn} from 'node:child_process';
import readline from 'node:readline';

const [project,entry='index.html',browserHelper,mode]=process.argv.slice(2);
if(!project)throw new Error('A project folder is required');
const root=await fs.realpath(project);
const port=Number(process.env.LITEFRONT_PREVIEW_PORT ?? 8765);
if(!Number.isInteger(port)||port<0||port>65535)throw new Error('Invalid preview port');
const inside=name=>name===root||name.startsWith(root+path.sep);
const mime={'.html':'text/html','.htm':'text/html','.xhtml':'text/html','.css':'text/css','.js':'text/javascript','.mjs':'text/javascript','.cjs':'text/javascript','.json':'application/json','.svg':'image/svg+xml','.png':'image/png','.jpg':'image/jpeg','.jpeg':'image/jpeg','.gif':'image/gif','.webp':'image/webp','.ico':'image/x-icon','.woff':'font/woff','.woff2':'font/woff2','.txt':'text/plain'};
const editable=new Set(['.html','.htm','.xhtml','.css','.js','.mjs','.cjs','.json','.svg','.txt']);
let diskVersion='initial',bufferVersion=0;
let overlays=new Map();
const clients=new Set();
const version=()=>`${diskVersion}:${bufferVersion}`;
function announce(){for(const client of clients)client.write(`data: ${version()}\n\n`);}
let initialBuffers;
const initial=new Promise(resolve=>{initialBuffers=resolve;});
if(mode==='--editor'){
  const input=readline.createInterface({input:process.stdin,crlfDelay:Infinity});
  input.on('line',line=>{
    try{
      const data=JSON.parse(line);
      if(!data.files||typeof data.files!=='object'||(Array.isArray(data.files)&&data.files.length))return;
      const next=new Map();
      for(const [relative,contents]of Object.entries(data.files)){
        const name=path.resolve(root,relative);
        if(typeof contents==='string'&&inside(name)&&editable.has(path.extname(name).toLowerCase()))next.set(name,contents);
      }
      if(next.size!==overlays.size||[...next].some(([name,text])=>overlays.get(name)!==text)){
        overlays=next;bufferVersion++;announce();
      }
      initialBuffers();
    }catch{ /* An interrupted or malformed editor message keeps the last complete snapshot. */ }
  });
  input.on('close',()=>{initialBuffers();stop();});
}
async function updateVersion(){
  const hashes=[];
  async function walk(dir){
    for(const entry of await fs.readdir(dir,{withFileTypes:true})){
      if(['node_modules','.git','.flatpak-builder','vendor','dist'].includes(entry.name))continue;
      const name=path.join(dir,entry.name);
      if(entry.isSymbolicLink())continue;
      if(entry.isDirectory())await walk(name);
      else{const stat=await fs.stat(name);hashes.push(`${name}:${stat.mtimeMs}:${stat.size}`);}
    }
  }
  try{
    await walk(root);
    const next=crypto.createHash('sha256').update(hashes.sort().join('\0')).digest('hex');
    if(next!==diskVersion){diskVersion=next;announce();}
  }catch{}
}
function reload(responseVersion){
  return `<script data-litefront-reload>(()=>{const current=${JSON.stringify(responseVersion)};const changed=v=>{if(v!==current)location.reload()};if(window.EventSource){const events=new EventSource('/__litefront_events');events.onmessage=e=>changed(e.data)}else{setInterval(async()=>{try{const r=await fetch('/__litefront_status',{cache:'no-store'});if(r.ok)changed(await r.text())}catch{}},250)}})();</script>`;
}
// Resolve existing ancestors for new named buffers, while refusing symlink escapes.
async function canonical(name){
  try{return await fs.realpath(name);}catch(error){
    if(error.code!=='ENOENT')throw error;
    const parent=path.dirname(name);
    if(parent===name)throw error;
    return path.join(await canonical(parent),path.basename(name));
  }
}
const server=http.createServer(async(req,res)=>{
  const send=(status,text)=>{res.writeHead(status,{'Content-Type':'text/plain','Cache-Control':'no-store'});res.end(text);};
  if(!['GET','HEAD'].includes(req.method))return send(405,'Method not allowed');
  try{
    const url=new URL(req.url,'http://127.0.0.1');
    if(url.pathname==='/__litefront_status')return send(200,version());
    if(url.pathname==='/__litefront_events'){
      if(req.method!=='GET')return send(405,'Method not allowed');
      res.writeHead(200,{'Content-Type':'text/event-stream','Cache-Control':'no-store','Connection':'keep-alive'});
      clients.add(res);res.write(`data: ${version()}\n\n`);
      res.on('close',()=>clients.delete(res));return;
    }
    let requested=path.resolve(root,'.'+decodeURIComponent(url.pathname));
    if(!inside(requested))return send(403,'Outside project');
    let name=await canonical(requested);
    if(!inside(name))return send(403,'Outside project');
    const stat=await fs.stat(name).catch(error=>{if(error.code==='ENOENT')return null;throw error;});
    if(stat?.isDirectory()){
      requested=path.join(requested,'index.html');name=await canonical(path.join(name,'index.html'));
    }
    if(!inside(name))return send(403,'Outside project');
    if(path.extname(name).toLowerCase()==='.php')return send(403,'PHP requires a PHP runtime');
    const type=mime[path.extname(name).toLowerCase()]||'application/octet-stream';
    const responseVersion=version();
    const buffer=overlays.get(requested)??overlays.get(name);
    let bytes=buffer!==undefined?Buffer.from(buffer):await fs.readFile(name);
    if(type==='text/html')bytes=Buffer.from(bytes.toString('utf8')+reload(responseVersion));
    res.writeHead(200,{'Content-Type':type,'Cache-Control':'no-store','Content-Length':bytes.length});
    res.end(req.method==='HEAD'?undefined:bytes);
  }catch(error){send(error.code==='ENOENT'?404:400,'Cannot serve this file');}
});
server.on('error',error=>{console.error(error.message);process.exit(1);});
let polling;
async function poll(){await updateVersion();polling=setTimeout(poll,850);polling.unref();}
await updateVersion();
if(mode==='--editor')await initial;
server.listen(port,'127.0.0.1',()=>{
  const url='http://127.0.0.1:'+server.address().port+'/'+entry.split('/').map(encodeURIComponent).join('/');
  console.log(url);
  if(browserHelper){const child=spawn(browserHelper,['uri',url],{stdio:'ignore'});child.on('error',()=>{});child.unref();}
});
polling=setTimeout(poll,850);polling.unref();
function stop(){
  clearTimeout(polling);
  for(const client of clients)client.end();
  server.close(()=>process.exit(0));server.closeAllConnections();
}
for(const signal of ['SIGTERM','SIGINT'])process.on(signal,stop);
