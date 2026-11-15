// Direct, offline Markdown PDF export using the same HTML snapshot as HTML export.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
import {randomUUID} from 'node:crypto';
const bundle=path.dirname(fileURLToPath(import.meta.url));
const require=createRequire(path.join(bundle,'tooling/package.json'));
const PDFDocument=require('pdfkit');
const {parseDocument}=require('htmlparser2');
export async function exportPDF(html, output, baseDir, fontsDir=path.join(bundle,'assets/fonts')) {
  const root=parseDocument(html);
  const body=root.children.find(n=>n.name==='html')?.children.find(n=>n.name==='body') || root;
  const temporary=output+'.'+randomUUID()+'.tmp';
  const doc=new PDFDocument({size:'A4',margin:48,info:{Title:'Markdown export'}});
  const stream=fs.createWriteStream(temporary,{flags:'wx'});
  const finished=new Promise((resolve,reject)=>{stream.on('finish',resolve);stream.on('error',reject);doc.on('error',reject);stream.on('close',()=>{if(!stream.writableFinished)reject(new Error('PDF output closed before completion'));});});
  doc.pipe(stream);
  doc.registerFont('body',path.join(fontsDir,'rubik-latin-400-normal.ttf'));
  doc.registerFont('bold',path.join(fontsDir,'rubik-latin-600-normal.ttf'));
  const mono=path.join(fontsDir,'../../../fonts/JetBrainsMono-Regular.ttf');
  doc.registerFont('code',fs.existsSync(mono)?mono:'Courier');
  const left=48,width=doc.page.width-96;
  const textContent=node=>node.type==='text'?node.data:(node.children || []).map(textContent).join('');
  const room=height=>{if(doc.y+height>doc.page.height-48)doc.addPage();};
  const leaves=(nodes,style={})=>nodes.flatMap(node=>{
    if(node.type==='text')return [{text:node.data.replace(/\s+/g,' '),...style}];
    if(['script','style'].includes(node.name))return [];
    const next={...style};
    if(['strong','b','th'].includes(node.name)) next.bold=true;
    if(['em','i'].includes(node.name)) next.italic=true;
    if(node.name==='u')next.underline=true;
    if(['del','s'].includes(node.name))next.strike=true;
    if(node.name==='code')next.code=true;
    if(node.name==='sub'||node.name==='sup')next.small=true;
    if(node.name==='a' && /^(https?:|mailto:)/i.test(node.attribs.href || ''))next.link=node.attribs.href;
    if(node.name==='br')return [{text:'\n',...next}];
    if(node.name==='img')return [{text:node.attribs.alt || '[image]',...next}];
    if(node.name==='input')return [{text:node.attribs.checked!==undefined?'[x] ':'[ ] ',...next}];
    return leaves(node.children || [],next);
  });
  function paragraph(nodes,{size=11,bold=false,indent=0,prefix=''}={}) {
    room(size*2);
    const runs=leaves(nodes,{bold});
    if(prefix)runs.unshift({text:prefix,bold});
    if(!runs.length)return;
    doc.x=left+indent;
    runs.forEach((run,i)=>{
      doc.font(run.code?'code':run.bold?'bold':'body').fontSize(run.small?size*.8:size).fillColor(run.link?'#1667a0':'#222222');
      doc.text(run.text,{width:width-indent,continued:i<runs.length-1,lineGap:3,underline:!!run.underline,strike:!!run.strike,link:run.link,oblique:run.italic?12:false});
    });
    doc.x=left;doc.moveDown(.55);
  }
  function image(node) {
    const src=node.attribs.src || '';
    // Export never downloads remote content or executes Markdown HTML.
    let filename;
    try {filename=src.startsWith('file:')?fileURLToPath(src):baseDir&&!/^[a-z]+:/i.test(src)?path.resolve(baseDir,decodeURIComponent(src)):null;} catch {}
    if(filename && /\.(png|jpe?g)$/i.test(filename) && fs.existsSync(filename)) {
      const img=doc.openImage(filename);
      const scale=Math.min(1,width/img.width,(doc.page.height-110)/img.height);
      const height=img.height*scale;
      room(height+12);doc.image(img,left,doc.y,{width:img.width*scale});doc.y+=height+12;
    } else paragraph([{type:'text',data:node.attribs.alt || '[Image unavailable]'}]);
  }
  function table(node) {
    const rows=[];
    const collect=n=>{if(n.name==='tr')rows.push(n);else for(const child of n.children || [])collect(child);};collect(node);
    const columns=Math.max(1,...rows.map(row=>row.children.filter(n=>['td','th'].includes(n.name)).length));
    const cellWidth=width/columns;
    for(const row of rows) {
      const cells=row.children.filter(n=>['td','th'].includes(n.name));
      const heights=cells.map(cell=>doc.font(cell.name==='th'?'bold':'body').fontSize(10).heightOfString(textContent(cell),{width:cellWidth-12}));
      const height=Math.max(24,...heights.map(h=>h+12));
      room(height);
      const y=doc.y;
      cells.forEach((cell,i)=>{
        doc.rect(left+i*cellWidth,y,cellWidth,height).strokeColor('#bbbbbb').stroke();
        doc.font(cell.name==='th'?'bold':'body').fontSize(10).fillColor('#222222').text(textContent(cell),left+i*cellWidth+6,y+6,{width:cellWidth-12});
      });
      doc.y=y+height;doc.x=left;
    }
    doc.moveDown(.6);
  }
  function blocks(nodes,indent=0) {
    for(const node of nodes) {
      if(node.type==='text'){if(node.data.trim())paragraph([node],{indent});continue;}
      if(['script','style','head','button'].includes(node.name))continue;
      if(/^h[1-6]$/.test(node.name))paragraph(node.children,{size:Math.max(12,26-Number(node.name[1])*2),bold:true,indent});
      else if(node.name==='pre'){
        room(30);doc.font('code').fontSize(10).fillColor('#222222').text(textContent(node),left+indent,doc.y,{width:width-indent,lineGap:3});doc.moveDown(.7);
      } else if(node.name==='table')table(node);
      else if(node.name==='img')image(node);
      else if(node.name==='p'){
        // Keep block images at their natural position instead of printing their URL.
        let group=[];
        for(const child of node.children || []){if(child.name==='img'){if(group.length)paragraph(group,{indent});group=[];image(child);}else group.push(child);}
        if(group.length)paragraph(group,{indent});
      } else if(node.name==='ul'||node.name==='ol'){
        let number=1;
        for(const li of node.children.filter(n=>n.name==='li')){
          paragraph(li.children.filter(n=>!['ul','ol'].includes(n.name)),{indent:indent+14,prefix:node.name==='ol'?`${number++}. `:'• '});
          blocks(li.children.filter(n=>['ul','ol'].includes(n.name)),indent+14);
        }
      } else if(node.name==='blockquote')blocks(node.children,indent+18);
      else if(node.name==='hr'){room(15);doc.moveTo(left,doc.y+5).lineTo(left+width,doc.y+5).strokeColor('#aaaaaa').stroke();doc.y+=15;}
      else blocks(node.children || [],indent);
    }
  }
  try {
    blocks(body.children);doc.end();await finished;
    fs.renameSync(temporary,output);
  } catch(error) {
    doc.destroy();stream.destroy();await finished.catch(()=>{});
    fs.rmSync(temporary,{force:true});throw error;
  }
}
if(process.argv[1] && path.resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  try {
    const [input,output,baseDir]=process.argv.slice(2);
    if(!input || !output)throw new Error('Expected input HTML and output PDF paths');
    await exportPDF(fs.readFileSync(input,'utf8'),output,baseDir);
  } catch(error) {console.error('PDF export failed: '+error.message);process.exitCode=1;}
}
