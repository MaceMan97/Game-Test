class_name Hud
extends CanvasLayer
## Builds the stats bar and toolbar in code. Emits tool_selected; holds no game logic.

signal tool_selected(id: String)

var _stat_labels := {}
var _buttons := {}
var _message: Label


func _ready() -> void:
	var stats := HBoxContainer.new()
	stats.position = Vector2(16, 10)
	stats.add_theme_constant_override("separation", 28)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stats)
	for key in ["Credits", "Power", "Citizens", "Net/sec"]:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 20)
		stats.add_child(label)
		_stat_labels[key] = label

	var bottom := VBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_bottom = -12

	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message.text = "Pick a building, then left-click a tile. Right-drag or arrows to pan, wheel to zoom."
	bottom.add_child(_message)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	bottom.add_child(row)

	var group := ButtonGroup.new()
	var n := 1
	for id in BuildingDefs.DEFS.keys():
		var def: Dictionary = BuildingDefs.DEFS[id]
		_add_tool_button(row, group, id, "[%d] %s\n%d cr" % [n, def["name"], def["cost"]])
		n += 1
	_add_tool_button(row, group, "demolish", "[%d] Demolish\n50%% refund" % n)


func _add_tool_button(row: Container, group: ButtonGroup, id: String, text: String) -> void:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.custom_minimum_size = Vector2(130, 48)
	b.pressed.connect(func(): tool_selected.emit(id))
	row.add_child(b)
	_buttons[id] = b


func select_tool(id: String) -> void:
	if _buttons.has(id):
		_buttons[id].set_pressed_no_signal(true)


func show_message(text: String) -> void:
	_message.text = text


func update_stats(city: CityState) -> void:
	_stat_labels["Credits"].text = "Credits: %d" % city.money
	_stat_labels["Power"].text = "Power: %d / %d" % [city.power_supply, city.power_demand]
	_stat_labels["Citizens"].text = "Citizens: %d / %d" % [city.population, city.housing]
	_stat_labels["Net/sec"].text = "Net/sec: %+d" % city.net_income
	var warn := Color(1.0, 0.3, 0.55)
	_stat_labels["Power"].add_theme_color_override("font_color", warn if city.power_ratio < 1.0 else Color.WHITE)
	_stat_labels["Net/sec"].add_theme_color_override("font_color", warn if city.net_income < 0 else Color.WHITE)
