class_name TestMovement
extends RefCounted
## Punto 1 / Q1: constantes de movimiento congeladas (provisionales validadas).
## Velocidades Light/Medium/Heavy, salto compartido, crouch, acel/ficción, grid.


func run(ctx: Object) -> void:
	# Velocidades por armadura sobre BASE_RUN_SPEED 240.
	ctx.approx(GameConstants.BASE_RUN_SPEED, 240.0, 0.001, "Base run speed 240")
	ctx.approx(ArmorData.movement_speed(ArmorData.ARMOR_LIGHT), 264.0, 0.001, "Light 264")
	ctx.approx(ArmorData.movement_speed(ArmorData.ARMOR_MEDIUM), 240.0, 0.001, "Medium 240")
	ctx.approx(ArmorData.movement_speed(ArmorData.ARMOR_HEAVY), 216.0, 0.001, "Heavy 216")

	# Salto compartido y gravedad/física sanas.
	ctx.check(GameConstants.JUMP_VELOCITY < 0.0, "Salto negativo (hacia arriba)")
	ctx.check(GameConstants.GROUND_ACCEL > 0.0, "Acel suelo > 0")
	ctx.check(GameConstants.AIR_ACCEL > 0.0, "Acel aire > 0")
	ctx.check(GameConstants.GROUND_FRICTION > 0.0, "Fricción > 0")
	ctx.check(GameConstants.MAX_FALL_SPEED > 0.0, "Caída máxima > 0")

	# Crouch: dimensiones y factor.
	ctx.approx(GameConstants.CROUCH_SPEED_FACTOR, 0.6, 0.001, "Crouch 0.6x velocidad")
	var p: Player = ctx.spawn_test_player()
	ctx.equals(p.body_height_stand, 24.0, "Altura de pie 24")
	ctx.equals(p.body_height_crouch, 14.0, "Altura crouch 14")
	# Head/body zones existen y no se solapan en vacío.
	var head := p.head_rect()
	var body := p.body_rect()
	ctx.check(head.size.y <= 8.0, "Cabeza <= 8px")
	ctx.check(body.size.y >= head.size.y, "Cuerpo contiene cabeza")

	# Grid baseline 16px (Q8 sigue abierto, pero el slice congela 16).
	ctx.equals(GameConstants.GRID_SIZE, 16, "Grid 16px baseline")
	ctx.equals(GameConstants.BUILD_RANGE_PX, 64, "Rango construcción 4*16=64")
