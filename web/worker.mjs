import {run} from './worker-core.mjs';
self.onmessage=async event=>{
  const {id,kind,payload}=event.data;
  try{self.postMessage({id,result:await run(kind,payload)});}
  catch(error){self.postMessage({id,error:String(error.message||error)});}
};
