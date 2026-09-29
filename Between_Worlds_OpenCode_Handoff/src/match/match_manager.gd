extends Node
## Gestor de partida (autoload "Match").
## - FRONTLINE (defecto, compatible con el slice anterior): vidas + objetivos.
## - VIP: cada equipo designa un VIP (primer registrado); matar al VIP rival gana.
## - DOMINATION: 3 zonas; cada zona controlada suma puntos por segundo.
## Simulación local autoritativa: estas reglas migrarán al servidor dedicado.
## Todo provisional Punto 2, validado en tests/unit/test_modes.gd.

const START_LIVES := GameConstants.STARTING_LIVES
const RESPAWN_TIME := GameConstants.RESPAWN_DELAY

var player: Player
# Sin tipo TestMap a propósito (duck-typing): los tests inyectan un stub
# liviano con la misma interfaz (objectives_total, spawns, zones).
var test_map
var lives := START_LIVES
var targets_remaining := 0
var targets_total := 0
var round_active := false

# Punto 2: modo + equipos 5v5.
var mode_id := ModeData.MODE_FRONTLINE
var roster: Array[Player] = []
var team_lives := {0: START_LIVES, 1: START_LIVES}
var team_scores := {0: 0, 1: 0}
var vip: Dictionary = {}  # team -> Player
var match_time_left := GameConstants.MATCH_DURATION
var _domination_accum := 0.0

signal lives_changed(remaining: int)
signal targets_remaining_changed(remaining: int, total: int)
signal round_won
signal round_lost
signal respawn_countdown(seconds: float)
signal mode_changed(mode: String)
signal team_lives_changed(lives: Dictionary)
signal scores_changed(scores: Dictionary)
signal vip_down(team: int)


func _ready() -> void:
	# Inicialmente sin partida: main.gd llama a start_round.
	pass


func start_round(p_player: Player, p_map, p_mode: String = "") -> void:
	player = p_player
	test_map = p_map
	if p_mode != "" and ModeData.is_valid(p_mode):
		mode_id = p_mode
	else:
		mode_id = ModeData.MODE_FRONTLINE
	lives = START_LIVES
	targets_remaining = test_map.objectives_total
	targets_total = test_map.objectives_total
	round_active = true
	roster.clear()
	vip.clear()
	team_lives = {0: START_LIVES * GameConstants.TEAM_SIZE, 1: START_LIVES * GameConstants.TEAM_SIZE}
	team_scores = {0: 0, 1: 0}
	match_time_left = GameConstants.MATCH_DURATION
	_domination_accum = 0.0
	register_player(player)

	if not test_map.target_destroyed.is_connected(_on_target_destroyed):
		test_map.target_destroyed.connect(_on_target_destroyed)
	if not test_map.objectives_cleared.is_connected(_on_objectives_cleared):
		test_map.objectives_cleared.connect(_on_objectives_cleared)

	emit_signal("mode_changed", mode_id)
	emit_signal("lives_changed", lives)
	emit_signal("targets_remaining_changed", targets_remaining, targets_total)
	emit_signal("team_lives_changed", team_lives)
	emit_signal("scores_changed", team_scores)


## Registra un jugador en el roster 5v5 (equipos por team_id del Player).
## El primer jugador de cada equipo en modo VIP es su VIP.
func register_player(p: Player) -> void:
	if p == null:
		return
	if not roster.has(p):
		roster.append(p)
	if not p.died.is_connected(_on_roster_died):
		p.died.connect(_on_roster_died.bind(p))
	if ModeData.uses_vip(mode_id) and not vip.has(p.team_id):
		vip[p.team_id] = p


func register_roster(players: Array[Player]) -> void:
	for p in players:
		register_player(p)


func is_vip(p: Player) -> bool:
	for team in vip:
		if vip[team] == p:
			return true
	return false


func _process(delta: float) -> void:
	if not round_active:
		return
	match_time_left -= delta
	if match_time_left <= 0.0:
		_timeout_decide()
		return
	if mode_id == ModeData.MODE_DOMINATION:
		_domination_accum += delta
		if _domination_accum >= GameConstants.DOMINATION_TICK_SECONDS:
			_domination_accum = 0.0
			_domination_tick()


