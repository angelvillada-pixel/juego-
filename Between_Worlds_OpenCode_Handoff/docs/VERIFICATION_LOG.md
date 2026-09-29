# Between Worlds — Verification Log

## Verificación real — Puntos 1-5 (2026-09-29, Godot 4.7.2 win64)

### Entorno
- Binario: `Godot_v4.7.2-stable_win64_console.exe` (4.7.2.stable.official.ed1daf0bf).

### Chequeo de arranque
- `--headless --path . --quit` → EXIT=0, cero errores de script (tras correcciones).
- Hallazgo 1: la caché de clases globales estaba obsoleta (todos los `class_name`
  de Puntos 1-5 sin resolver). Fix: `--import` para reconstruirla.
- Hallazgo 2 (bugs reales): `block.gd` inferencia con `abs()` (Variant) → tipo
  explícito; `match_manager.gd` `spawn` desde miembro untyped → `Vector2`;
  `backend.gd` usaba `FileAccess.APPEND` (no existe en Godot 4) → READ_WRITE + seek_end.

### Suite completa
- `-s res://tests/run_tests.gd` → **PASSED: 995, FAILED: 0** (19 suites).
  damage 11, armor 8, pickup 13, construction 16, respawn 20, map_layout 632,
  server 33, net_loopback 27, net_codec 11, ws_transport 9, movement 16,
  balance_point1 20, utility 12, modes 33, netcode_point3 37, audio 62,
  maps 16, telemetry 7, backend 12.
- Ruido esperado (no fallos): `push_error` deliberado en test_maps (fallback de
  mapa inválido); leaks cosméticos de RIDs/ObjectDB al salir (higiene de tests).

---

## Punto 5 — Servicios y producción (2026-09-29, slice provisional)

### Decisiones
- Ver `docs/DECISIONS.md` sección Punto 5 + `TELEMETRY/DEPLOY/LEGAL_CHECKLIST.md`.

### Cambios
- `src/telemetry/telemetry.gd`: nuevo autoload `Telemetry` (+ `project.godot`).
- `src/backend/backend.gd`: nuevo autoload `Backend` (+ `project.godot`).
- `src/ui/menu.gd`: Callsign + Server + JOIN (`join_requested`, recientes).
- `src/ui/main.gd`: `_on_join`, telemetría (start/hooks/end + `Backend.record_match`).
- `src/server/server_main.gd`: `--mode/--map` + sesión de telemetría.
- `export_presets.cfg`, `Dockerfile`, `.github/workflows/ci.yml`, docs nuevos.
- Tests: `test_telemetry.gd`, `test_backend.gd` (rutas temporales, limpieza).

### Verificación
- Revisión estática completa; `godot` sin binario aquí, pendiente headless + suite en Godot 4.7.2 (la CI lo correrá).
- Riesgos: presets sin verificar (regenerar en editor); ranking/matchmaking central y descubrimiento LAN fuera; Q9 legal humana.

---

## Punto 4 — Presentación jugable (2026-09-29, provisional)

### Decisiones
- Ver `docs/DECISIONS.md` sección Punto 4 + `docs/ART_PIPELINE.md`.

### Cambios
- `src/core/game.gd`: inputs `pause_menu` (Esc), `scoreboard` (Tab).
- `src/data/faction_data.gd`: nuevo (Aegis vs Rift, solo identidad).
- `src/data/map_data.gd`: nuevo (lab + arena); `MapLayout.generate(map_id)` (lab idéntico a M1); `TestMap.map_id` + `--map=`.
- `src/ui/pawn_art.gd`: nuevo (siluetas + trim); usado en `Player._draw` y `RemotePuppet`.
- `src/construction/block.gd`: remache determinista por celda.
- `src/map/test_map.gd`: fondo de territorios + zonas sutiles.
- `src/audio/sfx_synth.gd`: nuevo (14 SFX); `src/audio/audio_manager.gd`: nuevo autoload `Audio` (pool, pad loop, settings); `project.godot` registra autoload.
- `src/ui/menu.gd`: nuevo menú (modo/armadura/mapa/volúmenes/Jugar+Enter, CLI preselect).
- `src/ui/main.gd`: flujo menú→partida + `--armor=` + hooks de audio solo-lectura + música.
- `src/ui/hud.gd`: pausa (ALWAYS), scoreboard Tab, fin de ronda con Revancha.
- Tests: `test_audio.gd`, `test_maps.gd` nuevos.

