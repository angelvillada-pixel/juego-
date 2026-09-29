class_name FactionData
## Identidad visual de las dos civilizaciones (Punto 4, provisional).
## Mismo poder competitivo: solo cambian color, nombre y marcador de equipo.

const FACTION_AEGIS := 0
const FACTION_RIFT := 1

const DEFS := {
	FACTION_AEGIS: {
		"name": "Aegis",
		"color": Color("06d6a0"),
		"motto": "Hold the line.",
	},
	FACTION_RIFT: {
		"name": "Rift",
		"color": Color("ef476f"),
		"motto": "Break it open.",
	},
}


static func get_def(team: int) -> Dictionary:
	if DEFS.has(team):
		return DEFS[team]
	return DEFS[FACTION_AEGIS]


static func team_name(team: int) -> String:
	return str(get_def(team)["name"])


static func team_color(team: int) -> Color:
	return get_def(team)["color"]
