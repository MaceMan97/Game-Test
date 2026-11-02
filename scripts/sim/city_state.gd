class_name CityState
extends RefCounted
## All simulation data and rules. Knows nothing about rendering or UI,
## so it can be unit-tested, saved, and later run on a thread.

const SIZE := 40
const PAD_CAPACITY := 120  # cargo units the landing pad can hold before it must be unloaded
const DAY_TICKS := 10  # ticks (seconds) per in-game day
const STARTING_WALLET := Vector2i(5, 25)  # range of credits each person starts with
const EXPORT_RESERVE := 40  # auto-export keeps this much of each good in your hubs
const NO_BUILDING := {}

var money: int = 1000
var grid: Array[String] = []
var terrain := PackedByteArray()  # TerrainDefs enum per cell
var density := PackedByteArray()  # shanty density 1-3 (0 elsewhere)
var landing_pad := Vector2i.ZERO  # top-left cell of the player's 2x2 pad
var pad_stock := {}  # good id -> units waiting on the pad
var warehouses := {}  # Vector2i -> Warehouse
var people := Population.new()
var supplied := {}  # cell index -> bool: did this building get its daily inputs?
var output := {}  # cell index -> Vector2i(units stored, units made) from the last day
var unlocked_tier: int = 1
var rng := RandomNumberGenerator.new()

# Day cycle and company books.
var day: int = 1
var tick_in_day: int = 0
var spent_today: int = 0  # purchases, construction and clearing since the last day ended
var exported_today: int = 0  # credits from off-world sales since the last day ended
var auto_export := {}  # good id -> bool: sell surplus above EXPORT_RESERVE at the end of each day
var last_day := {}  # ledger line -> credits, from Economy.run_day
var debt_days: int = 0
var bankrupt: bool = false
var meals_served: int = 0

# Derived stats, recomputed every tick.
var power_supply: int = 0
var power_demand: int = 0
var power_ratio: float = 1.0
var jobs: int = 0
var employed: int = 0
var apartment_residents: int = 0
var apartment_capacity: int = 0
var shanty_population: int = 0
var homeless: int = 0
var storage_used: int = 0
var storage_capacity: int = 0


func _init(map_seed: int = 1) -> void:
	grid.resize(SIZE * SIZE)
	grid.fill("")
	terrain.resize(SIZE * SIZE)
	density.resize(SIZE * SIZE)
	for good in GoodsDefs.DEFS:
		pad_stock[good] = 0
		auto_export[good] = false
	MapGenerator.generate(self, map_seed)
	rng.seed = map_seed
	# Fill every shanty with people, each with a little money to seed the economy.
	for i in SIZE * SIZE:
		for p in housing_capacity(i):
			people.add(i, rng.randi_range(STARTING_WALLET.x, STARTING_WALLET.y))
	_update_stats()


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE and cell.y < SIZE


func idx(cell: Vector2i) -> int:
	return cell.y * SIZE + cell.x


func get_building(cell: Vector2i) -> String:
	return grid[idx(cell)]


## Building data for a cell index; empty if there is no building (or i is Population.NONE).
func building_def(i: int) -> Dictionary:
	if i < 0 or grid[i] == "":
		return NO_BUILDING
	return BuildingDefs.DEFS[grid[i]]


func building_cells() -> Array[int]:
	var out: Array[int] = []
	for i in grid.size():
		if grid[i] != "":
			out.append(i)
	return out


func get_terrain(cell: Vector2i) -> int:
	return terrain[idx(cell)]


func get_density(cell: Vector2i) -> int:
	return density[idx(cell)]


func set_terrain(cell: Vector2i, type: int, level: int = 0) -> void:
	terrain[idx(cell)] = type
	density[idx(cell)] = level


## Credits to clear the terrain on this cell, or -1 if it cannot be cleared.
func clear_cost(cell: Vector2i) -> int:
	var cost: int = TerrainDefs.DEFS[get_terrain(cell)]["clear_cost"]
	if cost > 0 and get_terrain(cell) == TerrainDefs.SHANTY:
		cost *= get_density(cell)
	return cost


