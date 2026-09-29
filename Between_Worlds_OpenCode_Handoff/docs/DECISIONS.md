# Between Worlds — Frozen Decisions

## Core
- Working title: Between Worlds.
- PC + browser.
- Pixel art + illustration.
- Fortoresse evolved, not a literal clone.
- 5v5.
- Fast but tactical.
- Standard match: 8–12 minutes.
- Respawn is fast in normal modes; special modes can have special life rules.

## Combat
- 100 HP.
- Armor mitigation is fixed for the current life.
- Light: 10% mitigation.
- Medium: 20% mitigation.
- Heavy: 30% mitigation.
- Light: +10% horizontal speed.
- Medium: normal horizontal speed.
- Heavy: -10% horizontal speed.
- All armor types share the same jump behavior.
- Global headshot multiplier: 1.5x.
- No conventional one-shot headshots.
- Damage zones are Head and Body only.
- Normal bullets cause damage only; they do not create knockback.
- HP does not automatically regenerate.
- Armor does not automatically regenerate.
- Health, armor and ammo pickups exist and cannot push a resource above its normal maximum.

## Loadout
- One Primary weapon.
- One Secondary weapon.
- One Armor slot.
- One Utility slot.
- Loadout changes only on death.
- Light/Medium/Heavy armor must be visually distinct.

## World / construction
- Large portion of terrain is destructible.
- Construction is quick, grid-based and a core combat mechanic.
- Map geometry is data-driven.
- The map has persistent/static geometry plus mutable/destructible/buildable geometry.

## Online
- Server authoritative.
- Client prediction/interpolation is expected.
- Damage, kills, pickups, objectives, inventory and match results are server-authoritative.

## Provisional technical direction
- Godot 4.7.2 stable.
- GDScript first; C++ only if justified by measurement.
- Dedicated/headless server.
- Web networking transport remains a prototype decision between WebSocket/WebRTC and must be benchmarked before being frozen.

## Punto 1 — OPEN_QUESTIONS 1-5 cerradas (provisional validado con tests, 2026-09-29)
- Q1 Movimiento congelado: BASE_RUN_SPEED 240 (Light 264 / Medium 240 / Heavy 216), GROUND_ACCEL 1500, AIR_ACCEL 1200, GROUND_FRICTION 1800, MAX_FALL_SPEED 900, JUMP_VELOCITY -360 compartido, CROUCH 12x24 -> 12x14 a 0.6x velocidad, cabeza = 8px superiores, grid 16px, BUILD_RANGE 64px. Ver `tests/unit/test_movement.gd`.
- Q2 TTK congelado: Rifle 20dmg/600rpm (body Medium 7 disparos/0.6s, head 5/0.4s), Precision 60dmg/100rpm (body 3, head 2), Pistol 14dmg/420rpm. Sin one-shot (máx 90 = Precision head sin armor). Helpers `DamageService.shots_to_kill/ttk_seconds`. Ver `tests/unit/test_balance_point1.gd`.
- Q3 Armor Pickup congelado: escudo temporal separado de la mitigación base (que sigue fija por vida), MAX_SHIELD 50, fracción 30% (+15), nunca supera 50. Ver `GameConstants.MAX_SHIELD`, `PickupService.apply_shield`.
- Q4 Bloques congelados: BUILD 200 HP / DESTRUCTIBLE 100 HP / TARGET 120 HP. Daño a estructuras separado: Rifle x1.0, Precision x2.0 anti-material, Pistol x0.6 (en `WeaponData.structure_mult`, aplicado en `Weapon.try_fire` solo vs `Block`).
- Q5 Utilidad congelada: una sola utilidad `Dash` (`src/data/utility_data.gd`), cooldown 8s, impulso horizontal 380, permitido en aire, sin daño. Intento `Client.send(UTILITY)` -> `Server.request_utility` valida cooldown/respawn/dirección; `Player.apply_utility_dash` aplica efecto. Input `use_utility` = E/Shift. Ver `tests/unit/test_utility.gd`.

## Punto 2 — Modos 5v5 cerrados (provisional validado con tests, 2026-09-29)
- Modos data-driven en `src/data/mode_data.gd`: FRONTLINE (base propio: destruir objetivos + vidas de equipo), VIP (matar al VIP rival gana), DOMINATION (3 zonas, punto por segundo por zona controlada, primero a 100 gana). Selección por CLI `--mode=frontline|vip|domination` (defecto frontline).
- Equipos: TEAM_SIZE 5, TEAM_COUNT 2, vidas de equipo = STARTING_LIVES x TEAM_SIZE (15/15), MATCH_DURATION 600s (10 min, dentro de 8-12). Timeout decide por vidas (frontline/vip) o puntos (domination); empate favorece equipo 0 local (provisional).
- VIP = primer registrado de cada equipo; su muerte emite `vip_down` y cierra la ronda. Sin respawn especial (respawn normal hasta que muere el VIP).
- Dominación: control = más jugadores vivos dentro; empate no puntúa. Tick en `Match._process` (local) y `Server._domination_tick_server` (dedicado). HUD reusa labels: vidas T0/T1, score T0/T1, aviso VIP.
- Spawns 5v5: `TestMap.spawn_for_team_index(team, index)` dispersa en X; servidor usa `_spawn_point_for_team` con conteo por equipo. Roster local 5v5 en `main.gd` (jugador + 9 dummies quietos sin IA todavía). Red: `Server.set_mode` + eventos `MODE_STATE/VIP_DOWN/SCORE` espejados en `NetClientDriver`.
- Ver `tests/unit/test_modes.gd`.

