---
name: bw-netcode-expert
description: Use for all Phase 2 networking work in Between Worlds — server authority extraction, session transport (local/WebSocket/WebRTC), client prediction, server reconciliation, entity interpolation, lag compensation for hitscan, tick design, and bandwidth discipline in Godot 4.7 MultiplayerAPI.
---

# BW Netcode Expert — Phase 2 Standard

## Mission
Convert the local-authoritative prototype into a real client/server game without changing how the game feels locally, and without ever letting a client decide a competitive outcome (see `bw-authority-check`).

## Target architecture (frozen by docs)
- **Server**: headless Godot dedicated server, authoritative for damage, kills, ammo, pickups, construction, objectives, respawns, match results.
- **Client**: prediction for the local player, interpolation for remote entities, sends *intentions* (inputs), never *outcomes*.
- **Transport abstraction**: `src/net/transport.gd` (`NetTransport`) with `LocalTransport` (current) → `WsTransport` (WebSocket, control plane) → `WebRtcTransport` (game data candidate). Transport choice is benchmarked, not assumed (OPEN_QUESTIONS #7).

## Tick & simulation model
- Fixed simulation tick: **30 Hz prototype** (provisional; tune by measurement). Client render interpolates between snapshots.
- Client sends input at its own rate; server consumes per-tick in order.
- Server keeps last N states (≥ 1 s) for reconciliation and lag compensation on hitscan.
- Sequence numbers on every input packet; server echoes last-processed input id for reconciliation.

## Implementation stages (strict order)
1. **Extraction**: move rule resolution out of `Player`/`Pickup`/`ConstructionController` into an authoritative `GameServer` node (still in-process). Client path becomes "intent → server → state broadcast". Local game boots identically to today.
2. **LocalTransport loopback**: same authority flow but through message passing (already partially stubbed).
3. **WebSocket LAN**: real socket server + 2 clients; authority stays on server; clients render server state.
4. **Prediction/reconciliation**: local player predicted; on snapshot mismatch, rewind+replay unacked inputs. Remote entities interpolated ≥ 100 ms.
5. **Lag compensation**: hitscan validated against server-side rewind of target positions.
6. **Web build**: negotiate WebSocket vs WebRTC by measurement; document in `docs/DECISIONS.md`.

## Security rules (server-side, always)
- Validate rate of fire against `WeaponData.cooldown_seconds(weapon_id)` with tolerance, not trust.
- Validate movement: speed cannot exceed `ArmorData.movement_speed(armor_id) * tolerance`; teleport requests rejected.
- Validate build range: `GameConstants.BUILD_RANGE_PX` from server-known player position.
- Validate pickups: distance + one-shot consumption; caps via `PickupService` only.
- Log every rejected action (cheat telemetry).

## Godot 4.7 implementation notes
- Use `MultiplayerAPI` + `ENetMultiplayerPeer` for dedicated server prototype; `WebSocketMultiplayerPeer` for browser clients later; keep peers behind `NetTransport`.
- Run server with `--headless`; same project, `ProjectSettings` feature tag or CLI flag distinguishes server mode (e.g., `--server`).
- Physics: run `move_and_slide()` only on server for authority; client prediction mirrors the same `_physics_process` code path (share the movement code between client prediction and server — do not duplicate).
- Snapshots: send diffs (position, hp, shield, weapon state, block grid changes as events), not whole scenes.
- Keep hitscan resolution server-side: client renders a predicted tracer immediately; server result is the truth.

## Bandwidth discipline (prototype budget)
- Target ≤ 20 kbps per player at 20 Hz snapshots baseline; measure, don't guess.
- Event-driven messages for rare events (block placed/destroyed, pickup, death).
- Quantize positions to cell+subcell precision for grid-aligned objects.

## Done criteria for Phase 2
- 2 real clients + headless server on LAN: movement smooth, no authority violations, hit registration consistent with server view.
- Full unit test suite stays green; new tests for reconciliation math and rate limiting.
- `docs/VERIFICATION_LOG.md` entry with latency/packet-loss benchmark table (0/50/100 ms, 0/1/2% loss).
