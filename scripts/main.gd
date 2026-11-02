extends Node
## Wires the simulation, the view, and the HUD together. Keep it thin.

@onready var sim: Simulation = $Simulation
@onready var view: CityView = $CityView
@onready var hud: Hud = $Hud

var tool: String = "apartment"
var _tools: Array = BuildingDefs.DEFS.keys() + ["demolish"]


func _ready() -> void:
	view.setup(sim.city)
	view.cell_clicked.connect(_on_cell_clicked)
	hud.tool_selected.connect(_set_tool)
	sim.ticked.connect(_refresh)
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
	view.queue_redraw()


func _on_cell_clicked(cell: Vector2i) -> void:
	var error := sim.city.demolish(cell) if tool == "demolish" else sim.city.build(cell, tool)
	if error != "":
		hud.show_message(error)
	_refresh()


func _refresh() -> void:
	hud.update_stats(sim.city)
	view.queue_redraw()
