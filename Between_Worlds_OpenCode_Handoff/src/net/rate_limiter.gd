class_name RateLimiter
extends RefCounted
## Token bucket puro y determinista (Punto 3, anti-cheat).
## El tiempo se inyecta como parámetro para que los tests sean deterministas;
## el servidor pasa Time.get_ticks_msec()/1000.0.

var capacity := 0.0
var tokens := 0.0
var refill_per_sec := 0.0
var _last_t := -1.0


func _init(p_capacity: float = 1.0, p_refill_per_sec: float = 1.0) -> void:
	capacity = p_capacity
	tokens = p_capacity
	refill_per_sec = p_refill_per_sec


## Intenta consumir `amount` tokens en el instante `now_sec`. Devuelve true si había.
func consume(amount: float = 1.0, now_sec: float = 0.0) -> bool:
	_refill(now_sec)
	if tokens >= amount:
		tokens -= amount
		return true
	return false


func _refill(now_sec: float) -> void:
	if _last_t < 0.0:
		_last_t = now_sec
		return
	var dt := maxf(0.0, now_sec - _last_t)
	_last_t = now_sec
	tokens = minf(capacity, tokens + dt * refill_per_sec)
