import assert from 'node:assert/strict';
import test from 'node:test';
import {run} from '../dist/web/worker-core.mjs';
import {relativePath,workspacePath,importFiles} from '../web/files.mjs';

test('browser imports reject traversal, drive letters and conflicting workspace files',async()=>{
  for(const path of ['../secret','a/../../secret','/root/file','C:/file','a\\file','a//b','a/./b','a\0b'])assert.throws(()=>relativePath(path));
  assert.equal(workspacePath('project/olá.css'),'/persist/workspace/project/olá.css');
  const written=new Map(),FS={mkdirTree(){},stat(path){if(!written.has(path))throw new Error('Missing');return {size:1};},writeFile(path,bytes){written.set(path,bytes);},unlink(path){written.delete(path);}};
  const file={name:'style.css',webkitRelativePath:'site/style.css',size:3,arrayBuffer:async()=>new TextEncoder().encode('a{}')};
  assert.deepEqual(await importFiles(FS,[file]),['/persist/workspace/site/style.css']);
  await assert.rejects(importFiles(FS,[file]),/already exists/);
  const another={...file,name:'new.css',webkitRelativePath:'site/new.css'};
  await assert.rejects(importFiles(FS,[another,file]),/already exists/);
  assert.equal(written.size,1,'a failed batch left partially imported files');
  assert.equal(new TextDecoder().decode(written.values().next().value),'a{}');
});
test('browser formatting uses local JS, HTML, CSS, Markdown and PHP parsers',async()=>{
  for(const [parser,source,expected]of [
    ['babel','const answer=42','const answer = 42;\n'],['html','<div><p>Hi</p></div>','<div><p>Hi</p></div>\n'],
    ['css','a{color:red}','a {\n  color: red;\n}\n'],['markdown','# Hello','# Hello\n'],['php','<?php $x=1;','<?php $x = 1;\n'],
  ])assert.equal(await run('format',{source,parser,tabWidth:2,useTabs:false}),expected);
  await assert.rejects(run('format',{source:'const =',parser:'babel'}));
});
test('browser outlines parse syntax instead of matching commented source',async()=>{
  const cases=[
    ['markdown','---\ntitle: metadata\n---\n# Real\n```md\n# Fake\n```\n## Child',['Real','Child']],
    ['javascript','// function fake() {}\nclass Real { method(){} }\nconst arrow=()=>42;',['Real','method','arrow']],
    ['typescript','interface Item {name:string}\nfunction test() {}',['Item','test']],
    ['html','<!-- <fake> --><main id="app"><p>Hello</p></main>',['main#app','p']],
    ['css','/* .fake{} */\nbody{color:red}\n@media (max-width:400px){.card{color:blue}}',['body','@media','.card']],
    ['php','<?php /* function fake(){} */ class Real { function hello() {} }',['Real','hello']],
    ['python','"""\ndef fake():\n"""\nclass Real:\n    def method(self): pass\n',['Real','method']],
  ];
  for(const [language,source,names]of cases){
    const result=await run('outline',{id:7,language,source});
    assert.equal(result.id,7);assert.deepEqual(result.entries.map(item=>item.name),names,language);
    assert(result.entries.every(item=>item.line>=1&&item.column>=1));
  }
});
test('outline and formatting jobs are bounded and preserve request identity',async()=>{
  const large='x'.repeat(2*1024*1024+1);
  assert.equal((await run('outline',{id:9,source:large,language:'javascript'})).tooLarge,true);
  await assert.rejects(run('format',{source:large,parser:'babel'}),/2 MiB/);
  assert.equal((await run('outline',{id:10,source:'plain text',language:'text'})).supported,false);
  const many=await run('outline',{id:11,source:Array.from({length:1002},(_,i)=>'# Heading '+i).join('\n'),language:'markdown'});
  assert.equal(many.entries.length,1000);assert.equal(many.limited,true);
});
