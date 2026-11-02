extends Camera2D
## Arrow keys pan, right/middle mouse drag pans, mouse wheel zooms.

const PAN_SPEED := 600.0
const ZOOM_STEP := 1.1

var _dragging := false


func _process(delta: float) -> void:
	var dir := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down"))
	position += dir * PAN_SPEED * delta / zoom.x


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom_by(ZOOM_STEP)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_by(1.0 / ZOOM_STEP)
			MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT:
				_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		position -= event.relative / zoom.x


func _zoom_by(factor: float) -> void:
	var z := clampf(zoom.x * factor, 0.3, 2.5)
	zoom = Vector2(z, z)
