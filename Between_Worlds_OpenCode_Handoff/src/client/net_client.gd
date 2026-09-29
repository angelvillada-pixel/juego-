class_name NetClientDriver
extends Node
## Modo cliente de red (Etapa 3): conecta por WebSocket al servidor dedicado,
## envía intenciones (MOVE a 60 Hz + acciones) y aplica eventos/snapshots al
## mundo local: el jugador propio se corrige suavemente hacia la posición
## autoritativa y los jugadores remotos se pintan como RemotePuppet.
##
## El cliente conserva una SIMULACIÓN LOCAL del movimiento (para feeling) y el
## servidor corrige por deriva. Reconciliación formal es Etapa 4.

const RECONCILE_SNAP_DISTANCE := 96.0  # snap duro si difiere más de esto (px)
const MOVE_SEND_HZ := 30.0

var player: Player = null
var test_map: TestMap = null
var match_ref: Node = null

var my_id := -1
var my_team := 0
var last_server_tick := 0  # Punto 3: último tick visto (se reenvía como ftick)
var _move_accum := 0.0
var _remote_puppets: Dictionary = {}   # id -> RemotePuppet
var _applied_api_url := ""
# S3: credenciales para el login (las pone main.gd desde el menú).
var auth_callsign := ""
var auth_password := ""
var auth_register := false
signal auth_failed(reason: String)


func setup(p_player: Player, p_map: TestMap, p_match: Node, p_callsign: String = "", p_password: String = "", p_register: bool = false) -> void:
	player = p_player
	test_map = p_map
	match_ref = p_match
	auth_callsign = p_callsign
	auth_password = p_password
	auth_register = p_register


func connect_to(url: String) -> void:
	var ws := WsTransport.new()
	Client.setup(ws)
	ws.message_received.connect(_on_server_message)
	ws.connected.connect(_on_ws_connected.bind(url))
	ws.disconnected.connect(_on_disconnected)
	_applied_api_url = url
	# S2: en web el navegador bloquea ws:// mixto; avisar antes del error críptico.
	if OS.has_feature("web") and not WsTransport.is_secure(url):
		push_error("NetClient: en web usa wss:// (el navegador bloquea ws:// sin cifrar)")
		return
	if not ws.connect_to_server(url):
		push_error("NetClient: no se pudo iniciar conexión %s" % url)


# S3: al conectar se intenta JOIN con el token guardado; si no hay,
# REGISTER/LOGIN con las credenciales del menú y JOIN al recibir AUTH_OK.
func _on_ws_connected(url: String) -> void:
	print("[NetClient] conectado a %s" % url)
	var saved: String = Backend.auth_token
	if saved != "":
		Client.send({"type": NetMsg.JOIN, "token": saved, "callsign": auth_callsign})
	elif auth_callsign != "":
		if auth_register:
			Client.send({"type": NetMsg.AUTH_REGISTER, "callsign": auth_callsign, "password": auth_password})
		else:
			Client.send({"type": NetMsg.AUTH_LOGIN, "callsign": auth_callsign, "password": auth_password})
	auth_password = ""  # nunca retener el password en memoria más de lo necesario


func _process(delta: float) -> void:
	if Client.transport != null:
		Client.transport.poll(delta)
	_send_move_intent(delta)


func _send_move_intent(delta: float) -> void:
	if player == null:
		return
	_move_accum += delta
	if _move_accum < 1.0 / MOVE_SEND_HZ:
		return
	_move_accum = 0.0
	Client.send({
		"type": NetMsg.MOVE,
		"axis": Input.get_axis("move_left", "move_right"),
		"jump_edge": Input.is_action_just_pressed("jump"),
		"crouch": Input.is_action_pressed("crouch"),
		"aim": player.aim_angle,
		"ftick": last_server_tick,
	})


# ---------------------------------------------------------------
# Mensajes del servidor

