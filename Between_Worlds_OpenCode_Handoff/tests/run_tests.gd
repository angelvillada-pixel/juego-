extends SceneTree
## Runner de tests headless: godot --headless --path . -s res://tests/run_tests.gd
## Exit code 0 = todo OK, 1 = fallos.
## Nota: se ejecuta en _initialize() (MainLoop), DESPUÉS de que existan los
## autoloads (Game, Server, Match); en _init() las referencias a autoloads
## como Server aún no son resolubles al compilar los scripts de juego.

var passed := 0
var failed := 0
var failures: Array[String] = []


func _initialize() -> void:
	# Los _ready de nodos de juego (Player._ready -> loadout) exigen que el
	# root ya esté dentro del árbol: esperamos al primer frame.
	process_frame.connect(_run_all, Object.ConnectFlags.CONNECT_ONE_SHOT)


func _run_all() -> void:
	var test_scripts := [
		"res://tests/unit/test_damage.gd",
		"res://tests/unit/test_armor.gd",
		"res://tests/unit/test_pickup.gd",
		"res://tests/unit/test_construction.gd",
		"res://tests/unit/test_respawn.gd",
		"res://tests/unit/test_map_layout.gd",
		"res://tests/unit/test_server.gd",
		"res://tests/unit/test_net_loopback.gd",
		"res://tests/unit/test_net_codec.gd",
		"res://tests/unit/test_ws_transport.gd",
		"res://tests/unit/test_movement.gd",
		"res://tests/unit/test_balance_point1.gd",
		"res://tests/unit/test_utility.gd",
		"res://tests/unit/test_modes.gd",
		"res://tests/unit/test_netcode_point3.gd",
		"res://tests/unit/test_audio.gd",
		"res://tests/unit/test_maps.gd",
		"res://tests/unit/test_telemetry.gd",
		"res://tests/unit/test_backend.gd",
		"res://tests/unit/test_security_s1.gd",
		"res://tests/unit/test_security_s2.gd",
		"res://tests/unit/test_auth_s3.gd",
	]
	print("\n========== Between Worlds — Unit Tests ==========")
	for path in test_scripts:
		_run_script(path)

	print("\n================================================")
	print("PASSED: %d   FAILED: %d" % [passed, failed])
	if not failures.is_empty():
		print("Failures:")
		for f in failures:
			print("  - " + f)
	quit(1 if failed > 0 else 0)


func _run_script(path: String) -> void:
	var script := load(path)
	if script == null:
		check(false, "No se pudo cargar el script: %s" % path)
		return
	var inst = script.new()
	if not inst.has_method("run"):
		check(false, "Test sin metodo run(): %s" % path)
		return
	print("\n--- %s ---" % path)
	var before := passed + failed
	inst.run(self)
	print("  [%d checks] %s" % [passed + failed - before, path])


func check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		failures.append(label)
		print("  FAIL: " + label)


## Fixture compartido: Player fuera de escena necesita WeaponArm + CollisionShape2D.
## NOTA: sin tipos de juego en la firma — este script se compila en el arranque,
## antes de que existan los autoloads (Game/Server/Client/Match). Referenciar
## clases de juego aquí rompe la compilación de run_tests.gd (carga dinámica).
func spawn_test_player() -> Node:
	var p: Node = load("res://src/player/player.gd").new()
	var arm := Node2D.new()
	arm.name = "WeaponArm"
	arm.position = Vector2(6, -12)
	p.add_child(arm)
	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 24)
	col.shape = shape
	p.add_child(col)
	root.add_child(p)
	return p


func equals(a: Variant, b: Variant, label: String) -> void:
	if a == b:
		passed += 1
	else:
		failed += 1
		failures.append(label + " (got %s, want %s)" % [str(a), str(b)])
		print("  FAIL: %s (got %s, want %s)" % [label, str(a), str(b)])


func approx(a: float, b: float, eps := 0.001, label := "") -> void:
	equals(absf(a - b) <= eps, true, "%s (%s ≈ %s)" % [label, str(a), str(b)])