class_name ArmorData
## Datos de armaduras (data-driven). La mitigación es fija durante la vida;
## la velocidad horizontal se modifica según peso. El salto es compartido.

const ARMOR_LIGHT := "light"
const ARMOR_MEDIUM := "medium"
const ARMOR_HEAVY := "heavy"

const DEFS := {
	ARMOR_LIGHT: {
		"id": ARMOR_LIGHT,
		"display_name": "Light",
		"mitigation": 0.10,
		"speed_modifier": 0.10,
		"color": Color("7ac74f"),
	},
	ARMOR_MEDIUM: {
		"id": ARMOR_MEDIUM,
		"display_name": "Medium",
		"mitigation": 0.20,
		"speed_modifier": 0.00,
		"color": Color("3a86ff"),
	},
	ARMOR_HEAVY: {
		"id": ARMOR_HEAVY,
		"display_name": "Heavy",
		"mitigation": 0.30,
		"speed_modifier": -0.10,
		"color": Color("ff6d00"),
	},
}

const ORDER := [ARMOR_LIGHT, ARMOR_MEDIUM, ARMOR_HEAVY]


static func get_def(armor_id: String) -> Dictionary:
	if DEFS.has(armor_id):
		return DEFS[armor_id]
	push_error("Arma desconocida: %s" % armor_id)
	return DEFS[ARMOR_MEDIUM]


static func mitigation(armor_id: String) -> float:
	return get_def(armor_id)["mitigation"]


static func speed_modifier(armor_id: String) -> float:
	return get_def(armor_id)["speed_modifier"]


## Velocidad horizontal resultante aplicando el modificador de la armadura.
static func movement_speed(armor_id: String) -> float:
	var mod: float = speed_modifier(armor_id)
	return GameConstants.BASE_RUN_SPEED * (1.0 + mod)