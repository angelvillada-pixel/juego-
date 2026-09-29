class_name TestAuthS3
extends RefCounted
## S3: cuentas completas (PBKDF2, tokens, callsign único, lockout, JOIN).


func _server(ctx: Object) -> Node:
	var s: Node = ctx.root.get_node_or_null("Server")
	if s == null:
		s = load("res://src/server/game_server.gd").new()
		ctx.root.call_deferred("add_child", s)
	return s


func _hex(bytes: Array) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(bytes.size())
	for i in range(bytes.size()):
		b[i] = bytes[i]
	return b


func run(ctx: Object) -> void:
	# --- HMAC-SHA256 contra vector RFC 4231 (caso 1) ---
	var key20 := _hex([11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11])
	var mac := AuthService.hmac_sha256(key20, "Hi There".to_utf8_buffer())
	ctx.equals(mac.hex_encode(), "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7", "HMAC-SHA256 (openssl)")
	ctx.equals(key20.size(), 20, "HMAC no muta la clave del llamante")

	# --- PBKDF2-HMAC-SHA256 contra openssl (c=1) ---
	var dk := AuthService.pbkdf2_sha256("password".to_utf8_buffer(), "salt".to_utf8_buffer(), 1)
	ctx.equals(dk.hex_encode(), "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b", "PBKDF2 c=1 (openssl)")
	var dk2 := AuthService.pbkdf2_sha256("password".to_utf8_buffer(), "salt".to_utf8_buffer(), 2)
	ctx.check(dk2.hex_encode() != dk.hex_encode(), "Más iteraciones => otro hash")

	# --- Callsigns ---
	ctx.check(AuthService.valid_callsign("Hero-1_X"), "Callsign válido")
	ctx.check(not AuthService.valid_callsign("ab"), "Muy corto")
	ctx.check(not AuthService.valid_callsign("0123456789ABCDEFGHIJ"), "Muy largo")
	ctx.check(not AuthService.valid_callsign("hola mundo!"), "Caracteres inválidos")
	ctx.equals(AuthService.callsign_key("  HeRo-1 "), "hero-1", "Clave case-insensitive")

	# --- Servidor con rutas temporales ---
	var server := _server(ctx)
	server._users_path = "user://test_auth_users.jsonl"
	server._secret_path = "user://test_server_secret"
	server._users.clear()
	server._tokens.clear()
	server._failed.clear()
	server.__auth_secret_cache = PackedByteArray()
	if FileAccess.file_exists("user://test_auth_users.jsonl"):
		DirAccess.remove_absolute("user://test_auth_users.jsonl")
	if FileAccess.file_exists("user://test_server_secret"):
		DirAccess.remove_absolute("user://test_server_secret")

	var world := Node2D.new()
	ctx.root.add_child(world)
	server.register_world(world)

	# --- REGISTER crea cuenta y emite token ---
	var t := LocalTransport.new()
	server._pending_auth[t] = {"t": 0.0, "rl": RateLimiter.new(50.0, 50.0), "callback": Callable(), "fails": 0}
	var got := []
	t.message_received.connect(func(m: Dictionary) -> void: got.append(m))
	server._on_pre_auth_message({"type": NetMsg.AUTH_REGISTER, "callsign": "Hero-1", "password": "s3cret!!"}, t)
	ctx.equals(got.size(), 1, "REGISTER responde")
	ctx.equals(str(got[0].get("type", "")), NetMsg.AUTH_OK, "REGISTER => AUTH_OK")
	var token := str(got[0].get("token", ""))
	ctx.check(token.split(".").size() == 3, "Token con 3 partes")
	ctx.check(server._users.has("hero-1"), "Usuario persistido en memoria")

	# --- Duplicado (otro case) rechazado sin re-hash ---
	got.clear()
	server._on_pre_auth_message({"type": NetMsg.AUTH_REGISTER, "callsign": "HERO-1", "password": "otra...."}, t)
	ctx.equals(str(got[0].get("reason", "")), "taken", "Duplicado => taken")

	# --- Nombre malo y password débil ---
	got.clear()
	server._on_pre_auth_message({"type": NetMsg.AUTH_REGISTER, "callsign": "no", "password": "s3cret!!"}, t)
	ctx.equals(str(got[0].get("reason", "")), "bad_name", "Nombre corto => bad_name")
	server._on_pre_auth_message({"type": NetMsg.AUTH_REGISTER, "callsign": "Nuevo-2", "password": "corta"}, t)
	ctx.equals(str(got[1].get("reason", "")), "weak_password", "Password corta => weak_password")

	# --- LOGIN bueno/malo + lockout ---
	got.clear()
	server._on_pre_auth_message({"type": NetMsg.AUTH_LOGIN, "callsign": "Hero-1", "password": "mal....."}, t)
	ctx.equals(str(got[0].get("reason", "")), "bad_credentials", "Password mal => bad_credentials")
	server._failed["hero-1"] = {"n": 5, "until": server._now_unix() + 900}
	got.clear()
	server._on_pre_auth_message({"type": NetMsg.AUTH_LOGIN, "callsign": "Hero-1", "password": "s3cret!!"}, t)
	ctx.equals(str(got[0].get("reason", "")), "locked", "Bloqueado tras 5 fallos")
	server._failed.erase("hero-1")
	got.clear()
	server._on_pre_auth_message({"type": NetMsg.AUTH_LOGIN, "callsign": "Hero-1", "password": "s3cret!!"}, t)
	ctx.equals(str(got[0].get("type", "")), NetMsg.AUTH_OK, "LOGIN bueno => AUTH_OK")
	var token2 := str(got[0].get("token", ""))

	# --- JOIN con token válido spawnea y da WELCOME ---
	got.clear()
	server._on_pre_auth_message({"type": NetMsg.JOIN, "token": token2, "callsign": "Hero-1"}, t)
	var welcome: Dictionary = {}
	for m in got:
		if str(m.get("type", "")) == NetMsg.WELCOME:
			welcome = m
	ctx.check(not welcome.is_empty(), "JOIN válido => WELCOME")
	ctx.equals(int(welcome.get("proto", -1)), NetMsg.PROTOCOL_VERSION, "WELCOME con proto")
	ctx.check(server._sessions.has(t), "Sesión creada tras JOIN")
	ctx.check(not server._pending_auth.has(t), "Pendiente consumido")

	# --- JOIN con token malo/expirado ---
	var t2 := LocalTransport.new()
	server._pending_auth[t2] = {"t": 0.0, "rl": RateLimiter.new(50.0, 50.0), "callback": Callable(), "fails": 0}
	var got2 := []
	t2.message_received.connect(func(m: Dictionary) -> void: got2.append(m))
	server._on_pre_auth_message({"type": NetMsg.JOIN, "token": "x.y.z", "callsign": "Hero-1"}, t2)
	ctx.equals(str(got2[0].get("reason", "")), "bad_token", "Token inventado => bad_token")
	var expired: String = AuthService.make_token(server._auth_secret(), "Hero-1", server._now_unix() - 10)
	server._tokens[expired] = {"callsign": "Hero-1", "exp": 0}
	server._on_pre_auth_message({"type": NetMsg.JOIN, "token": expired, "callsign": "Hero-1"}, t2)
	ctx.equals(str(got2[1].get("reason", "")), "bad_token", "Token expirado => bad_token")
	ctx.check(not server._sessions.has(t2), "Sin sesión con token malo")

	# --- Token manipulado ---
	var parts := token2.split(".")
	var forged: String = parts[0] + "." + parts[1] + "deadbeef"
	server._tokens[forged] = {"callsign": "Hero-1", "exp": 9999999999}
	server._on_pre_auth_message({"type": NetMsg.JOIN, "token": forged, "callsign": "Hero-1"}, t2)
	ctx.equals(str(got2[2].get("reason", "")), "bad_token", "Token forjado => bad_token")

	# --- Persistencia: recarga y login funciona ---
	server._auth_save()
	server._users.clear()
	server._auth_load()
	ctx.check(server._users.has("hero-1"), "Usuarios recargados del fichero")
	var rec: Dictionary = server._users["hero-1"]
	ctx.check(AuthService.verify_password("s3cret!!", rec), "Password verifica tras recarga")
	ctx.check(not AuthService.verify_password("otra....", rec), "Password ajena no verifica")

	# --- Basura pre-auth se ignora sin sesión ---
	var t3 := LocalTransport.new()
	server._pending_auth[t3] = {"t": 0.0, "rl": RateLimiter.new(50.0, 50.0), "callback": Callable(), "fails": 0}
	server._on_pre_auth_message({"type": NetMsg.FIRE, "weapon_index": 0}, t3)
	ctx.check(not server._sessions.has(t3), "Intent de juego pre-auth no crea sesión")

	server.clear_sessions()
	server.unregister_world()
	world.queue_free()
	if FileAccess.file_exists("user://test_auth_users.jsonl"):
		DirAccess.remove_absolute("user://test_auth_users.jsonl")
	if FileAccess.file_exists("user://test_server_secret"):
		DirAccess.remove_absolute("user://test_server_secret")
	server._users_path = "user://auth_users.jsonl"
	server._secret_path = "user://server_secret"
	server.__auth_secret_cache = PackedByteArray()
	server._users.clear()
	server._tokens.clear()
	server._failed.clear()
