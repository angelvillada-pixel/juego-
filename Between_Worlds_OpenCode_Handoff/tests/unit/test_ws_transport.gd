class_name TestWsTransport
extends RefCounted
## WsTransport in-process: cliente y peer de servidor en el mismo SceneTree,
## bombeando manualmente. Verifica handshake, ida y vuelta, y cierre limpio.

const TEST_PORT := 26531


func run(ctx: Object) -> void:
	var listener := TCPServer.new()
	var err := listener.listen(TEST_PORT, "127.0.0.1")
	ctx.check(err == OK, "TCPServer escucha en puerto de test")
	if err != OK:
		return

	var client := WsTransport.new()
	ctx.check(client.connect_to_server("ws://127.0.0.1:%d" % TEST_PORT), "connect_to_server inicia handshake")

	var server_transport: WsTransport = null
	var got_server_msg := []
	var got_client_msg := []
	var connected_flags := []

	# Pump manual hasta 3s para completar handshake y tráfico
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		if listener.is_connection_available():
			var stream := listener.take_connection()
			var ws := WebSocketPeer.new()
			ws.accept_stream(stream)
			server_transport = WsTransport.from_accepted_peer(ws)
			server_transport.message_received.connect(func(m: Dictionary) -> void: got_server_msg.append(m))
			client.message_received.connect(func(m: Dictionary) -> void: got_client_msg.append(m))
			server_transport.connected.connect(func() -> void: connected_flags.append("srv"))
			client.connected.connect(func() -> void: connected_flags.append("cli"))
		client.poll(0.016)
		if server_transport != null:
			server_transport.poll(0.016)
		OS.delay_msec(4)
		if client.is_open() and server_transport != null and server_transport.is_open() and not got_client_msg.is_empty():
			break

	ctx.check(client.is_open(), "Cliente alcanzó STATE_OPEN")
	ctx.check(server_transport != null and server_transport.is_open(), "Peer de servidor STATE_OPEN")
	ctx.check(connected_flags.size() >= 1, "Señal connected emitida")

	if server_transport != null and server_transport.is_open():
		# ida: cliente -> servidor
		client.send({"type": "fire", "weapon_index": 1, "direction": Vector2(1, 0)})
		# vuelta: servidor -> cliente
		server_transport.send({"type": NetMsg.SNAPSHOT, "players": {"7": {"p": [1.0, 2.0]}}})
		var wait_deadline := Time.get_ticks_msec() + 2000
		while Time.get_ticks_msec() < wait_deadline and (got_server_msg.is_empty() or got_client_msg.is_empty()):
			client.poll(0.016)
			server_transport.poll(0.016)
			OS.delay_msec(4)
		ctx.check(not got_server_msg.is_empty(), "Servidor recibió mensaje del cliente")
		if not got_server_msg.is_empty():
			ctx.equals(str(got_server_msg[0].get("type")), "fire", "Payload del cliente correcto")
		ctx.check(not got_client_msg.is_empty(), "Cliente recibió mensaje del servidor")
		if not got_client_msg.is_empty():
			ctx.equals(str(got_client_msg[0].get("type")), "snapshot", "Payload del servidor correcto")

	client.close()
	if server_transport != null:
		server_transport.close()
	listener.stop()
