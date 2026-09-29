class_name MapData
## Mapas data-driven (Punto 4, provisional). Misma escala de grid (Q8 sigue
## abierta); lo que cambia por mapa es seed, plataformas, cobertura y objetivos.

const MAP_LAB := "lab"
const MAP_ARENA := "arena"

const DEFS := {
	MAP_LAB: {
		"id": MAP_LAB,
		"display_name": "Laboratory",
		"seed": 177013,
		"ground_ratio": 0.45,
		"platform_bands": [8, 20, 34],  # distancia al suelo en celdas
		"cover_bands": [6, 16],
		"target_mod": 25,
		"target_off": 12,
		"target_rows": [12, 26],
	},
	MAP_ARENA: {
		"id": MAP_ARENA,
		"display_name": "Arena",
		"seed": 424242,
		"ground_ratio": 0.35,
		"platform_bands": [7, 15, 24, 33],
		"cover_bands": [5, 11, 21],
		"target_mod": 20,
		"target_off": 9,
		"target_rows": [11, 23],
	},
}

const ORDER := [MAP_LAB, MAP_ARENA]


static func get_def(map_id: String) -> Dictionary:
	if DEFS.has(map_id):
		return DEFS[map_id]
	push_error("Mapa desconocido: %s" % map_id)
	return DEFS[MAP_LAB]


static func is_valid(map_id: String) -> bool:
	return DEFS.has(map_id)
