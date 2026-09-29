extends Node
## Autoload "Audio": SFX procedurales + volumen persistido (Punto 4).
## Sin assets: los sonidos se sintetizan una vez al arrancar (SfxSynth) y se
## reproducen en un pool de 8 voces. La música es un pad ambiental en loop.

const POOL_SIZE := 8
const SETTINGS_PATH := "user://settings.cfg"

var sfx_volume := 0.8
var music_volume := 0.5

var _streams := {}
var _voices: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer


func _ready() -> void:
	for sfx_name in SfxSynth.NAMES:
		_streams[sfx_name] = SfxSynth.make(sfx_name)
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_voices.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	add_child(_music_player)
	_music_player.stream = _make_pad_loop()
	_load_settings()
	_apply_volumes()


func play(sfx_name: String) -> void:
	if not _streams.has(sfx_name):
		return
	for v in _voices:
		if not v.playing:
			v.stream = _streams[sfx_name]
			v.play()
			return
	# Sin voces libres: se descarta (no se apila para evitar avalanchas).


func play_shot(weapon_id: String) -> void:
	match weapon_id:
		WeaponData.WEAPON_PRECISION:
			play("shoot_precision")
		WeaponData.WEAPON_PISTOL:
			play("shoot_pistol")
		_:
			play("shoot_rifle")


func start_music() -> void:
	if not _music_player.playing:
		_music_player.play()


func stop_music() -> void:
	_music_player.stop()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()
	_save_settings()


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()
	_save_settings()


func _apply_volumes() -> void:
	var sfx_db := linear_to_db(maxf(sfx_volume, 0.001)) if sfx_volume > 0.0 else -60.0
	for v in _voices:
		v.volume_db = sfx_db
	_music_player.volume_db = (linear_to_db(maxf(music_volume, 0.001)) - 6.0) if music_volume > 0.0 else -60.0


## Pad ambiental de 6 s en loop (dos osciladores + envolvente lenta).
func _make_pad_loop() -> AudioStreamWAV:
	var secs := 6.0
	var n := int(SfxSynth.SAMPLE_RATE * secs)
	var data := PackedByteArray()
	data.resize(n * 2)
	var freqs := [110.0, 165.0, 220.0]
	for i in range(n):
		var t := float(i) / SfxSynth.SAMPLE_RATE
		var env := 0.6 + 0.4 * sin(TAU * t / secs)
		var s := 0.0
		for f in freqs:
			s += sin(TAU * f * t)
		s = s / float(freqs.size()) * 0.30 * env
		# Fundido en los bordes para loop limpio.
		var edge := minf(1.0, minf(float(i), float(n - i)) / (SfxSynth.SAMPLE_RATE * 0.5))
		SfxSynth._write_sample(data, i, s * edge)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SfxSynth.SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = n
	return stream


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		sfx_volume = clampf(float(cfg.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
		music_volume = clampf(float(cfg.get_value("audio", "music", music_volume)), 0.0, 1.0)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.save(SETTINGS_PATH)
