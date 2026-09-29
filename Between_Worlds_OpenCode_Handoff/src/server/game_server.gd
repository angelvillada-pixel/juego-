extends Node
## Autoload "Server": autoridad de la partida (Etapas 1-3 de networking).
## - Etapa 1: resolución local vía request_* (tests).
## - Etapa 2: intenciones por mensaje (LocalTransport loopback).
## - Etapa 3: servidor dedicado headless con WebSocket (start_listener),
##   simulación de jugadores net_controlled, snapshots a 30 Hz y eventos
##   de mundo (bloques/pickups/match) a los clientes conectados.
##
## Regla: NINGÚN resultado competitivo (daño, munición, pickups, construcción,
## muerte, respawn, match) se decide fuera de este autoload (y Match en local).

## Radio máximo para recoger un pickup (validación anti-teleport, provisional).
const PICKUP_RADIUS := GameConstants.GRID_SIZE * 1.5
const SNAPSHOT_HZ := 30.0
const MAX_NET_PLAYERS := 10

# Punto 3: anti-cheat + lag-comp (provisionales, ver docs/DECISIONS.md).
const RATE_KICK_STRIKES := 20  # flood persistente => kick de sesión
const REWIND_TOLERANCE_PX := 96.0  # tolerancia de hit vs posición rebobinada
const HISTORY_MAX := 90  # ~3 s de historial a 30 Hz
const SPEED_CAP := 1200.0  # muy por encima de lo legítimo (dash 380 + caída 900)
const CHEAT_LOG_MAX := 200

const BLOCK_SCENE := preload("res://src/construction/block.tscn")

## Contenedor del mundo autoritativo y su grid.
var world: Node2D = null
var world_grid: Grid = null

var is_dedicated_server := false

## Sesiones: transport -> {player, callback, net, id, lives}.
var _sessions: Dictionary = {}
var _next_player_id := 1
var _listener: TCPServer = null
var _pending_peers: Array[WebSocketPeer] = []
var _snapshot_accum := 0.0

# Punto 2: modo de partida + estado de equipos (autoridad del servidor).
var mode_id := ModeData.MODE_FRONTLINE
var team_scores := {0: 0, 1: 0}
var vip_ids := {}  # team -> player id (primer jugador de cada equipo en modo VIP)
var _domination_accum := 0.0

# Punto 3: tick de servidor, historiales de posición e historial de trampas.
var server_tick := 0
var cheat_log: Array[Dictionary] = []  # {tick, id, kind} (capado)
var _histories := {}  # session id -> Array[[tick, x, y]] (capado a HISTORY_MAX)

signal player_joined_net(player_id: int)


func _process(delta: float) -> void:
	_poll_network(delta)
	_poll_sessions(delta)
	if _sessions.size() > 0:
		_snapshot_accum += delta
		if _snapshot_accum >= 1.0 / SNAPSHOT_HZ:
			_snapshot_accum = 0.0
			_broadcast_snapshot()
		if mode_id == ModeData.MODE_DOMINATION and is_dedicated_server:
			_domination_accum += delta
			if _domination_accum >= GameConstants.DOMINATION_TICK_SECONDS:
				_domination_accum = 0.0
				_domination_tick_server()


## Cambia el modo de partida (autoridad). Retransmite el estado a los clientes.
func set_mode(p_mode: String) -> bool:
	if not ModeData.is_valid(p_mode):
		return false
	mode_id = p_mode
	team_scores = {0: 0, 1: 0}
	vip_ids.clear()
	_assign_existing_vips()
	_broadcast_event({"type": NetMsg.MODE_STATE, "mode": mode_id})
	return true


func _assign_existing_vips() -> void:
	if not ModeData.uses_vip(mode_id):
		return
	var seen := {}
	for transport in _sessions:
		var session: Dictionary = _sessions[transport]
		var p: Player = session.get("player", null)
		if p == null:
			continue
		if not seen.has(p.team_id):
			seen[p.team_id] = true
			vip_ids[p.team_id] = session.get("id", 0)


