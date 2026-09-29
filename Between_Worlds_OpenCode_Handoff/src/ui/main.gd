extends Node2D
## Ensambla la partida: menú → mapa + jugador + construcción + match + HUD.
## Punto 4: el menú elige modo/armadura/mapa antes de spawnear.

const TEST_MAP_SCENE := preload("res://src/map/test_map.tscn")
const PLAYER_SCENE := preload("res://src/player/player.tscn")

var test_map: TestMap
var player: Player
var squad: Array[Player] = []  # roster 5v5 local (jugador + dummies)
var construction: ConstructionController
var net_driver: NetClientDriver = null
var menu: GameMenu = null
var started := false

@onready var world: Node2D = $World
@onready var entities: Node2D = $Entities
@onready var hud: Control = $UI/HUD
@onready var ui_layer: CanvasLayer = $UI


func _ready() -> void:
	_show_menu()


func _show_menu() -> void:
	menu = GameMenu.new()
	ui_layer.add_child(menu)
	_apply_cli_to_menu()
	menu.start_requested.connect(_start_match)
	menu.join_requested.connect(_on_join)


func _apply_cli_to_menu() -> void:
	_select_option(menu.mode_opt, _mode_arg())
	_select_option(menu.armor_opt, _armor_arg())
	_select_option(menu.map_opt, _map_arg())


func _select_option(opt: OptionButton, id: String) -> void:
	for i in range(opt.item_count):
		if str(opt.get_item_metadata(i)) == id:
			opt.selected = i
			return


func _start_match(mode: String, armor: String, map: String, force_url: String = "") -> void:
	if started:
		return
	started = true
	menu.apply_volumes()
	menu.queue_free()
	menu = null
	_build_world(map)
	_build_player(armor)
	_build_squad()
	_build_construction()
	_setup_transport(force_url)
	Telemetry.start_session(mode, map)
	await get_tree().process_frame
	if net_driver == null:
		# Modo local: Match autoload gestiona respawn/vidas/objetivos.
		# En modo red es la simulación del servidor la que gestiona estos eventos.
		Match.start_round(player, test_map, mode)
		Match.register_roster(squad)
	_hook_audio()
	_hook_telemetry(mode, map)
	Audio.start_music()
	await get_tree().process_frame
	hud.setup(player, Match, construction)


## Unirse a un servidor remoto desde el menú (matchmaking manual, Punto 5).
func _on_join(address: String) -> void:
	if address == "":
		return
	_start_match(menu.selected_mode(), menu.selected_armor(), menu.selected_map(), address)


func _build_world(map: String) -> void:
	test_map = TEST_MAP_SCENE.instantiate()
	if MapData.is_valid(map):
		test_map.map_id = map
	world.add_child(test_map)
	await test_map.map_ready
	Server.register_world(test_map, test_map.grid)


func _build_player(armor: String) -> void:
	player = PLAYER_SCENE.instantiate()
	player.global_position = test_map.spawn_a
	player.set_armor(armor if armor in ArmorData.ORDER else ArmorData.ARMOR_MEDIUM)
	entities.add_child(player)

	var cam := player.get_node("Camera2D") as Camera2D
	var rect := test_map.world_rect()
	cam.limit_left = int(rect.position.x)
	cam.limit_top = int(rect.position.y)
	cam.limit_right = int(rect.end.x)
	cam.limit_bottom = int(rect.end.y)
	cam.make_current()


func _build_construction() -> void:
	construction = ConstructionController.new()
	construction.setup(test_map.grid, player)
	entities.add_child(construction)


## Roster 5v5 local (provisional Punto 2): el jugador + 9 dummies quietos
## (sin IA todavía) para validar equipos, spawns, VIP y zonas.
func _build_squad() -> void:
	squad.clear()
	squad.append(player)
	var armors := [ArmorData.ARMOR_LIGHT, ArmorData.ARMOR_MEDIUM, ArmorData.ARMOR_HEAVY]
	for i in range(GameConstants.TEAM_SIZE * GameConstants.TEAM_COUNT - 1):
		var dummy: Player = PLAYER_SCENE.instantiate()
		var team := (i + 1) / GameConstants.TEAM_SIZE  # 0..3 aliados, 4..8 rivales
		dummy.team_id = mini(team, 1)
		var idx := (i + 1) % GameConstants.TEAM_SIZE
		if dummy.team_id == 1:
			idx = (i + 1 - GameConstants.TEAM_SIZE) % GameConstants.TEAM_SIZE
		dummy.global_position = test_map.spawn_for_team_index(dummy.team_id, idx)
		dummy.set_armor(armors[(i + 1) % armors.size()])
		dummy.net_controlled = true  # quietos: sin lectura de input local
		entities.add_child(dummy)
		squad.append(dummy)


