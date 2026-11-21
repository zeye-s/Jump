extends RefCounted

static func solid(im: Image,x: int,y: int) -> bool:
	return x>=0 and x<768 and y>=0 and y<576 and im.get_pixel(x,y).a>=192.0/255.0

static func set_alpha(im: Image,x: int,y: int,a: float) -> void:
	var c: Color=im.get_pixel(x,y);c.a=a;im.set_pixel(x,y,c)

static func compose(source: Image,field: Array,old: Image,cells: Dictionary) -> Image:
	var coverage: Image=old.duplicate()
	for p in cells:
		if cells.has(p+Vector2i.RIGHT):
			for dy in [-1,1]:
				if not cells.has(p+Vector2i(0,dy)) and not cells.has(p+Vector2i(1,dy)):
					var yy: int=p.y*32+(0 if dy==-1 else 28);var xx: int=(p.x+1)*32
					for k in range(4):
						for u in range(6):
							set_alpha(coverage,xx-6+u,yy+k,old.get_pixel(xx-8,yy+k).a)
							set_alpha(coverage,xx+u,yy+k,old.get_pixel(xx+7,yy+k).a)
		if cells.has(p+Vector2i.DOWN):
			for dx in [-1,1]:
				if not cells.has(p+Vector2i(dx,0)) and not cells.has(p+Vector2i(dx,1)):
					var xx: int=p.x*32+(0 if dx==-1 else 28);var yy: int=(p.y+1)*32
					for k in range(4):
						for u in range(6):
							set_alpha(coverage,xx+k,yy-6+u,old.get_pixel(xx+k,yy-8).a)
							set_alpha(coverage,xx+k,yy+u,old.get_pixel(xx+k,yy+7).a)
	var out: Image=Image.create(768,576,false,Image.FORMAT_RGBA8)
	for y in range(576):
		for x in range(768):
			var a: float=coverage.get_pixel(x,y).a
			if a==0.0:continue
			var shift: int=0
			if not solid(coverage,x,y+3) or not solid(coverage,x+3,y):shift=-10
			if not solid(coverage,x,y-2) or not solid(coverage,x-2,y):shift=14
			if not solid(coverage,x,y+2) or not solid(coverage,x+2,y):shift=-24
			if not solid(coverage,x,y-1) or not solid(coverage,x-1,y):shift=-12
			if not solid(coverage,x,y+1) or not solid(coverage,x+1,y):shift=-58
			var c: Color=source.get_pixel(int(field[0])+x,int(field[1])+y)
			out.set_pixel(x,y,Color(clampi(roundi(c.r*255.0)+shift,0,255)/255.0,clampi(roundi(c.g*255.0)+shift,0,255)/255.0,clampi(roundi(c.b*255.0)+shift,0,255)/255.0,a))
	return out