func _on_player_died() -> void:
	# Compat: muerte del jugador local en FRONTLINE clásico.
	_on_roster_died(player)


func _on_roster_died(p: Player) -> void:
	if not round_active or p == null:
		return
	# Vidas: legado single + vidas de equipo.
	if p == player:
		lives -= 1
		emit_signal("lives_changed", lives)
	team_lives[p.team_id] = int(team_lives.get(p.team_id, 1)) - 1
	emit_signal("team_lives_changed", team_lives)

	# VIP: matar al VIP rival termina la ronda de inmediato.
	if ModeData.uses_vip(mode_id) and is_vip(p):
		round_active = false
		emit_signal("vip_down", p.team_id)
		if p.team_id == 1:
			emit_signal("round_won")
		else:
			emit_signal("round_lost")
		return

	# Equipo sin vidas pierde (si quedan objetivos o en cualquier modo con vidas).
	if int(team_lives[p.team_id]) <= 0:
		round_active = false
		if p.team_id == 1:
			emit_signal("round_won")
		else:
			emit_signal("round_lost")
		return

	if p == player and lives <= 0 and mode_id == ModeData.MODE_FRONTLINE and roster.size() <= 1:
		round_active = false
		emit_signal("round_lost")
		return
	_start_respawn_for(p)


func _on_target_destroyed(remaining: int, total: int) -> void:
	targets_remaining = remaining
	targets_total = total
	emit_signal("targets_remaining_changed", remaining, total)


func _on_objectives_cleared() -> void:
	if not round_active:
		return
	if mode_id != ModeData.MODE_FRONTLINE:
		return
	round_active = false
	emit_signal("round_won")


func _start_respawn_for(p: Player) -> void:
	if p == player:
		emit_signal("respawn_countdown", RESPAWN_TIME)
	get_tree().create_timer(RESPAWN_TIME).timeout.connect(_do_respawn.bind(p))


func _start_respawn() -> void:
	emit_signal("respawn_countdown", RESPAWN_TIME)
	get_tree().create_timer(RESPAWN_TIME).timeout.connect(_do_respawn)


func _do_respawn(p: Player = null) -> void:
	var target: Player = p if p != null else player
	if target == null or not round_active:
		return
	var spawn: Vector2 = test_map.spawn_a
	if test_map.has_method("spawn_for_team_index"):
		var idx := roster.find(target)
		spawn = test_map.spawn_for_team_index(target.team_id, maxi(idx, 0) % GameConstants.TEAM_SIZE)
	elif target.team_id == 1:
		spawn = test_map.spawn_b
	target.reset_for_respawn(spawn)


## Tick de dominación: cada zona controlada por un equipo suma puntos.
## Control = equipo con más jugadores vivos dentro; empate = nadie puntúa.
func _domination_tick() -> void:
	if test_map == null:
		return
	var zones: Array = test_map.domination_zones() if test_map.has_method("domination_zones") else []
	for zone in zones:
		var counts := {0: 0, 1: 0}
		for p in roster:
			if p == null or not is_instance_valid(p) or p.respawning:
				continue
			if zone.has_point(p.global_position):
				counts[p.team_id] = int(counts[p.team_id]) + 1
		if counts[0] > counts[1]:
			team_scores[0] = int(team_scores[0]) + GameConstants.DOMINATION_SCORE_PER_TICK
		elif counts[1] > counts[0]:
			team_scores[1] = int(team_scores[1]) + GameConstants.DOMINATION_SCORE_PER_TICK
	emit_signal("scores_changed", team_scores)
	if int(team_scores[0]) >= GameConstants.DOMINATION_WIN_SCORE:
		round_active = false
		emit_signal("round_won")
	elif int(team_scores[1]) >= GameConstants.DOMINATION_WIN_SCORE:
		round_active = false
		emit_signal("round_lost")


func _timeout_decide() -> void:
	round_active = false
	if mode_id == ModeData.MODE_DOMINATION:
		if int(team_scores[0]) >= int(team_scores[1]):
			emit_signal("round_won")
		else:
			emit_signal("round_lost")
	else:
		if int(team_lives[0]) >= int(team_lives[1]):
			emit_signal("round_won")
		else:
			emit_signal("round_lost")
