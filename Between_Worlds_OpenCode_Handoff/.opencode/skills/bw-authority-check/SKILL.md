---
name: bw-authority-check
description: Use when implementing or reviewing any competitive gameplay decision such as damage, kills, pickups, inventory, construction, objectives, deaths, respawns, or match results to ensure the server/local authoritative simulation is the source of truth.
---

# BW Authority Check

## Goal
Prevent client-authoritative gameplay decisions in Between Worlds.

## Rule
Never let the client decide competitive outcomes. The client can request actions (input, aim, place, destroy); the server/local sim must resolve and validate.

## Must Be Server-Authoritative
- Damage and hit resolution (zone, mitigation, HP/shield outcomes).
- Kill credit and death sequencing.
- Ammo counts and reload validation.
- Pickup application (never exceed max; applies server rules).
- Construction placement and block destruction.
- Objective destruction and win/loss handling.
- Match state transitions and respawn timing.

## Prototype Note
Until real networking is added, `Game.gd` and match autoloads act as the local authoritative simulation. Any new gameplay decision must flow through that authority path, not directly in client view/input-only code.

## Validation Checklist
- [ ] Does this action mutate player HP/shield/inventory? If yes, is the change resolved by a service/autoload?
- [ ] Does this action affect map blocks/objectives? If yes, is it resolved via grid/block service path?
- [ ] Are there any client-side assertive state changes for competitive outcomes?
- [ ] Can the same rule be executed headlessly in a future server context?