func _on_server_message(msg: Dictionary) -> void:
	var t := str(msg.get("type", ""))
	match t:
		NetMsg.WELCOME:
			my_id = int(msg.get("id", -1))
			my_team = int(msg.get("team", 0))
			var server_proto := int(msg.get("proto", NetMsg.PROTOCOL_VERSION))
			if server_proto != NetMsg.PROTOCOL_VERSION:
				push_warning("[NetClient] servidor con protocolo %d (local %d): actualiza el juego" % [server_proto, NetMsg.PROTOCOL_VERSION])
			var spawn: Array = msg.get("spawn", [256.0, 256.0])
			player.global_position = Vector2(spawn[0], spawn[1])
			player.team_id = my_team
			print("[NetClient] soy jugador #%d (team %d)" % [my_id, my_team])
		NetMsg.SNAPSHOT:
			last_server_tick = int(msg.get("tick", last_server_tick))
			Client.peer_tick = last_server_tick
			var acks: Dictionary = msg.get("acks", {})
			if acks.has(str(my_id)):
				Client.confirm_ack(int(acks[str(my_id)]))
			_apply_snapshot(msg.get("players", {}))
		NetMsg.BLOCK_ADDED:
			_mirror_block_added(msg)
		NetMsg.BLOCK_REMOVED:
			_mirror_block_removed(msg)
		NetMsg.PICKUP_CONSUMED:
			_mirror_pickup_consumed(str(msg.get("path", "")))
		NetMsg.PLAYER_DIED:
			_mirror_player_died(int(msg.get("id", -1)), int(msg.get("lives", 0)))
		NetMsg.PLAYER_RESPAWNED:
			_mirror_player_respawned(int(msg.get("id", -1)), msg.get("spawn", [0.0, 0.0]))
		NetMsg.TARGET_DESTROYED:
			if match_ref != null:
				match_ref._on_target_destroyed(int(msg.get("remaining", 0)), int(msg.get("total", 0)))
		NetMsg.ROUND_WON:
			if match_ref != null:
				match_ref._on_objectives_cleared()
		NetMsg.ROUND_LOST:
			if match_ref != null:
				match_ref.round_active = false
				match_ref.emit_signal("round_lost")
		NetMsg.VIP_DOWN:
			if match_ref != null:
				match_ref.emit_signal("vip_down", int(msg.get("team", 0)))
		NetMsg.SCORE:
			if match_ref != null:
				var sc := {0: 0, 1: 0}
				var raw: Dictionary = msg.get("scores", {})
				for k in raw:
					sc[int(k)] = int(raw[k])
				match_ref.team_scores = sc
				match_ref.emit_signal("scores_changed", sc)
		NetMsg.MODE_STATE:
			if match_ref != null and ModeData.is_valid(str(msg.get("mode", ""))):
				match_ref.mode_id = str(msg.get("mode"))
				match_ref.emit_signal("mode_changed", match_ref.mode_id)
		NetMsg.AUTH_OK:
			Backend.set_auth_token(str(msg.get("token", "")))
			Backend.set_callsign(str(msg.get("callsign", auth_callsign)))
			Client.send({"type": NetMsg.JOIN, "token": Backend.auth_token, "callsign": auth_callsign})
		NetMsg.AUTH_FAIL:
			Backend.clear_auth_token()
			emit_signal("auth_failed", str(msg.get("reason", "error")))


func _apply_snapshot(players: Dictionary) -> void:
	var seen := {}
	for id_str in players.keys():
		var data: Dictionary = players[id_str]
		var id := int(id_str)
		seen[id] = true
		if id == my_id:
			_apply_own_state(data)
		else:
			_apply_remote_state(id, data)
	# limpiar puppets que ya no están
	var drop := []
	for id in _remote_puppets.keys():
		if not seen.has(id):
			drop.append(id)
	for id in drop:
		_remote_puppets[id].queue_free()
		_remote_puppets.erase(id)


## Estado propio: el servidor manda la verdad; corregimos localmente.
func _apply_own_state(data: Dictionary) -> void:
	if player == null:
		return
	var p: Array = data.get("p", [player.global_position.x, player.global_position.y])
	var server_pos := Vector2(p[0], p[1])
	if player.global_position.distance_to(server_pos) > RECONCILE_SNAP_DISTANCE:
		player.global_position = server_pos
		player.velocity = Vector2.ZERO
	player.hp = float(data.get("hp", player.hp))
	player.shield = float(data.get("shield", player.shield))
	var alive := bool(data.get("alive", true))
	if not alive and not player.respawning:
		player.die()
	var w := player.active_weapon()
	if w != null:
		w.magazine = int(data.get("mag", w.magazine))
		w.reserve = int(data.get("res", w.reserve))


func _apply_remote_state(id: int, data: Dictionary) -> void:
	var puppet: RemotePuppet = _remote_puppets.get(id, null)
	if puppet == null:
		puppet = RemotePuppet.new()
		puppet.player_id = id
		get_parent().add_child(puppet)
		_remote_puppets[id] = puppet
	puppet.apply_state(data)


# ---------------------------------------------------------------
# Espejo del mundo: bloques / pickups / muertes

func _mirror_block_added(msg: Dictionary) -> void:
	if test_map == null:
		return
	var c: Array = msg.get("cell", [0, 0])
	var cell := Vector2i(int(c[0]), int(c[1]))
	var block_id := str(msg.get("block_id", BlockData.BLOCK_BUILD))
	var team := int(msg.get("team", 0))
	var grid: Grid = test_map.grid
	if grid.has_block(cell):
		return
	var block: Block = test_map._block_scene.instantiate()
	block.setup(block_id, cell, team)
	grid.add_block(block, cell)
	block.global_position = grid.cell_world_center(cell)
	test_map.add_child(block)


func _mirror_block_removed(msg: Dictionary) -> void:
	if test_map == null:
		return
	var c: Array = msg.get("cell", [0, 0])
	var cell := Vector2i(int(c[0]), int(c[1]))
	var block := test_map.grid.get_block(cell)
	if block != null:
		block.apply_damage(block.max_hp + 1.0)


func _mirror_pickup_consumed(path: String) -> void:
	if test_map == null:
		return
	var node := test_map.get_node_or_null(NodePath(path))
	if node != null:
		node.queue_free()


func _mirror_player_died(id: int, lives: int) -> void:
	if id == my_id and player != null:
		if match_ref != null:
			match_ref.lives = lives
			match_ref.emit_signal("lives_changed", lives)


func _mirror_player_respawned(id: int, spawn_arr: Variant) -> void:
	if id == my_id and player != null:
		var s: Array = spawn_arr
		player.reset_for_respawn(Vector2(s[0], s[1]))


func _on_disconnected() -> void:
	push_warning("[NetClient] desconectado del servidor")
	my_id = -1