## How many people can live on a cell index (shanty or apartment).
func housing_capacity(i: int) -> int:
	if grid[i] != "":
		return building_def(i).get("housing", 0)
	return TerrainDefs.DEFS[terrain[i]]["housing"] * density[i]


func residents_at(cell: Vector2i) -> int:
	return people.residents_at(idx(cell))


func workers_at(cell: Vector2i) -> int:
	return people.workers_at(idx(cell))


## 0..1: how well a building is running, from staffing, power and daily inputs.
func effectiveness(i: int) -> float:
	var def := building_def(i)
	var e := 1.0
	if def.get("jobs", 0) > 0:
		e = float(people.workers_at(i)) / def["jobs"]
	if def.get("power", 0) < 0:
		e *= power_ratio
	if def.has("consumes") and not supplied.get(i, false):
		e = 0.0
	return e


## Returns "" on success, otherwise a message explaining why it failed.
func build(cell: Vector2i, id: String) -> String:
	if bankrupt:
		return "The company is bankrupt."
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
	if def["tier"] > unlocked_tier:
		return "%s unlocks at %d people in company housing." % [
			def["name"], BuildingDefs.TIER_RESIDENTS[def["tier"]]]
	if money < def["cost"]:
		return "Not enough credits for %s (%d needed)." % [def["name"], def["cost"]]
	var mats: int = def.get("materials", 0)
	if count_goods("materials") < mats:
		return "%s needs %d building materials in your hubs (have %d)." % [
			def["name"], mats, count_goods("materials")]
	money -= def["cost"]
	spent_today += def["cost"]
	take_goods("materials", mats)
	grid[idx(cell)] = id
	if def.get("storage", 0) > 0:
		warehouses[cell] = Warehouse.new(def["storage"])
	if def.has("consumes"):
		supplied[idx(cell)] = consume(def["consumes"])
	_update_stats()
	return ""


## Demolishes a building (50% refund) or clears shanty/rubble terrain (costs credits).
## Anyone living or working there is turned out.
func demolish(cell: Vector2i) -> String:
	if bankrupt:
		return "The company is bankrupt."
	if not in_bounds(cell):
		return "Out of bounds."
	if get_building(cell) != "":
		var def: Dictionary = BuildingDefs.DEFS[get_building(cell)]
		money += def["cost"] / 2
		spent_today -= def["cost"] / 2
		people.vacate(idx(cell))
		grid[idx(cell)] = ""
		warehouses.erase(cell)  # stored goods are lost with it
		supplied.erase(idx(cell))
		output.erase(idx(cell))
		_update_stats()
		return ""
	var cost := clear_cost(cell)
	if cost < 0:
		return "Nothing to clear there."
	if money < cost:
		return "Not enough credits to clear (%d needed)." % cost
	money -= cost
	spent_today += cost
	people.vacate(idx(cell))
	set_terrain(cell, TerrainDefs.OPEN)
	_update_stats()
	return ""


func pad_total() -> int:
	var sum := 0
	for good in pad_stock:
		sum += pad_stock[good]
	return sum


## Orders cargo off-world; it lands on the pad. Buys as much as fits.
## Purchases cannot take credits below zero, but wages and upkeep can.
func buy(good: String, amount: int) -> String:
	if bankrupt:
		return "The company is bankrupt."
	var space := PAD_CAPACITY - pad_total()
	if space <= 0:
		return "Landing pad is full. Build a distribution hub nearby to unload it."
	amount = mini(amount, space)
	var cost: int = GoodsDefs.DEFS[good]["price"] * amount
	if money < cost:
		return "Not enough credits for %d %s (%d needed)." % [amount, GoodsDefs.DEFS[good]["name"], cost]
	money -= cost
	spent_today += cost
	pad_stock[good] += amount
	return ""


## Sells goods from your hubs off-world at the export price. Sells as much as you have.
func sell(good: String, amount: int) -> String:
	if bankrupt:
		return "The company is bankrupt."
	var sold := take_goods(good, amount)
	if sold == 0:
		return "No %s in your hubs to sell." % GoodsDefs.DEFS[good]["name"].to_lower()
	var earned: int = sold * GoodsDefs.DEFS[good]["export"]
	money += earned
	exported_today += earned
	return ""


