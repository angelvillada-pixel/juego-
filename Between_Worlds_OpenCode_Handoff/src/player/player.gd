class_name Player
extends PlayerController
## Entidad de combate del jugador: vida, armadura, escudo temporal,
## armas primaria/secundaria, zonas de daño y respawn.
##
## Nota de arquitectura: en este vertical slice la simulación es local y este
## nodo actúa como la entidad del "servidor lógico" para daño/muerte/respawn.
## Más adelante esta clase será la entidad validada por el servidor dedicado.

var max_hp := GameConstants.MAX_HP
var hp := max_hp
var shield := 0.0
var max_shield := GameConstants.MAX_SHIELD  # provisional Punto 1: escudo temporal separado, máx 50

var weapons: Array[Weapon] = []
var active_weapon_index := 0
var respawning := false
var team_id := 0
## true cuando ESTA instancia es simulada en el servidor (Etapa 3): no lee
## Input/mouse locales; su entrada llega por mensajes MOVE y sus disparos por FIRE.
var net_controlled := false

var aim_angle := 0.0

# Utilidad (Punto 1, provisional): Dash con cooldown validado por el servidor.
var utility_id := UtilityData.UTILITY_DASH
var utility_cooldown_left := 0.0

@onready var weapon_arm: Node2D = $WeaponArm

signal hp_changed(current: float, maximum: float)
signal shield_changed(current: float, maximum: float)
signal weapon_switched(index: int)
signal ammo_changed(weapon: Weapon)
signal died
signal respawned
signal picked_up(pickup_id: String)


func _ready() -> void:
	super._ready()
	_build_default_loadout()
	hp = max_hp
	shield = 0.0
	queue_redraw()


func _build_default_loadout() -> void:
	for weapon_id in WeaponData.DEFAULT_LOADOUT_WEAPONS:
		var w := Weapon.new(weapon_id)
		weapon_arm.add_child(w)
		w.ammo_changed.connect(_on_weapon_ammo_changed.bind(w))
		weapons.append(w)
	_active_weapon_changed()


func _process(delta: float) -> void:
	if net_controlled:
		return  # el servidor dirige esta instancia; nada de input/visual local
	_update_aim()
	_update_fire_input()


func _physics_process(delta: float) -> void:
	_tick_utility_cooldown(delta)
	super._physics_process(delta)


func _update_aim() -> void:
	if respawning:
		return
	var mouse_pos := get_global_mouse_position()
	aim_angle = (mouse_pos - global_position).angle()
	weapon_arm.rotation = aim_angle
	# El brazo se espeja al apuntar hacia la izquierda.
	var scale_val := 1.0 if cos(aim_angle) >= 0.0 else -1.0
	weapon_arm.scale.y = scale_val


func _update_fire_input() -> void:
	if respawning:
		return
	if Input.is_action_pressed("fire_primary"):
		_fire_active_weapon()
	if Input.is_action_just_pressed("fire_secondary"):
		_fire_offhand_weapon()
	if Input.is_action_just_pressed("reload"):
		try_reload_active()
	if Input.is_action_just_pressed("switch_weapon"):
		switch_weapon((active_weapon_index + 1) % weapons.size())
	if Input.is_action_just_pressed("use_utility"):
		try_utility()


func can_use_utility() -> bool:
	return utility_cooldown_left <= 0.0 and not respawning


func _tick_utility_cooldown(delta: float) -> void:
	if utility_cooldown_left > 0.0:
		utility_cooldown_left = maxf(0.0, utility_cooldown_left - delta)


## El servidor aplica el efecto y el cooldown; aquí solo se envía la intención.
func try_utility() -> void:
	if not can_use_utility():
		return
	NetMsg.send_intent({"type": NetMsg.UTILITY, "direction": Vector2.from_angle(aim_angle), "ftick": NetMsg.client_peer_tick()})


