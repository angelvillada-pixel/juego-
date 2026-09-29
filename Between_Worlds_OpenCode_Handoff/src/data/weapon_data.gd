class_name WeaponData
## Datos de armas (data-driven) para el primer prototipo.
## Valores de prueba según Prototype Blueprint v0.1 (arquetipos, no finales).

const WEAPON_RIFLE := "rifle"
const WEAPON_PRECISION := "precision"
const WEAPON_PISTOL := "pistol"

const SLOT_PRIMARY := "primary"
const SLOT_SECONDARY := "secondary"

const DEFS := {
	WEAPON_RIFLE: {
		"id": WEAPON_RIFLE,
		"display_name": "Rifle",
		"slot": SLOT_PRIMARY,
		"damage": 20.0,          # daño base
		"rounds_per_minute": 600.0,
		"magazine_size": 30,
		"reserve_max": 90,
		"reload_time": 2.1,
		"is_hitscan": true,
		"range": 1500.0,
		"structure_mult": 1.0,  # provisional Punto 1: daño x1.0 a estructuras
	},
	WEAPON_PRECISION: {
		"id": WEAPON_PRECISION,
		"display_name": "Precision",
		"slot": SLOT_PRIMARY,
		"damage": 60.0,
		"rounds_per_minute": 100.0,
		"magazine_size": 5,
		"reserve_max": 20,
		"reload_time": 3.0,
		"is_hitscan": true,
		"range": 1800.0,
		"structure_mult": 2.0,  # provisional Punto 1: anti-material
	},
	WEAPON_PISTOL: {
		"id": WEAPON_PISTOL,
		"display_name": "Pistol",
		"slot": SLOT_SECONDARY,
		"damage": 14.0,
		"rounds_per_minute": 420.0,
		"magazine_size": 12,
		"reserve_max": 48,
		"reload_time": 1.4,
		"is_hitscan": true,
		"range": 1200.0,
		"structure_mult": 0.6,  # provisional Punto 1: emergencia, floja vs estructuras
	},
}

## El set que equipa un jugador por defecto en el laboratorio.
const DEFAULT_LOADOUT_WEAPONS := [WEAPON_RIFLE, WEAPON_PISTOL]


static func get_def(weapon_id: String) -> Dictionary:
	if DEFS.has(weapon_id):
		return DEFS[weapon_id]
	push_error("Arma desconocida: %s" % weapon_id)
	return DEFS[WEAPON_RIFLE]


static func shots_per_second(weapon_id: String) -> float:
	return get_def(weapon_id)["rounds_per_minute"] / 60.0


static func cooldown_seconds(weapon_id: String) -> float:
	return 1.0 / shots_per_second(weapon_id)


static func structure_multiplier(weapon_id: String) -> float:
	return float(get_def(weapon_id).get("structure_mult", 1.0))