class_name PickupService
## Lógica pura de aplicación de pickups (sin estado, testable).
## Los pickups restablecen % del máximo y NUNCA superan el máximo.

static func apply_health(current: float, maximum: float, fraction: float) -> float:
	return clampf(current + maximum * fraction, 0.0, maximum)


static func apply_shield(current: float, maximum: float, fraction: float) -> float:
	return clampf(current + maximum * fraction, 0.0, maximum)


## Devuelve la munición de reserva tras el pickup, sin superar el máximo normal.
static func apply_ammo(reserve: int, reserve_max: int, fraction: float) -> int:
	var amount := int(roundf(float(reserve_max) * fraction))
	return mini(reserve + amount, reserve_max)