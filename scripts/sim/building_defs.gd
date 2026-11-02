class_name BuildingDefs
extends RefCounted
## Static building data. Pure data: no rendering, no nodes.
## Later this can move to Resource files (.tres) or JSON so designers can edit it.

## Optional key "storage": warehouse capacity in units (see Warehouse).
const DEFS := {
	"warehouse": {
		"name": "Distribution hub", "cost": 200, "power": 0, "jobs": 4,
		"housing": 0, "income": 0, "height": 20.0, "color": Color(0.55, 1.0, 0.35),
		"storage": 100,
	},
	"reactor": {
		"name": "Fusion reactor", "cost": 300, "power": 40, "jobs": 4,
		"housing": 0, "income": 0, "height": 40.0, "color": Color(1.0, 0.70, 0.28),
	},
	"apartment": {
		"name": "Capsule tower", "cost": 150, "power": -4, "jobs": 0,
		"housing": 20, "income": 0, "height": 58.0, "color": Color(1.0, 0.18, 0.53),
	},
	"hub": {
		"name": "Data hub", "cost": 400, "power": -15, "jobs": 12,
		"housing": 0, "income": 8, "height": 74.0, "color": Color(0.16, 0.88, 1.0),
	},
	"market": {
		"name": "Night market", "cost": 120, "power": -2, "jobs": 3,
		"housing": 0, "income": 5, "height": 24.0, "color": Color(0.59, 0.47, 1.0),
	},
}
