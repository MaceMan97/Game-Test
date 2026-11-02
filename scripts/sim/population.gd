class_name Population
extends RefCounted
## Every person in the city, stored as parallel arrays (one index per person) so
## thousands of them stay cheap to simulate. Homes and jobs are cell indices
## (y * CityState.SIZE + x).

const NONE := -1  # no home (homeless) or no job (unemployed)

var home := PackedInt32Array()
var job := PackedInt32Array()
var money := PackedInt32Array()
var hungry_days := PackedInt32Array()  # days in a row without a company meal

var _residents := {}  # cell index -> people living there
var _workers := {}  # cell index -> people working there


func size() -> int:
	return home.size()


func add(home_cell: int, wallet: int) -> void:
	home.append(NONE)
	job.append(NONE)
	money.append(wallet)
	hungry_days.append(0)
	set_home(size() - 1, home_cell)


func set_home(i: int, cell: int) -> void:
	_move(_residents, home[i], cell)
	home[i] = cell


func set_job(i: int, cell: int) -> void:
	_move(_workers, job[i], cell)
	job[i] = cell


func residents_at(cell: int) -> int:
	return _residents.get(cell, 0)


func workers_at(cell: int) -> int:
	return _workers.get(cell, 0)


## Fires everyone working at cell and evicts everyone living there.
func vacate(cell: int) -> void:
	for i in size():
		if job[i] == cell:
			set_job(i, NONE)
		if home[i] == cell:
			set_home(i, NONE)


func _move(counts: Dictionary, from: int, to: int) -> void:
	if from != NONE:
		counts[from] -= 1
	if to != NONE:
		counts[to] = counts.get(to, 0) + 1
