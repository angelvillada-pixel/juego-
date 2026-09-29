class_name Grid
extends Node
## Rejilla de construcción. La autoridad sobre colocación/destrucción será del
## servidor en la etapa de networking; aquí es la capa de estado del mundo.

var cell_size := GameConstants.GRID_SIZE
var bounds := Rect2i()  # límites de celdas

var _cells := {}  # Vector2i -> Block
var _permanent_cells := {}  # Vector2i -> true

signal block_added(cell: Vector2i, block: Block)
signal block_removed(cell: Vector2i)


func configure(rect: Rect2i) -> void:
	bounds = rect


func register_permanent(cell: Vector2i) -> void:
	_permanent_cells[cell] = true


func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / float(cell_size))), int(floor(pos.y / float(cell_size))))


func cell_world_center(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * cell_size, (cell.y + 0.5) * cell_size)


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= bounds.position.x and cell.x < bounds.end.x and cell.y >= bounds.position.y and cell.y < bounds.end.y


func is_free(cell: Vector2i) -> bool:
	return in_bounds(cell) and not _cells.has(cell) and not _permanent_cells.has(cell)


func has_block(cell: Vector2i) -> bool:
	return _cells.has(cell)


func get_block(cell: Vector2i) -> Block:
	return _cells.get(cell, null)


func add_block(block: Block, cell: Vector2i) -> void:
	_cells[cell] = block
	block.cell = cell
	if not block.destroyed.is_connected(_on_block_destroyed):
		block.destroyed.connect(_on_block_destroyed)
	emit_signal("block_added", cell, block)


func remove_block(block: Block) -> void:
	var cell: Vector2i = block.cell
	if _cells.get(cell, null) == block:
		_cells.erase(cell)
		emit_signal("block_removed", cell)


func _on_block_destroyed(block: Block) -> void:
	remove_block(block)