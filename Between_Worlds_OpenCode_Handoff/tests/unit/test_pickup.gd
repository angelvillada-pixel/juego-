class_name TestPickup
extends RefCounted
## Pickups: restauración 25-40% del máximo y nunca superan el máximo.


func run(ctx: Object) -> void:
	# Health: 30% del máximo, con y sin tocar el máximo.
	ctx.approx(PickupService.apply_health(50.0, 100.0, GameConstants.PICKUP_HEALTH_FRACTION), 80.0, 0.001, "Health 30% desde 50")
	ctx.approx(PickupService.apply_health(90.0, 100.0, GameConstants.PICKUP_HEALTH_FRACTION), 100.0, 0.001, "Health nunca supera 100")
	ctx.approx(PickupService.apply_health(0.0, 100.0, GameConstants.PICKUP_HEALTH_FRACTION), 30.0, 0.001, "Health 30% desde 0")

	# Armor (escudo temporal): misma política.
	ctx.approx(PickupService.apply_shield(15.0, 100.0, GameConstants.PICKUP_ARMOR_FRACTION), 45.0, 0.001, "Shield 30% desde 15")
	ctx.approx(PickupService.apply_shield(80.0, 100.0, GameConstants.PICKUP_ARMOR_FRACTION), 100.0, 0.001, "Shield nunca supera el máximo")
	ctx.approx(PickupService.apply_shield(100.0, 100.0, GameConstants.PICKUP_ARMOR_FRACTION), 100.0, 0.001, "Shield al máximo no cambia")

	# Ammo: % sobre la reserva máxima, sin pasarse.
	ctx.equals(PickupService.apply_ammo(15, 30, 0.40), 27, "Ammo 40% desde 15/30")
	ctx.equals(PickupService.apply_ammo(80, 90, 0.40), 90, "Ammo clamp a reserva máxima")
	ctx.equals(PickupService.apply_ammo(0, 50, 0.40), 20, "Ammo 40% desde 0")
	ctx.equals(PickupService.apply_ammo(60, 60, 0.40), 60, "Ammo al máximo no cambia")

	# Rango objetivo 25-40% explicitado en los datos.
	for pid in [PickupData.PICKUP_HEALTH, PickupData.PICKUP_ARMOR, PickupData.PICKUP_AMMO]:
		var frac: float = PickupData.get_def(pid)["fraction"]
		ctx.check(frac >= 0.25 and frac <= 0.40, "Pickup %s fracción %s en rango 25-40%%" % [pid, frac])