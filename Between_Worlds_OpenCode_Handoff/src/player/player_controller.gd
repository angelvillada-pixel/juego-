class_name PlayerController
extends CharacterBody2D
## Controlador de movimiento 2D inspirado en Fortoresse (reglas explícitas y deterministas).
## - Velocidad horizontal según armadura: Light +10%, Medium 0%, Heavy -10%.
## - Salto y gravedad compartidos por todas las armaduras.
## - Saltos también válidos al construir sobre ellos (control de aire razonable).

@export var armor_id := ArmorData.ARMOR_MEDIUM:
	set(value):
		armor_id = value
		_apply_armor()

@export var body_width := 12.0
@export var body_height_stand := 24.0
@export var body_height_crouch := 14.0

var _crouching := false
var _base_max_speed := GameConstants.BASE_RUN_SPEED

# Entrada por red (Etapa 3): cuando use_net_input es true el movimiento se
# gobierna desde estos campos en vez del singleton Input. El servidor los
# rellena desde mensajes MOVE; el cliente local sigue usando Input.
var use_net_input := false
var net_axis := 0.0
var net_jump_edge := false
var net_crouch := false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

signal armor_changed(armor_id: String)


func _ready() -> void:
	_apply_armor()
	_update_collider()


func _apply_armor() -> void:
	_base_max_speed = ArmorData.movement_speed(armor_id)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_update_movement(delta)
	move_and_slide()


func _update_movement(delta: float) -> void:
	var input_dir := _input_axis()
	_update_crouch_state()

	var max_speed := _current_max_speed()
	if is_on_floor():
		if input_dir != 0.0:
			velocity.x = move_toward(velocity.x, input_dir * max_speed, GameConstants.GROUND_ACCEL * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, GameConstants.GROUND_FRICTION * delta)
	else:
		velocity.x = _air_move(input_dir, max_speed, delta)

	if _jump_pressed() and is_on_floor():
		velocity.y = GameConstants.JUMP_VELOCITY
	_consume_jump_edge()

	if not is_on_floor():
		velocity.y = move_toward(velocity.y, GameConstants.MAX_FALL_SPEED, absf(get_gravity().y) * delta)


## Fuente de entrada: Input local o estado de red (mismo conjunto de reglas).
func _input_axis() -> float:
	if use_net_input:
		return net_axis
	return Input.get_axis("move_left", "move_right")


func _jump_pressed() -> bool:
	if use_net_input:
		return net_jump_edge
	return Input.is_action_just_pressed("jump")


func _consume_jump_edge() -> void:
	net_jump_edge = false


func _update_crouch_state() -> void:
	var want_crouch := _crouch_held() and is_on_floor()
	if want_crouch != _crouching:
		_crouching = want_crouch
		_update_collider()
		queue_redraw()


func _crouch_held() -> bool:
	if use_net_input:
		return net_crouch
	return Input.is_action_pressed("crouch")


func _air_move(input_dir: float, max_speed: float, _delta: float) -> float:
	# El jugador conserva su velocidad en el aire; puede corregir rumbo hasta el límite.
	if input_dir != 0.0:
		return clampf(velocity.x + input_dir * GameConstants.AIR_ACCEL * _delta, -max_speed, max_speed)
	return velocity.x


func _current_max_speed() -> float:
	if _crouching:
		return _base_max_speed * GameConstants.CROUCH_SPEED_FACTOR
	return _base_max_speed


func _update_collider() -> void:
	if collision_shape == null or collision_shape.shape == null:
		return
	var rect := collision_shape.shape as RectangleShape2D
	if rect == null:
		return
	if _crouching:
		rect.size = Vector2(body_width, body_height_crouch)
		collision_shape.position.y = -rect.size.y * 0.5
	else:
		rect.size = Vector2(body_width, body_height_stand)
		collision_shape.position.y = -rect.size.y * 0.5


## Caja de la cabeza usada para detectar HEAD en un impacto (espacio local).
func head_rect() -> Rect2:
	# La cabeza es la parte superior del hitbox (provisional: 8px superiores).
	var height := body_height_crouch if _crouching else body_height_stand
	var top_height := minf(8.0, height * 0.4)
	return Rect2(-body_width * 0.5, -height, body_width, top_height)


func body_rect() -> Rect2:
	var height := body_height_crouch if _crouching else body_height_stand
	return Rect2(-body_width * 0.5, -height, body_width, height)


## Determina la zona de daño para un punto de impacto (espacio local del jugador).
func get_hit_zone(local_point: Vector2) -> HitZone.Zone:
	if head_rect().has_point(local_point):
		return HitZone.Zone.HEAD
	return HitZone.Zone.BODY


func is_crouching() -> bool:
	return _crouching


func _draw() -> void:
	# Fallback genérico; Player lo sobrescribe con PawnArt (silueta + equipo).
	var rect_height := body_height_crouch if _crouching else body_height_stand
	var armor_col: Color = ArmorData.get_def(armor_id)["color"]
	draw_rect(Rect2(-body_width * 0.5, -rect_height, body_width, rect_height), armor_col)
	draw_rect(Rect2(-body_width * 0.5, -rect_height, body_width, 8.0), Color(1, 1, 1, 0.25))
	draw_rect(Rect2(-body_width * 0.5, -rect_height, body_width, 2.0), Color(0, 0, 0, 0.6))