# ---------------------------------------------------------------
# Mundo

func register_world(node: Node2D, grid: Grid = null) -> void:
	world = node
	world_grid = grid
	if world_grid != null and not world_grid.block_added.is_connected(_on_grid_block_added):
		world_grid.block_added.connect(_on_grid_block_added)
		world_grid.block_removed.connect(_on_grid_block_removed)


func unregister_world() -> void:
	world = null
	world_grid = null


func _on_grid_block_added(cell: Vector2i, block: Block) -> void:
	_broadcast_event({"type": NetMsg.BLOCK_ADDED, "cell": [cell.x, cell.y], "block_id": block.block_id, "team": block.team_id})


func _on_grid_block_removed(cell: Vector2i) -> void:
	_broadcast_event({"type": NetMsg.BLOCK_REMOVED, "cell": [cell.x, cell.y]})


# ---------------------------------------------------------------
# Listener dedicado (Etapa 3)

func start_listener(port: int) -> bool:
	_listener = TCPServer.new()
	if _listener.listen(port) != OK:
		push_error("No se pudo escuchar en el puerto %d" % port)
		_listener = null
		return false
	is_dedicated_server = true
	print("[Server] WebSocket escuchando en puerto %d" % port)
	return true


func stop_listener() -> void:
	if _listener != null:
		_listener.stop()
		_listener = null
	is_dedicated_server = false


func _poll_network(_delta: float) -> void:
	if _listener == null:
		return
	while _listener.is_connection_available():
		var stream := _listener.take_connection()
		var ws := WebSocketPeer.new()
		ws.accept_stream(stream)
		_pending_peers.append(ws)
	var still_pending: Array[WebSocketPeer] = []
	for ws in _pending_peers:
		ws.poll()
		match ws.get_ready_state():
			WebSocketPeer.STATE_OPEN:
				_adopt_peer(ws)
			WebSocketPeer.STATE_CLOSED:
				pass  # handshake fallido: se descarta
			_:
				still_pending.append(ws)
	_pending_peers = still_pending


func _adopt_peer(ws: WebSocketPeer) -> void:
	if count_net_players() >= MAX_NET_PLAYERS:
		ws.close()
		return
	var transport := WsTransport.from_accepted_peer(ws)
	var player := _spawn_net_player()
	if player == null:
		ws.close()
		return
	attach_transport(transport, player, true)
	var session: Dictionary = _sessions[transport]
	transport.send(_welcome_msg(session["id"], player))


func count_net_players() -> int:
	var n := 0
	for t in _sessions:
		if _sessions[t]["net"]:
			n += 1
	return n


func _welcome_msg(id: int, player: Player) -> Dictionary:
	return {"type": NetMsg.WELCOME, "id": id, "spawn": [player.global_position.x, player.global_position.y], "team": player.team_id}


# ---------------------------------------------------------------
# Sesiones (loopback local o transporte de red) y despacho de mensajes

func attach_transport(transport: NetTransport, player: Player, net := false) -> bool:
	if transport == null or player == null:
		return false
	var cb := _on_transport_message.bindv([transport])
	_sessions[transport] = {
		"player": player,
		"callback": cb,
		"net": net,
		"id": _next_player_id if net else 0,
		"lives": GameConstants.STARTING_LIVES,
		"last_seq": 0,  # Punto 3: último seq visto (para el ack del snapshot)
		"strikes": 0,  # Punto 3: infracciones acumuladas (kick al llegar al tope)
		"limiters": _new_limiters(),  # Punto 3: token buckets por tipo de intent
		"last_pos": player.global_position,  # Punto 3: control de velocidad
		"last_pos_t": _now_sec(),
	}
	if net:
		_next_player_id += 1
		player.died.connect(_on_net_player_died.bindv([transport]))
		emit_signal("player_joined_net", _sessions[transport]["id"])
	transport.message_received.connect(cb)
	return true


func session_count() -> int:
	return _sessions.size()


