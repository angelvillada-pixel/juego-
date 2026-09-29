class_name Weapon
extends Node2D
## Arma de prueba (data-driven). Hitscan por defecto. Daño únicamente, sin knockback.

var weapon_id: String = ""
var def: Dictionary = {}
var magazine := 0
var reserve := 0

var _cooldown_left := 0.0
var _reloading := false
var _reload_elapsed := 0.0
var _reload_take := 0

signal fired
signal ammo_changed(magazine: int, reserve: int)
signal reload_started
signal reload_finished


func _init(p_weapon_id: String = "") -> void:
	if p_weapon_id != "":
		setup(p_weapon_id)


func setup(p_weapon_id: String) -> void:
	weapon_id = p_weapon_id
	def = WeaponData.get_def(weapon_id)
	magazine = def["magazine_size"]
	reserve = def["reserve_max"]


func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)
	if _reloading:
		_reload_elapsed += delta
		if _reload_elapsed >= def["reload_time"]:
			_finish_reload()


func can_fire() -> bool:
	return _cooldown_left <= 0.0 and magazine > 0 and not _reloading


func start_reload() -> void:
	if _reloading:
		return
	if magazine >= int(def["magazine_size"]):
		return
	if reserve <= 0:
		return
	_reloading = true
	_reload_elapsed = 0.0
	var needed := int(def["magazine_size"]) - magazine
	_reload_take = mini(needed, reserve)
	emit_signal("reload_started")


func _finish_reload() -> void:
	reserve -= _reload_take
	magazine += _reload_take
	_reloading = false
	_reload_take = 0
	emit_signal("reload_finished")
	emit_signal("ammo_changed", magazine, reserve)


func is_reloading() -> bool:
	return _reloading


func reload_ratio() -> float:
	return clampf(_reload_elapsed / def["reload_time"], 0.0, 1.0) if _reloading else 0.0


## Dispara (hitscan). Devuelve información del impacto si lo hubo.
## Contract: el colisionador debe implementar damage_from_bullet(pos_global, base_damage).
func try_fire(world: World2D, source: Vector2, direction: Vector2, exclude: Array[RID]) -> Dictionary:
	if not can_fire():
		return {}
	magazine -= 1
	_cooldown_left = WeaponData.cooldown_seconds(weapon_id)
	emit_signal("fired")

	var query := PhysicsRayQueryParameters2D.create(
		source,
		source + direction * float(def["range"]),
		GameConstants.LAYER_WORLD | GameConstants.LAYER_PLAYER,
		exclude
	)
	var result := world.direct_space_state.intersect_ray(query)
	emit_signal("ammo_changed", magazine, reserve)

	if result.is_empty():
		return {"hit": false}
	var collider: Object = result["collider"]
	var hit_point: Vector2 = result["position"]
	if collider != null and collider.has_method("damage_from_bullet"):
		var dmg: float = def["damage"]
		# Daño a estructuras separado del daño a jugadores (provisional Punto 1).
		if collider is Block:
			dmg = float(def["damage"]) * WeaponData.structure_multiplier(weapon_id)
		collider.damage_from_bullet(hit_point, dmg)
	return {"hit": true, "position": hit_point, "collider": collider}


func refill_reserve(fraction: float) -> void:
	reserve = PickupService.apply_ammo(reserve, int(def["reserve_max"]), fraction)
	emit_signal("ammo_changed", magazine, reserve)


func reset() -> void:
	magazine = int(def["magazine_size"])
	reserve = int(def["reserve_max"])
	_cooldown_left = 0.0
	_reloading = false
	_reload_elapsed = 0.0
	emit_signal("ammo_changed", magazine, reserve)


func _draw() -> void:
	# Barra del arma + cargador simple, orientados hacia +X (el brazo rota).
	draw_rect(Rect2(0, -2.5, 16, 5), Color("2b2d42"))
	draw_rect(Rect2(10, -4, 6, 3), Color("495057"))
	if _reloading:
		draw_rect(Rect2(-2, -6, 12, 3), Color("e63946"))