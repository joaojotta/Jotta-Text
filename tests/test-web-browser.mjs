// Runs against the real compiled WASM engine, not a mocked browser editor.
import assert from 'node:assert/strict';
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import os from 'node:os';
// Usage: node tests/test-web-browser.mjs [chromium|firefox] [web directory]
const browserName=process.argv[2]||'chromium';
const root=path.resolve(process.argv[3]||'dist/web');
const playwright=await import(pathToFileURL(path.resolve('dist/browser-test/node_modules/playwright/index.mjs')));
if(!['chromium','firefox'].includes(browserName))throw new Error(`Unsupported browser: ${browserName}`);
const server=http.createServer(async(req,res)=>{
  try{
    const name=path.resolve(root,'.'+decodeURIComponent(new URL(req.url,'http://local').pathname));
    if(!name.startsWith(root+path.sep)&&name!==root){res.writeHead(403);res.end();return;}
    const file=name===root?path.join(root,'index.html'):name;
    const mime={'.html':'text/html','.js':'text/javascript','.mjs':'text/javascript','.wasm':'application/wasm','.css':'text/css','.svg':'image/svg+xml'};
    res.setHeader('Content-Type',mime[path.extname(file)]||'application/octet-stream');res.end(await fs.readFile(file));
  }catch{res.writeHead(404);res.end();}
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const browser=await playwright[browserName].launch({headless:true,...(browserName==='chromium'?{channel:'chromium'}:{})});
const fixture=await fs.mkdtemp(path.join(os.tmpdir(),'jotta-text-web-'));
try{
  const page=await browser.newPage({viewport:{width:1280,height:800}}),errors=[];
  page.on('pageerror',error=>errors.push(error.message));
  page.on('console',message=>{if(message.type()==='error'||message.text().startsWith('Error:'))console.error('Browser:',message.text());});
  const url=`http://127.0.0.1:${server.address().port}/`;
  async function ready(){
    await page.waitForFunction(()=>globalThis.JottaBrowserReady===true,null,{timeout:60000});
    assert(await page.locator('#status').isHidden(),'the startup notice stayed over the editor');
  }
  // The editor's own shortcuts replace the old toolbar; the key press is also
  // the user activation browsers require before opening a file picker.
  async function shortcut(keys){await page.focus('#canvas');await page.keyboard.press(keys);}
  async function snapshotContains(text){
    try{await page.waitForFunction(text=>{
      try{return Module.FS.readFile('/persist/user/documents.lua',{encoding:'utf8'}).includes(text);}catch{return false;}
    },text,{timeout:15000});}
    catch(error){
      console.error('Expected snapshot text:',text,'Page errors:',errors);
      console.error(await page.evaluate(()=>{try{return Module.FS.readFile('/persist/user/documents.lua',{encoding:'utf8'});}catch{return 'No snapshot';}}));
      await page.screenshot({path:`dist/web-test-failure-${browserName}.png`});throw error;
    }
  }
  async function importFile(name,source){
    const chooser=page.waitForEvent('filechooser');await shortcut('Control+o');
    await (await chooser).setFiles({name,mimeType:'text/plain',buffer:Buffer.from(source)});
    await snapshotContains(name);
  }
  await page.goto(url);await ready();
  assert.equal(await page.locator('header').count(),0,'the browser toolbar returned');
  await fs.mkdir(path.join(fixture,'site'));
  await fs.writeFile(path.join(fixture,'site/index.html'),'<h1>Folder project</h1>');
  const folderChooser=page.waitForEvent('filechooser');await shortcut('Control+Shift+o');
  await (await folderChooser).setFiles(path.join(fixture,'site'));
  await snapshotContains('/persist/workspace/site');
  await importFile('portable.js','const answer=42');
  await page.click('#canvas');await page.keyboard.press('Control+Alt+Shift+f');
  await snapshotContains('const answer = 42;');
  assert.equal(await page.evaluate(()=>Module.FS.readFile('/persist/workspace/portable.js',{encoding:'utf8'})),'const answer=42');
  await page.waitForFunction(()=>document.body.dataset.storage==='saved');
  await page.reload();await ready();
  await snapshotContains('/persist/workspace/site');
  await page.click('#canvas');await page.keyboard.press('Control+End');await page.keyboard.type('// reopened');
  await snapshotContains('// reopened');await snapshotContains('const answer = 42;');
  await importFile('preview.html','<!doctype html><html><body><h1>Initial</h1></body></html>');
  await shortcut('Control+Alt+p');await page.frameLocator('#preview-frame').getByText('Initial',{exact:true}).waitFor();
  await page.click('#canvas');await page.keyboard.press('Control+a');
  await page.keyboard.type('<!doctype html><html><body><h1>Changed live</h1></body></html>');
  await page.frameLocator('#preview-frame').getByText('Changed live',{exact:true}).waitFor();
  assert(!await page.evaluate(()=>Module.FS.readFile('/persist/workspace/preview.html',{encoding:'utf8'}).includes('Changed live')));
  assert.equal(await page.locator('#preview-frame').getAttribute('sandbox'),'allow-scripts allow-modals');
  await page.click('#canvas');await page.keyboard.press('Control+Shift+s');
  await page.waitForSelector('#save-dialog[open]');
  await page.locator('#save-dialog input').focus();await page.keyboard.press('Control+a');
  await page.keyboard.type('preview-copy.html');
  const downloaded=page.waitForEvent('download');await page.click('#save-dialog button[value="save"]');
  assert.equal((await downloaded).suggestedFilename(),'preview-copy.html');
  assert.equal(await page.evaluate(()=>Module.FS.readFile('/persist/workspace/preview-copy.html',{encoding:'utf8'})),
    '<!doctype html><html><body><h1>Changed live</h1></body></html>\n','save dialog typing changed the editor buffer');
  await shortcut('Control+Comma');
  assert.deepEqual(errors,[]);
  const errorLog=await page.evaluate(()=>Module.FS.analyzePath('/persist/user/error.txt').exists);
  assert.equal(errorLog,false,'The WASM engine wrote an error log');
  console.log(`PASS (${browserName}): compiled browser startup, file/folder imports, unsaved formatting, IndexedDB recovery, live sandboxed preview, Save As download, dialog isolation and shared settings`);
}finally{await browser.close();await new Promise(resolve=>server.close(resolve));await fs.rm(fixture,{recursive:true,force:true});}
