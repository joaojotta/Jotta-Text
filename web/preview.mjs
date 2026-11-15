// No same-origin permission: previewed scripts cannot read editor recovery data.
export function previewHTML(FS,html,filename,files={}){
  const doc=new DOMParser().parseFromString(html,'text/html');
  const root=(filename||'/persist/workspace/index.html').replace(/\/[^/]*$/,'/');
  const mime={css:'text/css',js:'text/javascript',mjs:'text/javascript',png:'image/png',jpg:'image/jpeg',jpeg:'image/jpeg',gif:'image/gif',svg:'image/svg+xml',woff:'font/woff',woff2:'font/woff2',ttf:'font/ttf'};
  function resource(value){
    if(!value||/^(?:[a-z]+:|\/\/|#)/i.test(value))return value;
    const target=new URL(value,'https://workspace.invalid'+root).pathname;
    if(!target.startsWith('/persist/workspace/'))return value;
    try{
      const bytes=files[target]!==undefined?new TextEncoder().encode(files[target]):FS.readFile(decodeURIComponent(target));
      let binary='';for(let i=0;i<bytes.length;i+=8192)binary+=String.fromCharCode(...bytes.subarray(i,i+8192));
      return 'data:'+(mime[target.split('.').at(-1)]||'application/octet-stream')+';base64,'+btoa(binary);
    }catch{return value;}
  }
  for(const element of doc.querySelectorAll('[src],link[href]')){
    const attr=element.hasAttribute('src')?'src':'href';element.setAttribute(attr,resource(element.getAttribute(attr)));
  }
  // The base element cannot escape the sandbox, but remote resources are left
  // explicit instead of accidentally resolving against the editor's origin.
  doc.querySelectorAll('base').forEach(element=>element.remove());
  return '<!doctype html>'+doc.documentElement.outerHTML;
}
