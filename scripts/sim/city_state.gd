class_name CityState
extends RefCounted
## All simulation data and rules. Knows nothing about rendering or UI,
## so it can be unit-tested, saved, and later run on a thread.

const SIZE := 22
const JOB_WAGE := 3

var money: int = 1000
var population: int = 0
var grid: Array[String] = []

# Derived stats, recomputed every tick.
var power_supply: int = 0
var power_demand: int = 0
var power_ratio: float = 1.0
var jobs: int = 0
var housing: int = 0
var employed: int = 0
var net_income: int = 0


func _init() -> void:
	grid.resize(SIZE * SIZE)
	grid.fill("")


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE and cell.y < SIZE


func get_building(cell: Vector2i) -> String:
	return grid[cell.y * SIZE + cell.x]


## Returns "" on success, otherwise a message explaining why it failed.
func build(cell: Vector2i, id: String) -> String:
	if not in_bounds(cell):
		return "Out of bounds."
	if get_building(cell) != "":
		return "That tile is taken. Demolish it first."
	var def: Dictionary = BuildingDefs.DEFS[id]
	if money < def["cost"]:
		return "Not enough credits for %s (%d needed)." % [def["name"], def["cost"]]
	money -= def["cost"]
	grid[cell.y * SIZE + cell.x] = id
	return ""


func demolish(cell: Vector2i) -> String:
	if not in_bounds(cell) or get_building(cell) == "":
		return "Nothing to demolish there."
	var def: Dictionary = BuildingDefs.DEFS[get_building(cell)]
	money += def["cost"] / 2
	grid[cell.y * SIZE + cell.x] = ""
	return ""


## One simulation step (the Simulation node calls this once per second).
func tick() -> void:
	power_supply = 0
	power_demand = 0
	jobs = 0
	housing = 0
	var business_income := 0
	var building_count := 0

	for id in grid:
		if id == "":
			continue
		var def: Dictionary = BuildingDefs.DEFS[id]
		building_count += 1
		var p: int = def["power"]
		if p > 0:
			power_supply += p
		else:
			power_demand -= p
		jobs += def["jobs"]
		housing += def["housing"]
		business_income += def["income"]

	power_ratio = 1.0 if power_demand == 0 else minf(1.0, float(power_supply) / power_demand)

	# Population drifts toward housing capacity; blackouts choke growth.
	var capacity := float(housing) * (1.0 if power_ratio >= 0.6 else 0.3)
	var diff := capacity - population
	var step := maxf(1.0, population * 0.1)
	population += roundi(signf(diff) * minf(absf(diff), step))

	employed = mini(population, floori(jobs * power_ratio))
	net_income = roundi(employed * JOB_WAGE + business_income * power_ratio - building_count)
	money += net_income