func clear_sessions() -> void:
	for transport: NetTransport in _sessions.keys():
		var cb: Callable = _sessions[transport]["callback"]
		if transport.message_received.is_connected(cb):
			transport.message_received.disconnect(cb)
	_sessions.clear()


func _poll_sessions(delta: float) -> void:
	var dropped: Array[NetTransport] = []
	for transport: NetTransport in _sessions.keys():
		transport.poll(delta)
		if _sessions[transport]["net"] and not transport.is_open():
			dropped.append(transport)
	for t in dropped:
		_drop_session(t)


func _drop_session(transport: NetTransport) -> void:
	var session: Dictionary = _sessions.get(transport, {})
	var player: Player = session.get("player", null)
	if player != null and is_instance_valid(player):
		player.queue_free()
	_sessions.erase(transport)
	transport.close()


# ---------------------------------------------------------------
# Punto 3: anti-cheat (rate-limit, plausibilidad, cheat-log) y lag-comp.
# El cliente nunca decide resultados; aquí solo se valida el ritmo y la
# cordura de sus intenciones. Los hits los resuelve el servidor con su
# propio estado; el historial rebobinado mide la divergencia (telemetría).

static func _now_sec() -> float:
	return Time.get_ticks_msec() / 1000.0


static func _new_limiters() -> Dictionary:
	return {
		NetMsg.FIRE: RateLimiter.new(8.0, 12.0),
		NetMsg.MOVE: RateLimiter.new(12.0, 40.0),
		NetMsg.BUILD_PLACE: RateLimiter.new(4.0, 4.0),
		NetMsg.BUILD_DESTROY: RateLimiter.new(4.0, 4.0),
		NetMsg.UTILITY: RateLimiter.new(2.0, 1.0),
		NetMsg.RELOAD: RateLimiter.new(4.0, 8.0),
		NetMsg.PICKUP_CLAIM: RateLimiter.new(4.0, 8.0),
		NetMsg.FALL_OUT: RateLimiter.new(4.0, 8.0),
	}


## Devuelve false (y cuenta strike) si la sesión excede su ritmo permitido.
func _check_rate(session: Dictionary, transport: NetTransport, kind: String) -> bool:
	var limiters: Dictionary = session.get("limiters", {})
	if not limiters.has(kind):
		return true
	var limiter: RateLimiter = limiters[kind]
	if limiter.consume(1.0, _now_sec()):
		return true
	_strike(session, transport, "rate:" + kind)
	return false


func _strike(session: Dictionary, transport: NetTransport, kind: String) -> void:
	session["strikes"] = int(session.get("strikes", 0)) + 1
	_log_cheat(int(session.get("id", 0)), kind)
	if int(session["strikes"]) >= RATE_KICK_STRIKES:
		_log_cheat(int(session.get("id", 0)), "kick")
		_drop_session(transport)


func _log_cheat(player_id: int, kind: String) -> void:
	cheat_log.append({"tick": server_tick, "id": player_id, "kind": kind})
	while cheat_log.size() > CHEAT_LOG_MAX:
		cheat_log.pop_front()


func _session_id_for(target: Player) -> int:
	for transport in _sessions:
		var session: Dictionary = _sessions[transport]
		if session.get("player", null) == target:
			return int(session.get("id", 0))
	return -1


## Posición rebobinada de una sesión en un tick dado (la más cercana <= tick).
func rewound_position(session_id: int, tick: int) -> Variant:
	var hist: Array = _histories.get(session_id, [])
	var best: Variant = null
	for entry in hist:
		if int(entry[0]) <= tick:
			best = entry
		else:
			break
	if best == null and not hist.is_empty():
		best = hist[0]
	if best == null:
		return null
	return Vector2(best[1], best[2])


