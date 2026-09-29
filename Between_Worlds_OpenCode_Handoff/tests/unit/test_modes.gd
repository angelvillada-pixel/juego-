class_name TestModes
extends RefCounted
## Punto 2: modos FRONTLINE/VIP/DOMINATION data-driven, roster 5v5,
## victoria autoritativa (Match local + Server).


class StubMap:
	extends Node
	var objectives_total := 0
	var spawn_a := Vector2(100, 100)
	var spawn_b := Vector2(900, 100)
	signal target_destroyed(remaining: int, total: int)
	signal objectives_cleared
	func spawn_for_team_index(team: int, index: int) -> Vector2:
		var base := spawn_a if team == 0 else spawn_b
		return base + Vector2(index * 32.0, 0.0)
	func domination_zones() -> Array:
		return [Rect2(0, 0, 400, 400), Rect2(400, 0, 400, 400), Rect2(800, 0, 400, 400)]


func _new_match(ctx: Object) -> Node:
	var m: Node = load("res://src/match/match_manager.gd").new()
	ctx.root.add_child(m)
	return m


func _squad(ctx: Object, n: int) -> Array:
	var players := []
	for i in range(n):
		var p: Player = ctx.spawn_test_player()
		p.team_id = i % 2
		players.append(p)
	return players


