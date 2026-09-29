extends Node
## Autoload "Backend": perfil local, historial de partidas y servidores
## recientes (Punto 5, sin servidor central todavía). Todo persiste en
## ficheros locales; cuando exista backend real, esta será su fachada.

const MAX_RECENTS := 8
const MAX_HISTORY := 20

var profile_path := "user://profile.cfg"
var history_path := "user://matches.jsonl"

var callsign := "Rookie"
var client_id := ""
var auth_token := ""  # S3: token de sesión (se renueva en cada AUTH_OK)


func clear_auth_token() -> void:
	auth_token = ""
	_save_profile()


## Guarda el token de sesión (persistido para auto-JOIN).
func set_auth_token(value: String) -> void:
	auth_token = value
	_save_profile()


func _ready() -> void:
	_load_profile()


func set_callsign(value: String) -> void:
	var clean := value.strip_edges()
	if clean == "":
		return
	callsign = clean.left(16)
	_save_profile()


func get_callsign() -> String:
	return callsign


func get_client_id() -> String:
	if client_id == "":
		client_id = "%d-%d" % [Time.get_unix_time_from_system(), randi() % 100000]
		_save_profile()
	return client_id


func add_recent(url: String) -> void:
	var clean := url.strip_edges()
	if clean == "":
		return
	var cfg := ConfigFile.new()
	cfg.load(profile_path)
	var recents: Array = cfg.get_value("servers", "recent", [])
	recents.erase(clean)
	recents.push_front(clean)
	while recents.size() > MAX_RECENTS:
		recents.pop_back()
	cfg.set_value("servers", "recent", recents)
	cfg.save(profile_path)


func get_recents() -> Array:
	var cfg := ConfigFile.new()
	if cfg.load(profile_path) != OK:
		return []
	return cfg.get_value("servers", "recent", [])


## Guarda un resultado al historial (JSONL). Devuelve true si se escribió.
func record_match(data: Dictionary) -> bool:
	var row := data.duplicate()
	row["when"] = Time.get_datetime_string_from_system()
	row["callsign"] = callsign
	# FileAccess no tiene modo APPEND: se abre READ_WRITE y se salta al final.
	var f: FileAccess
	if FileAccess.file_exists(history_path):
		f = FileAccess.open(history_path, FileAccess.READ_WRITE)
		if f == null:
			return false
		f.seek_end()
	else:
		f = FileAccess.open(history_path, FileAccess.WRITE)
		if f == null:
			return false
	f.store_line(JSON.stringify(row))
	f.close()
	return true


## Lee las últimas N partidas del historial (más recientes primero).
func recent_matches(limit: int = 5) -> Array:
	var out: Array = []
	if not FileAccess.file_exists(history_path):
		return out
	var f := FileAccess.open(history_path, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "":
			continue
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary:
			out.append(parsed)
	f.close()
	out.reverse()
	return out.slice(0, mini(limit, out.size()))


func history_count() -> int:
	if not FileAccess.file_exists(history_path):
		return 0
	var n := 0
	var f := FileAccess.open(history_path, FileAccess.READ)
	if f == null:
		return 0
	while not f.eof_reached():
		if f.get_line().strip_edges() != "":
			n += 1
	f.close()
	return n


func _load_profile() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(profile_path) == OK:
		callsign = str(cfg.get_value("profile", "callsign", callsign))
		client_id = str(cfg.get_value("profile", "client_id", ""))
		auth_token = str(cfg.get_value("auth", "token", ""))


func _save_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.load(profile_path)  # conserva [servers] si existe
	cfg.set_value("profile", "callsign", callsign)
	if client_id == "":
		client_id = "%d-%d" % [Time.get_unix_time_from_system(), randi() % 100000]
	cfg.set_value("profile", "client_id", client_id)
	cfg.set_value("auth", "token", auth_token)
	cfg.save(profile_path)
