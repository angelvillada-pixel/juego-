class_name PickupData
## Datos de pickups (data-driven).

const PICKUP_HEALTH := "health"
const PICKUP_ARMOR := "armor"  # provisional: escudo temporal separado de la armadura base
const PICKUP_AMMO := "ammo"

const DEFS := {
	PICKUP_HEALTH: {
		"id": PICKUP_HEALTH,
		"display_name": "Health",
		"color": Color("06d6a0"),
		"fraction": GameConstants.PICKUP_HEALTH_FRACTION,
	},
	PICKUP_ARMOR: {
		"id": PICKUP_ARMOR,
		"display_name": "Shield",
		"color": Color("4cc9f0"),
		"fraction": GameConstants.PICKUP_ARMOR_FRACTION,
	},
	PICKUP_AMMO: {
		"id": PICKUP_AMMO,
		"display_name": "Ammo",
		"color": Color("ffd166"),
		"fraction": GameConstants.PICKUP_AMMO_FRACTION,
	},
}

const ORDER := [PICKUP_HEALTH, PICKUP_ARMOR, PICKUP_AMMO]


static func get_def(pickup_id: String) -> Dictionary:
	if DEFS.has(pickup_id):
		return DEFS[pickup_id]
	push_error("Pickup desconocido: %s" % pickup_id)
	return DEFS[PICKUP_HEALTH]