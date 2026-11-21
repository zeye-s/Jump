extends RefCounted

static func groups(layout: Dictionary) -> Array:
	if str(layout.theme)!="01_sandstone" or not bool(layout.get("macroPaving",{}).get("enabled",false)):return []
	var roads={}
	for row in layout.roads:roads[Vector2i(int(row[0]),int(row[1]))]=int(row[2])
	var result=[]
	for gy in range(9):
		var y=gy*2
		for gx in range(12):
			var x=gx*2+(gy%2);var eligible=true
			for dy in range(2):
				for dx in range(2):
					var p=Vector2i(x+dx,y+dy)
					if not roads.has(p) or roads[p] not in [0,2,4,6]:eligible=false;continue
					for ny in range(-1,2):
						for nx in range(-1,2):
							if not roads.has(p+Vector2i(nx,ny)):eligible=false
			if not eligible:continue
			var h: int=((gx*73856093)^(gy*19349663)^(112*83492791))&0x7fffffff
			for i in range(2):h=((h^(h>>16))*0x45d9f3b)&0x7fffffff
			var phase:int=[3,3,3,3,3,3,0,0,1,2][(h^(h>>16))%10];var neighbors=[]
			for g in result:
				if (g.cell[1]==y and g.cell[0]==x-2) or (g.cell[1]==y-2 and abs(g.cell[0]-x)<2):neighbors.append(g.phase)
			if phase in [1,2] and neighbors.any(func(p):return p in [1,2]):phase=3
			if phase==0 and 0 in neighbors:phase=3
			result.append({"cell":[x,y],"phase":phase,"region":[256+phase*64,32,64,64]})
	return result
