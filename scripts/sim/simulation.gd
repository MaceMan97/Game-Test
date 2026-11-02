class_name Simulation
extends Node
## Owns the CityState and advances it on a fixed tick, independent of frame rate.

signal ticked

const TICK_SECONDS := 1.0

var city := CityState.new()
var speed: float = 1.0  # 0 = paused; hook this to UI later

var _accumulator := 0.0


func _process(delta: float) -> void:
	_accumulator += delta * speed
	while _accumulator >= TICK_SECONDS:
		_accumulator -= TICK_SECONDS
		city.tick()
		ticked.emit()
