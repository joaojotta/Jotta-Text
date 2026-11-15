import * as prettier from './lib/prettier/standalone.mjs';
import * as babel from './lib/prettier/plugins/babel.mjs';
import * as estree from './lib/prettier/plugins/estree.mjs';
import * as typescript from './lib/prettier/plugins/typescript.mjs';
import * as html from './lib/prettier/plugins/html.mjs';
import * as postcss from './lib/prettier/plugins/postcss.mjs';
import * as markdown from './lib/prettier/plugins/markdown.mjs';
import * as yaml from './lib/prettier/plugins/yaml.mjs';
const plugins=[babel,estree,typescript,html,postcss,markdown,yaml];
let php;
async function phpPlugin(){
  if(!php){globalThis.prettier=prettier;await import('./lib/php.mjs');php=globalThis.prettierPlugins.php;}
  return php;
}
export async function run(kind,payload){
  if(typeof payload.source!=='string'||new TextEncoder().encode(payload.source).length>2*1024*1024){
    if(kind==='outline')return {id:payload.id,entries:[],supported:true,tooLarge:true};
    throw new Error('The browser formatter supports documents up to 2 MiB.');
  }
  if(kind==='format')return prettier.format(payload.source,{
    parser:payload.parser,tabWidth:payload.tabWidth,useTabs:payload.useTabs,phpVersion:'8.4',
    plugins:payload.parser==='php'?[...plugins,await phpPlugin()]:plugins,
  });
  if(kind!=='outline')throw new Error('Unknown browser worker request');
  const {source,language,id}=payload,entries=[],lines=source.split('\n');
  const parser={javascript:'babel',jsx:'babel',typescript:'typescript',tsx:'typescript',
    html:'html',css:'css',scss:'scss',less:'less',markdown:'markdown',php:'php'}[language];
  if(!parser&&language!=='python')return {id,entries:[],supported:false};
  function add(name,kind,depth,start,end){
    if(entries.length>1000)return;
    entries.push({name:String(name||kind).replace(/\s+/g,' ').slice(0,240),kind,depth,
      line:start?.line||1,column:start?.column||1,endLine:end?.line||lines.length,endColumn:end?.column||1});
  }
  if(language==='python'){
    // Ignore Python comments and strings without executing or importing source.
    let quote='',triple=false,escaped=false,indentStack=[];
    const masked=source.split('');let offset=0;
    for(const line of lines){
      for(let i=0;i<line.length;i++,offset++){
        const char=line[i];
        if(quote){
          masked[offset]=' ';
          if(escaped){escaped=false;continue;}
          if(char==='\\'){escaped=true;continue;}
          if(char===quote&&(!triple||line.slice(i,i+3)===quote.repeat(3))){
            if(triple){masked[offset+1]=masked[offset+2]=' ';i+=2;offset+=2;}
            quote='';triple=false;
          }
        }else if(char==='#'){for(;i<line.length;i++,offset++)masked[offset]=' ';break;}
        else if(char==='"'||char==="'"){
          quote=char;triple=line.slice(i,i+3)===char.repeat(3);masked[offset]=' ';
          if(triple){masked[offset+1]=masked[offset+2]=' ';i+=2;offset+=2;}
        }
      }
      offset++;
      if(quote&&!triple)quote='';escaped=false;
    }
    masked.join('').split('\n').forEach((line,index)=>{
      const match=/^([ \t]*)(?:async\s+)?(def|class)\s+([\p{L}_][\p{L}\p{N}_]*)/u.exec(line);
      if(!match)return;
      const indent=match[1].replaceAll('\t','        ').length;
      while(indentStack.length&&indentStack.at(-1)>=indent)indentStack.pop();
      add(match[3],match[2]==='class'?'Class':'Function',indentStack.length,{line:index+1,column:match[1].length+1});indentStack.push(indent);
    });
  }else{
    const plugin=parser==='php'?await phpPlugin():plugins.find(value=>value.parsers?.[parser]);
    const tree=await plugin.parsers[parser].parse(source,{parser,originalText:source});
    const seen=new WeakSet();
    const position=(node,end=false)=>{
      const point=(node.loc||node.position)?.[end?'end':'start'];
      if(point)return {line:point.line,column:(node.position?point.column:point.column+1)};
      const span=node.sourceSpan?.[end?'end':'start'];
      if(span)return {line:span.line+1,column:span.col+1};
      const css=node.source?.[end?'end':'start'];if(css)return css;
    };
    function walk(node,depth=0){
      if(!node||typeof node!=='object'||seen.has(node)||entries.length>1000)return;
      seen.add(node);
      if(Array.isArray(node)){for(const item of node)walk(item,depth);return;}
      let name,kind;
      if(language==='markdown'&&node.type==='heading'){
        const text=item=>item.children?item.children.map(text).join(''):item.value||item.alt||'';
        add(text(node),'Heading',node.depth-1,position(node));return;
      }
      if(language==='html'&&node.type==='element'){
        const attrs=Object.fromEntries((node.attrs||[]).map(attr=>[attr.name,attr.value]));
        name=node.name+(attrs.id?'#'+attrs.id:'')+(attrs.class?'.'+attrs.class.trim().split(/\s+/).join('.'):'');kind='Element';
      }
      if(['css','scss','less'].includes(language)&&['css-rule','css-atrule','rule','atrule'].includes(node.type)){
        name=node.selector||'@'+node.name;kind='Selector';
      }
      if(['FunctionDeclaration','ClassDeclaration','TSInterfaceDeclaration','TSTypeAliasDeclaration','TSEnumDeclaration'].includes(node.type)){
        name=node.id?.name;kind=node.type.includes('Class')?'Class':node.type.includes('Function')?'Function':'Type';
      }
      if(['ClassMethod','ObjectMethod','MethodDefinition','TSMethodSignature'].includes(node.type)){
        name=node.key?.name||node.key?.value;kind='Method';
      }
      if(node.type==='VariableDeclarator'&&['ArrowFunctionExpression','FunctionExpression','ClassExpression'].includes(node.init?.type)){
        name=node.id?.name;kind='Function';
      }
      if(language==='php'&&['class','interface','trait','enum','function','method'].includes(node.kind)){
        name=typeof node.name==='string'?node.name:node.name?.name;kind=node.kind==='method'?'Method':node.kind==='function'?'Function':'Class';
      }
      if(name)add(name,kind,depth,position(node),position(node,true));
      const next=depth+(name?1:0);
      for(const [key,value]of Object.entries(node)){
        if(['parent','prev','next','loc','position','source','sourceSpan','comments','leadingComments','trailingComments','tokens','attrs'].includes(key))continue;
        if(value&&typeof value==='object')walk(value,next);
      }
    }
    walk(tree);
  }
  // Headings and Python definitions end before the next sibling/ancestor.
  if(['markdown','python'].includes(language)){
    for(let i=0;i<entries.length;i++){
      const next=entries.slice(i+1).find(item=>item.depth<=entries[i].depth);
      entries[i].endLine=next?next.line-1:lines.length;entries[i].endColumn=(lines[entries[i].endLine-1]||'').length+1;
    }
  }
  const byteColumn=(line,column)=>new TextEncoder().encode((lines[line-1]||'').slice(0,column-1)).length+1;
  return {id,entries:entries.slice(0,1000).map(item=>({...item,
    column:byteColumn(item.line,item.column),endColumn:byteColumn(item.endLine,item.endColumn)})),supported:true,limited:entries.length>1000};
}
