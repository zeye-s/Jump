extends Node2D
const ContinuousEdges=preload("res://Studio/continuous_edges.gd")
const StoneBoundaries=preload("res://Studio/stone_boundaries.gd")

const ORIGIN = Vector2(16, 104)
var contract: Dictionary
var layout: Dictionary
var atlas: Texture2D
var roads := {}
var mode := 0
var component := "large_a"
var decoration := 0
var variant := 0
var show_grid := false
var status: Label
var theme_select: OptionButton
var preset_select: OptionButton
var selected_components: OptionButton
var dialog: FileDialog
var saving := false
var last_cell := Vector2i(-100, -100)
const Paving = preload("res://Studio/paving.gd")
var paving_toggle: CheckButton
var material_toggle: CheckButton
var material_key := ""
var material_texture: ImageTexture
var auto_surface := false
var surface_seed := 112
var surface_toggle: CheckButton
var undo_stack: Array[Dictionary] = []
var stroke_before: Dictionary = {}

func json_file(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _ready() -> void:
	contract = json_file("res://Metadata/terrain.json")
	layout = json_file("res://Layouts/courtyard_whole.json")
	build_ui()
	apply_layout(layout)
	preset_select.select(0)

func make_button(text: String, p: Vector2, size: Vector2, action: Callable) -> Button:
	var b := Button.new(); b.text = text; b.position = p; b.size = size
	b.pressed.connect(action); add_child(b); return b

func label(text: String, p: Vector2, size: Vector2) -> Label:
	var l := Label.new(); l.text = text; l.position = p; l.size = size
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(l); return l

func build_ui() -> void:
	label("EIGHTFOLD TERRAIN 1.16  /  SHARED THEME STUDIO",Vector2(16,5),Vector2(700,28))
	theme_select = OptionButton.new(); theme_select.position = Vector2(16,40);theme_select.size=Vector2(256,36)
	for t in contract.themes: theme_select.add_item(t.id)
	theme_select.item_selected.connect(func(i: int): set_theme(contract.themes[i].id));add_child(theme_select)
	preset_select=OptionButton.new();preset_select.position=Vector2(284,40);preset_select.size=Vector2(250,36)
	for p in ["Courtyard / Whole stone", "Crossroads / Whole stone", "Winding / Whole stone", "Courtyard / Native32", "Crossroads / Native32", "Winding / Native32"]:preset_select.add_item(p)
	preset_select.item_selected.connect(func(i: int):
		var names=["courtyard_whole","cross_whole","winding_whole","courtyard_native","cross_native","winding_native"]
		var keep=layout.theme;apply_layout(json_file("res://Layouts/"+names[i]+".json"));set_theme(keep))
	add_child(preset_select)
	make_button("Grid",Vector2(548,40),Vector2(70,36),func(): show_grid=not show_grid;queue_redraw())
	make_button("Save JSON",Vector2(630,40),Vector2(128,36),func(): saving=true;dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE;dialog.current_file="eightfold_layout.json";dialog.popup_centered(Vector2i(880,550)))
	make_button("Load JSON",Vector2(770,40),Vector2(128,36),func(): saving=false;dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE;dialog.popup_centered(Vector2i(880,550)))
	make_button("Clear additions",Vector2(910,40),Vector2(190,36),clear_additions)
	label("One layout / eight matching themes",Vector2(800,100),Vector2(300,24))
	make_button("Undo",Vector2(800,128),Vector2(100,28),undo_edit)
	make_button("Mix existing",Vector2(912,128),Vector2(176,28),mix_existing)
	make_button("Draw road / current route",Vector2(800,164),Vector2(288,36),func():mode=0)
	make_button("Whole component",Vector2(800,208),Vector2(288,36),func():mode=1)
	selected_components=OptionButton.new();selected_components.position=Vector2(800,252);selected_components.size=Vector2(288,36)
	for key in contract.components.keys():selected_components.add_item(key)
	selected_components.item_selected.connect(func(i: int):component=selected_components.get_item_text(i));add_child(selected_components)
	make_button("Decoration",Vector2(800,304),Vector2(288,36),func():mode=2)
	var dec:=OptionButton.new();dec.position=Vector2(800,348);dec.size=Vector2(288,36)
	for i in range(6):dec.add_item("Decoration "+str(i+1))
	dec.item_selected.connect(func(i: int):decoration=i);add_child(dec)
	var var_select:=OptionButton.new();var_select.position=Vector2(800,400);var_select.size=Vector2(288,36)
	for i in range(8):var_select.add_item("Road appearance "+str(i+1))
	var_select.item_selected.connect(func(i: int):variant=i;auto_surface=false;surface_toggle.set_pressed_no_signal(false);save_surface_policy());add_child(var_select)
	surface_toggle=CheckButton.new();surface_toggle.text="Calm surface mix 0 / 2 / 4 / 6";surface_toggle.position=Vector2(800,444);surface_toggle.size=Vector2(288,36)
	surface_toggle.toggled.connect(func(value: bool):auto_surface=value;save_surface_policy());add_child(surface_toggle)
	paving_toggle=CheckButton.new();paving_toggle.text="Advanced sandstone compatibility";paving_toggle.position=Vector2(800,482);paving_toggle.size=Vector2(294,34);add_child(paving_toggle)
	paving_toggle.hide()
	paving_toggle.toggled.connect(func(value: bool):begin_edit();layout.macroPaving={"enabled":value,"pattern":"bridge_caps_1_11"};queue_redraw();end_edit())
	material_toggle=CheckButton.new();material_toggle.text="Whole stone route / off = Native32";material_toggle.position=Vector2(800,520);material_toggle.size=Vector2(294,34);add_child(material_toggle)
	material_toggle.toggled.connect(func(value: bool):begin_edit();layout.materialField={"enabled":value,"version":"1.16"};material_key="";queue_redraw();end_edit())
	label("Left paints; right removes additions.\nDrag roads without skipped cells.\nCtrl+Z undoes one stroke (32 steps).\nMix existing affects Native32 only.\n\nCurrent presets are editable.\nTheme switches keep every placement.\nSave/load retains selected surfaces.",Vector2(800,558),Vector2(294,122))
	status=label("",Vector2(16,686),Vector2(1080,30))
	dialog=FileDialog.new();dialog.access=FileDialog.ACCESS_FILESYSTEM;dialog.filters=PackedStringArray(["*.json ; Eightfold layout"]);dialog.use_native_dialog=false
	dialog.file_selected.connect(func(path: String):
		if saving:
			var f=FileAccess.open(path,FileAccess.WRITE)
			if f:f.store_string(JSON.stringify(layout,"\t"));status.text="Saved "+path
			else:status.text="Save failed: "+error_string(FileAccess.get_open_error())
		else:
			var data=json_file(path)
			if valid_layout(data):apply_layout(data);status.text="Loaded "+path
			else:status.text="Invalid or incompatible Eightfold layout; current layout retained.")
	add_child(dialog)

func integer_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value))

