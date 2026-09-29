class_name TestUtility
extends RefCounted
## Punto 1 / Q5: utilidad Dash data-driven, con cooldown 8s e impulso,
## validada por el servidor (no por el cliente).


func _server(ctx: Object) -> Node:
	var s: Node = ctx.root.get_node_or_null("Server")
	if s == null:
		s = load("res://src/server/game_server.gd").new()
		ctx.root.call_deferred("add_child", s)
	return s


func run(ctx: Object) -> void:
	var server := _server(ctx)
	# Datos congelados provisionales.
	ctx.approx(UtilityData.cooldown_seconds(UtilityData.UTILITY_DASH), 8.0, 0.001, "Dash cooldown 8s")
	ctx.approx(UtilityData.impulse(UtilityData.UTILITY_DASH), 380.0, 0.001, "Dash impulso 380")

	var player: Player = ctx.spawn_test_player()
	ctx.check(player.can_use_utility(), "Dash disponible al inicio")

	# Uso permitido: aplica impulso y arranca cooldown.
	ctx.check(server.request_utility(player, Vector2.RIGHT), "Dash permitido por servidor")
	ctx.check(not player.can_use_utility(), "Dash en cooldown tras uso")
	ctx.approx(absf(player.velocity.x), 380.0, 1.0, "Impulso horizontal aplicado")

	# Segundo uso inmediato denegado (cooldown).
	var vx := player.velocity.x
	ctx.check(not server.request_utility(player, Vector2.RIGHT), "Dash en cooldown denegado")
	ctx.approx(player.velocity.x, vx, 0.001, "Sin cambio tras intento denegado")

	# Dirección cero denegada.
	player.utility_cooldown_left = 0.0
	ctx.check(not server.request_utility(player, Vector2.ZERO), "Dirección cero denegada")

	# En respawn denegado.
	player.utility_cooldown_left = 0.0
	player.respawning = true
	ctx.check(not server.request_utility(player, Vector2.RIGHT), "Sin dash durante respawn")
	player.respawning = false

	# Respawn restaura cooldown.
	player.utility_cooldown_left = 5.0
	player.reset_for_respawn(player.global_position)
	ctx.approx(player.utility_cooldown_left, 0.0, 0.001, "Respawn limpia cooldown utilidad")

	# Contrato de red: UTILITY es intent válido.
	ctx.check(NetMsg.is_intent(NetMsg.UTILITY), "UTILITY registrado como intent")
