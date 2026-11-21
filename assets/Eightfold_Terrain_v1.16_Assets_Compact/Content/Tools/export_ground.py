from pathlib import Path
import json,hashlib,shutil
from PIL import Image,ImageDraw
import numpy as np
import legacy_render as old
R=Path(__file__).resolve().parent; AUTHOR=(R/'customer').exists();C=R/'customer' if AUTHOR else R.parent;Q=R/'qa' if AUTHOR else C/'qa'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,v):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(v,ensure_ascii=False,indent=2),encoding='utf-8')
def legacy_road_layer(layout,atlas,d,tid):
 r=d['materialFields']['themes'][tid]['region'];field=np.array(atlas.crop((r[0],r[1],r[0]+768,r[1]+576)));alpha=np.zeros((576,768),dtype=np.uint8)
 roads={(int(x),int(y)):int(v) for x,y,v in layout['roads']};yy,xx=np.mgrid[:32,:32]
 for (x,y),v in roads.items():
  if old.mask(set(roads),(x,y))!=255:continue
  m=old.mask(set(roads),(x,y));rr=d['roads'][f'{m}:{v}'];aa=np.array(atlas.crop((rr[0],rr[1],rr[0]+32,rr[1]+32)))[:,:,3]
  keep=((yy<6)&(not bool(m&1)))|((xx>=26)&(not bool(m&4)))|((yy>=26)&(not bool(m&16)))|((xx<6)&(not bool(m&64)))
  for bit,corner in [(128,(xx<6)&(yy<6)),(2,(xx>=26)&(yy<6)),(8,(xx>=26)&(yy>=26)),(32,(xx<6)&(yy>=26))]:
   if not m&bit:keep|=corner
  alpha[y*32:y*32+32,x*32:x*32+32]=np.where(keep,aa,255)
  # Preserve the existing shallow edge and contact pixels only at true outside
  # boundaries; never paste an edge at a connected interior cell boundary.
  rim=((yy<4)&(not bool(m&1)))|((xx>=28)&(not bool(m&4)))|((yy>=28)&(not bool(m&16)))|((xx<4)&(not bool(m&64)))
  for bit,corner in [(128,(xx<4)&(yy<4)),(2,(xx>=28)&(yy<4)),(8,(xx>=28)&(yy>=28)),(32,(xx<4)&(yy>=28))]:
   if not m&bit:rim|=corner
  oldtile=np.array(atlas.crop((rr[0],rr[1],rr[0]+32,rr[1]+32)));view=field[y*32:y*32+32,x*32:x*32+32];view[rim]=oldtile[rim]
 field[:,:,3]=alpha;field[alpha==0]=0;return Image.fromarray(field)
def connected_material(layout):
 return bool(layout.get('materialField',{}).get('enabled',False)) and layout['materialField'].get('version') in ['1.13','1.14','1.15','1.16']

def source_road_layer(layout,atlas,d,tid):
 if not connected_material(layout):return legacy_road_layer(layout,atlas,d,tid)
 r=d['materialFields']['themes'][tid]['region'];field=np.array(atlas.crop((r[0],r[1],r[0]+768,r[1]+576)))
 result=np.zeros_like(field);roads={(int(x),int(y)):int(v) for x,y,v in layout['roads']};cells=set(roads)
 yy,xx=np.mgrid[:32,:32]
 for (x,y),v in roads.items():
  m=old.mask(cells,(x,y));rr=d['roads'][f'{m}:{v}'];edge=np.array(atlas.crop((rr[0],rr[1],rr[0]+32,rr[1]+32)))
  tile=field[y*32:y*32+32,x*32:x*32+32].copy()
  rim=((yy<4)&(not bool(m&1)))|((xx>=28)&(not bool(m&4)))|((yy>=28)&(not bool(m&16)))|((xx<4)&(not bool(m&64)))
  for bit,corner in [(128,(xx<4)&(yy<4)),(2,(xx>=28)&(yy<4)),(8,(xx>=28)&(yy>=28)),(32,(xx<4)&(yy>=28))]:
   if not m&bit:rim|=corner
  tile[rim]=edge[rim];tile[:,:,3]=edge[:,:,3];tile[tile[:,:,3]==0]=0
  result[y*32:y*32+32,x*32:x*32+32]=tile
 return Image.fromarray(result)

def road_layer(layout,atlas,d,tid):
 if layout.get('materialField',{}).get('enabled') and layout['materialField'].get('version') in ['1.15','1.16']:
  from stone_boundaries import compose
  return compose(layout['roads'],atlas,d['stoneBoundaries']['themes'][tid])
 if layout.get('materialField',{}).get('enabled') and layout['materialField'].get('version')=='1.14':
  from continuous_edges import joined
  return joined(layout,atlas,d,tid,source_road_layer)
 return source_road_layer(layout,atlas,d,tid)

def continuous_ground(layout,atlas,d,tid):
 entry=d.get('quietGround',{}).get(tid) if layout.get('materialField',{}).get('version')=='1.16' else None
 r=(entry or d['continuousGround'][tid])['region'];out=atlas.crop((r[0],r[1],r[0]+768,r[1]+576))
 for layer in layout['fixedLayers']:
  for x,y,rr in layer['sprites']:
   if layer['id']=='grass' and x%32==0 and y%32==0 and rr==[512+int(x)%512,int(y)%512,32,32]:continue
   out.alpha_composite(atlas.crop((rr[0],rr[1],rr[0]+rr[2],rr[1]+rr[3])),(int(x),int(y)))
 return out

def uses_continuous_ground(layout,d,tid):
 p=layout.get('materialField',{})
 if not p.get('enabled') or tid not in d.get('continuousGround',{}):return False
 return p.get('version') in ['1.15','1.16'] or (p.get('version')=='1.14' and d['continuousGround'][tid].get('introducedPolicy','1.14')!='1.15')

def render(layout,atlas,d,tid):
 if not layout.get('materialField',{}).get('enabled',False):return old.render(layout,atlas,d,tid)
 base=dict(layout);base['stamps']=[];base['decorations']=[]
 if connected_material(layout):
  # Paint the source silhouette once. An old road underneath would double its alpha.
  base['roads']=[];base['macroPaving']={'enabled':False}
 else:base['macroPaving']={'enabled':True,'pattern':'bridge_caps_1_11'}
 out=continuous_ground(base,atlas,d,tid) if uses_continuous_ground(layout,d,tid) else old.render(base,atlas,d,tid);out.alpha_composite(road_layer(layout,atlas,d,tid))
 for k,x,y in layout['stamps']:
  r=d['components'][k]['region'];out.alpha_composite(atlas.crop((r[0],r[1],r[0]+r[2],r[1]+r[3])),(x,y))
 for i,x,y in layout['decorations']:out.alpha_composite(atlas.crop((256+i*32,0,288+i*32,32)),(x,y))
 return out

def main():
 d=json.loads((C/'Metadata/terrain.json').read_text(encoding='utf-8'))
 targets=sorted((C/'Layouts').glob('*.json'))
 for t in d['themes']:
  atlas=Image.open(C/t['atlas']).convert('RGBA')
  for path in targets:
   lay=json.loads(path.read_text(encoding='utf-8'))
   if lay.get('schema')!='eightfold.layout/1.1':continue
   render(lay,atlas,d,t['id']).save(C/'Examples'/f'{t["id"]}_{path.stem}.png')
 print('Regenerated current layout previews from production atlases.')
if __name__=='__main__':main()