func number_record(value: Variant, count: int) -> bool:
	if not value is Array or value.size()!=count:return false
	for v in value:
		if not integer_number(v):return false
	return true

func valid_layout(data: Variant) -> bool:
	if not data is Dictionary:return false
	if data.get("schema","")!="eightfold.layout/1.1":return false
	for k in ["size","roads","stamps","decorations","fixedLayers"]:
		if not data.get(k) is Array:return false
	if not number_record(data["size"],2) or data["size"][0]!=24 or data["size"][1]!=18:return false
	if not data.get("theme") in contract.themes.map(func(t):return t.id):return false
	if data.has("surfaceMix"):
		var policy=data.surfaceMix
		if not policy is Dictionary or not policy.get("enabled") is bool or not integer_number(policy.get("seed")):return false
		if policy.seed<0 or policy.seed>1000000:return false
	if data.has("macroPaving"):
		if not data.macroPaving is Dictionary or not data.macroPaving.get("enabled") is bool:return false
		if data.macroPaving.has("pattern") and data.macroPaving.pattern not in ["mixed_bond_1_10","bridge_caps_1_11"]:return false
	if data.has("materialField"):
		if not data.materialField is Dictionary or not data.materialField.get("enabled") is bool or data.materialField.get("version") not in ["1.12","1.13","1.14","1.15","1.16"]:return false
	var seen={}
	for r in data.roads:
		if not number_record(r,3):return false
		if r[0]<0 or r[0]>=24 or r[1]<0 or r[1]>=18 or r[2]<0 or r[2]>7:return false
		var key=Vector2i(r[0],r[1])
		if seen.has(key):return false
		seen[key]=true
	for s in data.stamps:
		if not s is Array or s.size()!=3 or not s[0] is String or not contract.components.has(s[0]):return false
		if not integer_number(s[1]) or not integer_number(s[2]):return false
		var r=contract.components[s[0]].region
		if s[1]<0 or s[2]<0 or s[1]+r[2]>768 or s[2]+r[3]>576:return false
	for d in data.decorations:
		if not number_record(d,3) or d[0]<0 or d[0]>5 or d[1]<0 or d[1]>736 or d[2]<0 or d[2]>544:return false
	for l in data.fixedLayers:
		if not l is Dictionary or not l.get("sprites") is Array:return false
		for s in l.sprites:
			if not s is Array or s.size()!=3 or not integer_number(s[0]) or not integer_number(s[1]) or not number_record(s[2],4):return false
			var r=s[2]
			if r[0]<0 or r[1]<0 or r[2]!=32 or r[3]!=32 or r[0]+32>1024 or r[1]+32>1152:return false
	return true

