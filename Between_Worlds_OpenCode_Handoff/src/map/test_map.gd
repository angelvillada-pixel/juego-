class_name TestMap
extends Node2D
## Mapa de laboratorio construido a partir de MapLayout (datos deterministas).

var grid: Grid
var cells: Array = []
var objectives_total := 0
var objectives_destroyed := 0
var map_id := MapData.MAP_LAB  # Punto 4: seleccionable con --map=lab|arena

var spawn_a := Vector2.ZERO
var spawn_b := Vector2.ZERO

signal target_destroyed(remaining: int, total: int)
signal objectives_cleared
signal map_ready

@onready var _block_scene := preload("res://src/construction/block.tscn")
@onready var _pickup_scene := preload("res://src/pickups/pickup.tscn")


func _ready() -> void:
	_build()


func _build() -> void:
	cells = MapLayout.generate(map_id)
	var cell_size := GameConstants.GRID_SIZE

	grid = Grid.new()
	grid.configure(Rect2i(0, 0, MapLayout.W, MapLayout.H))
	add_child(grid)

	for y in range(MapLayout.H):
		for x in range(MapLayout.W):
			var c: int = cells[y][x]
			if c == MapLayout.Cell.EMPTY:
				continue
			_spawn_map_cell(Vector2i(x, y), c)

	_place_pickups()

	# Puntos de spawn basados en celdas libres cercanas al suelo.
	spawn_a = grid.cell_world_center(MapLayout.find_first_empty_near(cells, Vector2i(MapLayout.W / 4, MapLayout.H - 4)))
	spawn_b = grid.cell_world_center(MapLayout.find_first_empty_near(cells, Vector2i(MapLayout.W * 3 / 4, MapLayout.H - 4)))

	if spawn_a == Vector2.ZERO: spawn_a = Vector2(256, 256)
	if spawn_b == Vector2.ZERO: spawn_b = Vector2(3072, 256)

	emit_signal("map_ready")
	queue_redraw()


## Fondo de territorios (Punto 4, solo lectura visual): cada mitad del mapa
## lleva el tinte de su facción + contorno sutil de las zonas de dominación.
func _draw() -> void:
	var rect := world_rect()
	var half := rect.size.x * 0.5
	var c0: Color = FactionData.team_color(0)
	var c1: Color = FactionData.team_color(1)
	c0.a = 0.05
	c1.a = 0.05
	draw_rect(Rect2(rect.position, Vector2(half, rect.size.y)), c0)
	draw_rect(Rect2(rect.position + Vector2(half, 0), Vector2(half, rect.size.y)), c1)
	for zone in domination_zones():
		var zc := Color(1, 1, 1, 0.10)
		draw_rect(zone, zc, false, 1.0)


func _spawn_map_cell(cell: Vector2i, kind: int) -> void:
	var block := _block_scene.instantiate()
	match kind:
		MapLayout.Cell.PERMANENT:
			block.setup(BlockData.BLOCK_DESTRUCTIBLE, cell)
			block.is_permanent = true
			grid.register_permanent(cell)
		MapLayout.Cell.DESTRUCTIBLE:
			block.setup(BlockData.BLOCK_DESTRUCTIBLE, cell)
			grid.add_block(block, cell)
		MapLayout.Cell.TARGET:
			block.setup(BlockData.BLOCK_TARGET, cell)
			grid.add_block(block, cell)
			objectives_total += 1
			block.destroyed.connect(_on_block_destroyed.bind(true))
		_:
			return
	block.global_position = grid.cell_world_center(cell)
	add_child(block)


func _place_pickups() -> void:
	var pick_types := [PickupData.PICKUP_HEALTH, PickupData.PICKUP_ARMOR, PickupData.PICKUP_AMMO]
	for y in [MapLayout.H - 12, MapLayout.H - 26]:
		for x in range(14, MapLayout.W - 14, 25):
			var cell := Vector2i(x, y)
			if not grid.is_free(cell):
				continue
			var pickup := _pickup_scene.instantiate()
			pickup.setup(pick_types[(x + y) % pick_types.size()])
			# Nombre determinista: mismo nombre en cliente y servidor (el claim
			# de pickup viaja como path relativa al TestMap).
			pickup.name = "pickup_%d_%d" % [x, y]
			pickup.global_position = grid.cell_world_center(cell)
			add_child(pickup)


func _on_block_destroyed(_block: Block, _is_target: bool) -> void:
	if not _is_target:
		return
	objectives_destroyed += 1
	emit_signal("target_destroyed", objectives_total - objectives_destroyed, objectives_total)
	if objectives_destroyed >= objectives_total:
		emit_signal("objectives_cleared")


func world_rect() -> Rect2:
	return Rect2(0, 0, MapLayout.W * GameConstants.GRID_SIZE, MapLayout.H * GameConstants.GRID_SIZE)


## Spawn por equipo e índice (5v5): dispersa en X alrededor del spawn base
## para no apilar jugadores. Determinista y sin aleatoriedad.
func spawn_for_team_index(team: int, index: int) -> Vector2:
	var base := spawn_a if team == 0 else spawn_b
	var offset := float(index - GameConstants.TEAM_SIZE / 2) * GameConstants.GRID_SIZE * 2.0
	return base + Vector2(offset, 0.0)


## Zonas de dominación (provisional Punto 2): 3 rects verticales
## izq/centro/der sobre el tercio inferior del mapa.
func domination_zones() -> Array[Rect2]:
	var rect := world_rect()
	var zone_w := rect.size.x / float(GameConstants.DOMINATION_ZONES)
	var zones: Array[Rect2] = []
	for i in range(GameConstants.DOMINATION_ZONES):
		zones.append(Rect2(
			rect.position.x + zone_w * i,
			rect.position.y + rect.size.y * 0.55,
			zone_w,
			rect.size.y * 0.45
		))
	return zones