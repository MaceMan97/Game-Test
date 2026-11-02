class_name Hud
extends CanvasLayer
## Builds the stats bar, panels and toolbar in code. Emits signals; holds no game logic.

signal tool_selected(id: String)
signal buy_requested(good: String, amount: int)
signal accept_toggled(good: String, on: bool)
signal selection_closed
signal restart_requested

const BUY_AMOUNT := 10
const WARN := Color(1.0, 0.3, 0.55)
const LEDGER_LINES := ["Meal sales", "Rent", "Data sales", "Wages", "Upkeep", "Purchases"]

var _stat_labels := {}
var _buttons := {}
var _message: Label
var _tile_info: Label
var _pad_title: Label
var _pad_rows := {}  # good -> Label
var _hub_panel: PanelContainer
var _hub_title: Label
var _hub_status: Label
var _hub_checks := {}  # good -> CheckBox
var _ledger_title: Label
var _ledger_rows := {}  # ledger line -> Label (amount)
var _debt_label: Label
var _bankrupt_overlay: Control


func _ready() -> void:
	var stats := VBoxContainer.new()
	stats.position = Vector2(16, 8)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stats)
	for keys in [["Day", "Credits", "Power", "Storage"], ["Workers", "Apartments", "Shanty", "Homeless"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 26)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stats.add_child(row)
		for key in keys:
			var label := Label.new()
			label.add_theme_font_size_override("font_size", 17)
			row.add_child(label)
			_stat_labels[key] = label

	var bottom := VBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_bottom = -12

	_tile_info = Label.new()
	_tile_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tile_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tile_info.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	bottom.add_child(_tile_info)

	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_message)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	bottom.add_child(row)

	var group := ButtonGroup.new()
	var n := 1
	for id in BuildingDefs.DEFS.keys():
		var def: Dictionary = BuildingDefs.DEFS[id]
		var price := "%d cr" % def["cost"]
		if def.get("materials", 0) > 0:
			price += " + %d mat" % def["materials"]
		_add_tool_button(row, group, id, "[%d] %s\n%s" % [n, def["name"], price])
		n += 1
	_add_tool_button(row, group, "demolish", "[%d] Demolish / Clear\nrefund or cost" % n)
	_message.text = "Build a hub, buy materials and food, then a company store. Esc stops building."

	var left := VBoxContainer.new()
	left.position = Vector2(12, 66)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left)
	_build_ledger_panel(left)

	var side := VBoxContainer.new()
	side.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	side.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	side.offset_top = 66
	side.offset_right = -12
	side.add_theme_constant_override("separation", 8)
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(side)
	_build_pad_panel(side)
	_build_hub_panel(side)

	_build_bankrupt_overlay()


func _panel(parent: Container, width: float = 260) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	return box


func _build_ledger_panel(parent: Container) -> void:
	var box := _panel(parent, 220)
	_ledger_title = Label.new()
	box.add_child(_ledger_title)
	for line in LEDGER_LINES + ["Net"]:
		var row := HBoxContainer.new()
		box.add_child(row)
		var name_label := Label.new()
		name_label.text = line
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var amount := Label.new()
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(amount)
		_ledger_rows[line] = amount
	_debt_label = Label.new()
	_debt_label.add_theme_color_override("font_color", WARN)
	box.add_child(_debt_label)


func _build_pad_panel(parent: Container) -> void:
	var box := _panel(parent)
	_pad_title = Label.new()
	box.add_child(_pad_title)
	for good in GoodsDefs.DEFS:
		var def: Dictionary = GoodsDefs.DEFS[good]
		var row := HBoxContainer.new()
		box.add_child(row)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_color_override("font_color", def["color"])
		row.add_child(label)
		_pad_rows[good] = label
		var b := Button.new()
		b.text = "Buy %d (%d cr)" % [BUY_AMOUNT, def["price"] * BUY_AMOUNT]
		b.pressed.connect(func(): buy_requested.emit(good, BUY_AMOUNT))
		row.add_child(b)


func _build_hub_panel(parent: Container) -> void:
	var box := _panel(parent)
	_hub_panel = box.get_parent()
	_hub_panel.visible = false
	var head := HBoxContainer.new()
	box.add_child(head)
	_hub_title = Label.new()
	_hub_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_hub_title)
	var close := Button.new()
	close.text = "x"
	close.pressed.connect(func(): selection_closed.emit())
	head.add_child(close)
	_hub_status = Label.new()
	box.add_child(_hub_status)
	var hint := Label.new()
	hint.text = "Accepts:"
	box.add_child(hint)
	for good in GoodsDefs.DEFS:
		var check := CheckBox.new()
		check.add_theme_color_override("font_color", GoodsDefs.DEFS[good]["color"])
		check.toggled.connect(func(on): accept_toggled.emit(good, on))
		box.add_child(check)
		_hub_checks[good] = check


func _build_bankrupt_overlay() -> void:
	_bankrupt_overlay = ColorRect.new()
	_bankrupt_overlay.color = Color(0.05, 0.0, 0.05, 0.75)
	_bankrupt_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bankrupt_overlay.visible = false
	add_child(_bankrupt_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bankrupt_overlay.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	var title := Label.new()
	title.text = "BANKRUPT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", WARN)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Your company ended %d days in a row in debt.\nCreditors have seized the landing pad." % Economy.BANKRUPT_DAYS
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var restart := Button.new()
	restart.text = "Start over"
	restart.pressed.connect(func(): restart_requested.emit())
	box.add_child(restart)