## Efecto autoritativo del Dash: impulso horizontal en la dirección pedida.
## Llamado solo por Server.request_utility tras validar cooldown y respawn.
func apply_utility_dash(direction: Vector2) -> void:
	var impulse: float = UtilityData.impulse(utility_id)
	var dir := direction
	if dir.is_zero_approx():
		dir = Vector2.RIGHT
	dir = dir.normalized()
	# Dash horizontal de combate: conserva componente vertical (no rompe saltos).
	velocity.x = dir.x * impulse
	if absf(dir.x) < 0.1:
		velocity.x = (1.0 if cos(aim_angle) >= 0.0 else -1.0) * impulse
	utility_cooldown_left = UtilityData.cooldown_seconds(utility_id)


func active_weapon() -> Weapon:
	if weapons.is_empty():
		return null
	return weapons[active_weapon_index]


func offhand_weapon() -> Weapon:
	if weapons.size() < 2:
		return null
	return weapons[1] if active_weapon_index == 0 else weapons[0]


func _fire_active_weapon() -> void:
	if active_weapon() == null:
		return
	NetMsg.send_intent({
		"type": NetMsg.FIRE,
		"weapon_index": active_weapon_index,
		"direction": Vector2.from_angle(aim_angle),
		"ftick": NetMsg.client_peer_tick(),
	})


func _fire_offhand_weapon() -> void:
	var idx := 1 if active_weapon_index == 0 else 0
	if weapons.size() <= idx:
		return
	NetMsg.send_intent({
		"type": NetMsg.FIRE,
		"weapon_index": idx,
		"direction": Vector2.from_angle(aim_angle),
		"ftick": NetMsg.client_peer_tick(),
	})


## El servidor calcula el origen del disparo (brazo) a partir del estado de la sesión.


func switch_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size():
		return
	active_weapon_index = index
	emit_signal("weapon_switched", active_weapon_index)


## Contract de bala: recibe el punto de impacto en espacio GLOBAL.
func damage_from_bullet(hit_position: Vector2, base_damage: float) -> Dictionary:
	var zone := get_hit_zone(to_local(hit_position))
	var mitigation := ArmorData.mitigation(armor_id)
	var final := DamageService.final_damage(base_damage, zone, mitigation)
	var applied := DamageService.damage_to_armor_first(shield, hp, final)
	shield = applied["shield"]
	hp = applied["hp"]
	emit_signal("shield_changed", shield, max_shield)
	emit_signal("hp_changed", hp, max_hp)
	if hp <= 0.0:
		die()
	return {
		"zone": zone,
		"base_damage": base_damage,
		"final_damage": final,
		"hp_after": hp,
	}


func die() -> void:
	if respawning:
		return
	respawning = true
	velocity = Vector2.ZERO
	emit_signal("died")
	hide()


## Llamado por el Match manager cuando toca reaparecer.
func reset_for_respawn(spawn_position: Vector2) -> void:
	hp = max_hp
	shield = 0.0
	utility_cooldown_left = 0.0
	respawning = false
	global_position = spawn_position
	for w in weapons:
		w.reset()
	show()
	emit_signal("respawned")
	emit_signal("hp_changed", hp, max_hp)
	emit_signal("shield_changed", shield, max_shield)
	_active_weapon_changed()


func apply_pickup(pickup_id: String) -> void:
	emit_signal("picked_up", pickup_id)


func try_reload_active() -> void:
	NetMsg.send_intent({"type": NetMsg.RELOAD, "weapon_index": active_weapon_index})


func _on_weapon_ammo_changed(_magazine: int, _reserve: int, weapon: Weapon) -> void:
	emit_signal("ammo_changed", weapon)


func _active_weapon_changed() -> void:
	for i in weapons.size():
		var w: Weapon = weapons[i]
		w.visible = (i == active_weapon_index)
	emit_signal("weapon_switched", active_weapon_index)


func set_armor(p_armor_id: String) -> void:
	if armor_id != p_armor_id:
		armor_id = p_armor_id
	queue_redraw()


func _draw() -> void:
	# Punto 4: silueta por armadura + trim de equipo (ver PawnArt).
	PawnArt.draw_pawn(self, body_width, body_height_stand, armor_id, team_id, is_crouching())