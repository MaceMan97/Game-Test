class_name TerrainDefs
extends RefCounted
## Static terrain data for the ground layer under buildings. Pure data, like BuildingDefs.

enum { OPEN, ROAD, SHANTY, RUBBLE, RUIN, PAD }

## clear_cost: credits to clear one tile (multiplied by density for shanties); -1 = cannot clear.
## residents: shanty dwellers per density level.
const DEFS := {
	OPEN: {"name": "Open lot", "buildable": true, "clear_cost": -1, "residents": 0},
	ROAD: {"name": "Boulevard", "buildable": false, "clear_cost": -1, "residents": 0},
	SHANTY: {"name": "Shanty", "buildable": false, "clear_cost": 30, "residents": 6},
	RUBBLE: {"name": "Rubble", "buildable": false, "clear_cost": 15, "residents": 0},
	RUIN: {"name": "Regime ruins", "buildable": false, "clear_cost": -1, "residents": 0},
	PAD: {"name": "Landing pad", "buildable": false, "clear_cost": -1, "residents": 0},
}