### Verificación
- Revisión estática completa; `godot` sin binario aquí, pendiente headless + suite en Godot 4.7.2.
- Riesgos: síntesis de audio al arrancar (~1s, pad 6s); paneles centrados por código (revisar layout en vivo); pixel-art/música final fuera de alcance.

---

## Punto 3 — Netcode + anti-cheat (2026-09-29, provisional)

### Decisiones
- Ver `docs/DECISIONS.md` sección Punto 3 + `docs/NET_BENCH.md` (campo pendiente).

### Cambios
- `src/net/rate_limiter.gd`: nuevo, token bucket puro con tiempo inyectado.
- `src/net/sim_transport.gd`: nuevo, latencia/pérdida con seed.
- `src/net/net_messages.gd`: documenta seq/t/ftick/ack/tick.
- `src/net/client_net.gd`: sello seq+t, `confirm_ack` + RTT + ack_rate + peer_tick.
- `src/player/player.gd`: FIRE/UTILITY incluyen ftick.
- `src/client/net_client.gd`: MOVE con ftick; SNAPSHOT actualiza tick/peer_tick y confirma ACK.
- `src/client/remote_puppet.gd`: interpolación exp + snap > 96px.
- `src/server/game_server.gd`: limiters por sesión, strikes/kick (20), cheat_log (200), NaN rechazado, historial 90 ticks, `rewound_position`/`validate_hit_rewind`, snapshot con tick+acks, control velocidad (respawn excluido).
- Tests: `tests/unit/test_netcode_point3.gd` nuevo (limiter, sim delay/loss, seq/ack, flood=>kick, NaN, last_seq, snapshot tick/ack, rewind ok/ko+log, puppet interp/snap).

### Verificación
- Revisión estática completa; `godot` sin binario en este entorno, pendiente headless + suite en Godot 4.7.2.
- Riesgo conocido: reconciliación con replay completo e import real WebRTC quedan como Etapa 4; el rewind no revierte daño (el servidor ya decide hits), solo audita divergencia.

---

## Punto 2 — Modos 5v5 (2026-09-29, provisional)

### Decisiones
- Ver `docs/DECISIONS.md` sección Punto 2: FRONTLINE/VIP/DOMINATION data-driven, 5v5, vidas 15/15, 600s, zonas 3, win 100, VIP = primer registrado.

### Cambios
- `src/core/game_constants.gd`: TEAM_SIZE 5, TEAM_COUNT 2, MATCH_DURATION 600, DOMINATION_*.
- `src/data/mode_data.gd`: nuevo (3 modos + helpers).
- `src/net/net_messages.gd`: eventos VIP_DOWN/SCORE/MODE_STATE.
- `src/map/test_map.gd`: spawn_for_team_index + domination_zones.
- `src/match/match_manager.gd`: modo + roster + team_lives/scores + vip + tick dominación + timeout (compat start_round 1 jugador).
- `src/server/game_server.gd`: set_mode + vip_ids + spawn por equipo + VIP_DOWN en muerte + tick dominación dedicado.
- `src/client/net_client.gd`: espejo VIP_DOWN/SCORE/MODE_STATE.
- `src/ui/main.gd`: roster 5v5 local (jugador + 9 dummies) + `--mode=`.
- `src/ui/hud.gd`: líneas T0/T1 por modo, aviso VIP (reusa labels, sin cambio de escena).
- Tests: `tests/unit/test_modes.gd` nuevo (24 checks aprox: modos, roster 5v5, eliminación, VIP win/lose, dominación control/empate/win, timeout, Server.set_mode).

### Verificación
- Revisión estática completa; `godot` no disponible en este entorno, pendiente `--headless --path . --quit` y `-s res://tests/run_tests.gd` en máquina con Godot 4.7.2.
- Riesgo conocido: dummies sin IA (quietos); bots reales quedan para milestone posterior.

---

## Punto 1 — OPEN_QUESTIONS 1-5 cerradas (2026-09-29, provisional)

### Decisiones
- Ver `docs/DECISIONS.md` sección Punto 1: movimiento 240/264/216, TTK Rifle 7/0.6s body y 5/0.4s head vs Medium, shield máx 50 +15 por pickup, bloques 200/100/120 con structure_mult 1.0/2.0/0.6, Dash 8s/380.
- Autoridad: `Client.send(UTILITY)` -> `Server.request_utility` -> `Player.apply_utility_dash`. Sin mutación cliente. Daño a estructuras solo vía `Weapon.try_fire` vs `Block`.

