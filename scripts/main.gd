extends Node
## Wires the simulation, the view, and the HUD together. Keep it thin.

@onready var sim: Simulation = $Simulation
@onready var view: CityView = $CityView
@onready var hud: Hud = $Hud
@onready var camera: Camera2D = $Camera

const NO_SELECTION := Vector2i(-1, -1)
const NO_TOOL := ""  # nothing to build: clicks only inspect

var tool: String = NO_TOOL
var selected := NO_SELECTION
var _tier_seen: int = 1


func _ready() -> void:
	view.setup(sim.city)
	view.cell_clicked.connect(_on_cell_clicked)
	view.cell_hovered.connect(func(cell): hud.show_tile_info(sim.city, cell))
	hud.tool_selected.connect(_set_tool)
	hud.buy_requested.connect(_on_buy)
	hud.accept_toggled.connect(func(good, on): sim.city.set_accepts(selected, good, on))
	hud.selection_closed.connect(_select.bind(NO_SELECTION))
	hud.restart_requested.connect(func(): get_tree().reload_current_scene())
	hud.sell_requested.connect(_on_sell)
	hud.auto_export_toggled.connect(func(good, on): sim.city.auto_export[good] = on)
	sim.ticked.connect(_refresh)
	# Start the camera over the player's landing pad.
	camera.position = view.cell_to_world(sim.city.landing_pad + Vector2i(1, 1))
	_set_tool(tool)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			# First Esc stops building; the next closes the build menu.
			if tool != NO_TOOL:
				_set_tool(NO_TOOL)
			elif hud.is_menu_open():
				hud.open_category("")
			_select(NO_SELECTION)
			return
		var i: int = event.keycode - KEY_1
		if i >= 0 and i < hud.category_count():
			_set_tool(NO_TOOL)
			hud.open_category_index(i)
		elif i == hud.category_count():
			_set_tool("demolish")


func _set_tool(id: String) -> void:
	tool = id
	view.tool = id
	hud.select_tool(id)
	view.refresh()


func _select(cell: Vector2i) -> void:
	selected = cell
	view.selected = cell
	_refresh()


func _on_cell_clicked(cell: Vector2i) -> void:
	# Clicking a hub with a build tool opens it instead of trying to build on it.
	if tool != "demolish" and sim.city.warehouses.has(cell):
		_select(cell)
		return
	if tool == NO_TOOL:
		_select(NO_SELECTION)
		hud.show_tile_info(sim.city, cell)
		return
	var error := sim.city.demolish(cell) if tool == "demolish" else sim.city.build(cell, tool)
	if error != "":
		hud.show_message(error)
	elif sim.city.warehouses.has(cell):
		_select(cell)
	elif cell == selected:
		_select(NO_SELECTION)
	_refresh()
	hud.show_tile_info(sim.city, cell)


func _on_buy(good: String, amount: int) -> void:
	var error := sim.city.buy(good, amount)
	hud.show_message(error if error != "" else "Cargo ordered. It waits on the pad until a hub in range pulls it.")
	_refresh()


func _refresh() -> void:
	if sim.city.unlocked_tier > _tier_seen:
		_tier_seen = sim.city.unlocked_tier
		var names: Array[String] = []
		for id in BuildingDefs.DEFS:
			if BuildingDefs.DEFS[id]["tier"] == _tier_seen:
				names.append(BuildingDefs.DEFS[id]["name"])
		hud.show_message("Tier %d unlocked: %s" % [_tier_seen, ", ".join(names)])
	hud.update_stats(sim.city)
	hud.update_selection(sim.city, selected)
	view.refresh()


func _on_sell(good: String, amount: int) -> void:
	var error := sim.city.sell(good, amount)
	hud.show_message(error if error != "" else "Sold off-world. Credits added.")
	_refresh()
