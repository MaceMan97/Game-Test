class_name CityState
extends RefCounted
## All simulation data and rules. Knows nothing about rendering or UI,
## so it can be unit-tested, saved, and later run on a thread.

const SIZE := 40
const JOB_WAGE := 3
const PAD_CAPACITY := 120  # cargo units the landing pad can hold before it must be unloaded

var money: int = 1000
var population: int = 0
var grid: Array[String] = []
var terrain := PackedByteArray()  # TerrainDefs enum per cell
var density := PackedByteArray()  # shanty density 1-3 (0 elsewhere)
var landing_pad := Vector2i.ZERO  # top-left cell of the player's 2x2 pad
var pad_stock := {}  # good id -> units waiting on the pad
var warehouses := {}  # Vector2i -> Warehouse

# Derived stats, recomputed every tick.
var power_supply: int = 0
var power_demand: int = 0
var power_ratio: float = 1.0
var jobs: int = 0
var housing: int = 0
var employed: int = 0
var net_income: int = 0
var shanty_population: int = 0
var storage_used: int = 0
var storage_capacity: int = 0


func _init(map_seed: int = 1) -> void:
	grid.resize(SIZE * SIZE)
	grid.fill("")
	terrain.resize(SIZE * SIZE)
	density.resize(SIZE * SIZE)
	for good in GoodsDefs.DEFS:
		pad_stock[good] = 0
	MapGenerator.generate(self, map_seed)
	_count_shanty_population()


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE and cell.y < SIZE


func get_building(cell: Vector2i) -> String:
	return grid[cell.y * SIZE + cell.x]


func get_terrain(cell: Vector2i) -> int:
	return terrain[cell.y * SIZE + cell.x]


func get_density(cell: Vector2i) -> int:
	return density[cell.y * SIZE + cell.x]


func set_terrain(cell: Vector2i, type: int, level: int = 0) -> void:
	terrain[cell.y * SIZE + cell.x] = type
	density[cell.y * SIZE + cell.x] = level


## Credits to clear the terrain on this cell, or -1 if it cannot be cleared.
func clear_cost(cell: Vector2i) -> int:
	var cost: int = TerrainDefs.DEFS[get_terrain(cell)]["clear_cost"]
	if cost > 0 and get_terrain(cell) == TerrainDefs.SHANTY:
		cost *= get_density(cell)
	return cost


func residents_at(cell: Vector2i) -> int:
	return TerrainDefs.DEFS[get_terrain(cell)]["residents"] * get_density(cell)


## Returns "" on success, otherwise a message explaining why it failed.
func build(cell: Vector2i, id: String) -> String:
	if not in_bounds(cell):
		return "Out of bounds."
	if get_building(cell) != "":
		return "That tile is taken. Demolish it first."
	var ground: Dictionary = TerrainDefs.DEFS[get_terrain(cell)]
	if not ground["buildable"]:
		if clear_cost(cell) > 0:
			return "%s is in the way. Clear it first." % ground["name"]
		return "Can't build on %s." % ground["name"].to_lower()
	var def: Dictionary = BuildingDefs.DEFS[id]
	if money < def["cost"]:
		return "Not enough credits for %s (%d needed)." % [def["name"], def["cost"]]
	money -= def["cost"]
	grid[cell.y * SIZE + cell.x] = id
	if def.get("storage", 0) > 0:
		warehouses[cell] = Warehouse.new(def["storage"])
	return ""


## Demolishes a building (50% refund) or clears shanty/rubble terrain (costs credits).
func demolish(cell: Vector2i) -> String:
	if not in_bounds(cell):
		return "Out of bounds."
	if get_building(cell) != "":
		var def: Dictionary = BuildingDefs.DEFS[get_building(cell)]
		money += def["cost"] / 2
		grid[cell.y * SIZE + cell.x] = ""
		warehouses.erase(cell)  # stored goods are lost with it
		return ""
	var cost := clear_cost(cell)
	if cost < 0:
		return "Nothing to clear there."
	if money < cost:
		return "Not enough credits to clear (%d needed)." % cost
	money -= cost
	set_terrain(cell, TerrainDefs.OPEN)
	_count_shanty_population()
	return ""


func pad_total() -> int:
	var sum := 0
	for good in pad_stock:
		sum += pad_stock[good]
	return sum


## Orders cargo off-world; it lands on the pad. Buys as much as fits.
func buy(good: String, amount: int) -> String:
	var space := PAD_CAPACITY - pad_total()
	if space <= 0:
		return "Landing pad is full. Build a distribution hub nearby to unload it."
	amount = mini(amount, space)
	var cost: int = GoodsDefs.DEFS[good]["price"] * amount
	if money < cost:
		return "Not enough credits for %d %s (%d needed)." % [amount, GoodsDefs.DEFS[good]["name"], cost]
	money -= cost
	pad_stock[good] += amount
	return ""


## Manhattan distance from a cell to the nearest tile of the 2x2 landing pad.
func distance_to_pad(cell: Vector2i) -> int:
	var dx := maxi(0, maxi(landing_pad.x - cell.x, cell.x - (landing_pad.x + 1)))
	var dy := maxi(0, maxi(landing_pad.y - cell.y, cell.y - (landing_pad.y + 1)))
	return dx + dy


func in_pad_range(cell: Vector2i) -> bool:
	return distance_to_pad(cell) <= Warehouse.RANGE


func set_accepts(cell: Vector2i, good: String, on: bool) -> void:
	if warehouses.has(cell):
		warehouses[cell].accepts[good] = on


## Warehouses in range pull cargo off the pad, nearest first, a unit of each good per pass.
func _distribute() -> void:
	var hubs: Array = warehouses.keys().filter(in_pad_range)
	hubs.sort_custom(func(a, b): return distance_to_pad(a) < distance_to_pad(b))
	for w in warehouses.values():
		w.pulled_last_tick = 0
	for cell in hubs:
		var w: Warehouse = warehouses[cell]
		var moved := true
		while moved and w.pulled_last_tick < Warehouse.PULL_RATE and w.space() > 0:
			moved = false
			for good in pad_stock:
				if w.pulled_last_tick >= Warehouse.PULL_RATE or w.space() <= 0:
					break
				if w.accepts[good] and pad_stock[good] > 0:
					pad_stock[good] -= 1
					w.stock[good] += 1
					w.pulled_last_tick += 1
					moved = true


func _count_shanty_population() -> void:
	shanty_population = 0
	for y in SIZE:
		for x in SIZE:
			shanty_population += residents_at(Vector2i(x, y))


## One simulation step (the Simulation node calls this once per second).
func tick() -> void:
	_distribute()
	storage_used = 0
	storage_capacity = 0
	for w in warehouses.values():
		storage_used += w.total()
		storage_capacity += w.capacity

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
