class_name TestBalancePoint1
extends RefCounted
## Punto 1 / Q2-Q4: TTK congelado, sin one-shot, escudo máx 50, bloques y
## daño a estructuras separado por arma.


func run(ctx: Object) -> void:
	# Q2: TTK teórico (sin escudo, Medium 20%).
	var mit := ArmorData.mitigation(ArmorData.ARMOR_MEDIUM)
	var rifle_sps := WeaponData.shots_per_second(WeaponData.WEAPON_RIFLE)
	# Rifle body Medium: 16 dmg -> 7 disparos -> 0.6s.
	ctx.equals(DamageService.shots_to_kill(20.0, HitZone.Zone.BODY, mit), 7, "Rifle body Medium 7 disparos")
	ctx.approx(DamageService.ttk_seconds(20.0, HitZone.Zone.BODY, mit, rifle_sps), 0.6, 0.05, "Rifle body Medium TTK 0.6s")
	# Rifle head Medium: 24 dmg -> 5 disparos -> 0.4s.
	ctx.equals(DamageService.shots_to_kill(20.0, HitZone.Zone.HEAD, mit), 5, "Rifle head Medium 5 disparos")
	# Precision body Medium: 48 dmg -> 3 disparos; head 72 -> 2 disparos.
	ctx.equals(DamageService.shots_to_kill(60.0, HitZone.Zone.BODY, mit), 3, "Precision body 3 disparos")
	ctx.equals(DamageService.shots_to_kill(60.0, HitZone.Zone.HEAD, mit), 2, "Precision head 2 disparos")
	# Sin one-shot en todo el arsenal (peor caso head sin armor < 100).
	for wid in WeaponData.DEFS:
		var base: float = WeaponData.DEFS[wid]["damage"]
		ctx.check(not DamageService.is_one_shot_possible(base), "No one-shot %s" % wid)

	# Q3: escudo temporal separado, máx 50, fracción 30% (15 pts).
	ctx.equals(GameConstants.MAX_SHIELD, 50.0, "Max shield 50")
	ctx.approx(GameConstants.PICKUP_ARMOR_FRACTION, 0.30, 0.001, "Armor pickup 30%")
	ctx.approx(PickupService.apply_shield(0.0, GameConstants.MAX_SHIELD, 0.30), 15.0, 0.001, "Shield 0+30% de 50 = 15")
	ctx.approx(PickupService.apply_shield(45.0, GameConstants.MAX_SHIELD, 0.30), 50.0, 0.001, "Shield capado a 50")

	# Q4: bloques HP + daño a estructuras por arma.
	ctx.equals(GameConstants.BUILD_BLOCK_HP, 200.0, "Build block 200 HP")
	ctx.equals(GameConstants.MAP_DESTRUCTIBLE_HP, 100.0, "Terreno 100 HP")
	ctx.equals(GameConstants.MAP_TARGET_HP, 120.0, "Objetivo 120 HP")
	ctx.approx(WeaponData.structure_multiplier(WeaponData.WEAPON_RIFLE), 1.0, 0.001, "Rifle x1.0 estructuras")
	ctx.approx(WeaponData.structure_multiplier(WeaponData.WEAPON_PRECISION), 2.0, 0.001, "Precision x2.0 estructuras")
	ctx.approx(WeaponData.structure_multiplier(WeaponData.WEAPON_PISTOL), 0.6, 0.001, "Pistol x0.6 estructuras")
	# Rifle necesita 10 disparos para bloque construido (200/20).
	var rifle_struct: float = 20.0 * WeaponData.structure_multiplier(WeaponData.WEAPON_RIFLE)
	ctx.equals(int(ceil(200.0 / rifle_struct)), 10, "Rifle 10 disparos vs build block")
	# Precision necesita 2 disparos (120*2? no: 60*2=120 por disparo -> 200/120 = 2).
	var prec_struct: float = 60.0 * WeaponData.structure_multiplier(WeaponData.WEAPON_PRECISION)
	ctx.equals(int(ceil(200.0 / prec_struct)), 2, "Precision 2 disparos vs build block")
