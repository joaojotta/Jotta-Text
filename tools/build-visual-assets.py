#!/usr/bin/env python3
"""Regenerate the bundled native icon font from the imported SVG sources.
Requires fontTools (asset development only, not needed to build/run Jotta Text).
"""
import json
import math
import shutil
import re
from pathlib import Path
import xml.etree.ElementTree as ET
from fontTools.misc.transform import Transform
from fontTools.fontBuilder import FontBuilder
from fontTools.ttLib import TTFont
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.basePen import BasePen
from fontTools.svgLib.path import parse_path

ROOT=Path(__file__).resolve().parent.parent
ASSETS=ROOT/'profile/assets'

def circle(pen,x,y,r):
    k=.5522847498*r
    pen.moveTo((x+r,y))
    pen.curveTo((x+r,y+k),(x+k,y+r),(x,y+r))
    pen.curveTo((x-k,y+r),(x-r,y+k),(x-r,y))
    pen.curveTo((x-r,y-k),(x-k,y-r),(x,y-r))
    pen.curveTo((x+k,y-r),(x+r,y-k),(x+r,y))
    pen.closePath()

class Stroke(BasePen):
    """Expand flattened SVG strokes to overlapping, consistently wound contours."""
    def __init__(self,output,width):
        super().__init__(None);self.output=output;self.radius=width/2;self.points=[]
    def _moveTo(self,p):self.finish();self.points=[p]
    def _lineTo(self,p):self.points.append(p)
    def _curveToOne(self,a,b,c):
        origin=self.points[-1]
        for n in range(1,17):
            t=n/16;u=1-t
            self.points.append(tuple(u**3*origin[i]+3*u*u*t*a[i]+3*u*t*t*b[i]+t**3*c[i] for i in [0,1]))
    def _qCurveToOne(self,a,b):
        origin=self.points[-1]
        for n in range(1,17):
            t=n/16;u=1-t
            self.points.append(tuple(u*u*origin[i]+2*u*t*a[i]+t*t*b[i] for i in [0,1]))
    def _closePath(self):
        if self.points:self.points.append(self.points[0])
        self.finish()
    def _endPath(self):self.finish()
    def finish(self):
        for a,b in zip(self.points,self.points[1:],strict=False):
            dx,dy=b[0]-a[0],b[1]-a[1];length=math.hypot(dx,dy)
            if not length:continue
            nx,ny=-dy/length*self.radius,dx/length*self.radius
            self.output.moveTo((a[0]+nx,a[1]+ny))
            for p in [(a[0]-nx,a[1]-ny),(b[0]-nx,b[1]-ny),(b[0]+nx,b[1]+ny)]:self.output.lineTo(p)
            self.output.closePath()
        for x,y in self.points:circle(self.output,x,y,self.radius)
        self.points=[]

def draw_element(element,pen,root):
    tag=element.tag.split('}')[-1]
    fill=element.get('fill',root.get('fill','black'))
    stroke=element.get('stroke',root.get('stroke','none'))
    target=Stroke(pen,float(element.get('stroke-width',root.get('stroke-width','1.7')))) if fill=='none' and stroke!='none' else pen
    if tag=='path':parse_path(element.get('d',''),target)
    elif tag=='circle':circle(target,float(element.get('cx','0')),float(element.get('cy','0')),float(element.get('r','0')))
    elif tag in ('rect','line','polyline','polygon'):
        if tag=='rect':
            x,y,w,h=[float(element.get(k,'0')) for k in ['x','y','width','height']];points=[(x,y),(x+w,y),(x+w,y+h),(x,y+h)]
        elif tag=='line':points=[(float(element.get('x1','0')),float(element.get('y1','0'))),(float(element.get('x2','0')),float(element.get('y2','0')))]
        else:
            values=[float(x) for x in element.get('points','').replace(',',' ').split()];points=list(zip(values[::2],values[1::2],strict=False))
        if points:
            target.moveTo(points[0])
            for point in points[1:]:target.lineTo(point)
            if tag in ('rect','polygon'):target.closePath()
            else:target.endPath()
    if isinstance(target,Stroke):target.finish()

