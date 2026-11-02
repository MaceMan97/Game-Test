class_name Warehouse
extends RefCounted
## State for one distribution hub: what it stores and which goods it accepts.
## CityState owns these, keyed by cell, and moves goods into them each tick.

const RANGE := 10  # max tiles (Manhattan) from the landing pad to pull cargo
const PULL_RATE := 8  # units pulled from the pad per tick

var capacity: int
var accepts := {}  # good id -> bool
var stock := {}  # good id -> int
var pulled_last_tick: int = 0


func _init(cap: int) -> void:
	capacity = cap
	for good in GoodsDefs.DEFS:
		accepts[good] = true
		stock[good] = 0


func total() -> int:
	var sum := 0
	for good in stock:
		sum += stock[good]
	return sum


func space() -> int:
	return capacity - total()
