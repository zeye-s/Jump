"""Export selected 1.11 native sandstone faces; source PNGs are read-only."""
from pathlib import Path
import json,hashlib,shutil,tarfile,io,gzip
from PIL import Image,ImageDraw
from macro_paving import groups
R=Path(__file__).resolve().parent;AUTHOR=(R/'customer').exists();C=R/'customer' if AUTHOR else R.parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,d):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(d,ensure_ascii=False,indent=2),encoding='utf-8')
def surface(x,y,seed=112):
 h=((x*73856093)^(y*19349663)^(seed*83492791))&0x7fffffff
 for _ in range(2):h=((h^(h>>16))*0x45d9f3b)&0x7fffffff
 return [0,0,0,0,0,0,0,4,4,4,4,4,4,2,2,6][(h^(h>>16))&15]
def mask(cells,p):
 x,y=p;ds=[(0,-1),(1,-1),(1,0),(1,1),(0,1),(-1,1),(-1,0),(-1,-1)];a=[int((x+dx,y+dy) in cells) for dx,dy in ds]
 for k,l,r in [(1,0,2),(3,2,4),(5,4,6),(7,6,0)]:a[k]&=a[l]&a[r]
 return sum(v<<i for i,v in enumerate(a))
def render(layout,atlas,d,tid):
 r=d['groundSampling']['themes'].get(tid,d['groundSampling']['default'])['region'];patch=atlas.crop((r[0],r[1],r[0]+r[2],r[1]+r[3]));out=Image.new('RGBA',(768,576))
 for y in range(0,576,r[3]):
  for x in range(0,768,r[2]):out.paste(patch,(x,y))
 def draw(r,x,y):out.alpha_composite(atlas.crop((r[0],r[1],r[0]+r[2],r[1]+r[3])),(int(x),int(y)))
 for layer in layout['fixedLayers']:
  for x,y,rr in layer['sprites']:
   if layer['id']=='grass' and tid in d['groundSampling']['themes'] and x%32==0 and y%32==0 and rr==[512+int(x)%512,int(y)%512,32,32]:rr=[r[0]+int(x)%r[2],r[1]+int(y)%r[3],32,32]
   draw(rr,x,y)
 roads={(int(x),int(y)):int(v) for x,y,v in layout['roads']}
 chosen=groups(layout,d,tid);covered={(g['cell'][0]+x,g['cell'][1]+y) for g in chosen for y in range(g['region'][3]//32) for x in range(g['region'][2]//32)}
 for p,v in roads.items():
  if p not in covered:draw(d['roads'][f'{mask(set(roads),p)}:{v}'],p[0]*32,p[1]*32)
 for group in chosen:draw(group['region'],group['cell'][0]*32,group['cell'][1]*32)
 for k,x,y in layout['stamps']:draw(d['components'][k]['region'],x,y)
 for i,x,y in layout['decorations']:draw([256+i*32,0,32,32],x,y)
 return out