def draw_tree(element, pen, inherited=None):
    # Inkscape exports include nested transforms and CSS presentation styles.
    tag = element.tag.split('}')[-1]
    if tag in ('defs', 'namedview', 'metadata', 'title', 'desc'):
        return
    attributes = dict(inherited or {})
    attributes.update(element.attrib)
    attributes.update(part.strip().split(':', 1) for part in element.get('style', '').split(';') if ':' in part)
    transform = Transform()
    for kind, raw in re.findall(r'(matrix|translate|scale)\s*\(([^)]+)\)', element.get('transform', '')):
        values = [float(value) for value in re.split(r'[,\s]+', raw.strip())]
        if kind == 'matrix': transform = transform.transform(values)
        elif kind == 'translate': transform = transform.translate(values[0], values[1] if len(values) > 1 else 0)
        elif kind == 'scale': transform = transform.scale(values[0], values[1] if len(values) > 1 else values[0])
    output = TransformPen(pen, transform)
    if tag not in ('svg', 'g'):
        draw_element(ET.Element(element.tag, attributes), output, {})
    for child in element:
        draw_tree(child, output, attributes)

# User-supplied Markdown toolbar SVGs. Keep other application icons unchanged.
MARKDOWN_ICONS = {
    'heading': 'heading', 'bold': 'bold', 'italic': 'italic',
    'underline': 'underline', 'strike': 'strikethrough',
    'subscript': 'subscript', 'superscript': 'superscript',
    'link': 'link-m', 'image': 'file-image', 'code': 'code',
    'code-block': 'code', 'quote': 'double-quotes-r',
    'list': 'list-unordered', 'ordered-list': 'list-ordered',
    'task-list': 'list-check-3', 'rule': 'horizontal-rule',
    'table': 'table-2', 'braces': 'formatter', 'preview': 'markdown-preview',
}
for action, source in MARKDOWN_ICONS.items():
    shutil.copy2(ROOT / 'icons/ui-icons' / (source + '.svg'),
                 ASSETS / 'jotta-icons' / ('md-' + action + '.svg'))

for source in (ROOT / 'icons/file-icons').glob('*.svg'):
    shutil.copy2(source, ASSETS / 'jotta-icons' / ('file-' + source.name))

for source in (ASSETS/'fonts').glob('*.woff'):
    font=TTFont(source);font.flavor=None;font.save(source.with_suffix('.ttf'))

names=sorted(path.stem for path in (ASSETS/'jotta-icons').glob('*.svg'))
font=FontBuilder(1024,isTTF=True)
order=['.notdef']+names
font.setupGlyphOrder(order)
glyphs={'.notdef':TTGlyphPen(None).glyph()}
for name in names:
    pen=TTGlyphPen(None)
    output=TransformPen(Cu2QuPen(pen,1,reverse_direction=False),(1024/24,0,0,-1024/24,0,900))
    tree=ET.parse(ASSETS/'jotta-icons'/f'{name}.svg').getroot()
    draw_tree(tree, output)
    glyphs[name]=pen.glyph()
font.setupCharacterMap({0xE000+i:name for i,name in enumerate(names)})
font.setupGlyf(glyphs)
font.setupHorizontalMetrics({name:(1024,0) for name in order})
font.setupHorizontalHeader(ascent=900,descent=-124)
font.setupOS2(sTypoAscender=900,sTypoDescender=-124,usWinAscent=1024,usWinDescent=124)
font.setupNameTable({'familyName':'LiteFront Jotta Icons','styleName':'Regular','uniqueFontIdentifier':'LiteFront Jotta Icons 1','fullName':'LiteFront Jotta Icons','psName':'LiteFrontJottaIcons','version':'Version 1.0','licenseDescription':'Adapted from Jotta Edit SVG icons. GPL-2.0-or-later. See bundled asset notices.'})
font.setupPost();font.setupMaxp();font.save(ASSETS/'fonts/jotta-icons.ttf')
lua='-- Generated from imported Jotta Edit SVG icons. See assets/NOTICE.md.\nreturn {\n'
for i,name in enumerate(names):lua+='  ['+json.dumps(name)+']=utf8.char('+str(0xE000+i)+'),\n'
(ROOT/'profile/litefront/icon-map.lua').write_text(lua+'}\n')
print(f'Generated native icon font with {len(names)} glyphs')
