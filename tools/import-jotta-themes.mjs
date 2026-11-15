#!/usr/bin/env node
// Regenerate imported data from a local checkout; no network access at build time.
import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
const source=process.argv[2];
if(!source)throw new Error('Usage: node tools/import-jotta-themes.mjs /path/to/jotta-edit');
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const load=name=>import(pathToFileURL(path.resolve(source,'src',name)));
const {syntaxPalettes,syntaxThemeChoices}=await load('syntax-themes.js');
const {deriveInterfaceColoursFromPalette}=await load('interface-theme.js');
const {explorerIconPalettes,explorerIconPaletteChoices,explorerIconColour}=await load('explorer-icon-palettes.js');
const gitdir=path.resolve(source,'.git');
const head=fs.readFileSync(path.join(gitdir,'HEAD'),'utf8').trim();
let revision=head;
if(head.startsWith('ref: ')){
 const ref=head.slice(5), loose=path.join(gitdir,ref);
 revision=fs.existsSync(loose)?fs.readFileSync(loose,'utf8').trim():fs.readFileSync(path.join(gitdir,'packed-refs'),'utf8').split('\n').find(line=>line.endsWith(' '+ref))?.split(' ')[0];
}
if(!/^[a-f0-9]{40}$/.test(revision))throw new Error('Cannot read upstream revision');
function lua(value){
 if(typeof value==='string')return JSON.stringify(value);
 if(typeof value==='boolean'||typeof value==='number')return String(value);
 if(Array.isArray(value))return '{'+value.map(lua).join(',')+'}';
 return '{'+Object.entries(value).map(([key,item])=>'['+lua(key)+']='+lua(item)).join(',')+'}';
}
const icons={};
for(const mode of ['dark','light']){
 icons[mode]={};
 for(const choice of [...syntaxThemeChoices,...explorerIconPaletteChoices].filter(x=>x.id!=='auto')){
  icons[mode][choice.id]={};
  for(const name of Object.keys(explorerIconPalettes['jotta-dark']))
   icons[mode][choice.id][name]=explorerIconColour(name,{},choice.id,choice.id,mode);
 }
}
const palettes=Object.fromEntries(syntaxThemeChoices.filter(x=>x.id!=='auto').map(x=>[x.id,{label:x.label,...syntaxPalettes[x.id]}]));
// Jotta's default pair inherits the CSS root variables rather than derived colors.
const css=fs.readFileSync(path.resolve(source,'src/style.css'),'utf8');
const fields=['bg','surface','surface-alt','sidebar','title','ink','muted','line','accent','accent-text'];
function defaults(mode){
 const selector=mode==='dark'?':root':':root[data-theme="light"]';
 const start=css.indexOf(selector+' {');
 if(start<0)throw new Error(`Missing ${selector} colors`);
 const block=css.slice(start,css.indexOf('}',start));
 const colors={};
 for(const [,key,raw] of block.matchAll(/--([\w-]+)\s*:\s*(#[\da-f]{3,8})\s*;/gi)){
  colors[key]=raw.length===4?'#'+[...raw.slice(1)].map(x=>x+x).join(''):raw;
 }
 for(const key of fields)if(!colors[key])throw new Error(`Missing ${mode} UI field ${key}`);
 return colors;
}
const interfaces=Object.fromEntries(Object.entries(palettes).map(([id,palette])=>[
 id,{label:palette.label,mode:palette.mode,...(palette.inheritSyntax?defaults(palette.mode):deriveInterfaceColoursFromPalette(palette))}
]));
for(const [name,value] of Object.entries({palettes,'interface-palettes':interfaces,'icon-palettes':icons,'icon-palette-choices':explorerIconPaletteChoices}))
 fs.writeFileSync(path.join(root,'profile/litefront',name+'.lua'),`-- Imported from Jotta Edit ${revision}; see assets/NOTICE.md.\nreturn ${lua(value)}\n`);
fs.writeFileSync(path.join(root,'profile/assets/reference/Jotta-Edit-theme-catalog.json'),JSON.stringify({revision,editor:palettes,ui:interfaces},null,2)+'\n');
for(const name of ['syntax-themes.js','interface-theme.js','explorer-icon-palettes.js','color-utils.js','style.css'])
 fs.copyFileSync(path.resolve(source,'src',name),path.join(root,'profile/assets/reference','Jotta-Edit-'+name));
console.log(`Imported ${Object.keys(palettes).length} editor palettes, ${Object.keys(interfaces).length} UI palettes and ${explorerIconPaletteChoices.length-1} icon palettes from ${revision}`);
