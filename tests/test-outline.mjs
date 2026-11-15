import test from 'node:test';
import assert from 'node:assert/strict';
import {documentOutline} from '../dist/native/share/lite-xl/litefront/outline.mjs';

test('Markdown headings skip metadata and fenced code, preserve hierarchy and line positions',async()=>{
  const source='---\ntitle: metadata\n---\n# Overview **bold**\n\n```js\n# Fake\n```\n## [Details](url)\n\nEnd\n===\n';
  const result=await documentOutline(source,'markdown');
  assert.deepEqual(result.entries.map(x=>[x.name,x.depth,x.line]),[['Overview bold',0,4],['Details',1,9],['End',0,11]]);
  assert.equal(result.entries[0].endLine,10);
});
test('HTML includes elements and embedded CSS with source positions; scripts and comments stay opaque',async()=>{
  const source='<!-- <fake></fake> -->\n<main id="app" class="wide content"><style>.card {color:red}</style><script>const x="<fake>";</script><p>😀</p><span>ok</span></main>';
  const result=await documentOutline(source,'html');
  assert.deepEqual(result.entries.map(x=>x.name),['main#app.wide.content','style','.card','script','p','span']);
  const selector=result.entries.find(x=>x.name==='.card');
  assert.equal(selector.depth,2);assert.equal(selector.line,2);
  assert.equal(selector.column,Buffer.byteLength(source.split('\n')[1].split('.card')[0])+1);
  const span=result.entries.find(x=>x.name==='span');
  assert.equal(span.column,Buffer.byteLength(source.split('\n')[1].split('<span>')[0])+1);
  const nonCss=await documentOutline('<style type="text/plain">.fake{color:red}</style>','html');
  assert.deepEqual(nonCss.entries.map(x=>x.name),['style']);
});
test('CSS/SCSS/LESS selectors use the bundled service and nested rule hierarchy',async()=>{
  for(const language of ['css','scss','less']){
    const result=await documentOutline('/* .fake {} */\n@media print { .card, .wide { color: red; } }',language);
    assert.deepEqual(result.entries.map(x=>[x.name,x.depth]),[['@media print',0],['.card',1],['.wide',1]]);
  }
});
test('JavaScript and TypeScript use real syntax trees including class members and arrow functions',async()=>{
  const result=await documentOutline('// function fake() {}\nclass Café { run() {} }\nconst text="function fakeAgain(){}";\nconst action=()=>1;','javascript');
  assert.deepEqual(result.entries.map(x=>x.name),['Café','run','text','action']);
  assert.equal(result.entries[1].depth,1);
  const ts=await documentOutline('interface User { name: string; }\ntype Id = number;\nfunction fetch(id: Id): User { return {name:"ok"}; }','typescript');
  assert.deepEqual(ts.entries.map(x=>x.name),['User','name','Id','fetch']);
  const unicode='const café=()=>{}; const next=()=>{};';
  const entries=(await documentOutline(unicode,'javascript')).entries;
  assert.equal(entries[1].column,Buffer.byteLength(unicode.split('next')[0])+1);
  const jsx=await documentOutline('const App=()=> <div/>;','tsx');assert.equal(jsx.entries[0].name,'App');
});
test('PHP parser and Python lexical mask ignore strings, comments and docstrings',async()=>{
  const php=await documentOutline('<?php $fake="function nope() {}"; class Page { public function render() {} }','php');
  assert.deepEqual(php.entries.map(x=>[x.name,x.depth]),[['Page',0],['render',1]]);
  const python=await documentOutline('"""\ndef fake(): pass\n"""\nclass Page:\n    async def render(self):\n        pass\ndef outside():\n    pass\n','python');
  assert.deepEqual(python.entries.map(x=>[x.name,x.depth,x.line]),[['Page',0,4],['render',1,5],['outside',0,7]]);
  assert.equal(python.entries[0].endLine,6);
});
test('Entry/size limits and unsupported documents return explicit states',async()=>{
  const limited=await documentOutline(Array.from({length:1005},(_,i)=>'# Heading '+i).join('\n'),'markdown');
  assert.equal(limited.entries.length,1000);assert.equal(limited.limited,true);
  const large=await documentOutline('x'.repeat(2*1024*1024+1),'markdown');assert.equal(large.tooLarge,true);
  assert.equal((await documentOutline('text','plaintext')).supported,false);
});
