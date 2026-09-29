class_name UtilityData
## Roster mínimo de utilidades (Punto 1, provisional): un Dash de combate.
## Data-driven: cooldown e impulso viven aquí, no en la lógica.

const UTILITY_DASH := "dash"

const DEFS := {
	UTILITY_DASH: {
		"id": UTILITY_DASH,
		"display_name": "Dash",
		"slot": "utility",
		"cooldown": 8.0,  # provisional
		"impulse": 380.0,  # provisional: velocidad horizontal aplicada al usar
		"air_allowed": true,
	},
}


static func get_def(utility_id: String) -> Dictionary:
	if DEFS.has(utility_id):
		return DEFS[utility_id]
	push_error("Utilidad desconocida: %s" % utility_id)
	return DEFS[UTILITY_DASH]


static func cooldown_seconds(utility_id: String) -> float:
	return float(get_def(utility_id)["cooldown"])


static func impulse(utility_id: String) -> float:
	return float(get_def(utility_id)["impulse"])
