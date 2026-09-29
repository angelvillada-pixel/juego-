# OpenCode — First Task for Between Worlds

Read `AGENTS.md`, then read `docs/MASTER_DESIGN.md`, `docs/DECISIONS.md`, and `docs/OPEN_QUESTIONS.md`.

Your first job is NOT to build the whole game. Create a clean, runnable Godot 4.7.2 prototype repository for the laboratory vertical slice.

## Phase 0 — inspect and plan
1. Inspect the repository/workspace.
2. Verify available Godot version.
3. Produce a concise implementation plan with milestones and dependencies.
4. Do not ask about minor design details. Use documented provisional values and record them.
5. Flag only major conflicts with the master design.

## Phase 1 — project scaffold
Create a clean Godot project structure for:
- player;
- weapons;
- combat/damage;
- armor/equipment;
- construction/grid;
- destructible terrain;
- pickups;
- match state;
- networking abstraction;
- UI;
- tests/tools.

Keep systems modular and data-driven.

## Phase 2 — local playable prototype
Implement:
- one test map;
- one controllable player;
- camera;
- Light/Medium/Heavy armor speed + mitigation;
- 100 HP;
- Head/Body hit detection;
- 1.5x global headshot multiplier;
- no one-shot headshots;
- one primary weapon;
- one secondary weapon;
- basic ammo/reload;
- simple utility placeholder;
- grid construction;
- destructible blocks;
- health/armor/ammo pickups;
- fast respawn;
- basic win condition.

Start with local/server-authoritative simulation architecture even if only one machine is used.

## Phase 3 — verification
Create reproducible tests for:
- armor mitigation;
- headshot damage;
- one-shot prevention;
- Light/Medium/Heavy horizontal movement modifiers;
- pickup max clamping;
- construction placement validity;
- structure destruction;
- respawn reset.

## Important constraints
- No final artwork yet.
- No copied Fortoresse assets/code.
- No public matchmaking yet.
- No economy/shop/battle pass.
- No campaign.
- No large arsenal.
- No premature optimization.

When the first playable slice runs, stop and report:
- what works;
- what was tested;
- what is provisional;
- what the next milestone should be.
