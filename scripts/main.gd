extends Node
## Wires the simulation, the view, and the HUD together. Keep it thin.

@onready var sim: Simulation = $Simulation
@onready var view: CityView = $CityView
@onready var hud: Hud = $Hud
@onready var camera: Camera2D = $Camera

var tool: String = "apartment"
var _tools: Array = BuildingDefs.DEFS.keys() + ["demolish"]


func _ready() -> void:
	view.setup(sim.city)
	view.cell_clicked.connect(_on_cell_clicked)
	view.cell_hovered.connect(func(cell): hud.show_tile_info(sim.city, cell))
	hud.tool_selected.connect(_set_tool)
	sim.ticked.connect(_refresh)
	# Start the camera over the player's landing pad.
	camera.position = view.cell_to_world(sim.city.landing_pad + Vector2i(1, 1))
	_set_tool(tool)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var i: int = event.keycode - KEY_1
		if i >= 0 and i < _tools.size():
			_set_tool(_tools[i])


func _set_tool(id: String) -> void:
	tool = id
	view.tool = id
	hud.select_tool(id)
	view.refresh()


func _on_cell_clicked(cell: Vector2i) -> void:
	var error := sim.city.demolish(cell) if tool == "demolish" else sim.city.build(cell, tool)
	if error != "":
		hud.show_message(error)
	_refresh()
	hud.show_tile_info(sim.city, cell)


func _refresh() -> void:
	hud.update_stats(sim.city)
	view.refresh()
