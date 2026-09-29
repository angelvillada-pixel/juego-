class_name TestTelemetry
extends RefCounted
## Punto 5: registro de eventos, contadores y volcado JSONL.


func run(ctx: Object) -> void:
	var tel: Node = ctx.root.get_node_or_null("Telemetry")
	if tel == null:
		ctx.check(false, "Autoload Telemetry disponible")
		return
	tel.enabled = true
	tel.base_dir = "user://test_telemetry"
	tel.start_session("frontline", "lab")
	tel.record("died", {"team": 0})
	tel.record("pickup", {"id": "health"})
	tel.inc("shots_rifle", 3)
	ctx.equals(tel.count_of("died"), 1, "Contador died")
	ctx.equals(tel.count_of("shots_rifle"), 3, "Contador shots")
	var summary: Dictionary = tel.end_session("won")
	ctx.equals(str(summary.get("result", "")), "won", "Resultado en resumen")
	ctx.equals(int(summary.get("events", 0)), 4, "4 eventos (start+died+pickup+end)")
	var path: String = tel.flush()
	ctx.check(path != "" and path.begins_with("user://test_telemetry/"), "Flush devuelve ruta")
	ctx.check(FileAccess.file_exists(path), "JSONL escrito")
	# Segunda sesión limpia contadores.
	tel.start_session("vip", "arena")
	ctx.equals(tel.count_of("died"), 0, "Contadores limpios por sesión")
	tel.enabled = true
	# Limpieza del dir de test.
	var dir := DirAccess.open("user://test_telemetry")
	if dir != null:
		for f in dir.get_files():
			dir.remove(f)