## Valida un hit contra jugador frente al historial (tolerancia de lag).
## Devuelve true si el hit es plausible. Siempre registra divergencias.
func validate_hit_rewind(target: Player, hit_pos: Vector2, ftick: int) -> bool:
	var sid := _session_id_for(target)
	if sid < 0 or ftick < 0:
		return true  # sin datos: no se puede juzgar, se acepta
	var rewound: Variant = rewound_position(sid, ftick)
	if rewound == null:
		return true
	if (rewound as Vector2).distance_to(hit_pos) <= REWIND_TOLERANCE_PX:
		return true
	_log_cheat(sid, "rewind_miss")
	return false


func _on_transport_message(msg: Dictionary, transport: NetTransport) -> void:
	var session: Dictionary = _sessions.get(transport, {})
	var player: Player = session.get("player", null)
	if player == null or not is_instance_valid(player):
		return
	if not NetMsg.is_valid_type(msg.get("type")):
		push_warning("Mensaje con tipo inválido desechado: %s" % msg)
		return
	# Punto 3: seq + rate-limit antes de despachar. El flood persistente
	# termina en kick; cada rechazo queda en el cheat_log.
	var seq := int(msg.get("seq", 0))
	if seq > int(session.get("last_seq", 0)):
		session["last_seq"] = seq
	if not _check_rate(session, transport, str(msg["type"])):
		return
	match msg["type"]:
		NetMsg.FIRE:
			_handle_fire(player, msg)
		NetMsg.RELOAD:
			_handle_reload(player, msg)
		NetMsg.BUILD_PLACE:
			request_build_place(world_grid, msg.get("cell", Vector2i.ZERO), player.team_id, player.global_position)
		NetMsg.BUILD_DESTROY:
			request_build_destroy(world_grid, msg.get("cell", Vector2i.ZERO), player.team_id, player.global_position)
		NetMsg.PICKUP_CLAIM:
			_handle_pickup_claim(player, msg)
		NetMsg.FALL_OUT:
			request_fall_out(player)
		NetMsg.MOVE:
			_handle_move(player, msg)
		NetMsg.UTILITY:
			_handle_utility(player, msg)


func _handle_fire(player: Player, msg: Dictionary) -> void:
	var index: int = msg.get("weapon_index", -1)
	if index < 0 or index >= player.weapons.size():
		return
	var dir: Vector2 = msg.get("direction", Vector2.ZERO)
	if not is_finite(dir.x) or not is_finite(dir.y):
		return
	if dir.is_zero_approx():
		return
	dir = dir.normalized()  # el servidor nunca confía en el módulo del vector cliente
	var src := player.weapon_arm.global_position + dir * 10.0
	request_fire(player, player.weapons[index], src, dir, int(msg.get("ftick", -1)))


func _handle_reload(player: Player, msg: Dictionary) -> void:
	var index: int = msg.get("weapon_index", -1)
	if index < 0 or index >= player.weapons.size():
		return
	request_reload(player, player.weapons[index])


func _handle_pickup_claim(player: Player, msg: Dictionary) -> void:
	# El path es relativo al mundo registrado (TestMap u otro contenedor de test).
	if world == null or not is_instance_valid(world):
		return
	var node := world.get_node_or_null(NodePath(msg.get("path", "")))
	if node is Pickup:
		if request_pickup(player, node):
			_broadcast_event({"type": NetMsg.PICKUP_CONSUMED, "path": msg.get("path", "")})


func _handle_move(player: Player, msg: Dictionary) -> void:
	if not player.use_net_input:
		return
	player.net_axis = clampf(float(msg.get("axis", 0.0)), -1.0, 1.0)
	if bool(msg.get("jump_edge", false)):
		player.net_jump_edge = true
	player.net_crouch = bool(msg.get("crouch", false))
	var aim := float(msg.get("aim", player.aim_angle))
	if not is_finite(aim):
		return
	player.aim_angle = aim
	player.weapon_arm.rotation = player.aim_angle
	var scale_val := 1.0 if cos(player.aim_angle) >= 0.0 else -1.0
	player.weapon_arm.scale.y = scale_val


func _handle_utility(player: Player, msg: Dictionary) -> void:
	var dir: Vector2 = msg.get("direction", Vector2.RIGHT)
	if not is_finite(dir.x) or not is_finite(dir.y):
		return
	request_utility(player, dir)


