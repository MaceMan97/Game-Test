class_name CityView
extends Node2D
## Draws the city in isometric view and reports clicks. Reads CityState; never changes it.
## Drawing is done in code so the project needs no art assets yet. When you have
## sprites, replace _draw_building/_draw_tile with TileMapLayer or Sprite2D nodes.

signal cell_clicked(cell: Vector2i)
signal cell_hovered(cell: Vector2i)

const TW := 32.0  # half tile width
const TH := 16.0  # half tile height
const NIGHT := Color(0.07, 0.06, 0.15)
const SHACK_COLORS := [
	Color("8a4a2b"), Color("2f5f8a"), Color("5a5560"), Color("4a6a4a"), Color("6a3a7a"), Color("8a7a4a"),
]
# Shack slots inside a tile (cell units from the centre), in back-to-front order.
const SHACK_SLOTS := [Vector2(-0.22, -0.22), Vector2(0.22, -0.22), Vector2(-0.22, 0.22), Vector2(0.22, 0.22)]

var city: CityState
var tool: String = "apartment"
var hover := Vector2i(-1, -1)

# The hover marker lives on its own layer so moving the mouse doesn't redraw the whole map.
var _hover_layer := Node2D.new()


func _ready() -> void:
	_hover_layer.z_index = 1
	_hover_layer.draw.connect(_draw_hover)
	add_child(_hover_layer)


func setup(state: CityState) -> void:
	city = state
	queue_redraw()


func refresh() -> void:
	queue_redraw()
	_hover_layer.queue_redraw()


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2((cell.x - cell.y) * TW, (cell.x + cell.y) * TH)


func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x / TW + p.y / TH) / 2.0), floori((p.y / TH - p.x / TW) / 2.0))


func _process(_delta: float) -> void:
	var c := world_to_cell(get_local_mouse_position())
	if c != hover:
		hover = c
		_hover_layer.queue_redraw()
		cell_hovered.emit(c)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var c := world_to_cell(get_local_mouse_position())
		if city.in_bounds(c):
			cell_clicked.emit(c)


func _draw() -> void:
	if city == null:
		return
	var n := CityState.SIZE
	# Painter's order: back to front by diagonal.
	for s in range(2 * n - 1):
		for i in range(maxi(0, s - n + 1), mini(s, n - 1) + 1):
			var cell := Vector2i(i, s - i)
			var o := cell_to_world(cell)
			_draw_terrain(o, cell)
			var id := city.get_building(cell)
			if id != "":
				_draw_building(o, BuildingDefs.DEFS[id])


func _diamond(o: Vector2, lift: float = 0.0) -> PackedVector2Array:
	return PackedVector2Array([
		o + Vector2(0, -lift),
		o + Vector2(TW, TH - lift),
		o + Vector2(0, 2 * TH - lift),
		o + Vector2(-TW, TH - lift),
	])


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array(points)
	out.append(points[0])
	return out


## Screen offset of a point given in cell units relative to the tile centre.
func _iso(u: float, v: float) -> Vector2:
	return Vector2((u - v) * TW, (u + v) * TH)


## Stable pseudo-random int per cell, so the shanty town looks the same every redraw.
func _rand(cell: Vector2i, k: int) -> int:
	return absi(hash(Vector3i(cell.x, cell.y, k)))


func _draw_ground(o: Vector2, fill: Color, line: Color) -> void:
	var d := _diamond(o)
	draw_colored_polygon(d, fill)
	draw_polyline(_closed(d), line, 1.0)


func _draw_terrain(o: Vector2, cell: Vector2i) -> void:
	match city.get_terrain(cell):
		TerrainDefs.OPEN:
			_draw_ground(o, Color("1a1538") if (cell.x + cell.y) % 2 == 0 else Color("171231"), Color("2b2358"))
		TerrainDefs.ROAD:
			if city.get_density(cell) == 1:  # alley
				_draw_ground(o, Color("1d1828"), Color("221c30"))
			else:
				_draw_ground(o, Color("2a2540"), Color("332c4d"))
				draw_circle(o + Vector2(0, TH), 1.5, Color(1.0, 0.75, 0.3, 0.5))  # old street lamp
		TerrainDefs.SHANTY:
			_draw_ground(o, Color("211726"), Color("2a1e30"))
			_draw_shanty(o, cell)
		TerrainDefs.RUBBLE:
			_draw_ground(o, Color("221d2b"), Color("2b2536"))
			_draw_rubble(o, cell)
		TerrainDefs.RUIN:
			_draw_ground(o, Color("2a2535"), Color("3a3348"))
			_draw_ruin(o, cell)
		TerrainDefs.PAD:
			_draw_ground(o, Color("16243a"), Color("2a8ab0"))
			if cell == city.landing_pad + Vector2i(1, 1):
				_draw_pad_marker(cell_to_world(city.landing_pad) + Vector2(0, 2 * TH))


