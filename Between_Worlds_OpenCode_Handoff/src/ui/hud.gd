extends Control
## HUD del laboratorio. Lee el estado por frame (sencillo y robusto para el slice).

const BAR_WIDTH := 180.0
const BAR_HEIGHT := 14.0

var player: Player
var match_man: Node
var construction: ConstructionController
var round_result := ""  # "", "won", "lost"
var respawn_until := 0.0
var _overlay_wants_redraw := false

# Punto 4: overlays construidos por código.
var pause_panel: PanelContainer
var score_panel: PanelContainer
var score_label: Label
var end_panel: PanelContainer
var end_label: Label

@onready var hp_bar: ProgressBar = $Root/TopLeft/HpBar
@onready var hp_label: Label = $Root/TopLeft/HpLabel
@onready var shield_bar: ProgressBar = $Root/TopLeft/ShieldBar
@onready var armor_label: Label = $Root/TopLeft/ArmorLabel
@onready var weapon_label: Label = $Root/TopLeft/WeaponLabel
@onready var ammo_label: Label = $Root/TopLeft/AmmoLabel
@onready var reload_bar: ProgressBar = $Root/TopLeft/ReloadBar
@onready var lives_label: Label = $Root/TopRight/LivesLabel
@onready var targets_label: Label = $Root/TopRight/TargetsLabel
@onready var round_label: Label = $Root/Center/RoundLabel
@onready var hint_label: Label = $Root/BottomHint/HintLabel


func _ready() -> void:
	# El HUD sigue vivo en pausa para poder reanudar desde el menú.
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_panel = _build_center_panel("PAUSED")
	var resume_btn := Button.new()
	resume_btn.text = "Resume  (Esc)"
	resume_btn.pressed.connect(_toggle_pause)
	(pause_panel.get_child(0) as VBoxContainer).add_child(resume_btn)
	var restart_btn := Button.new()
	restart_btn.text = "Restart round"
	restart_btn.pressed.connect(_on_restart_pressed)
	(pause_panel.get_child(0) as VBoxContainer).add_child(restart_btn)
	var menu_btn := Button.new()
	menu_btn.text = "Back to menu"
	menu_btn.pressed.connect(_on_restart_pressed)
	(pause_panel.get_child(0) as VBoxContainer).add_child(menu_btn)
	pause_panel.visible = false

	score_panel = _build_center_panel("SCOREBOARD (Tab)")
	score_label = Label.new()
	(score_panel.get_child(0) as VBoxContainer).add_child(score_label)
	score_panel.visible = false

	end_panel = _build_center_panel("ROUND OVER")
	end_label = Label.new()
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	(end_panel.get_child(0) as VBoxContainer).add_child(end_label)
	var rematch_btn := Button.new()
	rematch_btn.text = "Rematch  (Enter)"
	rematch_btn.pressed.connect(_on_restart_pressed)
	(end_panel.get_child(0) as VBoxContainer).add_child(rematch_btn)
	end_panel.visible = false


func _build_center_panel(title_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(340, 0)
	add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)
	return panel


func setup(p_player: Player, p_match: Node, p_construction: ConstructionController) -> void:
	player = p_player
	match_man = p_match
	construction = p_construction
	hint_label.text = ("WASD move · Space jump · S/Control crouch · LMB fire · RMB offhand · "
		+ "R reload · Q switch · F build · G destroy · E/Shift dash · Enter restart")
	match_man.round_won.connect(func() -> void: _set_round_result("round_won"))
	match_man.round_lost.connect(func() -> void: _set_round_result("round_lost"))
	match_man.respawn_countdown.connect(_on_respawn_countdown)
	match_man.targets_remaining_changed.connect(_on_targets_changed)
	match_man.lives_changed.connect(_on_lives_changed)
	if match_man.has_signal("mode_changed"):
		match_man.mode_changed.connect(_on_mode_changed)
	if match_man.has_signal("team_lives_changed"):
		match_man.team_lives_changed.connect(_on_team_lives_changed)
	if match_man.has_signal("scores_changed"):
		match_man.scores_changed.connect(_on_scores_changed)
	if match_man.has_signal("vip_down"):
		match_man.vip_down.connect(_on_vip_down)
	_on_mode_changed(match_man.get("mode_id"))


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause_menu"):
		_toggle_pause()
	_update_scoreboard_visibility()
	if player == null:
		return
	_refresh_bars()
	if respawn_until > 0.0:
		respawn_until -= delta
		if respawn_until <= 0.0:
			round_label.text = ""
	queue_redraw()