## Punto 3 — Netcode + anti-cheat cerrados (provisional validado con tests, 2026-09-29)
- Protocolo seq/ack: `Client.send` sella `seq`+`t`; SNAPSHOT lleva `tick`+`acks`; driver confirma ACK, estima RTT (`Client.rtt_ms/ack_rate`) y reenvía `ftick` en MOVE/FIRE/UTILITY. Predicción = sim local + snap si deriva > 96px (existente); reconciliación formal con replay queda como Etapa 4.
- Interpolación remotos: `RemotePuppet` suavizado exp (tasa 12 ≈ 120ms), snap solo si deriva > 96px.
- Lag-comp: servidor guarda historial 90 ticks (~3s) por sesión; `validate_hit_rewind` valida hits vs posición rebobinada (tolerancia 96px) y registra divergencias en `cheat_log` (los hits los sigue decidiendo el servidor; no hay vector de cheat por claim).
- SimTransport (`src/net/sim_transport.gd`): latencia/pérdida configurables con seed para validar sin red real.
- Anti-cheat: token buckets por intent (FIRE 8/12s, MOVE 12/40s, BUILD 4/4s, UTILITY 2/1s, resto 4/8s), 20 strikes => kick; NaN rechazado; control de velocidad (cap 1200, respawn excluido); `cheat_log` capado a 200.
- WebRTC/benchmark real pendiente de medición de campo: ver `docs/NET_BENCH.md`.
- Ver `tests/unit/test_netcode_point3.gd`.

## Punto 4 — Presentación jugable cerrada (provisional validado con tests, 2026-09-29)
- Audio procedural sin assets: `SfxSynth` (14 SFX deterministas, 22050Hz mono) + autoload `Audio` (pool 8 voces, pad ambiental en loop, volúmenes en `user://settings.cfg`). Hooks solo-lectura en `main.gd` (disparo/muerte/pickup/build/win/lose). Música compuesta y voces quedan fuera.
- Mapas data-driven en `src/data/map_data.gd`: lab (idéntico a M1, misma seed/salida) + arena (seed/bandas/cobertura/objetivos distintos); selección `--map=` y en menú. Escala final de grid sigue abierta (Q8).
- Arte procedural (ver `docs/ART_PIPELINE.md`): siluetas distintas por armadura + trim de facción (`PawnArt`, usado en `Player` y `RemotePuppet`), remache por celda en bloques, fondo de territorios en `TestMap`. Facciones `Aegis vs Rift` solo identidad (`faction_data.gd`); pixel-art final fuera (Q10 abierta).
- UI: menú principal (modo/armadura/mapa/volúmenes/Jugar, Enter), pausa Esc (HUD ALWAYS, Resume/Restart/Menu), scoreboard Tab (vivos/VIP/puntos por equipo), fin de ronda con ganador + Revancha. Selección pre-partida (no viola cambio-solo-al-morir).
- Ver `tests/unit/test_audio.gd`, `tests/unit/test_maps.gd`.

## Punto 5 — Servicios y producción cerrados como slice (provisional, 2026-09-29)
- Telemetría local: autoload `Telemetry` (eventos + contadores + JSONL en `user://telemetry`), hooks solo-lectura en `main.gd` (shots/muertes/pickups/build/objetivos/fin). Esquema en `docs/TELEMETRY.md`. Agregación central fuera.
- Backend local sin servidor central: autoload `Backend` (callsign + client_id en `user://profile.cfg`, recientes máx 8, historial JSONL últimas 20). Fachada lista para backend real.
- Matchmaking manual: menú con Callsign + dirección + JOIN (más `--connect=`); recientes persistidos. Sin descubrimiento LAN ni ranking todavía.
- Servidor dedicado con `--mode/--map`; Docker + CI (headless + suite) + `export_presets.cfg` (Web/Windows/Linux) **sin verificar con binario**; guía en `docs/DEPLOY.md`.
- Legal: checklist humana en `docs/LEGAL_CHECKLIST.md`; Q9 sigue ABIERTA.
- Ver `tests/unit/test_telemetry.gd`, `tests/unit/test_backend.gd`.
