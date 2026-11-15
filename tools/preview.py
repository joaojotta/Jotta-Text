#!/usr/bin/env python3
"""Localhost-only live preview for static web projects (no third-party modules).

Serves HTML with an injected reload client; browser polls metadata for changes.
Never binds to a public network interface. PHP is NOT executed.
"""
import argparse
import http.server
import json
import os
from pathlib import Path
import threading
import urllib.parse
import webbrowser

RELOAD = '''<script data-litefront-reload>\n(()=>{let previous=null;async function tick(){try{const r=await fetch('/__litefront_status',{cache:'no-store'});if(!r.ok)return;const info=await r.json();if(previous!==null&&previous!==info.version)location.reload();previous=info.version;}catch(e){} }setInterval(tick,850);tick();})();\n</script>'''

class Preview(http.server.SimpleHTTPRequestHandler):
    root: Path
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(self.root), **kwargs)

    def do_GET(self):
        path = urllib.parse.urlsplit(self.path).path
        if path == '/__litefront_status':
            value = self.tree_stamp()
            payload = json.dumps({'version': value}).encode()
            self.send_response(200)
            self.send_header('Content-Type','application/json')
            self.send_header('Cache-Control','no-store')
            self.send_header('Content-Length',str(len(payload)))
            self.end_headers(); self.wfile.write(payload); return
        parsed = urllib.parse.unquote(path)
        full = (self.root / parsed.lstrip('/')).resolve()
        if not full.is_relative_to(self.root):
            self.send_error(403); return
        if full.is_dir():
            full = full / 'index.html'
        if full.is_file() and full.suffix.lower() in {'.html', '.htm'}:
            data = full.read_bytes().decode('utf-8', errors='replace')
            if '</body>' in data.lower():
                pos = data.lower().rfind('</body>'); data = data[:pos] + RELOAD + data[pos:]
            else:
                data += RELOAD
            payload = data.encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type','text/html; charset=utf-8')
            self.send_header('Cache-Control','no-store')
            self.send_header('Content-Length',str(len(payload)))
            self.end_headers(); self.wfile.write(payload); return
        return super().do_GET()

    def tree_stamp(self):
        latest = 0
        count = 0
        # Deliberately capped for responsiveness in large directories.
        for folder, dirs, files in os.walk(self.root):
            dirs[:] = [x for x in dirs if x not in {'.git', 'node_modules', '.cache', '.venv', 'vendor'}]
            for name in files:
                if count > 15000: break
                try:
                    s = (Path(folder) / name).stat()
                    latest = max(latest, s.st_mtime_ns)
                    count += 1
                except OSError: pass
            if count > 15000: break
        return f'{latest}:{count}'
    def end_headers(self):
        self.send_header('X-Content-Type-Options','nosniff')
        return super().end_headers()

def main():
    ap=argparse.ArgumentParser(description='Jotta Text external-browser live preview')
    ap.add_argument('directory',nargs='?',default='.',help='Project root')
    ap.add_argument('--port',type=int,default=8765)
    ap.add_argument('--file',default='index.html',help='Page to open, relative to project root')
    ap.add_argument('--no-browser',action='store_true')
    args=ap.parse_args()
    root=Path(args.directory).expanduser().resolve()
    if not root.is_dir(): ap.error(f'Not a directory: {root}')
    if not 1 <= args.port <= 65535: ap.error('Port outside valid range')
    Preview.root=root
    page = args.file.lstrip('/')
    url=f'http://127.0.0.1:{args.port}/'+urllib.parse.quote(page, safe='/')
    server = http.server.ThreadingHTTPServer(('127.0.0.1',args.port), Preview)
    print(f'Jotta Text preview: {url}',flush=True)
    print(f'Project root: {root}',flush=True)
    print('Ctrl+C to stop. Note: PHP files are served as text, not executed.',flush=True)
    if not args.no_browser: threading.Timer(0.5,lambda:webbrowser.open(url)).start()
    try: server.serve_forever()
    except KeyboardInterrupt: pass
    finally: server.server_close()
if __name__ == '__main__': main()