## Utilidad (Punto 1, provisional): el servidor valida cooldown y respawn.
func request_utility(player: Player, direction: Vector2) -> bool:
	if player == null or player.respawning:
		return false
	if not player.can_use_utility():
		return false
	var dir: Vector2 = direction
	if dir.is_zero_approx():
		return false
	player.apply_utility_dash(dir.normalized())
	return true


# ---------------------------------------------------------------
# Disparo: el servidor decide SI el arma dispara y ejecuta el raycast.
# `ftick` = tick que veía el cliente al disparar; si es >= 0 se valida el
# hit contra jugador frente al historial rebobinado (lag-comp, telemetría).
func request_fire(player: Player, weapon: Weapon, source: Vector2, direction: Vector2, ftick: int = -1) -> Dictionary:
	if player == null or weapon == null or player.respawning:
		return {}
	var w2d := player.get_world_2d()
	if w2d == null:
		return {}
	var exclude: Array[RID] = []
	var rid := player.get_rid()
	if rid.is_valid():
		exclude.append(rid)
	var result := weapon.try_fire(w2d, source, direction, exclude)
	if ftick >= 0 and not result.is_empty() and bool(result.get("hit", false)):
		var collider: Object = result.get("collider", null)
		if collider is Player and collider != player:
			validate_hit_rewind(collider, result.get("position", source), ftick)
	return result


func request_reload(player: Player, weapon: Weapon) -> bool:
	if player == null or weapon == null or player.respawning:
		return false
	weapon.start_reload()
	return weapon.is_reloading()


# ---------------------------------------------------------------
# Pickups: validación de estado + distancia, aplicación con tope de máximos.
func request_pickup(player: Player, pickup: Pickup) -> bool:
	if player == null or pickup == null or not is_instance_valid(pickup):
		return false
	if player.respawning:
		return false
	if player.global_position.distance_to(pickup.global_position) > PICKUP_RADIUS:
		return false
	_apply_pickup(player, pickup.pickup_id)
	player.apply_pickup(pickup.pickup_id)
	pickup.emit_signal("consumed", pickup.pickup_id)
	pickup.queue_free()
	return true


func _apply_pickup(player: Player, pickup_id: String) -> void:
	var def := PickupData.get_def(pickup_id)
	var fraction: float = def["fraction"]
	match pickup_id:
		PickupData.PICKUP_HEALTH:
			player.hp = PickupService.apply_health(player.hp, player.max_hp, fraction)
			player.emit_signal("hp_changed", player.hp, player.max_hp)
		PickupData.PICKUP_ARMOR:
			player.shield = PickupService.apply_shield(player.shield, player.max_shield, fraction)
			player.emit_signal("shield_changed", player.shield, player.max_shield)
		PickupData.PICKUP_AMMO:
			for w in player.weapons:
				w.refill_reserve(fraction)


# ---------------------------------------------------------------
# Construcción: valida rango desde el CONSTRUCTOR (no del cursor) y reglas
# de celda/equipo. Destrucción mantiene la regla del prototipo: no permanentes,
# no bloques ajenos salvo objetivos.
func request_build_place(grid: Grid, cell: Vector2i, team: int, builder_origin: Vector2) -> Block:
	if grid == null or world == null or not is_instance_valid(world):
		return null
	if grid.cell_world_center(cell).distance_to(builder_origin) > GameConstants.BUILD_RANGE_PX:
		return null
	if not grid.is_free(cell):
		return null
	var block: Block = BLOCK_SCENE.instantiate()
	block.setup(BlockData.BLOCK_BUILD, cell, team)
	grid.add_block(block, cell)
	block.global_position = grid.cell_world_center(cell)
	world.add_child(block)
	return block


func request_build_destroy(grid: Grid, cell: Vector2i, requester_team: int, origin: Vector2) -> bool:
	if grid == null:
		return false
	if grid.cell_world_center(cell).distance_to(origin) > GameConstants.BUILD_RANGE_PX:
		return false
	var block := grid.get_block(cell)
	if block == null or block.is_permanent:
		return false
	if not block.is_target and block.team_id != requester_team:
		return false
	block.apply_damage(block.max_hp)
	return true


