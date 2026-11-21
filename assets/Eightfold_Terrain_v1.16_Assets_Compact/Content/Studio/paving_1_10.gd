extends RefCounted
const Legacy=preload("res://Studio/paving_legacy.gd")
const REGIONS=[[256,96,96,64],[352,96,64,64],[416,96,32,64],[256,160,96,32],[352,160,64,32],[416,160,64,32],[416,192,64,32],[448,96,32,64],[480,96,32,64]]
const SPANS=[[3,2],[2,2],[1,2],[3,1],[2,1],[2,1],[2,1],[1,2],[1,2]]
static func hashcell(x:int,y:int)->int:
	var h:int=((x*73856093)^(y*19349663)^(112*83492791))&0x7fffffff
	for i in range(2):h=((h^(h>>16))*0x45d9f3b)&0x7fffffff
	return h^(h>>16)
static func mask(roads:Dictionary,p:Vector2i)->int:
	var dirs=[Vector2i(0,-1),Vector2i(1,-1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1),Vector2i(-1,1),Vector2i(-1,0),Vector2i(-1,-1)];var a=[]
	for v in dirs:a.append(int(roads.has(p+v)))
	for v in [[1,0,2],[3,2,4],[5,4,6],[7,6,0]]:a[v[0]]&=a[v[1]]&a[v[2]]
	var out=0
	for i in range(8):out|=int(a[i])<<i
	return out
static func place(result:Array,used:Dictionary,x:int,y:int,phase:int)->void:
	var wh=SPANS[phase]
	for dy in range(wh[1]):
		for dx in range(wh[0]):used[Vector2i(x+dx,y+dy)]=true
	result.append({"cell":[x,y],"phase":phase,"span":wh.duplicate(),"region":REGIONS[phase].duplicate()})
static func groups(layout:Dictionary,reserved:Dictionary={})->Array:
	if str(layout.theme)!="01_sandstone" or not bool(layout.get("macroPaving",{}).get("enabled",false)):return []
	if layout.get("macroPaving",{}).get("pattern","")!="mixed_bond_1_10":return Legacy.groups(layout)
	var roads={};var masks={};var used=reserved.duplicate();var result=[];var ordered=[]
	for row in layout.roads:roads[Vector2i(int(row[0]),int(row[1]))]=int(row[2])
	for y in range(18):
		for x in range(24):
			var p=Vector2i(x,y)
			if roads.has(p):ordered.append(p);masks[p]=mask(roads,p)
	for p in ordered:
		if used.has(p) or roads[p]!=0:continue
		var phase=int({124:5,199:6,31:7,241:8}.get(masks[p],-1))
		if phase<0:continue
		var wh=SPANS[phase];var eligible=true
		for dy in range(wh[1]):
			for dx in range(wh[0]):
				var n=p+Vector2i(dx,dy)
				if used.has(n) or roads.get(n,-1)!=0 or masks.get(n,-1)!=masks[p]:eligible=false
		if eligible:place(result,used,p.x,p.y,phase)
	var interior={}
	for p in ordered:
		if roads[p] in [0,2,4,6] and masks[p]==255:interior[p]=true
	for p in ordered:
		if not interior.has(p) or used.has(p):continue
		var x=p.x;var y=p.y;var first=[0,3,1,0,1,2,0,3][hashcell(x,y)%8];var choices=[]
		for v in [first,0,1,3,2,4]:
			if v not in choices:choices.append(v)
		var above=[];var upper_tall=[]
		for g in result:
			if g.cell[1]+g.span[1]==y and g.cell[0]<=x and x<g.cell[0]+g.span[0]:above.append(g.phase)
			if g.phase==2 and g.cell[1]+2==y:upper_tall.append(g)
		if above.any(func(v):return v in [3,4,5,6]):choices=choices.filter(func(v):return v not in [3,4])+choices.filter(func(v):return v in [3,4])
		choices=choices.filter(func(v):return v!=2)+[2]
		if upper_tall.any(func(g):return g.cell[0]==x+3):choices=choices.filter(func(v):return v not in [0,3])+choices.filter(func(v):return v in [0,3])
		for phase in choices:
			var wh=SPANS[phase];var eligible=true
			if phase==2:
				var left=result.filter(func(g):return g.cell[0]+g.span[0]==x and g.cell[1]==y)
				if not left.any(func(g):return g.span[1]==2 and g.phase!=2):continue
				if upper_tall.any(func(g):return g.cell[0]==x):continue
			for dy in range(wh[1]):
				for dx in range(wh[0]):
					var n=p+Vector2i(dx,dy)
					if not interior.has(n) or used.has(n):eligible=false
			if eligible:place(result,used,x,y,phase);break
	return result
