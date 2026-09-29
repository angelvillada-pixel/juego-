class_name TestMapLayout
extends RefCounted
## Mapa de laboratorio: generación determinista y con estructura válida.


func run(ctx: Object) -> void:
	var cells := MapLayout.generate()

	# Dimensiones
	ctx.equals(cells.size(), MapLayout.H, "Número de filas correcto")
	for row in cells:
		ctx.equals(row.size(), MapLayout.W, "Ancho de fila correcto")

	# Borde permanente
	for x in range(MapLayout.W):
		ctx.equals(cells[0][x], MapLayout.Cell.PERMANENT, "Borde superior permanente")
		ctx.equals(cells[MapLayout.H - 1][x], MapLayout.Cell.PERMANENT, "Borde inferior permanente")
	for y in range(MapLayout.H):
		ctx.equals(cells[y][0], MapLayout.Cell.PERMANENT, "Borde izquierdo permanente")

	# Debe haber terreno destruible y objetivos
	var destructibles := MapLayout.count_of(cells, MapLayout.Cell.DESTRUCTIBLE)
	var targets := MapLayout.count_of(cells, MapLayout.Cell.TARGET)
	ctx.check(destructibles > 0, "Hay terreno destruible (%d celdas)" % destructibles)
	ctx.check(targets > 0, "Hay objetivos (%d)" % targets)

	# Spawns válidos en celdas libres
	for from in [Vector2i(50, MapLayout.H - 4), Vector2i(150, MapLayout.H - 4)]:
		var cell := MapLayout.find_first_empty_near(cells, from)
		ctx.equals(cells[cell.y][cell.x], MapLayout.Cell.EMPTY, "Spawn %s cae en celda libre" % cell)
		ctx.check(cell.y < MapLayout.H - 3, "Spawn cerca del suelo pero no dentro de él")

	# Determinismo: generar dos veces → mismo mapa
	var cells2 := MapLayout.generate()
	ctx.equals(cells, cells2, "Mapa determinista (misma seed)")