# ---------------------------------------------------------------
# Muerte por caída fuera del mundo.
func request_fall_out(player: Player) -> bool:
	if player == null or player.respawning:
		return false
	player.die()
	return true


# ---------------------------------------------------------------
# Simulación de jugadores de red (spawn/muerte/respawn/vidas — match lite)

func _spawn_net_player() -> Player:
	if world == null or not is_instance_valid(world):
		return null
	var scene: PackedScene = load("res://src/player/player.tscn")
	var player: Player = scene.instantiate()
	player.net_controlled = true
	player.use_net_input = true
	player.team_id = _next_player_id % 2
	player.global_position = _spawn_point_for_team(player.team_id)
	world.add_child(player)
	if ModeData.uses_vip(mode_id) and not vip_ids.has(player.team_id):
		vip_ids[player.team_id] = _next_player_id
	return player


func _team_player_count(team: int) -> int:
	var n := 0
	for transport in _sessions:
		var p: Player = (_sessions[transport] as Dictionary).get("player", null)
		if p != null and is_instance_valid(p) and p.team_id == team:
			n += 1
	return n


func _spawn_point_for_team(team: int) -> Vector2:
	if world != null and is_instance_valid(world) and world.has_method("spawn_for_team_index"):
		return world.spawn_for_team_index(team, _team_player_count(team) % GameConstants.TEAM_SIZE)
	return _spawn_point_for(_next_player_id)


func _spawn_point_for(id: int) -> Vector2:
	if world is TestMap:
		return world.spawn_a if id % 2 == 1 else world.spawn_b
	return Vector2(256, 256)


func _on_net_player_died(transport: NetTransport) -> void:
	var session: Dictionary = _sessions.get(transport, {})
	if session.is_empty():
		return
	var player: Player = session["player"]
	var id: int = session["id"]
	session["lives"] = int(session["lives"]) - 1
	_broadcast_event({"type": NetMsg.PLAYER_DIED, "id": id, "lives": session["lives"]})
	# VIP: la muerte del VIP termina la ronda (el equipo del VIP pierde).
	if ModeData.uses_vip(mode_id) and int(vip_ids.get(player.team_id, -1)) == id:
		_broadcast_event({"type": NetMsg.VIP_DOWN, "team": player.team_id})
		_broadcast_event({"type": NetMsg.ROUND_WON if player.team_id == 1 else NetMsg.ROUND_LOST})
		return
	if session["lives"] <= 0:
		transport_send(transport, {"type": NetMsg.ROUND_LOST})
		return
	await_respawn(session)


func await_respawn(session: Dictionary) -> void:
	get_tree().create_timer(GameConstants.RESPAWN_DELAY).timeout.connect(_do_net_respawn.bindv([session]))


func _do_net_respawn(session: Dictionary) -> void:
	var player: Player = session.get("player", null)
	if player == null or not is_instance_valid(player):
		return
	var spawn := Vector2(256, 256)
	if player != null and is_instance_valid(player):
		spawn = _spawn_point_for_team(player.team_id)
	elif world != null and is_instance_valid(world):
		spawn = _spawn_point_for(int(session.get("id", 1)))
	player.reset_for_respawn(spawn)
	# El respawn teleporta: no debe contar como velocidad imposible.
	session["last_pos"] = spawn
	session["last_pos_t"] = _now_sec()
	_broadcast_event({"type": NetMsg.PLAYER_RESPAWNED, "id": session["id"], "spawn": [spawn.x, spawn.y]})


func transport_send(transport: NetTransport, msg: Dictionary) -> void:
	if transport.is_open():
		transport.send(msg)


func notify_targets(remaining: int, total: int) -> void:
	_broadcast_event({"type": NetMsg.TARGET_DESTROYED, "remaining": remaining, "total": total})
	if remaining <= 0:
		_broadcast_event({"type": NetMsg.ROUND_WON})


