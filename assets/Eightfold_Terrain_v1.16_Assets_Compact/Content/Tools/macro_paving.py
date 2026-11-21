from macro_paving_1_10 import groups as previous_groups,mask,hashcell,REGIONS as OLD_REGIONS,SPANS as OLD_SPANS
REGIONS=OLD_REGIONS+[[256,224,64,96],[320,224,64,32],[384,224,64,32],[320,256,64,32],[384,256,64,32],[320,288,96,32],[416,288,96,32]]
SPANS=OLD_SPANS+[(2,3),(2,1),(2,1),(2,1),(2,1),(3,1),(3,1)]
BOUNDARY={10:[28,124],11:[124,112],12:[7,199],13:[199,193],14:[124,124,124],15:[199,199,199]}
def groups(layout,d,tid):
 if tid!='01_sandstone' or not layout.get('macroPaving',{}).get('enabled',False):return []
 if layout.get('macroPaving',{}).get('pattern')!='bridge_caps_1_11':return previous_groups(layout,d,tid)
 roads={(int(x),int(y)):int(v) for x,y,v in layout['roads']};masks={p:mask(roads,*p) for p in roads};used=set();result=[]
 def place(p,phase):
  x,y=p;w,h=SPANS[phase];used.update((x+dx,y+dy) for dy in range(h) for dx in range(w));result.append({'cell':[x,y],'phase':phase,'span':[w,h],'region':REGIONS[phase]})
 ordered=sorted(roads,key=lambda p:(p[1],p[0]))
 for phase,pattern in BOUNDARY.items():
  for x,y in ordered:
   ps=[(x+i,y) for i in range(len(pattern))]
   if all(p not in used and roads.get(p)==0 and masks.get(p)==m for p,m in zip(ps,pattern)):place((x,y),phase)
 bridges=[]
 for x,y in ordered:
  if hashcell(x,y)%11!=0:continue
  ps=[(x+dx,y+dy) for dy in range(3) for dx in range(2)]
  if any(abs(x-bx)+abs(y-by)<7 for bx,by in bridges):continue
  if all(p not in used and roads.get(p) in [0,2,4,6] and masks.get(p)==255 for p in ps):place((x,y),9);bridges.append((x,y))
 old=dict(layout);old['macroPaving']={'enabled':True,'pattern':'mixed_bond_1_10'}
 return result+previous_groups(old,d,tid,used)
