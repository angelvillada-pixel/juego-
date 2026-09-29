class_name ModeData
## Modos de partida data-driven (Punto 2, provisional).
## FRONTLINE: modo base propio — destruir objetivos con vidas de equipo.
## VIP: cada equipo tiene un VIP; matar al VIP rival gana la ronda.
## DOMINATION: controlar zonas para sumar puntos; primero a WIN_SCORE gana.

const MODE_FRONTLINE := "frontline"
const MODE_VIP := "vip"
const MODE_DOMINATION := "domination"

const DEFS := {
	MODE_FRONTLINE: {
		"id": MODE_FRONTLINE,
		"display_name": "Frontline",
		"description": "Destroy all targets. Team lives shared.",
		"respawn": true,
		"vip": false,
		"zones": false,
	},
	MODE_VIP: {
		"id": MODE_VIP,
		"display_name": "VIP",
		"description": "Kill the enemy VIP. VIP death ends the round.",
		"respawn": true,
		"vip": true,
		"zones": false,
	},
	MODE_DOMINATION: {
		"id": MODE_DOMINATION,
		"display_name": "Domination",
		"description": "Hold zones to score. First to WIN_SCORE wins.",
		"respawn": true,
		"vip": false,
		"zones": true,
	},
}

const ORDER := [MODE_FRONTLINE, MODE_VIP, MODE_DOMINATION]


static func get_def(mode_id: String) -> Dictionary:
	if DEFS.has(mode_id):
		return DEFS[mode_id]
	push_error("Modo desconocido: %s" % mode_id)
	return DEFS[MODE_FRONTLINE]


static func is_valid(mode_id: String) -> bool:
	return DEFS.has(mode_id)


static func uses_vip(mode_id: String) -> bool:
	return bool(get_def(mode_id)["vip"])


static func uses_zones(mode_id: String) -> bool:
	return bool(get_def(mode_id)["zones"])
