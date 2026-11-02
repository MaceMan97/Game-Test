class_name BuildingDefs
extends RefCounted
## Static building data. Pure data: no rendering, no nodes.
## Later this can move to Resource files (.tres) or JSON so designers can edit it.
##
## category: build menu group (see CATEGORIES). tier: unlock tier (see TIER_RESIDENTS).
## cost: credits to build. materials: building materials taken from your hubs.
## upkeep: credits per day. jobs: worker slots; output scales with how many are filled.
## wage: credits per worker per day (default Economy.WAGE).
## power: + supplies, - consumes. consumes: goods per day taken from hubs (no supply = no output).
## produces: goods per day put into your hubs, scaled by how well the building runs.
## Optional: storage (hub capacity), housing + rent (apartments, rent per day),
## customers (company store meals sold per day), income (credits per day).

## Build menu groups, in toolbar order.
const CATEGORIES := {
	"logistics": "Logistics",
	"housing": "Housing",
	"food": "Food",
	"industry": "Industry",
	"power": "Power",
	"commerce": "Commerce",
}

## People living in company housing needed to unlock each tier. Unlocks are permanent.
const TIER_RESIDENTS := {1: 0, 2: 20, 3: 60}

const DEFS := {
	# Tier 1: a foothold around the landing pad.
	"warehouse": {
		"name": "Distribution hub", "category": "logistics", "tier": 1,
		"cost": 200, "materials": 0, "upkeep": 2, "jobs": 4, "power": 0,
		"height": 20.0, "color": Color(0.55, 1.0, 0.35),
		"storage": 100,
	},
	"market": {
		"name": "Company store", "category": "commerce", "tier": 1,
		"cost": 120, "materials": 5, "upkeep": 2, "jobs": 3, "power": 0,
		"height": 24.0, "color": Color(0.59, 0.47, 1.0),
		"customers": 60,
	},
	"apartment": {
		"name": "Capsule tower", "category": "housing", "tier": 1,
		"cost": 150, "materials": 10, "upkeep": 2, "jobs": 0, "power": 0,
		"height": 58.0, "color": Color(1.0, 0.18, 0.53),
		"housing": 20, "rent": 4,
	},
	"farm": {
		"name": "Hydroponic farm", "category": "food", "tier": 1,
		"cost": 180, "materials": 10, "upkeep": 2, "jobs": 4, "power": 0,
		"height": 14.0, "color": Color(0.35, 0.95, 0.45),
		"produces": {"food": 20},
	},

	# Tier 2: power and on-world industry.
	"reactor": {
		"name": "Fusion reactor", "category": "power", "tier": 2,
		"cost": 300, "materials": 15, "upkeep": 5, "jobs": 4, "wage": 12, "power": 40,
		"height": 40.0, "color": Color(1.0, 0.70, 0.28),
		"consumes": {"fuel": 2},
	},
	"vats": {
		"name": "Protein vats", "category": "food", "tier": 2,
		"cost": 350, "materials": 20, "upkeep": 4, "jobs": 6, "wage": 12, "power": -8,
		"height": 30.0, "color": Color(0.30, 0.85, 0.75),
		"produces": {"food": 50},
	},
	"fabplant": {
		"name": "Fabrication plant", "category": "industry", "tier": 2,
		"cost": 400, "materials": 20, "upkeep": 4, "jobs": 6, "wage": 12, "power": -10,
		"height": 34.0, "color": Color(0.85, 0.55, 0.30),
		"consumes": {"fuel": 1}, "produces": {"materials": 40},
	},
	"refinery": {
		"name": "Fuel refinery", "category": "industry", "tier": 2,
		"cost": 380, "materials": 20, "upkeep": 4, "jobs": 5, "wage": 12, "power": -8,
		"height": 44.0, "color": Color(1.0, 0.40, 0.20),
		"produces": {"fuel": 14},
	},

	# Tier 3: skilled work and the people who can afford better.
	"compfab": {
		"name": "Component fab", "category": "industry", "tier": 3,
		"cost": 650, "materials": 30, "upkeep": 6, "jobs": 8, "wage": 18, "power": -12,
		"height": 50.0, "color": Color(0.40, 0.70, 1.0),
		"consumes": {"materials": 6}, "produces": {"components": 16},
	},
	"hub": {
		"name": "Data hub", "category": "commerce", "tier": 3,
		"cost": 600, "materials": 30, "upkeep": 6, "jobs": 12, "wage": 18, "power": -15,
		"height": 74.0, "color": Color(0.16, 0.88, 1.0),
		"consumes": {"components": 2}, "income": 350,
	},
	"suites": {
		"name": "Skyline suites", "category": "housing", "tier": 3,
		"cost": 600, "materials": 40, "upkeep": 6, "jobs": 0, "power": -6,
		"height": 92.0, "color": Color(1.0, 0.85, 0.35),
		"housing": 12, "rent": 12,
	},
}


## Building ids in a category, in definition order.
static func in_category(category: String) -> Array[String]:
	var out: Array[String] = []
	for id in DEFS:
		if DEFS[id]["category"] == category:
			out.append(id)
	return out
