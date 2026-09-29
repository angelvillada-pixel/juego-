class_name BlockData
## Datos de bloques/muros (data-driven) para construcción y terreno.

const BLOCK_BUILD := "build"          # bloque construido por jugador
const BLOCK_DESTRUCTIBLE := "destructible"  # terreno destruible del mapa
const BLOCK_TARGET := "target"        # objetivo de la partida de laboratorio

const DEFS := {
	BLOCK_BUILD: {
		"id": BLOCK_BUILD,
		"display_name": "Block",
		"hp": GameConstants.BUILD_BLOCK_HP,
		"destructible": true,
		"is_target": false,
		"color": Color("4cc9f0"),
		"color_damaged": Color("3a86ff"),
		"outline": Color("2b2d42"),
	},
	BLOCK_DESTRUCTIBLE: {
		"id": BLOCK_DESTRUCTIBLE,
		"display_name": "Terrain",
		"hp": GameConstants.MAP_DESTRUCTIBLE_HP,
		"destructible": true,
		"is_target": false,
		"color": Color("a68a64"),
		"color_damaged": Color("6f4e37"),
		"outline": Color("2b2d42"),
	},
	BLOCK_TARGET: {
		"id": BLOCK_TARGET,
		"display_name": "Target",
		"hp": GameConstants.MAP_TARGET_HP,
		"destructible": true,
		"is_target": true,
		"color": Color("ffe066"),
		"color_damaged": Color("f9c74f"),
		"outline": Color("2b2d42"),
	},
}


static func get_def(block_id: String) -> Dictionary:
	if DEFS.has(block_id):
		return DEFS[block_id]
	push_error("Bloque desconocido: %s" % block_id)
	return DEFS[BLOCK_BUILD]