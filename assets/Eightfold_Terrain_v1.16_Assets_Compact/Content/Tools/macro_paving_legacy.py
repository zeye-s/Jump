"""Shared deterministic assembly rule, independent of drawing or export."""
def groups(layout,d,tid):
 if tid!='01_sandstone' or not layout.get('macroPaving',{}).get('enabled',False):return []
 roads={(int(x),int(y)):int(v) for x,y,v in layout['roads']};allowed={p for p,v in roads.items() if v in (0,2,4,6)};result=[]
 def inner(x,y):return all((x+dx,y+dy) in roads for dy in (-1,0,1) for dx in (-1,0,1))
 for gy in range(9):
  y=gy*2;offset=gy%2
  for gx in range(12):
   x=gx*2+offset;cells=[(x,y),(x+1,y),(x,y+1),(x+1,y+1)]
   if not all(p in allowed and inner(*p) for p in cells):continue
   h=((gx*73856093)^(gy*19349663)^(112*83492791))&0x7fffffff
   for _ in range(2):h=((h^(h>>16))*0x45d9f3b)&0x7fffffff
   phase=[3,3,3,3,3,3,0,0,1,2][(h^(h>>16))%10]
   neighbors=[g['phase'] for g in result if (g['cell'][1]==y and g['cell'][0]==x-2) or (g['cell'][1]==y-2 and abs(g['cell'][0]-x)<2)]
   if phase in (1,2) and any(p in (1,2) for p in neighbors):phase=3
   if phase==0 and 0 in neighbors:phase=3
   result.append({'cell':[x,y],'phase':phase,'region':[256+phase*64,32,64,64]})
 return result
