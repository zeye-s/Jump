extends RefCounted

# The metadata owns the stone partition. A selected domain is copied whole,
# including its original mortar pixels, at its original world phase.
const DIRECTIONS = {"N":Vector2i.UP,"E":Vector2i.RIGHT,"S":Vector2i.DOWN,"W":Vector2i.LEFT}

static func select_components(theme: Dictionary, occupied: Dictionary) -> Array:
	var chosen := {}
	for p in occupied:
		var cell: Dictionary = theme.cells[p.y][p.x]
		for id in cell.anchors:chosen[int(id)] = true
		chosen[int(cell.center)] = true
		for direction in DIRECTIONS:
			if occupied.has(p + DIRECTIONS[direction]):
				for id in cell[direction]:chosen[int(id)] = true
	var ids: Array = chosen.keys()
	ids.sort()
	return ids

static func compose(source: Image, theme: Dictionary, occupied: Dictionary) -> Image:
	var output := Image.create(768,576,false,Image.FORMAT_RGBA8)
	var region: Array = theme.region
	for id in select_components(theme,occupied):
		var component: Dictionary = theme.components[id]
		for run in component.runs:
			var y := int(run[0]);var x := int(run[1]);var width := int(run[2])
			output.blit_rect(source,Rect2i(int(region[0])+x,int(region[1])+y,width,1),Vector2i(x,y))
	return output