## Hooks de audio en señales existentes (solo lectura, sin lógica de juego).
func _hook_audio() -> void:
	for w in player.weapons:
		w.fired.connect(_on_local_shot.bind(w))
	player.died.connect(func() -> void: Audio.play("death"))
	player.picked_up.connect(func(_id: String) -> void: Audio.play("pickup"))
	test_map.grid.block_added.connect(func(_c: Vector2i, _b: Block) -> void: Audio.play("build"))
	test_map.grid.block_removed.connect(func(_c: Vector2i) -> void: Audio.play("destroy"))
	Match.round_won.connect(func() -> void: Audio.play("win"))
	Match.round_lost.connect(func() -> void: Audio.play("lose"))


func _on_local_shot(w: Weapon) -> void:
	if not player.respawning:
		Audio.play_shot(w.weapon_id)
		Telemetry.inc("shots_" + w.weapon_id)


## Telemetría en señales existentes (solo lectura, ver docs/TELEMETRY.md).
func _hook_telemetry(mode: String, map: String) -> void:
	player.died.connect(func() -> void: Telemetry.record("died", {"team": player.team_id}))
	player.picked_up.connect(func(pid: String) -> void: Telemetry.record("pickup", {"id": pid}))
	test_map.grid.block_added.connect(func(_c: Vector2i, _b: Block) -> void: Telemetry.record("build", {}))
	test_map.grid.block_removed.connect(func(_c: Vector2i) -> void: Telemetry.record("destroy", {}))
	test_map.target_destroyed.connect(func(rem: int, total: int) -> void: Telemetry.record("target", {"remaining": rem, "total": total}))
	Match.round_won.connect(func() -> void: _on_match_end(mode, map, "won"))
	Match.round_lost.connect(func() -> void: _on_match_end(mode, map, "lost"))


func _on_match_end(mode: String, map: String, result: String) -> void:
	var summary := Telemetry.end_session(result)
	Telemetry.flush()
	Backend.record_match({"mode": mode, "map": map, "result": result, "counters": summary.get("counters", {})})


## CLI: --mode=, --map=lab|arena, --armor=light|medium|heavy.
func _mode_arg() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			var m := a.trim_prefix("--mode=")
			if ModeData.is_valid(m):
				return m
	return ModeData.MODE_FRONTLINE


func _map_arg() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			var m := a.trim_prefix("--map=")
			if MapData.is_valid(m):
				return m
	return MapData.MAP_LAB


func _armor_arg() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--armor="):
			var m := a.trim_prefix("--armor=")
			if m in ArmorData.ORDER:
				return m
	return ArmorData.ARMOR_MEDIUM


## Dos modos: local (LocalTransport loopback, por defecto) o red
## (`--connect=` o Join del menú para hablar con el servidor dedicado).
func _setup_transport(force_url: String = "") -> void:
	var url := force_url if force_url != "" else _connect_arg()
	if url != "":
		net_driver = NetClientDriver.new()
		entities.add_child(net_driver)
		net_driver.setup(player, test_map, Match)
		net_driver.connect_to(url)
		return
	var transport := LocalTransport.new()
	Client.setup(transport)
	Server.attach_transport(transport, player)


func _connect_arg() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--connect="):
			return a.trim_prefix("--connect=")
	return ""


func _process(_delta: float) -> void:
	if not started or player == null:
		return
	if Input.is_action_just_pressed("restart_round"):
		get_tree().reload_current_scene()
		return
	_check_fell_out_of_world()


func _check_fell_out_of_world() -> void:
	if player == null:
		return
	if player.global_position.y > test_map.world_rect().end.y + 120.0:
		if net_driver != null:
			Client.send({"type": NetMsg.FALL_OUT})
		else:
			Server.request_fall_out(player)


func _exit_tree() -> void:
	Server.clear_sessions()
	Client.setup(null)
	Server.unregister_world()
