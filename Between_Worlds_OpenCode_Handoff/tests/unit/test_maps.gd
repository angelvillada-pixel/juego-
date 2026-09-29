class_name TestMaps
extends RefCounted
## Punto 4: mapas data-driven (lab + arena) y facciones.


func run(ctx: Object) -> void:
	# Catálogo.
	ctx.check(MapData.is_valid(MapData.MAP_LAB), "Lab válido")
	ctx.check(MapData.is_valid(MapData.MAP_ARENA), "Arena válido")
	ctx.check(not MapData.is_valid("nuke"), "Mapa inventado rechazado")
	ctx.equals(MapData.get_def("nuke")["id"], MapData.MAP_LAB, "Mapa inválido cae al lab")

	# Lab idéntico al de M1 (compat): misma seed y salida determinista.
	var lab := MapLayout.generate(MapData.MAP_LAB)
	var lab2 := MapLayout.generate()
	ctx.equals(lab, lab2, "generate() por defecto = lab")
	ctx.check(MapLayout.count_of(lab, MapLayout.Cell.TARGET) > 0, "Lab con objetivos")

	# Arena: válido, determinista y distinto del lab.
	var arena := MapLayout.generate(MapData.MAP_ARENA)
	var arena2 := MapLayout.generate(MapData.MAP_ARENA)
	ctx.equals(arena, arena2, "Arena determinista")
	ctx.check(arena != lab, "Arena distinto del lab")
	ctx.equals(arena.size(), MapLayout.H, "Arena misma altura (Q8 abierta)")
	ctx.check(MapLayout.count_of(arena, MapLayout.Cell.DESTRUCTIBLE) > 0, "Arena con destruible")
	ctx.check(MapLayout.count_of(arena, MapLayout.Cell.TARGET) > 0, "Arena con objetivos")
	# Borde permanente en ambos.
	ctx.equals(arena[0][0], MapLayout.Cell.PERMANENT, "Arena borde permanente")
	# Spawns libres en arena.
	var cell := MapLayout.find_first_empty_near(arena, Vector2i(50, MapLayout.H - 4))
	ctx.equals(arena[cell.y][cell.x], MapLayout.Cell.EMPTY, "Spawn arena en celda libre")

	# Facciones: dos nombres y colores distintos, mismo poder (sin stats).
	ctx.check(FactionData.team_name(0) != FactionData.team_name(1), "Facciones con nombre distinto")
	ctx.check(FactionData.team_color(0) != FactionData.team_color(1), "Facciones con color distinto")
	ctx.equals(FactionData.team_name(99), FactionData.team_name(0), "Equipo inválido cae a Aegis")
