class_name Economy
extends RefCounted
## The company-town economy. Pure rules on a CityState, like MapGenerator.
## Every tick: idle people fill open jobs. Every day: upkeep, building inputs,
## income, wages, company store meals, rent, and people moving house.

const WAGE := 10  # credits per worker per day, paid by the company
const MEAL_PRICE := 5  # what a company store charges for one ration pack
const MOVE_INS_PER_DAY := 2  # per apartment, so towers fill gradually
const SAVINGS_TO_MOVE := 2  # days of rent a worker must have saved before moving in
const BANKRUPT_DAYS := 3  # days in a row ending in debt before the company folds


## Unemployed people take any open job slots.
static func assign_jobs(city: CityState) -> void:
	var people := city.people
	var open: Array[int] = []
	var slots: Array[int] = []
	for cell in city.building_cells():
		var free: int = city.building_def(cell).get("jobs", 0) - people.workers_at(cell)
		if free > 0:
			open.append(cell)
			slots.append(free)
	if open.is_empty() or people.size() == 0:
		return
	var o := 0
	var start := city.rng.randi() % people.size()
	for k in people.size():
		var i := (start + k) % people.size()
		if people.job[i] != Population.NONE:
			continue
		people.set_job(i, open[o])
		slots[o] -= 1
		if slots[o] == 0:
			o += 1
			if o == open.size():
				return


static func run_day(city: CityState) -> void:
	var people := city.people
	var ledger := {
		"Wages": 0, "Upkeep": 0, "Meal sales": 0, "Rent": 0, "Data sales": 0,
		"Purchases": -city.spent_today,
	}
	city.spent_today = 0

	# Upkeep, daily inputs (fuel, components...) and off-world income.
	for cell in city.building_cells():
		var def := city.building_def(cell)
		ledger["Upkeep"] -= def.get("upkeep", 0)
		if def.has("consumes"):
			city.supplied[cell] = city.consume(def["consumes"])
	for cell in city.building_cells():
		ledger["Data sales"] += roundi(city.building_def(cell).get("income", 0) * city.effectiveness(cell))

	# Payday.
	for i in people.size():
		if people.job[i] != Population.NONE:
			var pay := wage_at(city, people.job[i])
			people.money[i] += pay
			ledger["Wages"] -= pay

	# Company stores sell one meal per person, while stock and store capacity last.
	var capacity := 0
	for cell in city.building_cells():
		capacity += roundi(city.building_def(cell).get("customers", 0) * city.effectiveness(cell))
	var limit := mini(capacity, city.count_goods("food"))
	var served := 0
	var start := city.rng.randi() % maxi(1, people.size())
	for k in people.size():
		var i := (start + k) % people.size()
		if served < limit and people.money[i] >= MEAL_PRICE:
			people.money[i] -= MEAL_PRICE
			people.hungry_days[i] = 0
			served += 1
		else:
			people.hungry_days[i] += 1
	city.take_goods("food", served)
	ledger["Meal sales"] = served * MEAL_PRICE
	city.meals_served = served

	# Rent. Anyone who can't pay is evicted.
	for i in people.size():
		var rent: int = city.building_def(people.home[i]).get("rent", 0)
		if rent == 0:
			continue
		if people.money[i] >= rent:
			people.money[i] -= rent
			ledger["Rent"] += rent
		else:
			people.set_home(i, Population.NONE)

	# On-world production goes into hubs after meals have freed up space.
	# Whatever doesn't fit is wasted.
	city.output.clear()
	for cell in city.building_cells():
		var makes: Dictionary = city.building_def(cell).get("produces", {})
		for good in makes:
			var wanted := roundi(makes[good] * city.effectiveness(cell))
			city.output[cell] = Vector2i(city.store_goods(good, wanted), wanted)

	_move_into_apartments(city)
	_rehome_in_shanties(city)

	for line in ledger:
		if line != "Purchases":
			city.money += ledger[line]
	# Exports are paid out as they happen (manual sales during the day, auto-export now).
	city.export_surplus()
	ledger["Exports"] = city.exported_today
	city.exported_today = 0
	var net := 0
	for line in ledger:
		net += ledger[line]
	ledger["Net"] = net
	city.last_day = ledger
	city.day += 1
	city.debt_days = city.debt_days + 1 if city.money < 0 else 0
	if city.debt_days >= BANKRUPT_DAYS:
		city.bankrupt = true


static func wage_at(city: CityState, job_cell: int) -> int:
	return city.building_def(job_cell).get("wage", WAGE)


## Workers move into vacant company apartments, a few per building per day, best
## apartments first. A worker moves if their wage covers the rent after a meal,
## they have SAVINGS_TO_MOVE days of rent saved, and it's better than where they live.
static func _move_into_apartments(city: CityState) -> void:
	var people := city.people
	var apartments: Array[int] = []
	for cell in city.building_cells():
		if city.building_def(cell).get("housing", 0) > 0:
			apartments.append(cell)
	if apartments.is_empty():
		return
	apartments.sort_custom(func(a, b): return city.building_def(a)["rent"] > city.building_def(b)["rent"])
	var workers: Array[int] = []
	for i in people.size():
		if people.job[i] != Population.NONE:
			workers.append(i)
	for cell in apartments:
		var def := city.building_def(cell)
		var rent: int = def["rent"]
		var free: int = mini(def["housing"] - people.residents_at(cell), MOVE_INS_PER_DAY)
		for i in workers:
			if free <= 0:
				break
			if wage_at(city, people.job[i]) - MEAL_PRICE < rent or people.money[i] < rent * SAVINGS_TO_MOVE:
				continue
			if city.building_def(people.home[i]).get("rent", 0) >= rent:
				continue  # already living somewhere at least as good
			people.set_home(i, cell)
			free -= 1


## Homeless people squat in any shanty with room.
static func _rehome_in_shanties(city: CityState) -> void:
	var people := city.people
	var room: Array[int] = []
	for idx in CityState.SIZE * CityState.SIZE:
		if city.terrain[idx] == TerrainDefs.SHANTY:
			for s in city.housing_capacity(idx) - people.residents_at(idx):
				room.append(idx)
	var r := 0
	for i in people.size():
		if r == room.size():
			return
		if people.home[i] == Population.NONE:
			people.set_home(i, room[r])
			r += 1
