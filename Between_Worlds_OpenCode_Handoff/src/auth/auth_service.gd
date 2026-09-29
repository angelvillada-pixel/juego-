class_name AuthService
extends RefCounted
## S3: criptografía de cuentas, pura y sin estado (testeable sin árbol).
## - Passwords: PBKDF2-HMAC-SHA256, sal de 16 bytes, 10000 iteraciones.
##   HMAC manual sobre HashingContext (sin dependencias externas).
## - Tokens: 256 bits efectivos (rand + HMAC del secreto), TTL 24 h.
## - Callsigns: 3-16 [A-Za-z0-9_-], únicos case-insensitive.

const ITERATIONS := 10000
const SALT_LEN := 16
const TOKEN_RAND_LEN := 16
const TOKEN_TTL_SEC := 86400
const CALLSIGN_MIN := 3
const CALLSIGN_MAX := 16


## HMAC-SHA256 manual: H(K,m) con bloques de 64 bytes.
static func hmac_sha256(key: PackedByteArray, msg: PackedByteArray) -> PackedByteArray:
	var k := key.duplicate()  # PackedByteArray se aliasa: duplicar o mutamos al llamante
	if k.size() > 64:
		k = _sha256(k)
	while k.size() < 64:
		k.append(0)
	var ipad := PackedByteArray()
	var opad := PackedByteArray()
	ipad.resize(64)
	opad.resize(64)
	for i in range(64):
		ipad[i] = k[i] ^ 0x36
		opad[i] = k[i] ^ 0x5C
	var inner := _sha256(ipad + msg)
	return _sha256(opad + inner)


static func _sha256(data: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data)
	return ctx.finish()


## PBKDF2-HMAC-SHA256 de 32 bytes (RFC 2898, un bloque).
static func pbkdf2_sha256(password: PackedByteArray, salt: PackedByteArray, iterations: int) -> PackedByteArray:
	var block := salt + PackedByteArray([0, 0, 0, 1])
	var u := hmac_sha256(password, block)
	var out := u.duplicate()
	for i in range(1, iterations):
		u = hmac_sha256(password, u)
		for j in range(32):
			out[j] = out[j] ^ u[j]
	return out


## Crea un registro de password listo para persistir (hex).
static func hash_password(password: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var salt := PackedByteArray()
	salt.resize(SALT_LEN)
	for i in range(SALT_LEN):
		salt[i] = rng.randi() & 0xFF
	var dk := pbkdf2_sha256(password.to_utf8_buffer(), salt, ITERATIONS)
	return {"salt": salt.hex_encode(), "hash": dk.hex_encode(), "iter": ITERATIONS}


## Verifica contra un registro. Comparación sin cortocircuito.
static func verify_password(password: String, rec: Dictionary) -> bool:
	if not rec.has("salt") or not rec.has("hash") or not rec.has("iter"):
		return false
	var salt := hex_decode(str(rec["salt"]))
	var want := hex_decode(str(rec["hash"]))
	var iters := int(rec["iter"])
	if salt.is_empty() or want.size() != 32 or iters <= 0:
		return false
	var got := pbkdf2_sha256(password.to_utf8_buffer(), salt, iters)
	return _secure_eq(got, want)


static func _secure_eq(a: PackedByteArray, b: PackedByteArray) -> bool:
	if a.size() != b.size():
		return false
	var diff := 0
	for i in range(a.size()):
		diff |= a[i] ^ b[i]
	return diff == 0


## Decodifica hex (no existe from_hex en PackedByteArray de Godot 4.7).
static func hex_decode(s: String) -> PackedByteArray:
	var clean := s.strip_edges()
	if clean.is_empty() or clean.length() % 2 != 0:
		return PackedByteArray()
	var out := PackedByteArray()
	out.resize(clean.length() / 2)
	for i in range(out.size()):
		var pair := clean.substr(i * 2, 2)
		if not pair.is_valid_hex_number(false):
			return PackedByteArray()
		out[i] = pair.hex_to_int()
	return out


static func valid_callsign(name: String) -> bool:
	var s := name.strip_edges()
	if s.length() < CALLSIGN_MIN or s.length() > CALLSIGN_MAX:
		return false
	var re := RegEx.new()
	if re.compile("^[A-Za-z0-9_-]+$") != OK:
		return false
	return re.search(s) != null


## Clave de unicidad (case-insensitive).
static func callsign_key(name: String) -> String:
	return name.strip_edges().to_lower()


static func random_hex(nbytes: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var b := PackedByteArray()
	b.resize(nbytes)
	for i in range(nbytes):
		b[i] = rng.randi() & 0xFF
	return b.hex_encode()


## Token "rand.expiry.mac" con mac = HMAC(secret, rand|expiry|callsign).
static func make_token(secret: PackedByteArray, callsign: String, expiry_unix: int) -> String:
	var r := random_hex(TOKEN_RAND_LEN)
	var body := "%s|%d|%s" % [r, expiry_unix, callsign]
	var mac := hmac_sha256(secret, body.to_utf8_buffer()).hex_encode()
	return "%s.%d.%s" % [r, expiry_unix, mac]


## Devuelve el callsign si el token es auténtico y vigente, "" si no.
static func check_token(secret: PackedByteArray, token: String, callsign: String, now_unix: int) -> String:
	var parts := token.split(".")
	if parts.size() != 3:
		return ""
	var exp := parts[1].to_int()
	if exp <= now_unix:
		return ""
	var body := "%s|%s|%s" % [parts[0], parts[1], callsign]
	var want := hmac_sha256(secret, body.to_utf8_buffer()).hex_encode()
	if not _secure_eq(want.to_utf8_buffer(), String(parts[2]).to_utf8_buffer()):
		return ""
	return callsign
