extends Node
## Autoload "Telemetry": registro de eventos y métricas de balance (Punto 5).
## Solo lectura/escritura de logs: jamás decide gameplay. Los datos se vuelcan
## a JSONL en `base_dir` al cerrar la sesión. Ver docs/TELEMETRY.md.

const MAX_EVENTS := 5000

var enabled := true
var base_dir := "user://telemetry"

var _session := ""
var _t0_msec := 0
var _events: Array[Dictionary] = []
var _counters := {}
var _meta := {}


func start_session(mode_id: String, map_id: String) -> void:
	_session = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	_t0_msec = Time.get_ticks_msec()
	_events.clear()
	_counters.clear()
	_meta = {"mode": mode_id, "map": map_id}
	record("session_start", _meta.duplicate())


func end_session(result: String) -> Dictionary:
	record("session_end", {"result": result})
	var out := summary()
	out["result"] = result
	return out


func record(event_name: String, data: Dictionary = {}) -> void:
	if not enabled:
		return
	if _events.size() >= MAX_EVENTS:
		_events.pop_front()
	_events.append({
		"t": (Time.get_ticks_msec() - _t0_msec) / 1000.0,
		"event": event_name,
		"data": data,
	})
	_counters[event_name] = int(_counters.get(event_name, 0)) + 1


func inc(counter: String, n: int = 1) -> void:
	_counters[counter] = int(_counters.get(counter, 0)) + n


func count_of(event_name: String) -> int:
	return int(_counters.get(event_name, 0))


func summary() -> Dictionary:
	return {
		"session": _session,
		"meta": _meta,
		"counters": _counters.duplicate(),
		"events": _events.size(),
	}


## Vuelca la sesión a JSONL y limpia. Devuelve la ruta o "" si está vacío.
func flush() -> String:
	if _events.is_empty():
		return ""
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.make_dir_recursive(base_dir.trim_prefix("user://"))
	var path := "%s/session_%s.jsonl" % [base_dir, _session if _session != "" else "unsessioned"]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Telemetry: no se pudo escribir %s" % path)
		return ""
	for e in _events:
		f.store_line(JSON.stringify(e))
	f.close()
	_events.clear()
	return path
