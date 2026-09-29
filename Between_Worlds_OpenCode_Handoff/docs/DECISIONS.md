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

## S1 — Endurecimiento de entrada del servidor (provisional validado con tests, 2026-09-29)
- Protocolo versionado: `NetMsg.PROTOCOL_VERSION = 1`; `Client.send` lo sella en cada intent, `WELCOME` lo anuncia. Sesiones de red exigen coincidencia exacta o se dropean (loopback local tolerante). Cliente avisa con warning si el servidor anuncia otra versión.
- Anti-replay: `seq > 0` debe ser estrictamente creciente (duplicado/viejo => strike `replay`); `t > 0` debe ser monótono con holgura de reorden 1000 ms (`replay_time`). Ausentes (0) = llamada local legada, aceptada con rate-limit igualmente.
- Payloads tipados: ningún Variant atacante llega a asignación tipada. `weapon_index` int en rango, `direction`/`cell` con `is Vector2`/`is Vector2i`, `axis`/`aim` numéricos (`aim` con wrap `fmod`), path de pickup String ≤128 con whitelist `^[A-Za-z0-9_\-/.]+$` sin `..` ni `/` inicial. Violación => strike `bad_payload:<tipo>`.
- Handshakes: `_pending_peers` como `{ws, t}`, cap 16, timeout 10 s (`prune_pending` estático y testeable).
- Sesiones: `_histories` se borra al dropear y en `clear_sessions`; idle kick a 300 s sin intents (solo red, con `idle` en log); respawn sigue excluido del speed-check.
- Ver `tests/unit/test_security_s1.gd`.

## S2 — TLS delante del juego (provisional validado con tests, 2026-09-29)
- TLS termina en Caddy (HTTPS automático Let's Encrypt); Godot solo habla `ws://` en localhost. Internet entra únicamente por 80/443 → `wss://` obligatorio en producción.
- Servidor: `start_listener(port, bind)` con bind `127.0.0.1` por defecto y flag CLI `--bind=` (compose usa `0.0.0.0` dentro de su red; el puerto del host queda en `127.0.0.1:26500`).
- Budget de aceptadas: token bucket 10/10 s en `_poll_network`; el exceso espera y caduca por `prune_pending` (log `accept_flood` como mucho 1/s).
- Cliente: `WsTransport.normalize_url` (host pelado → `ws://`) + `is_secure` (`wss://`); en build web se rehúsa `ws://` sin cifrar con error claro (el navegador lo bloquearía igual).
- Despliegue: `deploy/Caddyfile` (HSTS, gzip, reverse_proxy a `game:26500`) + `deploy/docker-compose.yml` (game + caddy, restart unless-stopped, healthcheck TCP, volumen de datos) + `deploy/.env.example`.
- Ver `tests/unit/test_security_s2.gd`.

## S3 — Cuentas completas (provisional validado con tests + smoke real, 2026-09-29)
- Flujo: conexión nace SIN jugador (`_pending_auth`, timeout 30 s) → `AUTH_REGISTER`/`AUTH_LOGIN` → `AUTH_OK {token}` → `JOIN {token}` → spawn + `WELCOME`. Sin token no hay intents de juego. Loopback local exento (sin cuenta).
- Passwords: PBKDF2-HMAC-SHA256, sal 16 B, 10000 iteraciones, HMAC manual sobre HashingContext (verificado contra openssl: vectores HMAC y PBKDF2 c=1). Nunca en claro. Coste ~bloqueo breve en registro/login (raros); documentado.
- Tokens 256-bit `rand.expiry.mac` (HMAC del secreto), TTL 24 h, doble chequeo (mac + registro en memoria); reiniciar invalida sesiones. Secreto generado y persistido (`user://server_secret`, chmod 600 en despliegue).
- Callsign 3-16 `[A-Za-z0-9_-]`, único case-insensitive; mismo error `bad_credentials` exista o no (anti-enumeración); 5 fallos => bloqueo 15 min.
- Persistencia sin dependencias: `user://auth_users.jsonl` (un JSON por línea). Sin GDExtensions.
- Cliente: driver prueba JOIN con token guardado, si no LOGIN/REGISTER del menú y JOIN al `AUTH_OK`; password nunca retenido; `auth_failed(reason)` para la UI. Menú con password + Login/Register + token persistido en `profile.cfg`.
- Fuera del día 1: recuperación de password (reset manual por admin).
- Ver `tests/unit/test_auth_s3.gd` (31 checks).

## P3-P5 — Operación 24/7 cerrada como slice (validado 2026-09-29)
- Watchdog: `deploy/watchdog.sh` (cron 5 min, 3 sondas TCP → `restart game`); logs rotados 10m x3 en compose.
- Backups: `deploy/backup.sh` (volumen `bw-data` → tgz con retención 7, restore documentado). E2E pendiente de daemon en marcha.
- CI-deploy: `deploy.yml` manual (verify → build/push GHCR → SSH redeploy) con secrets `VPS_HOST/USER/SSH_KEY`; `ci.yml` corregido (path al subdir + `workflow_call`).
- Presets verificados de verdad: Linux x86_64 (73 MB), Web (html/js/wasm/pck) y Windows (109 MB) exportan limpio en headless 4.7.2.
- Higiene de build: `.dockerignore` (sin `.godot/` en contexto), `BW_IMAGE` overridable en compose.
- Ver `docs/DEPLOY.md`.

## P1-P2 — Docker 24/7 + dominio, jugable online (provisional validado, 2026-09-29)
- Compose verificado (`docker compose config` OK): `game` + `caddy`, restart unless-stopped, healthcheck TCP, volumen de datos, 26500 solo en `127.0.0.1` del host.
- Servidor dedicado arranca de verdad (hallazgo del smoke test: `server_main.gd` no compilaba con `-s` por refs estáticas a autoloads; `player.gd`/`pickup.gd` igual con `Client`). Regla nueva: **los scripts que carga el dedicado no nombran autoloads**; usan `NetMsg.send_intent()` / `NetMsg.client_peer_tick()` (resolución en runtime, igual en local/red/servidor).
- Arranque diferido al primer frame (`_boot()`): en `_initialize` el `add_child` aún no dispara `_ready` y el grid quedaba null (construcción muerta en dedicado).
- Smoke test real `tests/smoke_join.gd` (manual, fuera de la suite): dedicado en 26601 + handshake WS → WELCOME proto=1 + MOVE aceptado + SNAPSHOT con el id. Log del servidor limpio, cero strikes.
- Guía VPS gratis 24/7 en `docs/VPS_GRATIS.md` (Oracle Always Free, red, DNS, compose, límites honestos).
