class_name TestNetLoopback
extends RefCounted
## Etapa 2: el cliente habla con el servidor SÓLO mediante mensajes por un
## NetTransport (LocalTransport). A prueba: ninguna intención toca el estado
## sin pasar por el despachador del Server, y el contrato de mensajes es estable.


func run(ctx: Object) -> void:
	# --- Contrato de mensajes: el wire payload contiene solo datos primitivos ---
	ctx.check(NetMsg.is_valid_type(NetMsg.FIRE), "FIRE es un tipo válido")
	ctx.check(not NetMsg.is_valid_type("hack"), "Tipo desconocido es rechazado")
	ctx.check(not NetMsg.is_valid_type(42), "Tipo no-string es rechazado")

	var server: Node = ctx.root.get_node_or_null("Server")
	var client: Node = ctx.root.get_node_or_null("Client")
	ctx.check(server != null and client != null, "Autoloads Server y Client disponibles")
	if server == null or client == null:
		return

	var player: Player = ctx.spawn_test_player()
	var transport := LocalTransport.new()

	# Sin transporte configurado, el cliente no envía nada
	ctx.check(not client.has_transport(), "Client desconectado sin setup")
	ctx.check(not client.send({"type": NetMsg.FIRE}), "Send sin transporte devuelve false")

	client.setup(transport)
	ctx.check(client.has_transport(), "Client conectado tras setup")
	ctx.check(server.session_count() == 0, "Sin sesiones antes de attach")
	ctx.check(server.attach_transport(transport, player), "Sesión LocalTransport <-> jugador")
	ctx.check(server.session_count() == 1, "Una sesión registrada")

	# --- Fuego por mensaje: el servidor calcula muzzle y valida cooldown ---
	var rifle: Weapon = player.weapons[0]
	ctx.check(client.send({"type": NetMsg.FIRE, "weapon_index": 0, "direction": Vector2.RIGHT}), "Intent FIRE enviado")
	ctx.equals(rifle.magazine, 29, "El servidor consumió la bala del mensaje")
	client.send({"type": NetMsg.FIRE, "weapon_index": 0, "direction": Vector2.RIGHT})
	ctx.equals(rifle.magazine, 29, "Cooldown del servidor rechaza el segundo disparo")

	# Índice de arma fuera de rango: no explota, no muta
	client.send({"type": NetMsg.FIRE, "weapon_index": 99, "direction": Vector2.RIGHT})
	ctx.equals(rifle.magazine, 29, "weapon_index inválido ignorado")
	# Dirección cero o con módulo >1: el servidor la normaliza o la desecha
	client.send({"type": NetMsg.FIRE, "weapon_index": 0, "direction": Vector2.ZERO})
	ctx.equals(rifle.magazine, 29, "direction cero desechada")

	# --- Recarga por mensaje ---
	rifle.magazine = 5
	ctx.check(client.send({"type": NetMsg.RELOAD, "weapon_index": 0}), "Intent RELOAD enviado")
	ctx.check(rifle.is_reloading(), "El servidor inició la recarga")

	# --- Mensaje malicioso/desconocido: el estado no cambia ---
	var hp_before: float = player.hp
	client.send({"type": "spawn_nuke", "damage": 999999})
	ctx.approx(player.hp, hp_before, 0.001, "Mensaje desconocido no muta estado")

	# --- Construcción por mensaje ---
	var container := Node2D.new()
	ctx.root.add_child(container)
	var grid := Grid.new()
	grid.configure(Rect2i(0, 0, 40, 20))
	container.add_child(grid)
	server.register_world(container, grid)

	player.global_position = Vector2(88, 88)
	client.send({"type": NetMsg.BUILD_PLACE, "cell": Vector2i(5, 5)})
	ctx.check(grid.has_block(Vector2i(5, 5)), "BUILD_PLACE coloca bloque vía servidor")
	client.send({"type": NetMsg.BUILD_PLACE, "cell": Vector2i(30, 15)})
	ctx.check(not grid.has_block(Vector2i(30, 15)), "BUILD_PLACE lejano rechazado (origen = posición de sesión)")
	client.send({"type": NetMsg.BUILD_DESTROY, "cell": Vector2i(5, 5)})
	ctx.check(not grid.has_block(Vector2i(5, 5)), "BUILD_DESTROY elimina el bloque propio")

	# --- Pickup por mensaje (path relativa al mundo registrado) ---
	player.hp = 50.0
	var pk := Pickup.new()
	pk.setup(PickupData.PICKUP_HEALTH)
	container.add_child(pk)
	pk.global_position = player.global_position
	var rel := str(container.get_path_to(pk))
	client.send({"type": NetMsg.PICKUP_CLAIM, "path": rel})
	ctx.approx(player.hp, 80.0, 0.001, "PICKUP_CLAIM aplica el efecto vía servidor")

	# Path maliciosa a un nodo que no es Pickup
	var fake := Node2D.new()
	fake.name = "NotAPickup"
	container.add_child(fake)
	player.hp = 50.0
	client.send({"type": NetMsg.PICKUP_CLAIM, "path": str(container.get_path_to(fake))})
	ctx.approx(player.hp, 50.0, 0.001, "Path a no-Pickup ignorada")

	# --- Caída por mensaje ---
	client.send({"type": NetMsg.FALL_OUT})
	ctx.check(player.respawning, "FALL_OUT mata al jugador vía servidor")
	client.send({"type": NetMsg.FALL_OUT})
	ctx.check(player.respawning, "FALL_OUT duplicado ignorado (sigue en respawn)")

	# --- Cierre de sesión ---
	server.clear_sessions()
	ctx.check(server.session_count() == 0, "clear_sessions libera los transportes")
	client.setup(null)
	ctx.check(not client.has_transport(), "Client queda desconectado en teardown")
	server.unregister_world()
