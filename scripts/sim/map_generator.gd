class_name MapGenerator
extends RefCounted
## Builds the starting map: a shanty town megacity laid over the old regime's
## boulevard grid, with the toppled palace in the centre and the player's
## landing pad near one corner. Deterministic for a given seed.

const BOULEVARDS := [9, 20, 31]  # x and y lines of the regime-era grid
const PALACE_RADIUS := 2  # ruins span centre +/- this
const PLAZA_RADIUS := 4  # rubble-strewn plaza around the ruins
const ALLEY_COUNT := 60
const LOT_START := Vector2i(3, 3)  # player's cleared lot, touching boulevard 9
const LOT_SIZE := 6


static func generate(city: CityState, map_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	var n := CityState.SIZE

	var density_noise := FastNoiseLite.new()
	density_noise.seed = map_seed
	density_noise.frequency = 0.08
	var damage_noise := FastNoiseLite.new()
	damage_noise.seed = map_seed + 1
	damage_noise.frequency = 0.12

	# 1. Shanty everywhere, with war-damage rubble patches and the odd empty lot.
	for y in n:
		for x in n:
			var cell := Vector2i(x, y)
			if damage_noise.get_noise_2d(x, y) > 0.45:
				city.set_terrain(cell, TerrainDefs.RUBBLE)
			elif rng.randf() < 0.03:
				city.set_terrain(cell, TerrainDefs.OPEN)
			else:
				var d := density_noise.get_noise_2d(x, y)  # roughly -1..1
				var level := clampi(2 + roundi(d * 2.0) + rng.randi_range(-1, 0), 1, 3)
				city.set_terrain(cell, TerrainDefs.SHANTY, level)

	# 2. Regime boulevards.
	for line in BOULEVARDS:
		for i in n:
			city.set_terrain(Vector2i(line, i), TerrainDefs.ROAD)
			city.set_terrain(Vector2i(i, line), TerrainDefs.ROAD)

	# 3. Palace ruins in a rubble plaza at the centre.
	var centre := Vector2i(n / 2, n / 2)
	for dy in range(-PLAZA_RADIUS, PLAZA_RADIUS + 1):
		for dx in range(-PLAZA_RADIUS, PLAZA_RADIUS + 1):
			var cell := centre + Vector2i(dx, dy)
			if absi(dx) <= PALACE_RADIUS and absi(dy) <= PALACE_RADIUS:
				city.set_terrain(cell, TerrainDefs.RUIN)
			elif city.get_terrain(cell) != TerrainDefs.ROAD:
				city.set_terrain(cell, TerrainDefs.RUBBLE if rng.randf() < 0.6 else TerrainDefs.OPEN)

	# 4. Alleys wandering off the boulevards into the shanties (density 1 marks an alley).
	for a in ALLEY_COUNT:
		var line: int = BOULEVARDS[rng.randi() % BOULEVARDS.size()]
		var along := rng.randi_range(0, n - 1)
		var vertical_line := rng.randf() < 0.5
		var pos := Vector2i(line, along) if vertical_line else Vector2i(along, line)
		var dir := Vector2i(1 if rng.randf() < 0.5 else -1, 0)
		if not vertical_line:
			dir = Vector2i(0, dir.x)
		for step in rng.randi_range(4, 12):
			pos += dir
			if not city.in_bounds(pos):
				break
			var t := city.get_terrain(pos)
			if t != TerrainDefs.SHANTY and t != TerrainDefs.RUBBLE:
				break
			city.set_terrain(pos, TerrainDefs.ROAD, 1)
			if rng.randf() < 0.25:  # jog sideways
				dir = Vector2i(dir.y, dir.x) * (1 if rng.randf() < 0.5 else -1)

	# 5. The player's cleared lot and landing pad.
	for dy in LOT_SIZE:
		for dx in LOT_SIZE:
			city.set_terrain(LOT_START + Vector2i(dx, dy), TerrainDefs.OPEN)
	city.landing_pad = LOT_START + Vector2i(2, 2)
	for dy in 2:
		for dx in 2:
			city.set_terrain(city.landing_pad + Vector2i(dx, dy), TerrainDefs.PAD)
