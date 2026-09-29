class_name NetCodec
## Serialización de mensajes cliente<->servidor (Etapa 3).
## var_to_bytes/bytes_to_var soportan Vector2/Vector2i nativamente.
## SEGURIDAD: bytes_to_var sin objetos (no instancia clases del remitente).
## No depende de estado: wrapper puro y testeable.

const MAX_PACKET_BYTES := 16384


static func encode(msg: Dictionary) -> PackedByteArray:
	return var_to_bytes(msg)


## Devuelve Dictionary o {} si el payload no es válido (nunca lanza).
static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty() or bytes.size() > MAX_PACKET_BYTES:
		return {}
	var data: Variant = bytes_to_var(bytes)
	if data is Dictionary:
		return data
	return {}
