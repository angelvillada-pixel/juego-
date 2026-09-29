class_name SimTransport
extends NetTransport
## Transporte de laboratorio (Punto 3): entrega con latencia y pérdida
## configurables para validar predicción/reconciliación sin red real.
## Determinista con `seed`. Para benchmarks de campo (WS vs WebRTC) ver docs.

var delay_ms := 0.0
var loss_pct := 0.0  # 0..100

var sent_count := 0
var delivered_count := 0
var dropped_count := 0

var _clock_ms := 0.0
var _queue: Array[Dictionary] = []  # {msg, due}
var _rng := RandomNumberGenerator.new()


func _init(p_delay_ms: float = 0.0, p_loss_pct: float = 0.0, p_seed: int = 12345) -> void:
	delay_ms = p_delay_ms
	loss_pct = clampf(p_loss_pct, 0.0, 100.0)
	_rng.seed = p_seed


func send(msg: Dictionary) -> void:
	sent_count += 1
	if _rng.randf() * 100.0 < loss_pct:
		dropped_count += 1
		return
	_queue.append({"msg": msg, "due": _clock_ms + delay_ms})


func poll(delta: float) -> void:
	_clock_ms += delta * 1000.0
	var ready: Array[Dictionary] = []
	var pending: Array[Dictionary] = []
	for item in _queue:
		if float(item["due"]) <= _clock_ms:
			ready.append(item)
		else:
			pending.append(item)
	_queue = pending
	for item in ready:
		delivered_count += 1
		emit_signal("message_received", item["msg"])


func pending_count() -> int:
	return _queue.size()
