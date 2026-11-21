"""Mixed native-sized stones and bounded straight-edge pairs; no image drawing."""
from macro_paving_legacy import groups as legacy_groups
REGIONS=[[256,96,96,64],[352,96,64,64],[416,96,32,64],[256,160,96,32],[352,160,64,32],[416,160,64,32],[416,192,64,32],[448,96,32,64],[480,96,32,64]]
SPANS=[(3,2),(2,2),(1,2),(3,1),(2,1),(2,1),(2,1),(1,2),(1,2)]
def hashcell(x,y):
 h=((x*73856093)^(y*19349663)^(112*83492791))&0x7fffffff
 for _ in range(2):h=((h^(h>>16))*0x45d9f3b)&0x7fffffff
 return h^(h>>16)
def mask(roads,x,y):
 a=[int((x+dx,y+dy) in roads) for dx,dy in [(0,-1),(1,-1),(1,0),(1,1),(0,1),(-1,1),(-1,0),(-1,-1)]]
 for i,j,k in [(1,0,2),(3,2,4),(5,4,6),(7,6,0)]:a[i]&=a[j]&a[k]
 return sum(v<<i for i,v in enumerate(a))
def groups(layout,d,tid,reserved=None):
 if tid!='01_sandstone' or not layout.get('macroPaving',{}).get('enabled',False):return []
 if layout.get('macroPaving',{}).get('pattern')!='mixed_bond_1_10':return legacy_groups(layout,d,tid)
 roads={(int(x),int(y)):int(v) for x,y,v in layout['roads']};masks={p:mask(roads,*p) for p in roads};used=set(reserved or []);result=[]
 def place(x,y,phase):
  w,h=SPANS[phase];used.update((x+dx,y+dy) for dy in range(h) for dx in range(w));result.append({'cell':[x,y],'phase':phase,'span':[w,h],'region':REGIONS[phase]})
 # Boundary pairs only join two identical existing face0 straight-edge cells.
 for x,y in sorted(roads,key=lambda p:(p[1],p[0])):
  if (x,y) in used or roads[(x,y)]!=0:continue
  m=masks[(x,y)];phase={124:5,199:6,31:7,241:8}.get(m)
  if phase is None:continue
  w,h=SPANS[phase];cells=[(x+dx,y+dy) for dy in range(h) for dx in range(w)]
  if all(p not in used and roads.get(p)==0 and masks.get(p)==m for p in cells):place(x,y,phase)
 eligible={p for p,v in roads.items() if v in (0,2,4,6) and masks[p]==255}
 for x,y in sorted(eligible,key=lambda p:(p[1],p[0])):
  if (x,y) in used:continue
  first=[0,3,1,0,1,2,0,3][hashcell(x,y)%8]
  choices=list(dict.fromkeys([first,0,1,3,2,4]))
  above=[g['phase'] for g in result if g['cell'][1]+g['span'][1]==y and g['cell'][0]<=x<g['cell'][0]+g['span'][0]]
  if any(p in [3,4,5,6] for p in above):choices=[p for p in choices if p not in [3,4]]+[p for p in choices if p in [3,4]]
  # A narrow upright is a final fitted remainder, never the first choice that
  # splits an available two-cell span into twin upright columns.
  choices=[p for p in choices if p!=2]+[2]
  upper_tall=[g for g in result if g['phase']==2 and g['cell'][1]+2==y]
  if any(g['cell'][0]==x+3 for g in upper_tall):choices=[p for p in choices if p not in [0,3]]+[p for p in choices if p in [0,3]]
  for phase in dict.fromkeys(choices):
   w,h=SPANS[phase];cells=[(x+dx,y+dy) for dy in range(h) for dx in range(w)]
   if phase==2:
    left=[g for g in result if g['cell'][0]+g['span'][0]==x and g['cell'][1]==y]
    if not any(g['span'][1]==2 and g['phase']!=2 for g in left):continue
    if any(g['cell'][0]==x for g in upper_tall):continue
   if all(p in eligible and p not in used for p in cells):place(x,y,phase);break
 return result