func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	pause_panel.visible = get_tree().paused


func _on_restart_pressed() -> void:
	get_tree().paused = false
	Audio.play("click")
	get_tree().reload_current_scene()


func _update_scoreboard_visibility() -> void:
	var show := Input.is_action_pressed("scoreboard")
	score_panel.visible = show
	if show:
		score_label.text = _scoreboard_text()


func _refresh_bars() -> void:
	hp_bar.max_value = player.max_hp
	hp_bar.value = player.hp
	hp_label.text = "HP %d / %d" % [round(player.hp), round(player.max_hp)]
	shield_bar.max_value = player.max_shield
	shield_bar.value = player.shield
	armor_label.text = "Armor: %s (%d%%)" % [
		ArmorData.get_def(player.armor_id)["display_name"],
		round(ArmorData.mitigation(player.armor_id) * 100.0),
	]

	var w := player.active_weapon()
	if w != null:
		weapon_label.text = "Weapon: %s" % w.def["display_name"]
		ammo_label.text = "Ammo: %d / %d" % [w.magazine, w.reserve]
		reload_bar.visible = w.is_reloading()
		if w.is_reloading():
			reload_bar.value = w.reload_ratio() * 100.0


func _on_respawn_countdown(seconds: float) -> void:
	respawn_until = seconds
	round_label.text = "Respawning in %.0f..." % seconds


func _on_targets_changed(remaining: int, total: int) -> void:
	targets_label.text = "Targets: %d / %d" % [total - remaining, total]


func _on_lives_changed(remaining: int) -> void:
	lives_label.text = "Lives: %d" % remaining
	_refresh_team_line()


func _on_mode_changed(mode: Variant) -> void:
	_refresh_team_line()


func _on_team_lives_changed(_lives: Dictionary) -> void:
	_refresh_team_line()


func _on_scores_changed(_scores: Dictionary) -> void:
	_refresh_team_line()


func _on_vip_down(team: int) -> void:
	round_label.text = "VIP down (team %d)!\nPress Enter to restart." % team


## Línea de equipos según modo (reusa labels existentes, sin cambiar la escena).
func _refresh_team_line() -> void:
	if match_man == null:
		return
	var mode: String = str(match_man.get("mode_id"))
	if mode == ModeData.MODE_DOMINATION:
		var sc: Dictionary = match_man.get("team_scores")
		targets_label.text = "Score T0 %d — T1 %d (1st %d)" % [int(sc.get(0, 0)), int(sc.get(1, 0)), GameConstants.DOMINATION_WIN_SCORE]
		lives_label.text = "[Domination]"
	elif mode == ModeData.MODE_VIP:
		targets_label.text = "[VIP: kill enemy VIP]"
		var tl: Dictionary = match_man.get("team_lives")
		lives_label.text = "Lives T0 %d — T1 %d" % [int(tl.get(0, 0)), int(tl.get(1, 0))]
	else:
		var tl2: Dictionary = match_man.get("team_lives")
		if not tl2.is_empty():
			lives_label.text = "Lives T0 %d — T1 %d" % [int(tl2.get(0, 0)), int(tl2.get(1, 0))]