### Cambios
- `src/core/game_constants.gd`: MAX_SHIELD 50.
- `src/data/weapon_data.gd`: structure_mult + helper.
- `src/combat/damage_service.gd`: shots_to_kill/ttk_seconds.
- `src/data/utility_data.gd`: nuevo, solo Dash.
- `src/player/player.gd`: utility cooldown + try/apply dash, max_shield 50, tick en physics para net.
- `src/net/net_messages.gd`: intent UTILITY. `src/core/game.gd`: input use_utility E/Shift.
- `src/server/game_server.gd`: request_utility + dispatcher.
- `src/weapons/weapon.gd`: daño x structure_mult solo vs Block.
- Tests nuevos: test_movement, test_balance_point1, test_utility. Ajuste test_server shield 30->15.

### Verificación
- Revisión manual tipada completa; `godot` no disponible en este entorno (sin binario en PATH), pendiente `--headless --path . --quit` y `-s res://tests/run_tests.gd` en máquina con Godot 4.7.2.
- Limitación aceptada: sin medición de feeling en vivo; valores marcados provisionales.

---

## Phase 2 / Stage 2 — LocalTransport loopback (2026-09-21)

### Goal (bw-netcode-expert stage 2)
The client no longer calls `Server.request_*` directly. Every intent travels as
a serializable message (dictionaries of primitives only, no node references)
through a `NetTransport`; `LocalTransport` loops it back in-process. Stage 3
will swap the transport for WebSocket/WebRTC without touching game logic.

### Changes
- New autoload `Client` (`src/net/client_net.gd`): intent gateway, warns when sending without an active transport.
- New shared contract `src/net/net_messages.gd` (`NetMsg`): single source of truth for message types (`fire`, `reload`, `build_place`, `build_destroy`, `pickup_claim`, `fall_out`).
- `game_server.gd`: session layer (`attach_transport`/`clear_sessions`/`session_count`) + message dispatcher `_on_transport_message`. Server derives attacker position/team/muzzle from the **session player**, never from message payload; incoming directions are normalized; unknown message types are dropped.
- Client senders rewired: `player.gd` (fire/reload), `construction_controller.gd` (build/destroy), `pickup.gd` (claim by absolute node path), `main.gd` (fall out, transport wiring, session teardown in `_exit_tree`).
- Test harness fixes: `run_tests.gd` runs test scripts inside `_run_all()` on the first `process_frame`; shared `spawn_test_player()` fixture. Warning: the runner script itself must NOT reference game classes statically (autoloads do not exist when it compiles).
- `Client.is_connected()` renamed to `has_transport()` (name collided with `Object.is_connected`, parse error in 4.7).

### Verification
- Launch: `--headless --path . --quit` → EXIT=0, zero errors.
- Tests: **760 passed, 0 failed**
  - new `tests/unit/test_net_loopback.gd`: 27 checks (message contract validity, disconnected-send guard, session attach/clear, fire + cooldown via message, invalid weapon index dropped, zero direction dropped, reload via message, malicious/unknown type ignored, build place/destroy via message with server-side origin, pickup claim with path spoofing rejected, fall out idempotent).
- bw-authority-check: client code paths contain zero `Server.request_*` calls; only `Client.send(NetMsg.*)` intents. `grep` clean.

### Known limitations
- No serialization yet: messages travel as live Dictionaries (LocalTransport). Byte-level encoding + versioning lands with the wire transport.
- No client-side prediction: the loopback is synchronous so the local player feels identical; prediction/reconciliation is Stage 4 work against real latency.
- HUD still reads `Player`/`Match` state directly (read-only view; acceptable).
- The game currently ships only 1 playable player locally; multi-client sessions exist at the Server layer but have no second client driver yet.

---

## Phase 2 / Stage 1 — Server authority extraction (2026-09-21)

### Goal (bw-netcode-expert stage 1)
All competitive outcomes now flow through the `Server` autoload
(`src/server/game_server.gd`): client code sends intents, the authority validates
and resolves. Same process today; the contract is the one the dedicated server
will expose in later stages.

