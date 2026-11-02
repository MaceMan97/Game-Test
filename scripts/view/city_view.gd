class_name CityView
extends Node2D
## Draws the city in isometric view and reports clicks. Reads CityState; never changes it.
## Drawing is done in code so the project needs no art assets yet. When you have
## sprites, replace _draw_building/_draw_tile with TileMapLayer or Sprite2D nodes.

signal cell_clicked(cell: Vector2i)

const TW := 32.0  # half tile width
const TH := 16.0  # half tile height

var city: CityState
var tool: String = "apartment"
var hover := Vector2i(-1, -1)


func setup(state: CityState) -> void:
	city = state
	queue_redraw()


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2((cell.x - cell.y) * TW, (cell.x + cell.y) * TH)


func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x / TW + p.y / TH) / 2.0), floori((p.y / TH - p.x / TW) / 2.0))


func _process(_delta: float) -> void:
	var c := world_to_cell(get_local_mouse_position())
	if c != hover:
		hover = c
		queue_redraw()


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
			var id := city.get_building(cell)
			_draw_tile(o, (cell.x + cell.y) % 2 == 0)
			if id != "":
				_draw_building(o, BuildingDefs.DEFS[id])
			if cell == hover:
				_draw_hover(o, id)


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


func _draw_tile(o: Vector2, alt: bool) -> void:
	var d := _diamond(o)
	draw_colored_polygon(d, Color("1a1538") if alt else Color("171231"))
	draw_polyline(_closed(d), Color("2b2358"), 1.0)


func _draw_building(o: Vector2, def: Dictionary) -> void:
	var h: float = def["height"]
	var c: Color = def["color"]
	var base := Color(0.07, 0.06, 0.15)
	draw_colored_polygon(PackedVector2Array([
		o + Vector2(-TW, TH - h), o + Vector2(0, 2 * TH - h),
		o + Vector2(0, 2 * TH), o + Vector2(-TW, TH)]), base.lerp(c, 0.22))
	draw_colored_polygon(PackedVector2Array([
		o + Vector2(0, 2 * TH - h), o + Vector2(TW, TH - h),
		o + Vector2(TW, TH), o + Vector2(0, 2 * TH)]), base.lerp(c, 0.38))
	var top_face := _diamond(o, h)
	draw_colored_polygon(top_face, base.lerp(c, 0.55))
	draw_polyline(_closed(top_face), Color(c, 0.25), 6.0)  # cheap neon glow
	draw_polyline(_closed(top_face), c, 2.0)


func _draw_hover(o: Vector2, id: String) -> void:
	var ok: bool
	if tool == "demolish":
		ok = id != ""
	else:
		ok = id == "" and city.money >= BuildingDefs.DEFS[tool]["cost"]
	var col := Color(0.16, 0.88, 1.0) if ok else Color(1.0, 0.18, 0.53)
	var d := _diamond(o)
	draw_colored_polygon(d, Color(col, 0.2))
	draw_polyline(_closed(d), col, 2.0)