func _set_round_result(result: String) -> void:
	round_result = result
	match result:
		"round_won":
			round_label.text = "ROUND WON — All targets destroyed.\nPress Enter to restart."
		"round_lost":
			round_label.text = "ROUND LOST — Out of lives.\nPress Enter to restart."
		_: round_label.text = ""
	_show_end_panel()


## Panel de fin de ronda con ganador por modo.
func _show_end_panel() -> void:
	if match_man == null:
		return
	var mode: String = str(match_man.get("mode_id"))
	var title := "VICTORY" if round_result == "round_won" else "DEFEAT"
	end_label.text = "%s\n[%s] %s" % [title, str(ModeData.get_def(mode)["display_name"]), _scoreboard_text()]
	end_panel.visible = true


## Texto del scoreboard: equipos, vivos, VIP y puntos según modo.
func _scoreboard_text() -> String:
	if match_man == null:
		return ""
	var lines: Array[String] = []
	var roster: Array = match_man.get("roster")
	var vip_map: Dictionary = match_man.get("vip")
	for team in [0, 1]:
		var alive := 0
		var total := 0
		var rows: Array[String] = []
		for p in roster:
			if p == null or not is_instance_valid(p):
				continue
			if p.team_id != team:
				continue
			total += 1
			var tag := "alive" if not p.respawning else "dead"
			if tag == "alive":
				alive += 1
			var star := " [VIP]" if vip_map.get(team, null) == p else ""
			rows.append("%s%s (%s)" % [str(ArmorData.get_def(p.armor_id)["display_name"]), star, tag])
		lines.append("%s %s: %d/%d alive" % [FactionData.team_name(team), "T%d" % team, alive, total])
		lines.append_array(rows)
	var mode: String = str(match_man.get("mode_id"))
	if mode == ModeData.MODE_DOMINATION:
		var sc: Dictionary = match_man.get("team_scores")
		lines.append("Score: T0 %d — T1 %d" % [int(sc.get(0, 0)), int(sc.get(1, 0))])
	return "\n".join(lines)


func _draw() -> void:
	if player == null:
		return
	_draw_crosshair()
	_draw_build_target()


func _draw_crosshair() -> void:
	var mouse := get_viewport().get_mouse_position()
	draw_line(mouse + Vector2(-8, 0), mouse + Vector2(-2, 0), Color(1, 1, 1, 0.9), 1.0)
	draw_line(mouse + Vector2(2, 0), mouse + Vector2(8, 0), Color(1, 1, 1, 0.9), 1.0)
	draw_line(mouse + Vector2(0, -8), mouse + Vector2(0, -2), Color(1, 1, 1, 0.9), 1.0)
	draw_line(mouse + Vector2(0, 2), mouse + Vector2(0, 8), Color(1, 1, 1, 0.9), 1.0)
	var wp := player.global_position
	var screen := get_viewport().get_canvas_transform() * wp
	var dist := mouse.distance_to(screen)
	var in_range := dist <= GameConstants.BUILD_RANGE_PX * get_viewport().get_canvas_transform().get_scale().x
	var col := Color(0.3, 0.9, 0.4, 0.85) if in_range else Color(0.9, 0.3, 0.3, 0.6)
	draw_circle_arc_at(mouse, 10.0, col)


func _draw_build_target() -> void:
	if construction == null:
		return
	var cell := construction.build_target_cell()
	if cell == ConstructionController.INVALID_CELL:
		return
	var world_center := construction.grid.cell_world_center(cell)
	var screen := get_viewport().get_canvas_transform() * world_center
	var half := GameConstants.GRID_SIZE * 0.5 * get_viewport().get_canvas_transform().get_scale().x
	draw_rect(Rect2(screen - Vector2(half, half), Vector2(half * 2, half * 2)), Color(0.3, 0.9, 0.4, 0.5), false, 1.5)


func draw_circle_arc_at(center: Vector2, radius: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(0, 33):
		var a := TAU * i / 32.0
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_polyline(pts, color, 1.0, true)