### What moved to the Server
- `request_fire` / `request_reload` (weapons: cooldown, ammo, respawn gate, raycast exclusion)
- `request_pickup` (state + distance validation + capped application via `PickupService`)
- `request_build_place` / `request_build_destroy` (range from the builder, cell rules, team rules, permanent blocks)
- `request_fall_out` (out-of-world death)
- Built blocks are instanced under the Server-registered world container (`register_world`/`unregister_world`).

### Extra bugs found and fixed while wiring authority
1. **`player.team_id` did not exist** — `ConstructionController` dereferenced it, so pressing F/G would have crashed at runtime before this change. `Player.team_id := 0` added and now exercised by tests.
2. `run_tests.gd` executed in `_init()`, before autoloads exist, so classes referencing the `Server` autoload could not compile in the test context. Runner now executes on the first `process_frame` (`_initialize` + one-shot defer), which also guarantees in-tree `_ready` for spawned nodes.
3. Cleanup from Milestone 1 audit: unused `wrect` (main.gd), unused `Match.respawn_timer`, orphaned empty `menu.gd` (+ `.uid`) removed.
4. `ConstructionController` no longer duplicates build rules or preloads the block scene (single block factory = Server).

### Verification
- Launch: `--headless --path . --quit` → EXIT=0, zero script errors, zero warnings.
- Tests: `-s res://tests/run_tests.gd` → **733 passed, 0 failed**
  - new `tests/unit/test_server.gd`: 33 checks (fire allow/deny, cooldown, respawn gates, reload, pickup caps/distance/oneshot consumption, shield, build range/occupancy/team/permanent/target rules, world unregister, fall-out death).
- bw-authority-check: no client-side decision path remains for fire/reload/pickup/build/destroy/fall; HUD and controller only read state or send intents.
- bw-balance-check: unchanged rules (733 tests re-verify 100 HP, mitigation tiers, 1.5x, no one-shot, capped pickups).

### Known limitations (accepted for this stage)
- The authority call is a direct in-process call; message serialization/transports come in Stage 2 (LocalTransport loopback) and Stage 3 (LAN).
- The hitscan raycast still executes against the client's World2D (same data today as server world). Lag-compensated server rewind arrives with prediction (Stage 4-5).
- Test node leaks at exit remain cosmetic-only.

---

## Milestone 1 — Playable laboratory prototype (2026-09-21)

### Launch check
- Command: `Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit`
- Initial state: FAILED. `player_controller.gd` had two parse errors cascading into `player.gd`, `match_manager.gd`, `main.gd` and others:
  1. `move_toward()` called with `get_gravity()` (Vector2) where a float was expected. Fixed with `absf(get_gravity().y)`.
  2. `armor_col` type could not be inferred from `Dictionary["color"]`. Fixed with explicit `Color` typing.
  3. `tests/unit/test_respawn.gd` typed `player`/`hit` could not be inferred. Fixed with explicit `Player` type.
- After fixes: EXIT=0, no script errors, zero warnings on boot.

### Unit tests
- Command: `godot --headless --path . -s res://tests/run_tests.gd`
- Result: **700 passed, 0 failed**
  - test_damage: 11 checks (headshot 1.5x, mitigation tiers, no one-shot, shield-first order)
  - test_armor: 8 checks
  - test_pickup: 13 checks
  - test_construction: 16 checks
  - test_respawn: 20 checks
  - test_map_layout: 632 checks (deterministic seed, ~60% mutable geometry, spawns)

### Known limitations (to resolve in later milestones)
1. **Authority flow (bw-authority-check):** Weapon raycast, pickup application, construction place/destroy, and round restart are currently resolved on the client node path. This is intentional for the local-authoritative slice (Player node acts as the logical server) but MUST migrate to the authoritative server path in the networking milestone. No new competitive outcome may be decided client-side from now on.
2. **Test hygiene:** unit tests allocate nodes (Player/Grid/Block) without freeing them; RID/ObjectDB leak warnings appear at exit of the test runner. Cosmetic; does not affect results.
3. **Dead code:** `main.gd` keeps an unused `wrect` local and `src/ui/menu.gd` is empty (placeholder).
4. `Match.respawn_timer` field is unused (timers created inline). Harmless; review when networking lands.

### Balance snapshot (bw-balance-check)
All frozen rules verified in code + tests: 100 HP, mitigation 10/20/30%, speed +10/0/-10%, shared jump, 1.5x headshot, no one-shot (max 90 dmg = Precision headshot), no regen, pickups capped at maxima, damage-only bullets.
