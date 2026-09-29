class_name TestServer
extends RefCounted
## Autoridad (Etapa 1): toda acción competitiva pasa por el autoload Server.
## Valida permitir/denegar: fuego, recarga, pickups (tope y distancia),
## construcción (rango, ocupación, permanente, equipos) y caída del mundo.


func _server(ctx: Object) -> Node:
	var s: Node = ctx.root.get_node_or_null("Server")
	if s == null:
		s = load("res://src/server/game_server.gd").new()
		ctx.root.call_deferred("add_child", s)
	return s


func run(ctx: Object) -> void:
	var server := _server(ctx)
	ctx.check(server != null, "Autoload Server disponible")

	# ---------------- Fuego: permitido y denegado por cooldown ----------------
	var player: Player = ctx.spawn_test_player()
	var rifle: Weapon = player.weapons[0]
	ctx.equals(rifle.magazine, 30, "Cargador inicial 30")
	var res: Dictionary = server.request_fire(player, rifle, player.global_position, Vector2.RIGHT)
	ctx.check(not res.is_empty(), "Disparo permitido resuelto (sin colisión => hit=false)")
	ctx.equals(rifle.magazine, 29, "Munición decrementada por el servidor")
	var denied: Dictionary = server.request_fire(player, rifle, player.global_position, Vector2.RIGHT)
	ctx.check(denied.is_empty(), "Segundo disparo inmediato DENEGADO (cooldown)")
	ctx.equals(rifle.magazine, 29, "Disparo denegado no consume munición")

	# El servidor no dispara por un jugador en respawn
	player.respawning = true
	ctx.check(server.request_fire(player, rifle, player.global_position, Vector2.RIGHT).is_empty(), "Sin fuego durante respawn")
	player.respawning = false

	# ---------------- Recarga ----------------
	rifle.magazine = 5
	ctx.check(server.request_reload(player, rifle), "Recarga permitida")
	ctx.check(rifle.is_reloading(), "Arma en estado recargando")
	player.respawning = true
	ctx.check(not server.request_reload(player, rifle), "Sin recarga durante respawn")
	player.respawning = false

	# ---------------- Pickups: aplicación, tope y distancia ----------------
	player.hp = 50.0
	var pk: Pickup = Pickup.new()
	pk.setup(PickupData.PICKUP_HEALTH)
	pk.global_position = player.global_position
	ctx.check(server.request_pickup(player, pk), "Pickup de salud aceptado")
	ctx.approx(player.hp, 80.0, 0.001, "Salud 50 + 30% de 100 = 80")
	ctx.check(pk.is_queued_for_deletion(), "Pickup consumido se libera")

	# Tope: nunca supera el máximo
	player.hp = 95.0
	var pk2: Pickup = Pickup.new()
	pk2.setup(PickupData.PICKUP_HEALTH)
	pk2.global_position = player.global_position
	server.request_pickup(player, pk2)
	ctx.approx(player.hp, 100.0, 0.001, "Pickup nunca supera MAX_HP (95+30 -> 100)")

	# Distancia: pickup lejano se rechaza
	var pk3: Pickup = Pickup.new()
	pk3.setup(PickupData.PICKUP_HEALTH)
	pk3.global_position = player.global_position + Vector2(500, 0)
	ctx.check(not server.request_pickup(player, pk3), "Pickup fuera de rango rechazado")
	ctx.check(not pk3.is_queued_for_deletion(), "Pickup rechazado no se consume")
	pk3.free()

	# Shield vía Server (Punto 1: máx 50, 30% = 15)
	var pk4: Pickup = Pickup.new()
	pk4.setup(PickupData.PICKUP_ARMOR)
	pk4.global_position = player.global_position
	server.request_pickup(player, pk4)
	ctx.approx(player.shield, 15.0, 0.001, "Shield 0 + 30% de 50 = 15")

	# ---------------- Construcción: rango, ocupación, equipos, permanentes ----------------
	var container := Node2D.new()
	ctx.root.add_child(container)
	server.register_world(container)
	var grid := Grid.new()
	grid.configure(Rect2i(0, 0, 40, 20))
	container.add_child(grid)

	var cell := Vector2i(5, 5)
	var origin := grid.cell_world_center(cell)
	var placed: Block = server.request_build_place(grid, cell, 0, origin)
	ctx.check(placed != null, "Construir en celda libre y en rango: permitido")
	ctx.check(grid.has_block(cell), "Bloque registrado en la rejilla")
	ctx.check(placed.get_parent() == container, "Bloque construido cuelga del mundo del servidor")

	ctx.check(server.request_build_place(grid, cell, 0, origin) == null, "Celda ocupada: rechazado")
	var far_cell := Vector2i(20, 15)
	ctx.check(server.request_build_place(grid, far_cell, 0, Vector2.ZERO) == null, "Fuera de rango: rechazado")

	# Equipos: un equipo no puede borrar el bloque de otro (salvo objetivos)
	ctx.check(not server.request_build_destroy(grid, cell, 1, origin), "Equipo rival NO destruye bloque ajeno")
	ctx.check(grid.has_block(cell), "Bloque ajeno sigue en pie")
	ctx.check(server.request_build_destroy(grid, cell, 0, origin), "Equipo propio destruye su bloque")
	ctx.check(not grid.has_block(cell), "Celda liberada tras destrucción autoritativa")

	# Permanente: indestructible
	var pcell := Vector2i(8, 8)
	var perm: Block = Block.new()
	perm.setup(BlockData.BLOCK_DESTRUCTIBLE, pcell)
	perm.is_permanent = true
	grid.add_block(perm, pcell)
	ctx.check(not server.request_build_destroy(grid, pcell, 0, grid.cell_world_center(pcell)), "Permanente no se destruye")
	ctx.approx(perm.hp, perm.max_hp, 0.001, "Permanente no pierde HP")

	# Objetivo: cualquier equipo puede destruirlo
	var tcell := Vector2i(10, 10)
	var tgt: Block = Block.new()
	tgt.setup(BlockData.BLOCK_TARGET, tcell, 5)
	grid.add_block(tgt, tcell)
	ctx.check(server.request_build_destroy(grid, tcell, 0, grid.cell_world_center(tcell)), "Objetivo destruible por cualquier equipo")

	server.unregister_world()
	ctx.check(server.world == null, "Mundo desregistrado al salir")

	# ---------------- Caída fuera del mundo ----------------
	ctx.check(server.request_fall_out(player), "Caída fuera del mundo mata al jugador")
	ctx.check(player.respawning, "Jugador en respawn tras caída")
	ctx.check(not server.request_fall_out(player), "Segunda caída durante respawn ignorada")
