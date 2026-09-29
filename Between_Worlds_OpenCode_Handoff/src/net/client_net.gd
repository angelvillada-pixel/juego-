extends Node
## Autoload "Client": puerta de salida de las intenciones del jugador local.
## Serializa cada intención como mensaje Dictionary (solo datos primitivos:
## sin referencias a nodos, pensado para sockets) y la envía por el transporte
## activo: LocalTransport hoy (loopback), WebSocket/WebRTC en etapas 3-4.
## Nunca muta estado de juego: sólo transmite intenciones al Server.
##
## Punto 3: sella cada mensaje con `seq` (secuencia) y `t` (ms de envío);
## `confirm_ack(seq)` poda el buffer y estima RTT (para reconciliación).

var transport: NetTransport = null

var _next_seq := 1
var _send_times := {}  # seq -> ms de envío
var rtt_ms := 0.0
var sent_count := 0
var acked_count := 0
var peer_tick := 0  # Punto 3: último tick de servidor visto (lo actualiza el driver)


func setup(p_transport: NetTransport) -> void:
	transport = p_transport


func has_transport() -> bool:
	return transport != null


func send(msg: Dictionary) -> bool:
	if transport == null:
		push_warning("Client.send sin transporte activo: %s" % msg)
		return false
	if not msg.has("seq"):
		msg["seq"] = _next_seq
		_next_seq += 1
	if not msg.has("t"):
		msg["t"] = Time.get_ticks_msec()
	if not msg.has("proto"):
		msg["proto"] = NetMsg.PROTOCOL_VERSION
	_send_times[int(msg["seq"])] = int(msg["t"])
	sent_count += 1
	transport.send(msg)
	return true


## El driver de red llama esto con el `ack` del SNAPSHOT (ack acumulativo:
## confirma todo seq <= ack). Devuelve el RTT estimado en ms.
func confirm_ack(ack_seq: int) -> float:
	var now := Time.get_ticks_msec()
	var sample := -1
	if _send_times.has(ack_seq):
		sample = now - int(_send_times[ack_seq])
	var old := []
	for s in _send_times:
		if int(s) <= ack_seq:
			old.append(s)
	for s in old:
		_send_times.erase(s)
		acked_count += 1
	if sample >= 0:
		var base := rtt_ms if rtt_ms > 0.0 else float(sample)
		rtt_ms = lerpf(base, float(sample), 0.2)
	return rtt_ms


func ack_rate() -> float:
	if sent_count == 0:
		return 1.0
	return clampf(float(acked_count) / float(sent_count), 0.0, 1.0)


func reset_stats() -> void:
	_next_seq = 1
	_send_times.clear()
	rtt_ms = 0.0
	sent_count = 0
	acked_count = 0
	peer_tick = 0
