class_name TestSecurityS1
extends RefCounted
## S1: endurecimiento de entrada del servidor (payloads, replay, protocolo,
## pending cap, limpieza de historiales, idle kick).


func _server(ctx: Object) -> Node:
	var s: Node = ctx.root.get_node_or_null("Server")
	if s == null:
		s = load("res://src/server/game_server.gd").new()
		ctx.root.call_deferred("add_child", s)
	return s


func _kinds(server: Node) -> Array:
	var kinds := []
	for e in server.cheat_log:
		kinds.append(e["kind"])
	return kinds


func run(ctx: Object) -> void:
	var server := _server(ctx)

	# --- Payloads malformados: se rechazan sin crash y con strike ---
	var p1: Player = ctx.spawn_test_player()
	var t1 := LocalTransport.new()
	server.attach_transport(t1, p1)
	var mag: int = p1.weapons[0].magazine
	t1.send({"type": NetMsg.FIRE, "weapon_index": "0", "direction": Vector2.RIGHT})
	t1.send({"type": NetMsg.FIRE, "weapon_index": 0, "direction": "izquierda"})
	t1.send({"type": NetMsg.BUILD_PLACE, "cell": "5,5"})
	t1.send({"type": NetMsg.UTILITY, "direction": [1, 0]})
	ctx.equals(p1.weapons[0].magazine, mag, "Payloads malformados no consumen munición")
	ctx.check(_kinds(server).has("bad_payload:fire"), "Strike bad_payload:fire")
	ctx.check(_kinds(server).has("bad_payload:build"), "Strike bad_payload:build")
	ctx.check(_kinds(server).has("bad_payload:utility"), "Strike bad_payload:utility")

	# --- PICKUP_CLAIM: paths hostiles rechazados ---
	var log_before: int = server.cheat_log.size()
	t1.send({"type": NetMsg.PICKUP_CLAIM, "path": "../../secret"})
	t1.send({"type": NetMsg.PICKUP_CLAIM, "path": "a".repeat(200)})
	t1.send({"type": NetMsg.PICKUP_CLAIM, "path": "pickup con espacios!"})
	ctx.check(server.cheat_log.size() == log_before + 3, "3 paths hostiles => 3 strikes")
	ctx.check(_kinds(server).has("bad_payload:pickup"), "Strike bad_payload:pickup")

	# --- Replay: seq duplicado o decreciente se dropea ---
	var p2: Player = ctx.spawn_test_player()
	var t2 := LocalTransport.new()
	server.attach_transport(t2, p2)
	var replay_before: int = server.cheat_log.size()
	t2.send({"type": NetMsg.BUILD_DESTROY, "cell": Vector2i(1, 1), "seq": 50})
	t2.send({"type": NetMsg.BUILD_DESTROY, "cell": Vector2i(1, 1), "seq": 50})
	t2.send({"type": NetMsg.BUILD_DESTROY, "cell": Vector2i(1, 1), "seq": 40})
	ctx.check(server.cheat_log.size() == replay_before + 2, "Replay x2 => 2 strikes")
	ctx.check(_kinds(server).has("replay"), "Strike replay registrado")

	# --- Reloj cliente: t que retrocede más allá de la holgura se dropea ---
	var now_ms := Time.get_ticks_msec()
	t2.send({"type": NetMsg.BUILD_DESTROY, "cell": Vector2i(1, 1), "seq": 51, "t": now_ms})
	var time_before: int = server.cheat_log.size()
	t2.send({"type": NetMsg.BUILD_DESTROY, "cell": Vector2i(1, 1), "seq": 52, "t": now_ms - 5000})
	ctx.check(server.cheat_log.size() == time_before + 1, "Reloj retrocedido => strike")
	ctx.check(_kinds(server).has("replay_time"), "Strike replay_time registrado")

	# --- Protocolo: sesiones de red exigen versión exacta ---
	var p3: Player = ctx.spawn_test_player()
	var t3 := LocalTransport.new()
	server.attach_transport(t3, p3, true)
	var count_before: int = server.session_count()
	t3.send({"type": NetMsg.BUILD_DESTROY, "cell": Vector2i(1, 1)})
	ctx.check(server.session_count() == count_before - 1, "Net sin proto => sesión dropeada")
	ctx.check(_kinds(server).has("proto"), "Strike proto registrado")
	var p4: Player = ctx.spawn_test_player()
	var t4 := LocalTransport.new()
	server.attach_transport(t4, p4, true)
	t4.send({"type": NetMsg.BUILD_DESTROY, "cell": Vector2i(1, 1), "proto": NetMsg.PROTOCOL_VERSION, "seq": 1})
	ctx.check(server._sessions.has(t4), "Net con proto válido sobrevive")
	# Loopback local sigue siendo tolerante (sin proto).
	var p5: Player = ctx.spawn_test_player()
	var t5 := LocalTransport.new()
	server.attach_transport(t5, p5, false)
	t5.send({"type": NetMsg.BUILD_DESTROY, "cell": Vector2i(1, 1)})
	ctx.check(server._sessions.has(t5), "Loopback sin proto sobrevive")

	# --- WELCOME lleva la versión de protocolo ---
	var welcome: Dictionary = server._welcome_msg(7, p5)
	ctx.equals(int(welcome.get("proto", -1)), NetMsg.PROTOCOL_VERSION, "WELCOME anuncia proto")

	# --- Pending cap + timeout (estático, sin sockets reales) ---
	var peers: Array = []
	for i in range(20):
		peers.append({"ws": WebSocketPeer.new(), "t": 100.0})
	peers.append({"ws": WebSocketPeer.new(), "t": 0.0})  # caducado
	var pruned: Array = server.prune_pending(peers, 100.0)
	ctx.check(pruned.size() <= 16, "Pending capado a 16 (got %d)" % pruned.size())
	ctx.equals(pruned.size(), 16, "Solo frescos dentro del cap")

	# --- Idle kick: net muda 5 min => fuera ---
	var p6: Player = ctx.spawn_test_player()
	var t6 := LocalTransport.new()
	server.attach_transport(t6, p6, true)
	server._sessions[t6]["last_input_t"] = server._now_sec() - 400.0
	server._sessions[t6]["last_pos_t"] = server._now_sec()
	var idle_before: int = server.session_count()
	server._poll_sessions(0.0)
	ctx.check(server.session_count() == idle_before - 1, "Sesión idle expulsada")
	ctx.check(_kinds(server).has("idle"), "Strike idle registrado")

	# --- Historiales: no sobreviven a la sesión ---
	var sid: int = server._sessions[t4]["id"]
	server._histories[sid] = [[1, 0.0, 0.0]]
	server._drop_session(t4)
	ctx.check(not server._histories.has(sid), "Historial borrado con la sesión")

	server.clear_sessions()
	ctx.check(server._histories.is_empty(), "clear_sessions vacía historiales")
