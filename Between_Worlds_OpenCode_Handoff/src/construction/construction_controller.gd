class_name ConstructionController
extends Node
## Entrada local de construcción: calcula la celda objetivo (para el ghost del
## HUD) y envía INTENCIONES al Server, que valida y resuelve (Etapa 1 de red).

const INVALID_CELL := Vector2i(500000, 500000)

var grid: Grid
var player: Player


func setup(p_grid: Grid, p_player: Player) -> void:
	grid = p_grid
	player = p_player


func _process(_delta: float) -> void:
	if grid == null or player == null or player.respawning:
		return
	var target := build_target_cell()
	if target == INVALID_CELL:
		return
	if Input.is_action_just_pressed("build_place"):
		Client.send({"type": NetMsg.BUILD_PLACE, "cell": target})
	if Input.is_action_just_pressed("build_destroy"):
		Client.send({"type": NetMsg.BUILD_DESTROY, "cell": target})


func build_target_cell() -> Vector2i:
	if player == null:
		return INVALID_CELL
	var mouse := player.get_global_mouse_position()
	var cell := grid.world_to_cell(mouse)
	if player.global_position.distance_to(mouse) > GameConstants.BUILD_RANGE_PX:
		return INVALID_CELL
	return cell