func run(ctx: Object) -> void:
	# Datos de modos.
	ctx.check(ModeData.is_valid(ModeData.MODE_FRONTLINE), "Frontline válido")
	ctx.check(ModeData.is_valid(ModeData.MODE_VIP), "VIP válido")
	ctx.check(ModeData.is_valid(ModeData.MODE_DOMINATION), "Domination válido")
	ctx.check(not ModeData.is_valid("royale"), "Modo inventado rechazado")
	ctx.check(ModeData.uses_vip(ModeData.MODE_VIP), "VIP usa VIP")
	ctx.check(not ModeData.uses_vip(ModeData.MODE_FRONTLINE), "Frontline sin VIP")
	ctx.check(ModeData.uses_zones(ModeData.MODE_DOMINATION), "Domination usa zonas")
	ctx.check(not ModeData.uses_zones(ModeData.MODE_VIP), "VIP sin zonas")

	# Constantes de equipos.
	ctx.equals(GameConstants.TEAM_SIZE, 5, "Equipos de 5")
	ctx.equals(GameConstants.TEAM_COUNT, 2, "Dos equipos")
	ctx.equals(GameConstants.DOMINATION_ZONES, 3, "3 zonas")

	# FRONTLINE por defecto: vidas de equipo 15/15, roster con el jugador.
	var sm := StubMap.new()
	ctx.root.add_child(sm)
	var m := _new_match(ctx)
	var solo: Player = ctx.spawn_test_player()
	m.start_round(solo, sm)
	ctx.equals(m.mode_id, ModeData.MODE_FRONTLINE, "Modo por defecto frontline")
	ctx.equals(int(m.team_lives[0]), 15, "Vidas equipo 0 = 3x5")
	ctx.equals(int(m.team_lives[1]), 15, "Vidas equipo 1 = 3x5")
	ctx.check(m.roster.has(solo), "Roster contiene al jugador")

	# Roster 5v5: 5 por equipo.
	var m2 := _new_match(ctx)
	var ten := _squad(ctx, 10)
	m2.start_round(ten[0], sm, ModeData.MODE_FRONTLINE)
	var typed: Array[Player] = []
	for p in ten:
		typed.append(p)
	m2.register_roster(typed)
	var t0 := 0
	var t1 := 0
	for p in m2.roster:
		if p.team_id == 0:
			t0 += 1
		else:
			t1 += 1
	ctx.equals(t0, 5, "Equipo 0 con 5")
	ctx.equals(t1, 5, "Equipo 1 con 5")

	# FRONTLINE: eliminar al equipo 1 gana la ronda.
	var won := [false]
	m2.round_won.connect(func() -> void: won[0] = true)
	m2.team_lives[1] = 1
	ten[1].die()
	ctx.check(won[0], "Eliminar equipo 1 => round_won")
	ctx.check(not m2.round_active, "Ronda cerrada tras eliminación")

	# VIP: el primero de cada equipo es VIP; matar al VIP rival gana.
	var m3 := _new_match(ctx)
	var v0: Player = ctx.spawn_test_player()
	v0.team_id = 0
	var v1: Player = ctx.spawn_test_player()
	v1.team_id = 1
	m3.start_round(v0, sm, ModeData.MODE_VIP)
	var vip_roster: Array[Player] = [v0, v1]
	m3.register_roster(vip_roster)
	ctx.check(m3.is_vip(v0), "v0 es VIP del equipo 0")
	ctx.check(m3.is_vip(v1), "v1 es VIP del equipo 1")
	var vip_down := [-1]
	var vip_won := [false]
	m3.vip_down.connect(func(team: int) -> void: vip_down[0] = team)
	m3.round_won.connect(func() -> void: vip_won[0] = true)
	v1.die()
	ctx.equals(vip_down[0], 1, "vip_down equipo 1")
	ctx.check(vip_won[0], "Matar VIP rival => round_won")

	# VIP propio muerto => derrota.
	var m4 := _new_match(ctx)
	var w0: Player = ctx.spawn_test_player()
	w0.team_id = 0
	var w1: Player = ctx.spawn_test_player()
	w1.team_id = 1
	m4.start_round(w0, sm, ModeData.MODE_VIP)
	var wroster: Array[Player] = [w0, w1]
	m4.register_roster(wroster)
	var lost := [false]
	m4.round_lost.connect(func() -> void: lost[0] = true)
	w0.die()
	ctx.check(lost[0], "Muerte del VIP propio => round_lost")

	# DOMINATION: zona controlada suma puntos; llegar a WIN_SCORE gana.
	var m5 := _new_match(ctx)
	var d0: Player = ctx.spawn_test_player()
	d0.team_id = 0
	var d1: Player = ctx.spawn_test_player()
	d1.team_id = 0
	var e1: Player = ctx.spawn_test_player()
	e1.team_id = 1
	m5.start_round(d0, sm, ModeData.MODE_DOMINATION)
	var droster: Array[Player] = [d0, d1, e1]
	m5.register_roster(droster)
	d0.global_position = Vector2(100, 100)  # zona 0
	d1.global_position = Vector2(150, 150)  # zona 0
	e1.global_position = Vector2(850, 100)  # zona 2, solo: puntúa equipo 1
	m5._domination_tick()
	ctx.equals(int(m5.team_scores[0]), 1, "Zona 0 controlada por T0 suma 1")
	ctx.equals(int(m5.team_scores[1]), 1, "Zona 2 controlada por T1 suma 1")
	# Empate en zona 1: nadie puntúa esa zona.
	var f0: Player = ctx.spawn_test_player()
	f0.team_id = 0
	var f1: Player = ctx.spawn_test_player()
	f1.team_id = 1
	var froster: Array[Player] = [f0, f1]
	m5.register_roster(froster)
	f0.global_position = Vector2(500, 100)
	f1.global_position = Vector2(550, 100)
	var s0_before: int = m5.team_scores[0]
	m5._domination_tick()
	# Zona 0 (2v0) y zona 2 (0v1) puntúan; zona 1 empatada no.
	ctx.equals(int(m5.team_scores[0]), s0_before + 1, "Empate no puntúa")
	# Victoria por puntuación.
	var dwon := [false]
	m5.round_won.connect(func() -> void: dwon[0] = true)
	m5.team_scores[0] = GameConstants.DOMINATION_WIN_SCORE - 1
	m5._domination_tick()
	ctx.check(dwon[0], "Llegar a WIN_SCORE => round_won")

	# Timeout decide por puntuación/vidas.
	var m6 := _new_match(ctx)
	var g0: Player = ctx.spawn_test_player()
	m6.start_round(g0, sm, ModeData.MODE_DOMINATION)
	var t6won := [false]
	m6.round_won.connect(func() -> void: t6won[0] = true)
	m6.team_scores = {0: 10, 1: 4}
	m6._timeout_decide()
	ctx.check(t6won[0], "Timeout con más puntos => round_won")

	# Servidor: set_mode válido/inválido.
	var server: Node = ctx.root.get_node_or_null("Server")
	if server != null:
		ctx.check(server.set_mode(ModeData.MODE_VIP), "Server acepta modo VIP")
		ctx.equals(server.mode_id, ModeData.MODE_VIP, "Server en modo VIP")
		ctx.check(not server.set_mode("royale"), "Server rechaza modo inventado")
		ctx.check(server.set_mode(ModeData.MODE_FRONTLINE), "Server vuelve a frontline")
	else:
		ctx.check(false, "Autoload Server disponible para modos")

	sm.free()
