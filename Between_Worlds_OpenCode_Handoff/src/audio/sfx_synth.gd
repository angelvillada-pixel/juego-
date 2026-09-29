class_name SfxSynth
extends RefCounted
## Sintetizador procedural de SFX (Punto 4, provisional hasta audio final).
## Todo determinista (seed fija en ruido) y sin assets binarios: genera
## AudioStreamWAV mono 22050 Hz 16-bit con envolvente de decaimiento.

const SAMPLE_RATE := 22050

const NAMES := [
	"shoot_rifle", "shoot_precision", "shoot_pistol",
	"hit", "headshot", "pickup", "build", "destroy",
	"dash", "death", "respawn", "win", "lose", "click",
]


static func is_valid(name: String) -> bool:
	return NAMES.has(name)


## Genera el SFX pedido. Siempre devuelve un stream válido.
static func make(sfx_name: String) -> AudioStreamWAV:
	match sfx_name:
		"shoot_rifle":
			return _shot(880.0, 220.0, 0.09, 0.5)
		"shoot_precision":
			return _shot(1400.0, 180.0, 0.22, 0.6)
		"shoot_pistol":
			return _shot(660.0, 300.0, 0.07, 0.45)
		"hit":
			return _tone(520.0, 520.0, 0.06, 0.4, false)
		"headshot":
			return _tone(880.0, 1320.0, 0.09, 0.45, false)
		"pickup":
			return _tone(520.0, 1040.0, 0.12, 0.4, false)
		"build":
			return _tone(300.0, 480.0, 0.10, 0.4, false)
		"destroy":
			return _noise_hit(0.25, 0.55)
		"dash":
			return _noise_hit(0.12, 0.35)
		"death":
			return _tone(400.0, 90.0, 0.35, 0.5, false)
		"respawn":
			return _tone(300.0, 700.0, 0.15, 0.4, false)
		"win":
			return _arp([523.0, 659.0, 784.0, 1046.0], 0.09, 0.45)
		"lose":
			return _arp([392.0, 330.0, 262.0], 0.14, 0.45)
		_:
			return _tone(440.0, 440.0, 0.05, 0.3, false)  # click


## Tono con slide de frecuencia y decaimiento exponencial.
static func _tone(f0: float, f1: float, dur: float, vol: float, square: bool) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var k := float(i) / maxf(1.0, float(n - 1))
		var f := lerpf(f0, f1, k)
		phase += TAU * f / SAMPLE_RATE
		var s := sin(phase)
		if square:
			s = 1.0 if s >= 0.0 else -1.0
		s *= vol * exp(-3.0 * k) * (1.0 - k * 0.2)
		_write_sample(data, i, s)
	return _stream(data)


## Disparo: tono cuadrado con slide + golpe de ruido.
static func _shot(f0: float, f1: float, dur: float, vol: float) -> AudioStreamWAV:
	var stream := _tone(f0, f1, dur, vol, true)
	var data := stream.data
	var n := data.size() / 2
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var burst := mini(n, SAMPLE_RATE / 60)
	for i in range(burst):
		var old := _read_sample(data, i)
		_write_sample(data, i, old * 0.5 + rng.randf_range(-1.0, 1.0) * vol * 0.5)
	stream.data = data
	return stream


## Golpe de ruido filtrado por decaimiento (explosiones, dash, pasos).
static func _noise_hit(dur: float, vol: float) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var last := 0.0
	for i in range(n):
		var k := float(i) / maxf(1.0, float(n - 1))
		var s := rng.randf_range(-1.0, 1.0)
		last = last * 0.7 + s * 0.3  # pasa-bajos simple
		_write_sample(data, i, last * vol * exp(-4.0 * k))
	return _stream(data)


## Arpegio de tonos encadenados (win/lose).
static func _arp(freqs: Array, note_dur: float, vol: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	for f in freqs:
		var n := int(SAMPLE_RATE * note_dur)
		var start := data.size() / 2
		data.resize(data.size() + n * 2)
		var phase := 0.0
		for i in range(n):
			var k := float(i) / maxf(1.0, float(n - 1))
			phase += TAU * float(f) / SAMPLE_RATE
			_write_sample(data, start + i, sin(phase) * vol * exp(-2.0 * k))
	return _stream(data)


static func _write_sample(data: PackedByteArray, i: int, s: float) -> void:
	var v := int(clampf(s, -1.0, 1.0) * 32767.0)
	data.encode_s16(i * 2, v)


static func _read_sample(data: PackedByteArray, i: int) -> float:
	return float(data.decode_s16(i * 2)) / 32767.0


static func _stream(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
