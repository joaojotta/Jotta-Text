// Imported copies stay inside the browser workspace, including nested folders.
export const WORKSPACE='/persist/workspace';
export function relativePath(value){
  if(typeof value!=='string'||!value||value.startsWith('/')||value.includes('\\')||value.includes('\0')||/^[a-z]:/i.test(value))throw new Error('Invalid import path');
  const parts=value.split('/');
  if(parts.some(part=>!part||part==='.'||part==='..'))throw new Error('Invalid import path');
  return parts.join('/');
}
export function workspacePath(value){return WORKSPACE+'/'+relativePath(value);}
export async function importFiles(FS,files){
  const imported=[],prepared=[],seen=new Set();let total=0;
  if(files.length>10000)throw new Error('Import at most 10,000 files at a time.');
  for(const file of files){
    const relative=relativePath(file.webkitRelativePath||file.name),path=workspacePath(relative);
    if(file.size>64*1024*1024)throw new Error(`File exceeds the 64 MiB import limit: ${relative}`);
    total+=file.size;
    if(total>128*1024*1024)throw new Error('Import at most 128 MiB at a time.');
    if(seen.has(path))throw new Error(`Duplicate import path: ${relative}`);seen.add(path);
    // Confirm before replacing workspace data; session buffers are restored
    // independently and are never silently replaced by a new import.
    let exists=false;try{exists=FS.stat(path).size>=0;}catch{}
    if(exists)throw new Error(`${relative} already exists in this browser workspace. Rename it before importing again.`);
    prepared.push({file,path});
  }
  try{
    for(const {file,path}of prepared){
      const bytes=new Uint8Array(await file.arrayBuffer());
      let exists=false;try{FS.stat(path);exists=true;}catch{}
      if(exists)throw new Error('The workspace changed during import. Try again.');
      FS.mkdirTree(path.slice(0,path.lastIndexOf('/')));FS.writeFile(path,bytes);imported.push(path);
    }
  }catch(error){for(const path of imported)FS.unlink(path);throw error;}
  return imported;
}
export function downloadName(path){return path.replaceAll('\\','/').split('/').at(-1)||'untitled.txt';}
