class_name TestBackend
extends RefCounted
## Punto 5: perfil local, servidores recientes e historial de partidas.


func run(ctx: Object) -> void:
	var be: Node = ctx.root.get_node_or_null("Backend")
	if be == null:
		ctx.check(false, "Autoload Backend disponible")
		return
	be.profile_path = "user://test_profile.cfg"
	be.history_path = "user://test_matches.jsonl"
	if FileAccess.file_exists(be.history_path):
		DirAccess.remove_absolute(be.history_path)
	if FileAccess.file_exists(be.profile_path):
		DirAccess.remove_absolute(be.profile_path)

	# Callsign con tope y saneado.
	be.set_callsign("  Nova-7  ")
	ctx.equals(be.get_callsign(), "Nova-7", "Callsign saneado")
	be.set_callsign("   ")
	ctx.equals(be.get_callsign(), "Nova-7", "Vacío no borra")
	be.set_callsign("0123456789ABCDEFGHIJ")
	ctx.check(be.get_callsign().length() <= 16, "Callsign topado a 16")

	# Client id estable.
	var id1: String = be.get_client_id()
	var id2: String = be.get_client_id()
	ctx.check(id1 != "" and id1 == id2, "Client id estable")

	# Recientes: sin duplicados, tope 8.
	be.add_recent("ws://127.0.0.1:26500")
	be.add_recent("ws://127.0.0.1:26500")
	be.add_recent("ws://arena:26501")
	var recents: Array = be.get_recents()
	ctx.equals(recents.size(), 2, "Sin duplicados")
	ctx.equals(str(recents[0]), "ws://arena:26501", "Más reciente primero")
	for i in range(12):
		be.add_recent("ws://srv%d:26500" % i)
	ctx.check(be.get_recents().size() <= 8, "Tope 8 recientes")

	# Historial: append + lectura última-primero.
	ctx.check(be.record_match({"mode": "frontline", "result": "won"}), "Match guardado")
	ctx.check(be.record_match({"mode": "vip", "result": "lost"}), "Match 2 guardado")
	ctx.equals(be.history_count(), 2, "2 partidas en historial")
	var last: Array = be.recent_matches(1)
	ctx.equals(last.size(), 1, "recent_matches(1)")
	ctx.equals(str(last[0].get("mode", "")), "vip", "La más reciente primero")

	# Limpieza.
	if FileAccess.file_exists(be.history_path):
		DirAccess.remove_absolute(be.history_path)
	if FileAccess.file_exists(be.profile_path):
		DirAccess.remove_absolute(be.profile_path)
	be.profile_path = "user://profile.cfg"
	be.history_path = "user://matches.jsonl"
	be._load_profile()
