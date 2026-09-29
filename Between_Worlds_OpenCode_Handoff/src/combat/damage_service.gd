class_name DamageService
## Reglas puras de daño. Sin estado: ideal para tests y para el servidor autoritativo.
## Formula: daño final = daño base * mult. zona * (1 - mitigación de armadura).
## Damage y knockback quedan separados: aquí sólo se resuelve daño.

static func zone_multiplier(zone: HitZone.Zone) -> float:
	match zone:
		HitZone.Zone.HEAD:
			return GameConstants.HEADSHOT_MULTIPLIER
		_:
			return GameConstants.BODY_MULTIPLIER


static func final_damage(base_damage: float, zone: HitZone.Zone, armor_mitigation: float) -> float:
	return base_damage * zone_multiplier(zone) * (1.0 - clampf(armor_mitigation, 0.0, 1.0))


## Peor caso teórico: headshot sin armadura.
static func max_shot_damage(base_damage: float) -> float:
	return base_damage * GameConstants.HEADSHOT_MULTIPLIER


## Debe ser ALWAYS false para el arsenal actual: nunca one-shot por headshot convencional.
static func is_one_shot_possible(base_damage: float) -> bool:
	return max_shot_damage(base_damage) >= GameConstants.MAX_HP


static func damage_to_armor_first(shield: float, hp: float, amount: float) -> Dictionary:
	## Aplica daño primero al escudo temporal (pickup armor provisional) y luego al HP.
	var shield_absorbed := minf(shield, amount)
	var remaining := amount - shield_absorbed
	var new_shield := shield - shield_absorbed
	var new_hp := hp - remaining
	return {
		"shield": maxf(new_shield, 0.0),
		"hp": new_hp,
		"shield_absorbed": shield_absorbed,
		"hp_lost": remaining,
	}


## Disparos necesarios para matar (HP lleno, sin escudo). Mínimo 1.
static func shots_to_kill(base_damage: float, zone: HitZone.Zone, armor_mitigation: float) -> int:
	var per_shot := final_damage(base_damage, zone, armor_mitigation)
	if per_shot <= 0.0:
		return 999
	return int(ceil(GameConstants.MAX_HP / per_shot))


## TTK teórico = (disparos-1) * intervalo entre disparos. Sin contar recarga.
static func ttk_seconds(base_damage: float, zone: HitZone.Zone, armor_mitigation: float, shots_per_second: float) -> float:
	var n := shots_to_kill(base_damage, zone, armor_mitigation)
	if n <= 1 or shots_per_second <= 0.0:
		return 0.0
	return float(n - 1) / shots_per_second