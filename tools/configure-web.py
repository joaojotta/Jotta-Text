#!/usr/bin/env python3
"""Generate a cross file with relocatable, correctly quoted bundle paths."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
data=ROOT/'dist/web-data/data'
flags=['-sASYNCIFY=1','-sALLOW_MEMORY_GROWTH=1','-sINITIAL_MEMORY=134217728',
       '-sSTACK_SIZE=8388608','-sASYNCIFY_STACK_SIZE=1048576','-sEXIT_RUNTIME=0',
       '-sENVIRONMENT=web','-sFORCE_FILESYSTEM=1','-lidbfs.js',
       '-sEXPORTED_RUNTIME_METHODS='+json.dumps(['FS','IDBFS','ENV','addRunDependency','removeRunDependency']),
       '-sEXPORTED_FUNCTIONS='+json.dumps(['_main','_malloc','_free','_jotta_web_resize']),
       '--preload-file',str(data)+'@/app/data']
def literal(value):
    return "'"+value.replace('\\','\\\\').replace("'","\\'")+"'"
cross="""[binaries]
c = 'emcc'
ar = 'emar'
strip = 'emstrip'
pkg-config = 'false'
cmake = 'false'
[host_machine]
system = 'emscripten'
cpu_family = 'wasm32'
cpu = 'wasm32'
endian = 'little'
[properties]
needs_exe_wrapper = true
[built-in options]
"""+'c_link_args = ['+', '.join(map(literal,flags))+']\n'
(ROOT/'dist/web-cross.ini').write_text(cross)
