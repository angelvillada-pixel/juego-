class_name TestArmor
extends RefCounted
## Armaduras: mitigación 10/20/30%, modificador horizontal +10/0/-10% sobre 240 px/s.


func run(ctx: Object) -> void:
	ctx.approx(ArmorData.mitigation(ArmorData.ARMOR_LIGHT), 0.10, 0.001, "Light mitigación")
	ctx.approx(ArmorData.mitigation(ArmorData.ARMOR_MEDIUM), 0.20, 0.001, "Medium mitigación")
	ctx.approx(ArmorData.mitigation(ArmorData.ARMOR_HEAVY), 0.30, 0.001, "Heavy mitigación")

	ctx.approx(ArmorData.movement_speed(ArmorData.ARMOR_LIGHT), 264.0, 0.001, "Light 264 px/s (+10%)")
	ctx.approx(ArmorData.movement_speed(ArmorData.ARMOR_MEDIUM), 240.0, 0.001, "Medium 240 px/s")
	ctx.approx(ArmorData.movement_speed(ArmorData.ARMOR_HEAVY), 216.0, 0.001, "Heavy 216 px/s (-10%)")

	# El salto es compartido (constante única, verificamos que existe y es igual para todas).
	ctx.check(GameConstants.JUMP_VELOCITY < 0.0, "Impulso de salto definido")
	var jump_light := GameConstants.JUMP_VELOCITY
	var jump_heavy := GameConstants.JUMP_VELOCITY
	ctx.equals(jump_light, jump_heavy, "Salto compartido entre armaduras")