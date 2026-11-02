class_name GoodsDefs
extends RefCounted
## Tradeable goods. Pure data, like BuildingDefs.
## price: credits per unit when bought off-world at the landing pad.
## export: credits per unit when sold off-world (always below the import price).

const DEFS := {
	"materials": {"name": "Building materials", "price": 4, "export": 3, "color": Color(0.75, 0.55, 0.35)},
	"food": {"name": "Ration packs", "price": 3, "export": 2, "color": Color(0.45, 0.85, 0.40)},
	"fuel": {"name": "Fuel cells", "price": 8, "export": 6, "color": Color(1.0, 0.45, 0.20)},
	"components": {"name": "Components", "price": 12, "export": 9, "color": Color(0.40, 0.70, 1.0)},
}
