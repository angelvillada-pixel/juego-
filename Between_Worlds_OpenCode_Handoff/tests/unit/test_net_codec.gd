class_name TestNetCodec
extends RefCounted
## NetCodec: roundtrip y rechazo de payloads maliciosos.


func run(ctx: Object) -> void:
	# Roundtrip básico
	var msg := {"type": "fire", "weapon_index": 0, "direction": Vector2(0.7, -0.7), "cell": Vector2i(3, 4)}
	var decoded := NetCodec.decode(NetCodec.encode(msg))
	ctx.equals(str(decoded.get("type")), "fire", "type sobrevive al roundtrip")
	var dir: Vector2 = decoded.get("direction", Vector2.ZERO)
	ctx.approx(dir.x, 0.7, 0.0001, "Vector2.x roundtrip exacto")
	ctx.approx(dir.y, -0.7, 0.0001, "Vector2.y roundtrip exacto")
	ctx.equals(decoded.get("cell"), Vector2i(3, 4), "Vector2i roundtrip exacto")

	# Estructuras anidadas (snapshot-like)
	var snap := {"type": "snapshot", "players": {"1": {"p": [100.5, -40.25], "hp": 80.0, "alive": true}}}
	var dsnap := NetCodec.decode(NetCodec.encode(snap))
	var p1: Dictionary = dsnap["players"]["1"]
	ctx.approx(float(p1["p"][0]), 100.5, 0.001, "snapshot pos x")
	ctx.approx(float(p1["p"][1]), -40.25, 0.001, "snapshot pos y")
	ctx.equals(p1["alive"], true, "snapshot alive")

	# Basura: no lanza, devuelve {}
	ctx.equals(NetCodec.decode(PackedByteArray()), {}, "bytes vacíos -> {}")
	ctx.equals(NetCodec.decode(PackedByteArray([1, 2, 3, 255, 0, 13])), {}, "bytes basura -> {}")
	var raw_text := "hola esto no es un mensaje".to_utf8_buffer()
	ctx.equals(NetCodec.decode(raw_text), {}, "texto plano -> {}")
	# Un payload enorme se rechaza por tamaño
	var huge := PackedByteArray()
	huge.resize(NetCodec.MAX_PACKET_BYTES + 1)
	ctx.equals(NetCodec.decode(huge), {}, "payload > MAXPACKET rechazado")
