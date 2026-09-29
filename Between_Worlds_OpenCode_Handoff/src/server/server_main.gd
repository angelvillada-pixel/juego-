extends SceneTree
## Servidor dedicado headless (Etapa 3):
##   godot --headless --path . -s res://src/server/server_main.gd -- --port=26500
## Autoridad total: mapa, jugadores, combate, construcción y respawn se
## simulan aquí. Los clientes sólo envían intenciones y pintan estados.

const DEFAULT_PORT := WsTransport.DEFAULT_PORT

var world: TestMap = null
var _quit_after := 0.0  # 0 = sin límite (servidor real)
var _elapsed := 0.0
var _booted := false
var _port := 26500
var _mode := ""
var _map_id := ""
var _bind_addr := "127.0.0.1"

# S1/P1-P2: con `-s` el script se compila antes de que existan los autoloads,
# así que se resuelven en runtime (igual que tests/run_tests.gd).
var Server: Node
var MatchNode: Node
var TelemetryNode: Node


func _initialize() -> void:
	Server = root.get_node("Server")
	MatchNode = root.get_node("Match")
	TelemetryNode = root.get_node("Telemetry")
	var args := OS.get_cmdline_user_args()
	_port = _arg_int(args, "port", DEFAULT_PORT)
	_quit_after = _arg_float(args, "seconds", 0.0)
	_mode = _arg_str(args, "mode", ModeData.MODE_FRONTLINE)
	_map_id = _arg_str(args, "map", MapData.MAP_LAB)
	_bind_addr = _arg_str(args, "bind", "127.0.0.1")


func _boot() -> bool:
	# P1-P2: en el primer frame el árbol ya está listo y add_child dispara
	# _ready de forma síncrona (en _initialize el grid aún sería null).
	_build_world(_map_id)
	Server.register_world(world, world.grid)
	Server.set_mode(_mode if ModeData.is_valid(_mode) else ModeData.MODE_FRONTLINE)
	MatchNode.set("round_active", true)  # marcar la ronda activa para la simulación
	TelemetryNode.call("start_session", Server.get("mode_id"), world.map_id)
	if not Server.start_listener(_port, _bind_addr):
		quit(1)
		return false
	print("[server_main] mundo listo (%s, %s), %d objetivos, escuchando en ws://%s:%d" % [Server.get("mode_id"), world.map_id, world.objectives_total, _bind_addr, _port])
	return true


func _process(delta: float) -> bool:
	if not _booted:
		_booted = true
		if not _boot():
			return true  # listener caído: salir
	_elapsed += delta
	_check_falls()
	if _quit_after > 0.0 and _elapsed >= _quit_after:
		print("[server_main] fin programado alcanzado")
		TelemetryNode.call("end_session", "shutdown")
		TelemetryNode.call("flush")
		return true  # true = pedir salida
	return false


func _build_world(map_id: String) -> void:
	world = TestMap.new()
	if MapData.is_valid(map_id):
		world.map_id = map_id
	root.add_child(world)


func _check_falls() -> void:
	# La misma regla de caída del cliente, pero autoritativa en el servidor.
	var limit_y := world.world_rect().end.y + 120.0
	for transport: NetTransport in Server._sessions.keys():
		var player: Player = Server._sessions[transport]["player"]
		if player != null and is_instance_valid(player) and not player.respawning:
			if player.global_position.y > limit_y:
				Server.request_fall_out(player)


static func _arg_int(args: PackedStringArray, key: String, fallback: int) -> int:
	var prefix := "--%s=" % key
	for a in args:
		if a.begins_with(prefix):
			return int(a.trim_prefix(prefix))
	return fallback


static func _arg_float(args: PackedStringArray, key: String, fallback: float) -> float:
	var prefix := "--%s=" % key
	for a in args:
		if a.begins_with(prefix):
			return float(a.trim_prefix(prefix))
	return fallback


static func _arg_str(args: PackedStringArray, key: String, fallback: String) -> String:
	var prefix := "--%s=" % key
	for a in args:
		if a.begins_with(prefix):
			return a.trim_prefix(prefix)
	return fallback