## Small isometric box: centre c (screen), half-extent e (cell units), height h, raised by lift.
func _draw_box(c: Vector2, e: float, h: float, col: Color, lift: float = 0.0) -> void:
	var up := Vector2(0, -lift)
	var n := c + _iso(-e, -e) + up
	var east := c + _iso(e, -e) + up
	var s := c + _iso(e, e) + up
	var w := c + _iso(-e, e) + up
	var top := Vector2(0, -h)
	draw_colored_polygon(PackedVector2Array([w + top, s + top, s, w]), NIGHT.lerp(col, 0.45))
	draw_colored_polygon(PackedVector2Array([s + top, east + top, east, s]), NIGHT.lerp(col, 0.65))
	draw_colored_polygon(PackedVector2Array([n + top, east + top, s + top, w + top]), NIGHT.lerp(col, 0.85))


func _draw_shanty(o: Vector2, cell: Vector2i) -> void:
	var level := city.get_density(cell)
	var centre := o + Vector2(0, TH)
	var count := level + 1
	# Pick which slots are filled, keeping back-to-front order.
	var skip := _rand(cell, 0) % 4 if count < 4 else -1
	var drawn := 0
	for k in SHACK_SLOTS.size():
		if k == skip or drawn >= count:
			continue
		drawn += 1
		var slot: Vector2 = SHACK_SLOTS[k]
		var r := _rand(cell, k + 1)
		var c := centre + _iso(slot.x, slot.y)
		var col: Color = SHACK_COLORS[r % SHACK_COLORS.size()]
		var h := 6.0 + float(r % 7) + level * 2.0
		_draw_box(c, 0.18, h, col)
		if level == 3 and r % 3 == 0:  # stacked shack
			_draw_box(c, 0.13, 5.0, SHACK_COLORS[(r / 7) % SHACK_COLORS.size()], h)
		if r % 4 == 0:  # lit window
			var win := c + _iso(-0.06, 0.18) + Vector2(0, -h * 0.55)
			draw_rect(Rect2(win, Vector2(2, 2)), Color(1.0, 0.8, 0.4, 0.9))


func _draw_rubble(o: Vector2, cell: Vector2i) -> void:
	var centre := o + Vector2(0, TH)
	for k in 4:
		var r := _rand(cell, k)
		var u := float(r % 70) / 100.0 - 0.35
		var v := float((r / 70) % 70) / 100.0 - 0.35
		_draw_box(centre + _iso(u, v), 0.06 + float(r % 3) * 0.03, 2.0 + float(r % 4), Color("6a6470"))


func _draw_ruin(o: Vector2, cell: Vector2i) -> void:
	var centre := o + Vector2(0, TH)
	var r := _rand(cell, 0)
	var h := 14.0 + float(r % 30)
	if cell == Vector2i(CityState.SIZE / 2, CityState.SIZE / 2):
		h = 70.0  # what's left of the palace spire
	var stone := Color("8a8494")
	_draw_box(centre, 0.32, h, stone)
	if r % 3 == 0:
		# Faded regime red, still glowing on some of the wreckage.
		draw_circle(centre + Vector2(0, -h - 3), 2.5, Color(0.9, 0.15, 0.2, 0.8))


func _draw_pad_marker(c: Vector2) -> void:
	var ring := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		ring.append(c + _iso(cos(a) * 0.8, sin(a) * 0.8))
	var cyan := Color(0.16, 0.88, 1.0)
	draw_polyline(ring, Color(cyan, 0.25), 6.0)
	draw_polyline(ring, cyan, 2.0)
	# "H" landing marker laid flat on the pad.
	draw_line(c + _iso(-0.25, -0.3), c + _iso(-0.25, 0.3), cyan, 2.0)
	draw_line(c + _iso(0.25, -0.3), c + _iso(0.25, 0.3), cyan, 2.0)
	draw_line(c + _iso(-0.25, 0.0), c + _iso(0.25, 0.0), cyan, 2.0)


func _draw_building(o: Vector2, def: Dictionary) -> void:
	var h: float = def["height"]
	var c: Color = def["color"]
	draw_colored_polygon(PackedVector2Array([
		o + Vector2(-TW, TH - h), o + Vector2(0, 2 * TH - h),
		o + Vector2(0, 2 * TH), o + Vector2(-TW, TH)]), NIGHT.lerp(c, 0.22))
	draw_colored_polygon(PackedVector2Array([
		o + Vector2(0, 2 * TH - h), o + Vector2(TW, TH - h),
		o + Vector2(TW, TH), o + Vector2(0, 2 * TH)]), NIGHT.lerp(c, 0.38))
	var top_face := _diamond(o, h)
	draw_colored_polygon(top_face, NIGHT.lerp(c, 0.55))
	draw_polyline(_closed(top_face), Color(c, 0.25), 6.0)  # cheap neon glow
	draw_polyline(_closed(top_face), c, 2.0)


## Draws on _hover_layer, above the map.
func _draw_hover() -> void:
	if city == null or not city.in_bounds(hover):
		return
	var id := city.get_building(hover)
	var ok: bool
	if tool == "demolish":
		var cost := city.clear_cost(hover)
		ok = id != "" or (cost >= 0 and city.money >= cost)
	else:
		ok = id == "" and TerrainDefs.DEFS[city.get_terrain(hover)]["buildable"] \
				and city.money >= BuildingDefs.DEFS[tool]["cost"]
	var col := Color(0.16, 0.88, 1.0) if ok else Color(1.0, 0.18, 0.53)
	var d := _diamond(cell_to_world(hover))
	_hover_layer.draw_colored_polygon(d, Color(col, 0.2))
	_hover_layer.draw_polyline(_closed(d), col, 2.0)