## End-of-day auto-export of everything above the reserve.
func export_surplus() -> void:
	for good in auto_export:
		var surplus := count_goods(good) - EXPORT_RESERVE
		if auto_export[good] and surplus > 0:
			sell(good, surplus)


func is_unlocked(id: String) -> bool:
	return BuildingDefs.DEFS[id]["tier"] <= unlocked_tier


## Puts goods made on-world into hubs that accept them and have room.
## Returns how many fit; the rest is wasted.
func store_goods(good: String, amount: int) -> int:
	var stored := 0
	for w in warehouses.values():
		if w.accepts[good]:
			var t: int = mini(amount - stored, w.space())
			w.stock[good] += t
			stored += t
	return stored


## Units of a good across all hubs.
func count_goods(good: String) -> int:
	var sum := 0
	for w in warehouses.values():
		sum += w.stock[good]
	return sum


## Removes up to amount of a good from hubs, fullest first. Returns how many were taken.
func take_goods(good: String, amount: int) -> int:
	var hubs: Array = warehouses.values()
	hubs.sort_custom(func(a, b): return a.stock[good] > b.stock[good])
	var taken := 0
	for w in hubs:
		var t: int = mini(amount - taken, w.stock[good])
		w.stock[good] -= t
		taken += t
	return taken


## Takes a building's daily inputs if every one is in stock; returns whether it could.
func consume(needs: Dictionary) -> bool:
	for good in needs:
		if count_goods(good) < needs[good]:
			return false
	for good in needs:
		take_goods(good, needs[good])
	return true


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
## Understaffed hubs pull more slowly.
func _distribute() -> void:
	var hubs: Array = warehouses.keys().filter(in_pad_range)
	hubs.sort_custom(func(a, b): return distance_to_pad(a) < distance_to_pad(b))
	for w in warehouses.values():
		w.pulled_last_tick = 0
	for cell in hubs:
		var w: Warehouse = warehouses[cell]
		var rate := roundi(Warehouse.PULL_RATE * effectiveness(idx(cell)))
		var moved := true
		while moved and w.pulled_last_tick < rate and w.space() > 0:
			moved = false
			for good in pad_stock:
				if w.pulled_last_tick >= rate or w.space() <= 0:
					break
				if w.accepts[good] and pad_stock[good] > 0:
					pad_stock[good] -= 1
					w.stock[good] += 1
					w.pulled_last_tick += 1
					moved = true


func _update_stats() -> void:
	power_supply = 0
	power_demand = 0
	jobs = 0
	employed = 0
	apartment_residents = 0
	apartment_capacity = 0
	for i in building_cells():
		var def := building_def(i)
		var p: int = def.get("power", 0)
		if p > 0:
			power_supply += roundi(p * effectiveness(i))
		else:
			power_demand -= p
		jobs += def.get("jobs", 0)
		employed += people.workers_at(i)
		apartment_capacity += def.get("housing", 0)
		apartment_residents += people.residents_at(i)
	power_ratio = 1.0 if power_demand == 0 else minf(1.0, float(power_supply) / power_demand)

	shanty_population = 0
	for i in SIZE * SIZE:
		if terrain[i] == TerrainDefs.SHANTY:
			shanty_population += people.residents_at(i)
	homeless = people.size() - shanty_population - apartment_residents

	while BuildingDefs.TIER_RESIDENTS.has(unlocked_tier + 1) \
			and apartment_residents >= BuildingDefs.TIER_RESIDENTS[unlocked_tier + 1]:
		unlocked_tier += 1

	storage_used = 0
	storage_capacity = 0
	for w in warehouses.values():
		storage_used += w.total()
		storage_capacity += w.capacity


## One simulation step (the Simulation node calls this once per second).
func tick() -> void:
	if bankrupt:
		return
	Economy.assign_jobs(self)
	_update_stats()
	_distribute()
	tick_in_day += 1
	if tick_in_day >= DAY_TICKS:
		tick_in_day = 0
		Economy.run_day(self)
	_update_stats()