## Tick de dominación en el servidor dedicado: puntúa zonas por presencia.
func _domination_tick_server() -> void:
	if world == null or not is_instance_valid(world) or not world.has_method("domination_zones"):
		return
	var zones: Array = world.domination_zones()
	for zone in zones:
		var counts := {0: 0, 1: 0}
		for transport in _sessions:
			var session: Dictionary = _sessions[transport]
			if not bool(session.get("net", false)):
				continue
			var p: Player = session.get("player", null)
			if p == null or not is_instance_valid(p) or p.respawning:
				continue
			if zone.has_point(p.global_position):
				counts[p.team_id] = int(counts[p.team_id]) + 1
		if counts[0] > counts[1]:
			team_scores[0] = int(team_scores[0]) + GameConstants.DOMINATION_SCORE_PER_TICK
		elif counts[1] > counts[0]:
			team_scores[1] = int(team_scores[1]) + GameConstants.DOMINATION_SCORE_PER_TICK
	_broadcast_event({"type": NetMsg.SCORE, "scores": {0: team_scores[0], 1: team_scores[1]}})
	if int(team_scores[0]) >= GameConstants.DOMINATION_WIN_SCORE:
		_broadcast_event({"type": NetMsg.ROUND_WON})
	elif int(team_scores[1]) >= GameConstants.DOMINATION_WIN_SCORE:
		_broadcast_event({"type": NetMsg.ROUND_LOST})


# ---------------------------------------------------------------
# Snapshots y eventos servidor->clientes (solo sesiones de red)

func _broadcast_event(msg: Dictionary) -> void:
	for transport: NetTransport in _sessions.keys():
		if _sessions[transport]["net"]:
			transport_send(transport, msg)


func _broadcast_snapshot() -> void:
	server_tick += 1
	var now := _now_sec()
	var players := {}
	var acks := {}
	for transport: NetTransport in _sessions.keys():
		var session: Dictionary = _sessions[transport]
		if not session["net"]:
			continue
		var player: Player = session["player"]
		if player == null or not is_instance_valid(player):
			continue
		acks[str(session["id"])] = int(session.get("last_seq", 0))
		_record_history(int(session["id"]), player.global_position)
		_check_speed(session, transport, player, now)
		var w := player.active_weapon()
		players[str(session["id"])] = {
			"p": [player.global_position.x, player.global_position.y],
			"hp": player.hp,
			"shield": player.shield,
			"armor": player.armor_id,
			"alive": not player.respawning,
			"aim": player.aim_angle,
			"team": player.team_id,
			"weapon": player.active_weapon_index,
			"mag": w.magazine if w != null else 0,
			"res": w.reserve if w != null else 0,
		}
	if players.is_empty():
		return
	_broadcast_event({"type": NetMsg.SNAPSHOT, "players": players, "tick": server_tick, "acks": acks})


## Guarda la posición en el historial rebobinado (capado a HISTORY_MAX).
func _record_history(session_id: int, pos: Vector2) -> void:
	if not _histories.has(session_id):
		_histories[session_id] = []
	var hist: Array = _histories[session_id]
	hist.append([server_tick, pos.x, pos.y])
	while hist.size() > HISTORY_MAX:
		hist.pop_front()


## Control de velocidad: la simulación es del servidor, así que un salto
## imposible indica manipulación o bug; se registra y cuenta strike.
func _check_speed(session: Dictionary, transport: NetTransport, player: Player, now: float) -> void:
	var last_pos: Vector2 = session.get("last_pos", player.global_position)
	var last_t: float = session.get("last_pos_t", now)
	var dt := maxf(now - last_t, 0.0001)
	if player.global_position.distance_to(last_pos) / dt > SPEED_CAP:
		_strike(session, transport, "speed")
	session["last_pos"] = player.global_position
	session["last_pos_t"] = now


func snapshot_for_debug() -> Dictionary:
	_broadcast_snapshot()
	return {}