func apply_layout(data: Dictionary, clear_undo := true) -> void:
	layout=data.duplicate(true);sync_roads();set_theme(layout.theme)
	var policy=layout.get("surfaceMix",{})
	auto_surface=bool(policy.get("enabled",false));surface_seed=int(policy.get("seed",112))
	surface_toggle.set_pressed_no_signal(auto_surface)
	paving_toggle.set_pressed_no_signal(bool(layout.get("macroPaving",{}).get("enabled",false)))
	material_toggle.set_pressed_no_signal(bool(layout.get("materialField",{}).get("enabled",false)))
	if clear_undo:undo_stack.clear();stroke_before.clear()

func save_surface_policy() -> void:
	layout.surfaceMix={"enabled":auto_surface,"seed":surface_seed}

func surface_at(cell: Vector2i) -> int:
	var hashed: int=((cell.x*73856093)^(cell.y*19349663)^(surface_seed*83492791))&0x7fffffff
	for i in range(2):hashed=((hashed^(hashed>>16))*0x45d9f3b)&0x7fffffff
	hashed=hashed^(hashed>>16)
	return [0,0,0,0,0,0,0,4,4,4,4,4,4,2,2,6][hashed&15]

func begin_edit() -> void:
	if stroke_before.is_empty():stroke_before=layout.duplicate(true)

func end_edit() -> void:
	if stroke_before.is_empty():return
	if normalize_json(stroke_before)!=normalize_json(layout):
		undo_stack.append(stroke_before)
		if undo_stack.size()>32:undo_stack.pop_front()
	stroke_before={};last_cell=Vector2i(-100,-100)

func undo_edit() -> void:
	end_edit()
	if undo_stack.is_empty():status.text="No edit to undo";return
	var keep=layout.theme
	var previous: Dictionary=undo_stack.pop_back()
	apply_layout(previous,false);set_theme(keep)
	status.text="Undid one edit; "+str(undo_stack.size())+" remaining"

func clear_additions() -> void:
	begin_edit();layout.roads=[];layout.stamps=[];layout.decorations=[];sync_roads();queue_redraw();end_edit()

func mix_existing() -> void:
	if bool(layout.get("materialField",{}).get("enabled",false)):
		status.text="Whole stone uses fixed source pixels; appearance mix is Native32 only.";return
	begin_edit();auto_surface=true;surface_toggle.set_pressed_no_signal(true);save_surface_policy()
	for r in layout.roads:r[2]=surface_at(Vector2i(r[0],r[1]))
	sync_roads();queue_redraw();end_edit()

func sync_roads() -> void:
	roads.clear()
	for r in layout.roads:roads[Vector2i(r[0],r[1])]=int(r[2])

func set_theme(id: String) -> void:
	for i in range(contract.themes.size()):
		if contract.themes[i].id==id:
			layout.theme=id;atlas=load("res://"+contract.themes[i].atlas);theme_select.select(i)
			status.text=id+" | 24 x 18 cells | 1x actual pixels";queue_redraw();return

func mask_at(p: Vector2i) -> int:
	var ds=[Vector2i(0,-1),Vector2i(1,-1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1),Vector2i(-1,1),Vector2i(-1,0),Vector2i(-1,-1)]
	var m=0
	for i in range(8):
		if roads.has(p+ds[i]):m|=1<<i
	for bit in [1,3,5,7]:
		if not (m&(1<<((bit+7)%8)) and m&(1<<((bit+1)%8))):m&=~(1<<bit)
	return m

