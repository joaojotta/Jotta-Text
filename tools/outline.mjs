// Document outline adapted from Jotta Edit (GPL-2.0-or-later; see assets/NOTICE.md).
// Source buffers arrive in framed messages; no document or project file is read.
import {createRequire} from 'node:module';
import {createInterface} from 'node:readline';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
const require=createRequire(import.meta.url);
const LIMIT=1000,MAX_BYTES=2*1024*1024;
const supported=new Set(['markdown','html','javascript','jsx','typescript','tsx','css','scss','less','php','python']);
const compact=value=>Array.from(String(value??'').replace(/\s+/g,' ').trim()).slice(0,240).join('');
let css,html,ts,php,markdown,TextDocument;
function document(source,language){
  TextDocument??=require('./tooling/node_modules/vscode-languageserver-textdocument').TextDocument;
  return TextDocument.create('untitled:outline',language,1,source);
}
function entry(name,kind,depth,start,end){
  return {name:compact(name),kind,depth,line:start.line+1,column:start.character+1,endLine:end.line+1,endColumn:end.character+1};
}
async function markdownOutline(source){
  markdown??=await import('./tooling/node_modules/prettier/plugins/markdown.mjs');
  const tree=await markdown.parsers.markdown.parse(source,{}),items=[],lineCount=source.split('\n').length;
  const text=node=>node.type==='html'?'':node.type==='image'?node.alt:node.children?node.children.map(text).join(''):node.value??'';
  for(const node of tree.children){
    if(node.type!=='heading')continue;
    const p=node.position;
    items.push({name:compact(text(node)),kind:'Heading',depth:node.depth-1,line:p.start.line,column:p.start.column,endLine:lineCount,endColumn:Infinity});
    if(items.length>LIMIT)break;
  }
  const stack=[];
  for(const item of items){while(stack.length&&stack.at(-1).depth>=item.depth){const prev=stack.pop();prev.endLine=item.line-1;prev.endColumn=Infinity;}stack.push(item);}
  return items;
}
function stylesheetOutline(source,language){
  css??=require('./tooling/node_modules/vscode-css-languageservice');
  const service=(language==='scss'?css.getSCSSLanguageService:language==='less'?css.getLESSLanguageService:css.getCSSLanguageService)();
  const doc=document(source,language),symbols=service.findDocumentSymbols2(doc,service.parseStylesheet(doc));
  const entries=[],pending=symbols.map(item=>({item,depth:0})).reverse();
  while(pending.length&&entries.length<=LIMIT){
    const {item,depth}=pending.pop();
    entries.push(entry(item.name,'Selector',depth,item.range.start,item.range.end));
    for(let i=(item.children?.length??0)-1;i>=0;i--)pending.push({item:item.children[i],depth:depth+1});
  }
  return entries;
}
function htmlOutline(source){
  html??=require('./tooling/node_modules/vscode-html-languageservice');
  const doc=document(source,'html'),tree=html.getLanguageService().parseHTMLDocument(doc),items=[];
  const pending=tree.roots.map(node=>({node,depth:0})).reverse();
  while(pending.length&&items.length<=LIMIT){
    const {node,depth}=pending.pop();if(!node.tag)continue;
    const attrs=Object.fromEntries(Object.entries(node.attributes??{}).map(([key,value])=>[key.toLowerCase(),(value??'').replace(/^['"]|['"]$/g,'').trim()]));
    const name=node.tag+(attrs.id?'#'+attrs.id:'')+(attrs.class?attrs.class.split(/\s+/).map(value=>'.'+value).join(''):'');
    items.push(entry(name,'Element',depth,doc.positionAt(node.start),doc.positionAt(node.end)));
    if(node.tag.toLowerCase()==='style'&&node.startTagEnd!==undefined&&(!attrs.type||attrs.type.toLowerCase()==='text/css')){
      const offset=node.startTagEnd,embedded=source.slice(offset,node.endTagStart??node.end),inner=document(embedded,'css');
      for(const item of stylesheetOutline(embedded,'css')){
        if(items.length>LIMIT)break;
        const start=doc.positionAt(offset+inner.offsetAt({line:item.line-1,character:item.column-1}));
        const end=doc.positionAt(offset+inner.offsetAt({line:item.endLine-1,character:item.endColumn-1}));
        items.push(entry(item.name,item.kind,depth+1+item.depth,start,end));
      }
    }
    for(let i=node.children.length-1;i>=0;i--)pending.push({node:node.children[i],depth:depth+1});
  }
  return items;
}
function scriptOutline(source,language){
  ts??=require('./tooling/node_modules/typescript');
  const kind=language==='tsx'?ts.ScriptKind.TSX:language==='jsx'?ts.ScriptKind.JSX:language==='typescript'?ts.ScriptKind.TS:ts.ScriptKind.JS;
  const tree=ts.createSourceFile('outline.'+({typescript:'ts',javascript:'js'}[language]??language),source,ts.ScriptTarget.Latest,true,kind);
  const entries=[],pending=[{node:tree,depth:0}];
  while(pending.length&&entries.length<=LIMIT){
    const {node,depth}=pending.pop();let name,category;
    if(ts.isClassDeclaration(node)||ts.isInterfaceDeclaration(node)||ts.isEnumDeclaration(node)){name=node.name?.getText(tree);category='Class';}
    else if(ts.isFunctionDeclaration(node)||ts.isMethodDeclaration(node)||ts.isMethodSignature(node)||ts.isGetAccessorDeclaration(node)||ts.isSetAccessorDeclaration(node)){name=node.name?.getText(tree);category='Function';}
    else if(ts.isConstructorDeclaration(node)){name='constructor';category='Function';}
    else if(ts.isVariableDeclaration(node)){name=node.name.getText(tree);category=node.initializer&&(ts.isArrowFunction(node.initializer)||ts.isFunctionExpression(node.initializer))?'Function':'Symbol';}
    else if(ts.isTypeAliasDeclaration(node)||ts.isModuleDeclaration(node)||ts.isPropertyDeclaration(node)||ts.isPropertySignature(node)||ts.isEnumMember(node)){name=node.name?.getText(tree);category='Symbol';}
    const named=!!name;
    if(named){const start=tree.getLineAndCharacterOfPosition((node.name??node).getStart(tree)),end=tree.getLineAndCharacterOfPosition(node.getEnd());entries.push(entry(name,category,depth,start,end));}
    const children=[];ts.forEachChild(node,child=>{children.push(child);});
    for(let i=children.length-1;i>=0;i--)pending.push({node:children[i],depth:depth+(named?1:0)});
  }
  return entries;
}
function phpOutline(source){
  php??=require('./tooling/node_modules/php-parser');
  const parser=new php({parser:{suppressErrors:true,extractDoc:false},ast:{withPositions:true}});
  const tree=source.includes('<?')?parser.parseCode(source):parser.parseEval(source),entries=[],pending=[{node:tree,depth:0}];
  while(pending.length&&entries.length<=LIMIT){
    const {node,depth}=pending.pop();if(!node||typeof node!=='object')continue;
    const category=['class','interface','trait','enum'].includes(node.kind)?'Class':['function','method'].includes(node.kind)?'Function':null;
    const name=category&&(typeof node.name==='string'?node.name:node.name?.name);
    if(name&&node.loc){const start=node.name?.loc?.start??node.loc.start,end=node.loc.end;entries.push(entry(name,category,depth,{line:start.line-1,character:start.column},{line:end.line-1,character:end.column}));}
    const children=[];
    for(const [key,value] of Object.entries(node)){
      if(['loc','name','comments','errors','leadingComments','trailingComments'].includes(key))continue;
      if(Array.isArray(value)){for(const child of value)if(child&&typeof child==='object')children.push(child);}
      else if(value&&typeof value==='object'&&value.kind)children.push(value);
    }
    for(let i=children.length-1;i>=0;i--)pending.push({node:children[i],depth:depth+(name?1:0)});
  }
  return entries;
}
function pythonOutline(source){
  // A small lexical mask excludes strings, comments and triple-quoted docstrings.
  let masked='',i=0;
  while(i<source.length){
    const start=i,c=source[i],triple=source.slice(i,i+3);
    if(c==='#'){while(i<source.length&&source[i]!=='\n')i++;}
    else if(c==='"'||c==="'"){
      const quote=triple===c.repeat(3)?triple:c;i+=quote.length;
      while(i<source.length){if(source[i]==='\\'){i+=2;continue;}if(source.startsWith(quote,i)){i+=quote.length;break;}i++;}
    }else{masked+=c;i++;continue;}
    masked+=source.slice(start,i).replace(/[^\n\r]/g,' ');
  }
  const lines=masked.split('\n'),entries=[],parents=[];
  for(let index=0;index<lines.length;index++){
    const line=lines[index],indent=(line.match(/^[ \t]*/)?.[0]??'').replace(/\t/g,'        ').length;
    if(!line.trim())continue;
    while(parents.length&&indent<=parents.at(-1).indent){const prev=parents.pop();prev.item.endLine=index;prev.item.endColumn=Infinity;}
    const match=/^([ \t]*)(?:async\s+)?(def|class)\s+([\p{L}_][\p{L}\p{N}_]*)/u.exec(line);
    if(!match)continue;
    const item={name:match[3],kind:match[2]==='class'?'Class':'Function',depth:parents.length,line:index+1,column:line.indexOf(match[3],match[1].length)+1,endLine:lines.length,endColumn:Infinity};
    entries.push(item);parents.push({indent,item});if(entries.length>LIMIT)break;
  }
  return entries;
}
export async function documentOutline(source,language){
  language=String(language??'').toLowerCase();if(language==='php source')language='php';if(language==='typescript with jsx')language='tsx';
  if(!supported.has(language))return {entries:[],supported:false};
  if(Buffer.byteLength(source)>MAX_BYTES)return {entries:[],supported:true,tooLarge:true};
  let entries;
  if(language==='markdown')entries=await markdownOutline(source);
  else if(language==='html')entries=htmlOutline(source);
  else if(['css','scss','less'].includes(language))entries=stylesheetOutline(source,language);
  else if(language==='php')entries=phpOutline(source);
  else if(language==='python')entries=pythonOutline(source);
  else entries=scriptOutline(source,language);
  const limited=entries.length>LIMIT,lines=source.split('\n');
  const byteColumn=(line,col)=>Buffer.byteLength((lines[line-1]??'').slice(0,Number.isFinite(col)?col-1:undefined))+1;
  entries=entries.slice(0,LIMIT).map(item=>({...item,column:byteColumn(item.line,item.column),endColumn:byteColumn(item.endLine,item.endColumn)}));
  return {entries,supported:true,limited};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  const input=createInterface({input:process.stdin,crlfDelay:Infinity});let queue=Promise.resolve();
  input.on('line',line=>{queue=queue.then(async()=>{
    let id;try{const request=JSON.parse(line);id=request.id;const result=await documentOutline(request.source,request.language);await new Promise(resolve=>process.stdout.write(JSON.stringify({id,...result})+'\n',resolve));}
    catch(error){await new Promise(resolve=>process.stdout.write(JSON.stringify({id,error:String(error.message??error)})+'\n',resolve));}
  });});
}
