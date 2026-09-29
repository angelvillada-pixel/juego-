class_name MapLayout
## Mapa generado a partir de PARÁMETROS (datos), no lógica hardcodeada.
## Grid de 200x112 celdas (3200x1792 px ~ objetivo 3200x1800).
## El generador es determinista (seed por mapa) → mismo mapa en cada
## ejecución y cliente. `generate()` sin args = lab (compat con tests M1).

enum Cell { EMPTY, PERMANENT, DESTRUCTIBLE, TARGET }

const W := GameConstants.MAP_W_CELLS
const H := GameConstants.MAP_H_CELLS

const SEED := 177013  # compat: seed del lab
const DEFAULT_MAP := MapData.MAP_LAB

## Celdas del mapa: Array de H filas, cada una con W valores de Cell.
static func generate(map_id: String = DEFAULT_MAP) -> Array:
	var def := MapData.get_def(map_id)
	var cells: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = int(def["seed"])
	var bands: Array = def["platform_bands"]
	var covers: Array = def["cover_bands"]
	var rows: Array = def["target_rows"]
	for y in range(H):
		var row: Array = []
		for x in range(W):
			var c := Cell.EMPTY
			if x <= 0 or y <= 0 or x >= W - 1 or y >= H - 1:
				c = Cell.PERMANENT
			elif y >= H - 3:
				# Suelo: base sólida + secciones destruibles.
				c = Cell.PERMANENT if y >= H - 1 else (Cell.DESTRUCTIBLE if rng.randf() < float(def["ground_ratio"]) else Cell.PERMANENT)
			elif _band_hit(bands, y):
				# Plataformas de cobertura por bandas.
				if x % 9 != 7:
					c = Cell.DESTRUCTIBLE
			elif _band_hit(covers, y):
				if x % 7 == 3:
					c = Cell.DESTRUCTIBLE
			elif _is_target_cell(x, y, def):
				c = Cell.TARGET
			row.append(c)
		cells.append(row)
	return cells


static func _band_hit(bands: Array, y: int) -> bool:
	for b in bands:
		if y == H - int(b):
			return true
	return false


static func _is_target_cell(x: int, y: int, def: Dictionary) -> bool:
	if x % int(def["target_mod"]) != int(def["target_off"]):
		return false
	for r in def["target_rows"]:
		if y == H - int(r):
			return true
	return false


## Busca la primera celda libre cerca de la posición solicitada para spawns.
static func find_first_empty_near(cells: Array, from: Vector2i) -> Vector2i:
	var radius := 0
	while radius < H:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var c := from + Vector2i(dx, dy)
				if c.x < 0 or c.y < 0 or c.x >= W or c.y >= H:
					continue
				if cells[c.y][c.x] == Cell.EMPTY:
					return c
		radius += 1
	return from


static func count_of(cells: Array, wanted: int) -> int:
	var total := 0
	for y in range(H):
		for x in range(W):
			if cells[y][x] == wanted:
				total += 1
	return total
