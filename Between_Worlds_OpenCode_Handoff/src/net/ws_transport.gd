class_name WsTransport
extends NetTransport
## Transporte WebSocket (Etapa 3). Envuelve un WebSocketPeer: sirve para el
## cliente (connect_to_url) y para el servidor (wrap de un peer aceptado).
## Poll manual: lo conducen Server (peers) o Client (conexión local).

const DEFAULT_PORT := 26500
const MAX_BUFFER_BYTES := 1024 * 64

var peer: WebSocketPeer = null
var _was_open := false


## Modo cliente.
func connect_to_server(url: String) -> bool:
	close()
	peer = WebSocketPeer.new()
	var err := peer.connect_to_url(url)
	if err != OK:
		peer = null
		return false
	return true


## Modo servidor: envuelve un peer ya aceptado por el listener.
static func from_accepted_peer(p: WebSocketPeer) -> WsTransport:
	var t := WsTransport.new()
	t.peer = p
	t._was_open = false
	return t


func poll(_delta: float) -> void:
	if peer == null:
		return
	peer.poll()
	var state := peer.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _was_open:
			_was_open = true
			emit_signal("connected")
		while peer.get_available_packet_count() > 0:
			var msg := NetCodec.decode(peer.get_packet())
			if msg.is_empty():
				continue
			emit_signal("message_received", msg)
	elif state == WebSocketPeer.STATE_CLOSED:
		if _was_open:
			_was_open = false
			emit_signal("disconnected")


func send(msg: Dictionary) -> void:
	if peer == null or peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	peer.send(NetCodec.encode(msg), WebSocketPeer.WRITE_MODE_BINARY)


func is_open() -> bool:
	return peer != null and peer.get_ready_state() == WebSocketPeer.STATE_OPEN


func close() -> void:
	if peer != null:
		if peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
			peer.close()
		peer = null
	_was_open = false
