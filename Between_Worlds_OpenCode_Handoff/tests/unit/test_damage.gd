class_name TestDamage
extends RefCounted
## Reglas de daño: multiplicador 1.5x de headshot, mitigación por armadura,
## y NO existe one-shot por headshot convencional con el arsenal actual.


func run(ctx: Object) -> void:
	# Headshot > body
	var body_dmg := DamageService.final_damage(20.0, HitZone.Zone.BODY, 0.0)
	var head_dmg := DamageService.final_damage(20.0, HitZone.Zone.HEAD, 0.0)
	ctx.approx(head_dmg, 30.0, 0.001, "Rifle headshot 20*1.5")
	ctx.approx(body_dmg, 20.0, 0.001, "Rifle body 20")

	# Mitigación de armadura (sin armadura, light, medium, heavy)
	ctx.approx(DamageService.final_damage(20.0, HitZone.Zone.BODY, 0.10), 18.0, 0.001, "Light mitigación 10%")
	ctx.approx(DamageService.final_damage(20.0, HitZone.Zone.BODY, 0.20), 16.0, 0.001, "Medium mitigación 20%")
	ctx.approx(DamageService.final_damage(20.0, HitZone.Zone.BODY, 0.30), 14.0, 0.001, "Heavy mitigación 30%")

	# Headshot + armadura combinados
	ctx.approx(DamageService.final_damage(20.0, HitZone.Zone.HEAD, 0.30), 21.0, 0.001, "Heavy headshot rifle")

	# Sin one-shot: ningún arma del arsenal llega a 100 por disparo (peor caso: headshot sin armor)
	for weapon_id in WeaponData.DEFS:
		var base: float = WeaponData.DEFS[weapon_id]["damage"]
		ctx.check(not DamageService.is_one_shot_possible(base), "No one-shot para %s (max %.1f)" % [weapon_id, DamageService.max_shot_damage(base)])

	# Orden del escudo: el daño va primero al escudo temporal y luego al HP.
	var applied := DamageService.damage_to_armor_first(20.0, 100.0, 30.0)
	ctx.approx(applied["shield"], 0.0, 0.001, "Escudo absorbido")
	ctx.approx(applied["hp"], 90.0, 0.001, "HP tras escudo+daño")