func region(r: Array, p: Vector2) -> void:
	draw_texture_rect_region(atlas,Rect2(ORIGIN+p,Vector2(r[2],r[3])),Rect2(r[0],r[1],r[2],r[3]))

func continuous_ground_enabled(tid: String) -> bool:
	if not bool(layout.get("materialField",{}).get("enabled",false)) or not contract.continuousGround.has(tid):return false
	var policy: String=str(layout.materialField.get("version",""))
	return policy in ["1.15","1.16"] or (policy=="1.14" and str(contract.continuousGround[tid].get("introducedPolicy","1.14"))!="1.15")

func ground_region(cell: Vector2i, theme_id: String = "") -> Array:
	var tid: String = str(layout.theme) if theme_id.is_empty() else theme_id
	var entry: Dictionary = contract.groundSampling.themes.get(tid,contract.groundSampling.default)
	if continuous_ground_enabled(tid):
		entry=contract.continuousGround[tid]
		if str(layout.materialField.version)=="1.16" and contract.get("quietGround",{}).has(tid):entry=contract.quietGround[tid]
	var r: Array = entry.region
	return [int(r[0])+posmod(cell.x,int(r[2])/32)*32,int(r[1])+posmod(cell.y,int(r[3])/32)*32,32,32]

func fixed_region(layer_id: String, sprite: Array) -> Array:
	var r: Array = sprite[2]
	var x := int(sprite[0]); var y := int(sprite[1])
	if layer_id == "grass" and (contract.groundSampling.themes.has(str(layout.theme)) or continuous_ground_enabled(str(layout.theme))) and float(x) == float(sprite[0]) and float(y) == float(sprite[1]) and x % 32 == 0 and y % 32 == 0 and int(r[0]) == 512+posmod(x,512) and int(r[1]) == posmod(y,512) and float(r[0]) == int(r[0]) and float(r[1]) == int(r[1]) and float(r[2]) == 32.0 and float(r[3]) == 32.0:
		return ground_region(Vector2i(x/32,y/32))
	return r

func _draw() -> void:
	if not atlas:return
	for y in range(18):
		for x in range(24):region(ground_region(Vector2i(x,y)),Vector2(x*32,y*32))
	for layer in layout.fixedLayers:
		for s in layer.sprites:region(fixed_region(str(layer.id),s),Vector2(s[0],s[1]))
	var active_material: bool=bool(layout.get("materialField",{}).get("enabled",false))
	var render_layout: Dictionary=layout.duplicate(true)
	if active_material:render_layout.macroPaving={"enabled":true,"pattern":"bridge_caps_1_11"}
	var connected: bool=active_material and str(layout.materialField.version) in ["1.13","1.14","1.15","1.16"]
	var chosen=Paving.groups(render_layout) if not connected else [];var covered={}
	for g in chosen:
		for dy in range(int(g.region[3])/32):
			for dx in range(int(g.region[2])/32):covered[Vector2i(g.cell[0]+dx,g.cell[1]+dy)]=true
	for p in roads:
		if not connected and not covered.has(p):region(contract.roads[str(mask_at(p))+":"+str(roads[p])],Vector2(p*32))
	for group in chosen:region(group.region,Vector2(group.cell[0]*32,group.cell[1]*32))
	if active_material:draw_texture(field_texture(),ORIGIN)
	for s in layout.stamps:region(contract.components[s[0]].region,Vector2(s[1],s[2]))
	for d in layout.decorations:region([256+int(d[0])*32,0,32,32],Vector2(d[1],d[2]))
	if show_grid:
		for x in range(25):draw_line(ORIGIN+Vector2(x*32,0),ORIGIN+Vector2(x*32,576),Color(1,1,1,0.16))
		for y in range(19):draw_line(ORIGIN+Vector2(0,y*32),ORIGIN+Vector2(768,y*32),Color(1,1,1,0.16))


