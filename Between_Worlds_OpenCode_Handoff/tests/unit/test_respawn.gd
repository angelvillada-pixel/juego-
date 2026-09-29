class_name TestRespawn
extends RefCounted
## Respawn y zonas de daño del Player: reset de estado y detección HEAD/BODY.


func run(ctx: Object) -> void:
	var player: Player = Player.new()
	player.set_armor(ArmorData.ARMOR_MEDIUM)

	# Estado inicial
	ctx.approx(player.hp, 100.0, 0.001, "HP inicial 100")
	ctx.approx(player.shield, 0.0, 0.001, "Shield inicial 0")
	ctx.check(player.respawning == false, "No respawneando al inicio")

	# Detección de zonas HEAD/BODY
	ctx.equals(player.get_hit_zone(Vector2(-3, -20)), HitZone.Zone.HEAD, "Punto arriba = HEAD")
	ctx.equals(player.get_hit_zone(Vector2(-3, -10)), HitZone.Zone.BODY, "Punto medio = BODY")
	ctx.equals(player.get_hit_zone(Vector2(100, -2)), HitZone.Zone.BODY, "Punto fuera por x = BODY")

	# Daño aplicado con Medium (20%): 20 de base al cuerpo → 16
	var hit := player.damage_from_bullet(player.global_position + Vector2(0, -8), 20.0)
	ctx.equals(hit["zone"], HitZone.Zone.BODY, "Zona registrada BODY")
	ctx.approx(player.hp, 84.0, 0.001, "HP tras rifle body Medium (20*0.8=16)")

	# Headshot con Medium: 20*1.5*0.8 = 24
	hit = player.damage_from_bullet(player.global_position + Vector2(0, -20), 20.0)
	ctx.equals(hit["zone"], HitZone.Zone.HEAD, "Zona registrada HEAD")
	ctx.approx(player.hp, 60.0, 0.001, "HP tras rifle head Medium (24)")

	# Escudo temporal absorbe antes del HP
	player.shield = 20.0
	hit = player.damage_from_bullet(player.global_position + Vector2(0, -8), 20.0)
	ctx.approx(player.shield, 4.0, 0.001, "Shield 20 absorbe 16 (queda 4)")
	ctx.approx(player.hp, 60.0, 0.001, "HP intacto mientras hay shield")

	# Respawn restaura HP, shield y munición
	player.weapons = []
	var rifle := Weapon.new(WeaponData.WEAPON_RIFLE)
	player.weapons.append(rifle)
	rifle.reserve = 2
	rifle.magazine = 0
	player.reset_for_respawn(Vector2(100, 200))
	ctx.approx(player.hp, 100.0, 0.001, "Respawn restaura HP")
	ctx.approx(player.shield, 0.0, 0.001, "Respawn limpia shield (armor pickup NO persiste)")
	ctx.equals(player.global_position, Vector2(100, 200), "Respawn reubica al jugador")
	ctx.check(player.respawning == false, "Respawn desactiva estado respawning")
	ctx.equals(rifle.magazine, int(WeaponData.DEFS[WeaponData.WEAPON_RIFLE]["magazine_size"]), "Respawn recarga cargador")
	ctx.equals(rifle.reserve, int(WeaponData.DEFS[WeaponData.WEAPON_RIFLE]["reserve_max"]), "Respawn restaura reserva")

	# Muerte
	player.hp = 1.0
	player.damage_from_bullet(player.global_position + Vector2(0, -8), 20.0)
	ctx.check(player.hp <= 0.0, "HP llega a 0 con daño letal")
	ctx.check(player.respawning, "Jugador en estado respawning tras morir")