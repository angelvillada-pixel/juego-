extends SceneTree
## Smoke test manual P1-P2/S3 (NO va en la suite unitaria: necesita un servidor
## dedicado vivo). Uso:
##   godot --headless --path . -s res://src/server/server_main.gd -- --port=26601 --seconds=60 &
##   godot --headless --path . -s res://tests/smoke_join.gd -- --url=ws://127.0.0.1:26601 --callsign=Smoke-1 --password=s3cret!! --timeout=20
## Flujo: REGISTER (o LOGIN si existe) → AUTH_OK → JOIN → WELCOME → MOVE → SNAPSHOT.
## Exit 0 = SNAPSHOT con nuestro id. Exit 1 = fallo.

var _ws: WsTransport
var _url := "ws://127.0.0.1:26601"
var _timeout := 20.0
var _callsign := "Smoke-1"
var _password := "s3cret!!"
var _elapsed := 0.0
var _my_id := -1
var _got_welcome := false
var _done := false
var _seq := 1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--url="):
			_url = a.trim_prefix("--url=")
		if a.begins_with("--timeout="):
			_timeout = float(a.trim_prefix("--timeout="))
		if a.begins_with("--callsign="):
			_callsign = a.trim_prefix("--callsign=")
		if a.begins_with("--password="):
			_password = a.trim_prefix("--password=")
	_ws = WsTransport.new()
	_ws.message_received.connect(_on_msg)
	_ws.connected.connect(_on_connected)
	_ws.disconnected.connect(func() -> void: print("[smoke] desconectado"))
	if not _ws.connect_to_server(_url):
		print("[smoke] FAIL: no se pudo iniciar conexión")
		quit(1)


func _on_connected() -> void:
	print("[smoke] conectado, registrando %s" % _callsign)
	_ws.send({"type": NetMsg.AUTH_REGISTER, "callsign": _callsign, "password": _password})


func _process(delta: float) -> bool:
	if _done:
		return false
	_elapsed += delta
	_ws.poll(delta)
	if _elapsed >= _timeout:
		print("[smoke] FAIL: timeout sin SNAPSHOT válido")
		quit(1)
		return true
	return false


func _on_msg(msg: Dictionary) -> void:
	if _done:
		return
	match str(msg.get("type", "")):
		NetMsg.AUTH_OK:
			print("[smoke] AUTH_OK callsign=%s" % str(msg.get("callsign", "?")))
			_ws.send({"type": NetMsg.JOIN, "token": str(msg.get("token", "")), "callsign": _callsign})
		NetMsg.AUTH_FAIL:
			# Puede existir de un smoke anterior: reintentar como LOGIN.
			if str(msg.get("reason", "")) == "taken":
				print("[smoke] ya existe, probando LOGIN")
				_ws.send({"type": NetMsg.AUTH_LOGIN, "callsign": _callsign, "password": _password})
			else:
				print("[smoke] FAIL: auth %s" % str(msg.get("reason", "?")))
				_done = true
				quit(1)
		NetMsg.WELCOME:
			_my_id = int(msg.get("id", -1))
			var proto := int(msg.get("proto", -1))
			print("[smoke] WELCOME id=%d team=%s proto=%d" % [_my_id, str(msg.get("team", "?")), proto])
			if proto != NetMsg.PROTOCOL_VERSION:
				print("[smoke] FAIL: proto mismatch")
				_done = true
				quit(1)
				return
			_got_welcome = true
			_ws.send({
				"type": NetMsg.MOVE, "axis": 1.0, "jump_edge": false,
				"crouch": false, "aim": 0.0, "ftick": 0,
				"seq": _seq, "t": Time.get_ticks_msec(), "proto": NetMsg.PROTOCOL_VERSION,
			})
			_seq += 1
		NetMsg.SNAPSHOT:
			if not _got_welcome:
				return
			var players: Dictionary = msg.get("players", {})
			var acks: Dictionary = msg.get("acks", {})
			print("[smoke] SNAPSHOT tick=%s jugadores=%d acks=%s" % [str(msg.get("tick", "?")), players.size(), str(acks)])
			if players.has(str(_my_id)):
				print("[smoke] OK: snapshot contiene a id=%d" % _my_id)
				_done = true
				quit(0)


func _finalize() -> void:
	if _ws != null:
		_ws.close()
