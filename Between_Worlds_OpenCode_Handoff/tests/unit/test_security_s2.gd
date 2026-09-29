class_name TestSecurityS2
extends RefCounted
## S2: TLS delante (Caddy), bind localhost por defecto, budget de aceptadas
## y URLs wss:// en el cliente.


func _server(ctx: Object) -> Node:
	var s: Node = ctx.root.get_node_or_null("Server")
	if s == null:
		s = load("res://src/server/game_server.gd").new()
		ctx.root.call_deferred("add_child", s)
	return s


func run(ctx: Object) -> void:
	# --- URLs: normalización y detección de cifrado ---
	ctx.equals(WsTransport.normalize_url("example.com:26500"), "ws://example.com:26500", "Host pelado -> ws://")
	ctx.equals(WsTransport.normalize_url("ws://example.com:26500"), "ws://example.com:26500", "ws:// se respeta")
	ctx.equals(WsTransport.normalize_url("wss://juego.example.com"), "wss://juego.example.com", "wss:// se respeta")
	ctx.equals(WsTransport.normalize_url("  wss://juego.example.com  "), "wss://juego.example.com", "Espacios recortados")
	ctx.check(not WsTransport.is_secure("ws://127.0.0.1:26500"), "ws:// no es seguro")
	ctx.check(not WsTransport.is_secure("127.0.0.1:26500"), "Sin esquema no es seguro")
	ctx.check(WsTransport.is_secure("wss://juego.example.com"), "wss:// es seguro")

	# --- Listener: bindea donde se le dice y se detiene limpio ---
	var server := _server(ctx)
	ctx.check(server.start_listener(26599, "127.0.0.1"), "Listener en 127.0.0.1:26599")
	ctx.check(server.is_dedicated_server, "Flag dedicado activo")
	server.stop_listener()
	ctx.check(not server.is_dedicated_server, "Flag dedicado apagado tras stop")

	# --- Budget de aceptadas: ráfaga 10, la 11ª se niega ---
	var now := 1000.0
	var allowed := 0
	for i in range(11):
		if server._accept_limiter.consume(1.0, now):
			allowed += 1
	ctx.equals(allowed, 10, "Ráfaga de aceptadas topada a 10")
	ctx.check(server._accept_limiter.consume(1.0, now + 1.0), "Tras 1s hay tokens de nuevo")
