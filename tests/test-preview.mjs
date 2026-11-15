import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { spawn } from 'node:child_process';
import { once } from 'node:events';

test('bundled preview reloads and confines requests to the project', async()=>{
  const temp=await fs.mkdtemp(path.join(os.tmpdir(),'litefront-preview-'));
  const project=path.join(temp,'project');await fs.mkdir(project);
  await fs.writeFile(path.join(project,'index.html'),'<h1>Hello</h1>');
  await fs.writeFile(path.join(project,'index.php'),'SECRET PHP SOURCE');
  await fs.writeFile(path.join(temp,'outside.txt'),'outside');
  await fs.symlink(path.join(temp,'outside.txt'),path.join(project,'escape.txt'));
  const child=spawn(process.execPath,['tools/preview.mjs',project],{
    env:{...process.env,LITEFRONT_PREVIEW_PORT:'0'},stdio:['ignore','pipe','pipe']});
  let errors='';child.stderr.on('data',chunk=>errors+=chunk);
  try {
    const output=await Promise.race([
      once(child.stdout,'data').then(([chunk])=>chunk.toString()),
      once(child,'exit').then(()=>{throw new Error(errors || 'preview exited');}),
      new Promise((_,reject)=>{const timer=setTimeout(()=>reject(new Error('preview startup timeout')),5000);timer.unref();}),
    ]);
    const url=new URL(output.trim());
    assert.equal(url.hostname,'127.0.0.1');
    const response=await fetch(url);
    assert.equal(response.status,200);
    assert.match(await response.text(),/data-litefront-reload/);
    assert.equal((await fetch(new URL('/escape.txt',url))).status,403);
    assert.equal((await fetch(new URL('/index.php',url))).status,403);
    assert.equal((await fetch(new URL('/missing',url))).status,404);
    const status=new URL('/__litefront_status',url);
    const previous=await (await fetch(status)).text();
    await fs.writeFile(path.join(project,'new.css'),'body { color: red; }');
    await new Promise(resolve=>setTimeout(resolve,1200));
    assert.notEqual(await (await fetch(status)).text(),previous);
  } finally {
    if(child.exitCode===null&&child.signalCode===null){child.kill();await once(child,'exit');}await fs.rm(temp,{recursive:true,force:true});
  }
});

test('editor buffers stream without saving, push reloads and remain confined',async()=>{
  const temp=await fs.mkdtemp(path.join(os.tmpdir(),'jotta-text-live-'));
  const project=path.join(temp,'project');await fs.mkdir(project);
  await fs.writeFile(path.join(project,'index.html'),'<h1>Saved</h1>');
  await fs.writeFile(path.join(project,'style.css'),'body{color:black}');
  await fs.writeFile(path.join(project,'app.js'),'console.log("saved")');
  await fs.writeFile(path.join(temp,'outside.txt'),'private');
  await fs.symlink(temp,path.join(project,'escape'));
  const child=spawn(process.execPath,['tools/preview.mjs',project,'index.html','','--editor'],{
    env:{...process.env,LITEFRONT_PREVIEW_PORT:'0'},stdio:['pipe','pipe','pipe']});
  let errors='';child.stderr.on('data',chunk=>errors+=chunk);
  const snapshot=files=>child.stdin.write(JSON.stringify({files})+'\n');
  const output=once(child.stdout,'data');
  snapshot({'index.html':'<h1>Unsaved é</h1>','style.css':'body{color:red}','app.js':'console.log("unsaved")','fresh.html':'<p>New buffer</p>',
    '../outside.txt':'leak','escape/outside.txt':'leak','index.php':'<?php secret ?>'});
  let events;
  try{
    const [chunk]=await Promise.race([output,once(child,'exit').then(()=>{throw Error(errors||'preview exited');}),
      new Promise((_,reject)=>{const timer=setTimeout(()=>reject(Error('preview startup timeout')),5000);timer.unref();})]);
    const url=new URL(chunk.toString().trim());
    const html=await(await fetch(url)).text();
    assert.match(html,/<h1>Unsaved é<\/h1>/);
    assert.match(html,/EventSource/);
    assert.equal(await(await fetch(new URL('/style.css',url))).text(),'body{color:red}');
    assert.equal(await(await fetch(new URL('/app.js',url))).text(),'console.log("unsaved")');
    assert.match(await(await fetch(new URL('/fresh.html',url))).text(),/New buffer/);
    assert.equal((await fetch(new URL('/escape/outside.txt',url))).status,403);
    assert.equal((await fetch(new URL('/index.php',url))).status,403);
    const head=await fetch(url,{method:'HEAD'});assert.equal(await head.text(),'');assert.ok(Number(head.headers.get('content-length'))>0);
    const initial=await(await fetch(new URL('/__litefront_status',url))).text();
    const eventResponse=await fetch(new URL('/__litefront_events',url));events=eventResponse.body.getReader();
    assert.match(new TextDecoder().decode((await events.read()).value),new RegExp(initial));
    snapshot({'index.html':'<h1>Typing again</h1>'});
    const update=await Promise.race([events.read(),new Promise((_,reject)=>{const timer=setTimeout(()=>reject(Error('reload event timeout')),2000);timer.unref();})]);
    assert.match(new TextDecoder().decode(update.value),/data:/);
    assert.notEqual(await(await fetch(new URL('/__litefront_status',url))).text(),initial);
    assert.match(await(await fetch(url)).text(),/Typing again/);
    assert.equal(await fs.readFile(path.join(project,'index.html'),'utf8'),'<h1>Saved</h1>');
    assert.equal(await fs.readFile(path.join(project,'style.css'),'utf8'),'body{color:black}');
    assert.equal(await fs.readFile(path.join(project,'app.js'),'utf8'),'console.log("saved")');
    assert.equal(await(await fetch(new URL('/style.css',url))).text(),'body{color:black}','closing/discarding a buffer should return to disk');
    snapshot({});
    for(let attempt=0;attempt<50;attempt++){
      if((await(await fetch(url)).text()).includes('<h1>Saved</h1>'))break;
      await new Promise(resolve=>setTimeout(resolve,20));
    }
    assert.match(await(await fetch(url)).text(),/<h1>Saved<\/h1>/);
    assert.equal((await fetch(new URL('/fresh.html',url))).status,404);
  }finally{
    if(events)await events.cancel();if(child.exitCode===null&&child.signalCode===null){child.kill();await once(child,'exit');}await fs.rm(temp,{recursive:true,force:true});
  }
});