func _add_tool_button(row: Container, group: ButtonGroup, id: String, text: String) -> void:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.custom_minimum_size = Vector2(130, 48)
	b.pressed.connect(func(): tool_selected.emit(id))
	row.add_child(b)
	_buttons[id] = b


## Presses the button for id; an unknown id (e.g. "" for no tool) releases them all.
func select_tool(id: String) -> void:
	for b in _buttons:
		_buttons[b].set_pressed_no_signal(b == id)


func show_message(text: String) -> void:
	_message.text = text


func update_stats(city: CityState) -> void:
	_stat_labels["Day"].text = "Day %d (%d/%d)" % [city.day, city.tick_in_day, CityState.DAY_TICKS]
	_stat_labels["Credits"].text = "Credits: %d" % city.money
	_stat_labels["Power"].text = "Power: %d / %d" % [city.power_supply, city.power_demand]
	_stat_labels["Storage"].text = "Storage: %d / %d" % [city.storage_used, city.storage_capacity]
	_stat_labels["Workers"].text = "Workers: %d / %d" % [city.employed, city.jobs]
	_stat_labels["Apartments"].text = "Apartments: %d / %d" % [city.apartment_residents, city.apartment_capacity]
	_stat_labels["Shanty"].text = "Shanty: %d" % city.shanty_population
	_stat_labels["Homeless"].text = "Homeless: %d" % city.homeless
	_stat_labels["Credits"].add_theme_color_override("font_color", WARN if city.money < 0 else Color.WHITE)
	_stat_labels["Power"].add_theme_color_override("font_color", WARN if city.power_ratio < 1.0 else Color.WHITE)
	_stat_labels["Homeless"].add_theme_color_override("font_color", WARN if city.homeless > 0 else Color.WHITE)

	_pad_title.text = "Landing pad cargo: %d / %d" % [city.pad_total(), CityState.PAD_CAPACITY]
	for good in _pad_rows:
		_pad_rows[good].text = "%s: %d" % [GoodsDefs.DEFS[good]["name"], city.pad_stock[good]]

	_ledger_title.text = "Day %d books (%d meals sold)" % [city.day - 1, city.meals_served] \
			if not city.last_day.is_empty() else "Books: first payday at end of day 1"
	for line in _ledger_rows:
		var amount: int = city.last_day.get(line, 0)
		var label: Label = _ledger_rows[line]
		label.text = "%+d" % amount
		label.add_theme_color_override("font_color", WARN if amount < 0 else Color(0.6, 1.0, 0.6) if amount > 0 else Color.WHITE)
	_debt_label.visible = city.debt_days > 0
	_debt_label.text = "In debt! Bankrupt in %d day(s)" % (Economy.BANKRUPT_DAYS - city.debt_days)
	_bankrupt_overlay.visible = city.bankrupt


## Shows the panel for the selected distribution hub, or hides it if cell has none.
func update_selection(city: CityState, cell: Vector2i) -> void:
	_hub_panel.visible = city.warehouses.has(cell)
	if not _hub_panel.visible:
		return
	var w: Warehouse = city.warehouses[cell]
	_hub_title.text = "Distribution hub (%d, %d)" % [cell.x, cell.y]
	if city.in_pad_range(cell):
		_hub_status.text = "Stored %d / %d, pulling %d/sec" % [w.total(), w.capacity, w.pulled_last_tick]
	else:
		_hub_status.text = "Stored %d / %d. Too far from the pad\n(%d tiles, max %d)" % [
			w.total(), w.capacity, city.distance_to_pad(cell), Warehouse.RANGE]
	for good in _hub_checks:
		var check: CheckBox = _hub_checks[good]
		check.set_pressed_no_signal(w.accepts[good])
		check.text = "%s: %d" % [GoodsDefs.DEFS[good]["name"], w.stock[good]]


func show_tile_info(city: CityState, cell: Vector2i) -> void:
	if not city.in_bounds(cell):
		_tile_info.text = ""
		return
	var t := city.get_terrain(cell)
	var i := city.idx(cell)
	var text: String = TerrainDefs.DEFS[t]["name"]
	if t == TerrainDefs.ROAD and city.get_density(cell) == 1:
		text = "Alley"
	elif t == TerrainDefs.SHANTY:
		text += " (%s), %d / %d residents" % [
			["sparse", "crowded", "packed"][city.get_density(cell) - 1], city.residents_at(cell), city.housing_capacity(i)]
	var def := city.building_def(i)
	if not def.is_empty():
		var parts: Array[String] = [def["name"]]
		if def.get("housing", 0) > 0:
			parts.append("%d / %d residents, rent %d/day" % [city.residents_at(cell), def["housing"], def["rent"]])
		if def.get("jobs", 0) > 0:
			parts.append("%d / %d workers" % [city.workers_at(cell), def["jobs"]])
		if city.warehouses.has(cell):
			var w: Warehouse = city.warehouses[cell]
			parts.append("%d / %d stored, %s" % [
				w.total(), w.capacity, "linked to pad" if city.in_pad_range(cell) else "out of pad range"])
		if def.has("consumes"):
			var needs: Array[String] = []
			for good in def["consumes"]:
				needs.append("%d %s" % [def["consumes"][good], GoodsDefs.DEFS[good]["name"].to_lower()])
			parts.append("uses %s/day%s" % [", ".join(needs), "" if city.supplied.get(i, false) else " (OUT OF STOCK)"])
		if def.get("jobs", 0) > 0:
			parts.append("running at %d%%" % roundi(city.effectiveness(i) * 100))
		text = ", ".join(parts)
	elif city.clear_cost(cell) > 0:
		text += ". Clear: %d cr" % city.clear_cost(cell)
	_tile_info.text = text
