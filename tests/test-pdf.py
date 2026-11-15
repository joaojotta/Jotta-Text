#!/usr/bin/env python3
"""Validate offline PDFs with a separate parser, including pagination and Unicode."""
from pathlib import Path
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parent.parent
bundle=ROOT/'dist/native/share/lite-xl/litefront'
with tempfile.TemporaryDirectory(prefix='jotta-text-pdf-') as directory:
    temp=Path(directory)
    source=temp/'snapshot.html';target=temp/'Chosen name.pdf'
    html='''<!doctype html><html><head><script>throw Error('never execute')</script></head><body>
<h1>Résumé português</h1><p>Saved directly: <strong>bold</strong>, <em>italic</em>, <u>underlined</u>, <del>deleted</del>.</p>
<table><tr><th>Heading</th><th>Count</th></tr><tr><td>Cell content</td><td>42</td></tr></table>
<pre>const answer = 42;\nconsole.log(answer);</pre><ul><li>First item</li><li>Second item</li></ul>
<p><a href="https://example.org">Example link</a></p>'''
    html+=''.join(f'<p>Paragraph {i}: multipage export keeps the text.</p>' for i in range(110))+'</body></html>'
    source.write_text(html)
    invocation=[str(bundle/'node/node'),str(bundle/'markdown-pdf.mjs'),str(source),str(target),str(temp)]
    subprocess.run(invocation,check=True,capture_output=True,text=True,timeout=20)
    assert target.read_bytes().startswith(b'%PDF-')
    info=subprocess.run(['pdfinfo',str(target)],check=True,capture_output=True,text=True).stdout
    pages=int(next(line.split(':')[1] for line in info.splitlines() if line.startswith('Pages:')))
    assert pages>=3,info
    text=subprocess.run(['pdftotext','-layout',str(target),'-'],check=True,capture_output=True,text=True).stdout
    for fragment in ['Résumé português','Cell content','const answer = 42;','First item','Paragraph 109']:
        assert fragment in text,(fragment,text[:1000])
    assert 'never execute' not in text
    # Failed writes leave an existing destination intact and remove partial files.
    target.write_bytes(b'original')
    source.write_text('<html><body><p><img src="bad.png"></p></body></html>')
    (temp/'bad.png').write_bytes(b'invalid image')
    failed=subprocess.run(invocation,capture_output=True,text=True,timeout=10)
    assert failed.returncode!=0 and 'PDF export failed' in failed.stderr
    assert target.read_bytes()==b'original'
    assert not list(temp.glob('*.tmp'))
    print('PASS: valid multipage PDF, Unicode, styled content, tables, code, chosen destination and failed-export preservation')