func field_texture() -> ImageTexture:
	var key: String=str(layout.theme)+str(layout.get("materialField",{}).get("version",""))+JSON.stringify(layout.roads)
	if key==material_key and material_texture:return material_texture
	material_key=key
	var source: Image=atlas.get_image()
	if str(layout.materialField.version) in ["1.15","1.16"]:
		material_texture=ImageTexture.create_from_image(StoneBoundaries.compose(source,contract.stoneBoundaries.themes[str(layout.theme)],roads))
		return material_texture
	var rr: Array=contract.materialFields.themes[str(layout.theme)].region
	var result: Image=Image.create(768,576,false,Image.FORMAT_RGBA8)
	for cell in roads:
		var m: int=mask_at(cell)
		if m!=255 and str(layout.materialField.version)=="1.12":continue
		var maskr: Array=contract.roads[str(m)+":"+str(roads[cell])]
		var tile: Image=source.get_region(Rect2i(int(rr[0])+cell.x*32,int(rr[1])+cell.y*32,32,32))
		for y in range(32):
			for x in range(32):
				var rim: bool=(y<4 and not (m&1)) or (x>=28 and not (m&4)) or (y>=28 and not (m&16)) or (x<4 and not (m&64)) or (x<4 and y<4 and not (m&128)) or (x>=28 and y<4 and not (m&2)) or (x>=28 and y>=28 and not (m&8)) or (x<4 and y>=28 and not (m&32))
				var original: Color=source.get_pixel(int(maskr[0])+x,int(maskr[1])+y)
				var col: Color=original if rim else tile.get_pixel(x,y)
				col.a=original.a
				if col.a==0.0:col=Color(0,0,0,0)
				tile.set_pixel(x,y,col)
		result.blit_rect(tile,Rect2i(0,0,32,32),Vector2i(cell)*32)
	if str(layout.materialField.version)=="1.14":result=ContinuousEdges.compose(source,rr,result,roads)
	material_texture=ImageTexture.create_from_image(result)
	return material_texture

func paint_cell(cell: Vector2i, erase: bool) -> void:
	if cell.x<0 or cell.x>=24 or cell.y<0 or cell.y>=18:return
	if erase:
		if mode==0:layout.roads=layout.roads.filter(func(r):return Vector2i(r[0],r[1])!=cell)
		elif mode==1:
			layout.stamps=layout.stamps.filter(func(s):
				var r=contract.components[s[0]].region;return not Rect2(s[1],s[2],r[2],r[3]).has_point(Vector2(cell*32+Vector2i(16,16))))
		else:layout.decorations=layout.decorations.filter(func(d):return Vector2i(int(d[1])/32,int(d[2])/32)!=cell)
	elif mode==0:
		var chosen: int=roads[cell] if auto_surface and roads.has(cell) else surface_at(cell) if auto_surface else variant
		if roads.has(cell):
			for r in layout.roads:
				if Vector2i(r[0],r[1])==cell:r[2]=chosen;break
		else:layout.roads.append([cell.x,cell.y,chosen])
		save_surface_policy()
	elif mode==1:
		var r=contract.components[component].region
		if cell.x*32+r[2]<=768 and cell.y*32+r[3]<=576:layout.stamps.append([component,cell.x*32,cell.y*32])
	else:layout.decorations.append([decoration,cell.x*32,cell.y*32])
	sync_roads();queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_Z and (event.ctrl_pressed or event.meta_pressed):undo_edit();get_viewport().set_input_as_handled();return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		var cell=Vector2i((event.position-ORIGIN)/32.0)
		if Rect2(ORIGIN,Vector2(768,576)).has_point(event.position):begin_edit();paint_cell(cell,event.button_index==MOUSE_BUTTON_RIGHT);last_cell=cell
	if event is InputEventMouseMotion and mode==0 and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		var cell=Vector2i((event.position-ORIGIN)/32.0)
		if cell!=last_cell and Rect2(ORIGIN,Vector2(768,576)).has_point(event.position):begin_edit();paint_line(last_cell,cell,Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT));last_cell=cell

func paint_line(a: Vector2i,b: Vector2i,erase: bool) -> void:
	if a==Vector2i(-100,-100):paint_cell(b,erase);return
	var steps: int=maxi(absi(b.x-a.x),absi(b.y-a.y))
	for i in range(steps+1):paint_cell(Vector2i(roundi(lerpf(a.x,b.x,float(i)/maxi(1,steps))),roundi(lerpf(a.y,b.y,float(i)/maxi(1,steps)))),erase)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:end_edit()

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_node_ready():end_edit()

func normalize_json(value: Variant) -> Variant:
	if value is int or value is float:return float(value)
	if value is Array:return value.map(normalize_json)
	if value is Dictionary:
		var out={}
		for key in value:out[key]=normalize_json(value[key])
		return out
	return value

