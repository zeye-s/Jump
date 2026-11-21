extends RefCounted
const Previous=preload("res://Studio/paving_1_10.gd")
const NEW_REGIONS=[[256,224,64,96],[320,224,64,32],[384,224,64,32],[320,256,64,32],[384,256,64,32],[320,288,96,32],[416,288,96,32]]
const NEW_SPANS=[[2,3],[2,1],[2,1],[2,1],[2,1],[3,1],[3,1]]
const BOUNDARY={10:[28,124],11:[124,112],12:[7,199],13:[199,193],14:[124,124,124],15:[199,199,199]}
static func place(out:Array,used:Dictionary,p:Vector2i,phase:int)->void:
	var wh=NEW_SPANS[phase-9]
	for dy in range(wh[1]):
		for dx in range(wh[0]):used[p+Vector2i(dx,dy)]=true
	out.append({"cell":[p.x,p.y],"phase":phase,"span":wh.duplicate(),"region":NEW_REGIONS[phase-9].duplicate()})
static func groups(layout:Dictionary)->Array:
	if str(layout.theme)!="01_sandstone" or not bool(layout.get("macroPaving",{}).get("enabled",false)):return []
	if layout.get("macroPaving",{}).get("pattern","")!="bridge_caps_1_11":return Previous.groups(layout)
	var roads={};var masks={};var ordered=[];var used={};var result=[]
	for row in layout.roads:roads[Vector2i(int(row[0]),int(row[1]))]=int(row[2])
	for y in range(18):
		for x in range(24):
			var p=Vector2i(x,y)
			if roads.has(p):ordered.append(p);masks[p]=Previous.mask(roads,p)
	for phase in BOUNDARY:
		var pattern=BOUNDARY[phase]
		for p in ordered:
			var good=true
			for i in range(pattern.size()):
				var n=p+Vector2i(i,0)
				if used.has(n) or roads.get(n,-1)!=0 or masks.get(n,-1)!=pattern[i]:good=false
			if good:place(result,used,p,phase)
	var bridges=[]
	for p in ordered:
		if Previous.hashcell(p.x,p.y)%11!=0:continue
		var good=true
		for b in bridges:
			if abs(p.x-b.x)+abs(p.y-b.y)<7:good=false
		for dy in range(3):
			for dx in range(2):
				var n=p+Vector2i(dx,dy)
				if used.has(n) or roads.get(n,-1) not in [0,2,4,6] or masks.get(n,-1)!=255:good=false
		if good:place(result,used,p,9);bridges.append(p)
	var old=layout.duplicate(true);old.macroPaving={"enabled":true,"pattern":"mixed_bond_1_10"}
	return result+Previous.groups(old,used)
