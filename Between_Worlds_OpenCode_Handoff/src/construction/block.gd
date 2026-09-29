class_name Block
extends StaticBody2D
## Bloque con estado y colisión independiente del arte. Puede ser:
## - terreno destruible del mapa
## - objetivo de la partida de laboratorio
## - bloque construido por un jugador

var block_id: String = BlockData.BLOCK_BUILD
var def: Dictionary = {}
var max_hp := 100.0
var hp := 100.0
var cell := Vector2i.ZERO
var is_permanent := false
var is_target := false
var team_id := 0

signal destroyed(block: Block)
signal hp_changed(block: Block)

var _collision_shape: CollisionShape2D


func setup(p_block_id: String, p_cell: Vector2i, p_team: int = 0) -> void:
	block_id = p_block_id
	def = BlockData.get_def(block_id)
	cell = p_cell
	team_id = p_team
	max_hp = def["hp"]
	hp = max_hp
	is_target = def["is_target"]
	collision_layer = GameConstants.LAYER_WORLD
	collision_mask = 0
	_update_sprite()


func _ready() -> void:
	if def.is_empty():
		setup(block_id, cell, team_id)
	_ensure_collision_shape()


func _ensure_collision_shape() -> void:
	if _collision_shape != null and _collision_shape.is_inside_tree():
		return
	for child in get_children():
		if child is CollisionShape2D:
			_collision_shape = child
			return
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(GameConstants.GRID_SIZE, GameConstants.GRID_SIZE)
	cs.shape = shape
	add_child(cs)
	_collision_shape = cs


## Contract de bala. Recibe punto global y daño base (los bloques reciben daño íntegro).
func damage_from_bullet(_hit_position: Vector2, base_damage: float) -> void:
	apply_damage(base_damage)


func apply_damage(amount: float) -> void:
	if is_permanent or hp <= 0.0:
		return
	hp -= amount
	emit_signal("hp_changed", self)
	if hp <= 0.0:
		_destroy()


func _destroy() -> void:
	emit_signal("destroyed", self)
	queue_free()


func _update_sprite() -> void:
	queue_redraw()


func _draw() -> void:
	var col: Color = def.get("color", Color.WHITE) if not def.is_empty() else Color.WHITE
	if hp <= max_hp * 0.5:
		col = col.darkened(0.4)
	if is_permanent:
		col = Color("6c757d")
	var half := GameConstants.GRID_SIZE * 0.5
	draw_rect(Rect2(-half, -half, GameConstants.GRID_SIZE, GameConstants.GRID_SIZE), col)
	draw_rect(Rect2(-half, -half, GameConstants.GRID_SIZE, GameConstants.GRID_SIZE), def.get("outline", Color("2b2d42")), false, 1.0)
	# Punto 4: remache determinista por celda (variedad sin assets).
	var h: int = abs(cell.x * 73 + cell.y * 149) % 4
	var off := Vector2(-half + 3.0 + (h % 2) * 8.0, -half + 3.0 + (h / 2) * 8.0)
	draw_circle(off, 1.3, Color(0, 0, 0, 0.35))