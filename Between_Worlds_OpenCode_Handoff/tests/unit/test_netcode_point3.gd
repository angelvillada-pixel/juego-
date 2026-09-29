class_name TestNetcodePoint3
extends RefCounted
## Punto 3: rate-limit, seq/ack+RTT, transporte simulado, rewind,
## interpolación y cheat-log del servidor.


func _server(ctx: Object) -> Node:
	var s: Node = ctx.root.get_node_or_null("Server")
	if s == null:
		s = load("res://src/server/game_server.gd").new()
		ctx.root.call_deferred("add_child", s)
	return s


func run(ctx: Object) -> void:
	# --- RateLimiter puro: ráfaga + refill determinista ---
	var rl := RateLimiter.new(3.0, 2.0)
	ctx.check(rl.consume(1.0, 0.0), "Token 1/3")
	ctx.check(rl.consume(1.0, 0.0), "Token 2/3")
	ctx.check(rl.consume(1.0, 0.0), "Token 3/3")
	ctx.check(not rl.consume(1.0, 0.0), "Bucket vacío rechaza")
	ctx.check(rl.consume(1.0, 1.0), "Tras 1s hay 2 tokens, consume 1")
	ctx.check(rl.consume(1.0, 1.0), "Consume el 2º")
	ctx.check(not rl.consume(1.0, 1.0), "Vacío otra vez")
	ctx.check(rl.consume(1.0, 11.0), "Tras 10s vuelve al tope")

	# --- SimTransport: latencia y pérdida ---
	var sim := SimTransport.new(100.0, 0.0, 42)
	var got := []
	sim.message_received.connect(func(m: Dictionary) -> void: got.append(m))
	sim.send({"type": "fire", "n": 1})
	sim.poll(0.049)
	ctx.check(got.is_empty(), "Con 100ms, a 49ms no hay entrega")
	sim.poll(0.051)
	ctx.equals(got.size(), 1, "A 100ms se entrega")
	ctx.equals(sim.delivered_count, 1, "Contador delivered")
	var lossy := SimTransport.new(0.0, 100.0, 7)
	lossy.send({"type": "fire"})
	lossy.poll(0.016)
	ctx.equals(lossy.dropped_count, 1, "Pérdida 100% dropea")
	ctx.equals(lossy.delivered_count, 0, "Nada entregado con pérdida total")

	# --- Client: sello seq/t + ACK/RTT ---
	var client: Node = ctx.root.get_node_or_null("Client")
	if client == null:
		ctx.check(false, "Autoload Client disponible")
		return
	var probe := LocalTransport.new()
	var seen := []
	probe.message_received.connect(func(m: Dictionary) -> void: seen.append(m))
	client.setup(probe)
	client.reset_stats()
	ctx.check(client.send({"type": "reload", "weapon_index": 0}), "Send con transporte")
	ctx.equals(seen.size(), 1, "Mensaje emitido")
	ctx.equals(int(seen[0].get("seq", 0)), 1, "Primer seq = 1")
	ctx.check(seen[0].has("t"), "Mensaje sellado con t")
	client.send({"type": "reload", "weapon_index": 0})
	ctx.equals(int(seen[1].get("seq", 0)), 2, "Seq incrementa")
	var before_acked: int = client.acked_count
	client.confirm_ack(2)
	ctx.check(client.acked_count > before_acked, "ACK poda el buffer")
	ctx.check(client.ack_rate() > 0.0, "ACK rate > 0")
	client.setup(null)
	client.reset_stats()

	# --- Servidor: rate-limit + strike + kick ---
	var server := _server(ctx)
	var log_before: int = server.cheat_log.size()
	var p1: Player = ctx.spawn_test_player()
	var t1 := LocalTransport.new()
	server.attach_transport(t1, p1)
	for i in range(30):
		t1.send({"type": NetMsg.BUILD_DESTROY, "cell": Vector2i(9, 9), "seq": 100 + i})
	ctx.check(server.cheat_log.size() > log_before, "Flood genera entradas en cheat_log")
	var kinds := []
	for e in server.cheat_log:
		kinds.append(e["kind"])
	ctx.check(kinds.has("rate:" + NetMsg.BUILD_DESTROY), "Strike de rate registrado")
	ctx.check(kinds.has("kick"), "Flood persistente => kick")
	ctx.check(server.session_count() == 0, "Sesión expulsada tras kick")

	# --- Servidor: dirección NaN rechazada sin mutar ---
	var p2: Player = ctx.spawn_test_player()
	var t2 := LocalTransport.new()
	server.attach_transport(t2, p2)
	var mag: int = p2.weapons[0].magazine
	t2.send({"type": NetMsg.FIRE, "weapon_index": 0, "direction": Vector2(NAN, NAN), "seq": 3})
	ctx.equals(p2.weapons[0].magazine, mag, "FIRE NaN no consume munición")

	# --- Servidor: seq queda registrado para el ack ---
	t2.send({"type": NetMsg.MOVE, "axis": 0.0, "jump_edge": false, "crouch": false, "aim": 0.0, "seq": 7})
	ctx.equals(int(server._sessions[t2].get("last_seq", 0)), 7, "last_seq registrado")

	# --- Servidor: snapshot con tick + acks + historial ---
	var p3: Player = ctx.spawn_test_player()
	var t3 := LocalTransport.new()
	server.attach_transport(t3, p3, true)
	var snap_id: int = server._sessions[t3]["id"]
	t3.send({"type": NetMsg.MOVE, "axis": 0.0, "jump_edge": false, "crouch": false, "aim": 0.0, "seq": 11})
	var snaps := []
	t3.message_received.connect(func(m: Dictionary) -> void: snaps.append(m))
	server._broadcast_snapshot()
	var snap: Dictionary = {}
	for m in snaps:
		if str(m.get("type", "")) == NetMsg.SNAPSHOT:
			snap = m
	ctx.check(not snap.is_empty(), "Snapshot emitido")
	ctx.check(snap.has("tick"), "Snapshot lleva tick")
	var acks: Dictionary = snap.get("acks", {})
	ctx.equals(int(acks.get(str(snap_id), 0)), 11, "ACK del último seq")
	ctx.check(server._histories.has(snap_id), "Historial de posición registrado")

	# --- Servidor: validación rewind ---
	server._histories[snap_id] = [[90, 100.0, 100.0], [91, 110.0, 100.0]]
	ctx.check(server.validate_hit_rewind(p3, Vector2(112, 100), 91), "Hit cercano al rewind: plausible")
	var log_mid: int = server.cheat_log.size()
	ctx.check(not server.validate_hit_rewind(p3, Vector2(500, 500), 91), "Hit lejos del rewind: no plausible")
	ctx.check(server.cheat_log.size() > log_mid, "Divergencia rewind queda en log")
	var rw: Variant = server.rewound_position(snap_id, 90)
	ctx.check(rw != null and (rw as Vector2).distance_to(Vector2(100, 100)) < 1.0, "Rewind en tick 90")

	# --- RemotePuppet: interpola, snap si lejos ---
	var puppet := RemotePuppet.new()
	ctx.root.add_child(puppet)
	puppet.apply_state({"p": [0.0, 0.0]})
	puppet.apply_state({"p": [40.0, 0.0]})
	var d0 := puppet.global_position.distance_to(Vector2(40, 0))
	ctx.check(d0 > 0.5, "No teleporta de golpe en rango (interpola)")
	puppet._process(0.05)
	var d1 := puppet.global_position.distance_to(Vector2(40, 0))
	ctx.check(d1 < d0, "Interpolación acerca al objetivo")
	puppet.apply_state({"p": [900.0, 0.0]})
	ctx.check(puppet.global_position.distance_to(Vector2(900, 0)) < 1.0, "Snap duro si deriva > 96px")

	server.clear_sessions()
	puppet.free()
