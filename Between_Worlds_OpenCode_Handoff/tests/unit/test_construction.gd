class_name TestConstruction
extends RefCounted
## Construcción: validez de celdas, ocupación, destrucción y reutilización.


func run(ctx: Object) -> void:
	var grid := Grid.new()
	grid.configure(Rect2i(0, 0, 20, 10))

	# Límites
	ctx.check(grid.in_bounds(Vector2i(5, 5)), "Celda interior en límites")
	ctx.check(not grid.in_bounds(Vector2i(20, 5)), "Celda fuera de límites (x)")
	ctx.check(not grid.in_bounds(Vector2i(-1, 5)), "Celda fuera de límites (negativa)")

	# Permanente bloquea
	grid.register_permanent(Vector2i(3, 3))
	ctx.check(not grid.is_free(Vector2i(3, 3)), "Celda permanente no es libre")
	ctx.check(grid.is_free(Vector2i(4, 3)), "Celda vecina libre")

	# Ocupación por bloque construido
	var block := Block.new()
	block.setup(BlockData.BLOCK_BUILD, Vector2i(5, 5))
	grid.add_block(block, Vector2i(5, 5))
	ctx.check(grid.has_block(Vector2i(5, 5)), "Bloque registrado en la rejilla")
	ctx.check(not grid.is_free(Vector2i(5, 5)), "Celda ocupada no es libre")

	# Destrucción por daño elimina el bloque de la rejilla y libera la celda
	var destroyed := [false]
	grid.block_removed.connect(func(_c: Vector2i) -> void: destroyed[0] = true)
	block.apply_damage(block.max_hp)
	ctx.check(block.hp <= 0.0, "Bloque destruido por daño")
	ctx.check(destroyed[0], "Grid notifica block_removed")
	ctx.check(not grid.has_block(Vector2i(5, 5)), "Celda liberada tras destrucción")
	ctx.check(grid.is_free(Vector2i(5, 5)), "Redil permitido en celda liberada")

	# Bloques de terreno destruible no permanentes se pueden dañar
	var terrain := Block.new()
	terrain.setup(BlockData.BLOCK_DESTRUCTIBLE, Vector2i(7, 7))
	grid.add_block(terrain, Vector2i(7, 7))
	terrain.damage_from_bullet(Vector2.ZERO, 100.0)
	ctx.check(not grid.has_block(Vector2i(7, 7)), "Terreno destruible colapsa con daño")

	# Los bloques permanentes no reciben daño
	var permanent := Block.new()
	permanent.setup(BlockData.BLOCK_DESTRUCTIBLE, Vector2i(9, 9))
	permanent.is_permanent = true
	permanent.apply_damage(9999.0)
	ctx.approx(permanent.hp, permanent.max_hp, 0.001, "El permanente no se daña")

	# Rangos de construcción del controlador (distancias positivas)
	var w2c := grid.world_to_cell(Vector2(5.5 * GameConstants.GRID_SIZE, 5.5 * GameConstants.GRID_SIZE))
	ctx.equals(w2c, Vector2i(5, 5), "world_to_cell redondea correctamente")
	var center := grid.cell_world_center(Vector2i(5, 5))
	ctx.approx(center.x, 88.0, 0.001, "cell_world_center x (5.5*16)")
	ctx.approx(center.y, 88.0, 0.001, "cell_world_center y (5.5*16)")