class_name BuildingDefs
extends RefCounted
## Static building data. Pure data: no rendering, no nodes.
## Later this can move to Resource files (.tres) or JSON so designers can edit it.
##
## cost: credits to build. materials: building materials taken from your hubs.
## upkeep: credits per day. jobs: worker slots; output scales with how many are filled.
## power: + supplies, - consumes. consumes: goods per day taken from hubs (no supply = no output).
## Optional: storage (hub capacity), housing + rent (apartments, rent per day),
## customers (company store meals sold per day), income (credits per day).

const DEFS := {
	"warehouse": {
		"name": "Distribution hub", "cost": 200, "materials": 0, "upkeep": 2,
		"jobs": 4, "power": 0, "height": 20.0, "color": Color(0.55, 1.0, 0.35),
		"storage": 100,
	},
	"market": {
		"name": "Company store", "cost": 120, "materials": 5, "upkeep": 2,
		"jobs": 3, "power": 0, "height": 24.0, "color": Color(0.59, 0.47, 1.0),
		"customers": 60,
	},
	"apartment": {
		"name": "Capsule tower", "cost": 150, "materials": 10, "upkeep": 2,
		"jobs": 0, "power": 0, "height": 58.0, "color": Color(1.0, 0.18, 0.53),
		"housing": 20, "rent": 4,
	},
	"reactor": {
		"name": "Fusion reactor", "cost": 300, "materials": 15, "upkeep": 5,
		"jobs": 4, "power": 40, "height": 40.0, "color": Color(1.0, 0.70, 0.28),
		"consumes": {"fuel": 2},
	},
	"hub": {
		"name": "Data hub", "cost": 400, "materials": 20, "upkeep": 5,
		"jobs": 12, "power": -15, "height": 74.0, "color": Color(0.16, 0.88, 1.0),
		"consumes": {"components": 2}, "income": 350,
	},
}
