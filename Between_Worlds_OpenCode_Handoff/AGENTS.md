# Between Worlds — OpenCode Project Instructions

## Project goal
Build **Between Worlds**, a 2D competitive PvP game for PC + browser, 5v5, fast but tactical, strongly inspired by the core gameplay philosophy of Fortoresse while using original code, art, audio, characters, maps, naming, and implementation.

## Source of truth
Before making gameplay or architecture changes, read:
- `docs/MASTER_DESIGN.md`
- `docs/OPEN_QUESTIONS.md`
- `docs/DECISIONS.md`

The DOCX in `docs/Between_Worlds_Master_Design_v1_0.docx` is the human-readable master document. The Markdown copy is the agent-readable version.

## Current technical direction
- Provisional engine: Godot 4.7.2 stable.
- Primary scripting path: GDScript.
- C++ only when measurement proves it is necessary.
- Target platforms: Web + PC.
- Dedicated/headless authoritative game server.
- Client is never authoritative for damage, kills, inventory, pickups, objectives, or match results.
- Autoloads (in order): `Game` (input registration), `Server` (authority gateway), `Client` (intent gateway), `Match` (round/lives/objectives state).
- Contract: client code sends intents via `Client.send({"type": NetMsg.*, ...})`; the message travels through `NetTransport` (today: `LocalTransport` loopback) to `Server`; only `Server` mutates `Player`/`Grid`/`World`. Do not bypass it from UI/input code.

## Gameplay baselines
- 5v5.
- Standard match: 8–12 minutes.
- 100 HP.
- Armor depends on Light / Medium / Heavy equipment.
- Baseline armor mitigation: Light 10%, Medium 20%, Heavy 30%.
- Horizontal speed: Light +10%, Medium 0%, Heavy -10%.
- Jump behavior is shared across all armor weights.
- Global headshot multiplier: 1.5x.
- No conventional one-shot headshots.
- Damage zones: Head / Body only.
- Normal bullets deal damage only; no bullet knockback.
- No automatic HP regeneration.
- No automatic armor regeneration.
- Health, armor, and ammo pickups are planned; they never exceed normal maximums.
- Loadout: Primary + Secondary + Armor + Utility.
- Equipment can only be changed on death.
- Normal modes have fast respawn; special modes can use different survival rules.
- Large portion of terrain is destructible.
- Construction is a core combat system and is grid based.

## Development rules
1. Do not build the entire game at once.
2. Work in vertical-slice milestones.
3. Prefer simple, testable systems over premature abstraction.
4. Keep gameplay data separate from code where practical.
5. Do not introduce new mechanics silently. Record meaningful new decisions in `docs/DECISIONS.md`.
6. For unresolved details, make the smallest reasonable provisional assumption, document it, and continue. Do not block on minor questions.
7. Preserve the intended Fortoresse-like feel, but do not copy proprietary code, assets, maps, characters, sounds, text, or branding.
8. Every gameplay system that affects competitive outcome must be server-authoritative.
9. Add tests or reproducible checks for important gameplay rules.
10. Keep the project runnable after every milestone.

## First milestone
Implement only the playable laboratory prototype described in `docs/MASTER_DESIGN.md`:
- one test map;
- player movement/camera;
- Light/Medium/Heavy armor handling;
- one primary weapon;
- one secondary weapon;
- basic utility placeholder;
- 100 HP + armor mitigation + headshots;
- basic grid construction;
- destructible terrain;
- pickups;
- fast respawn;
- a simple match/win condition;
- local authoritative server simulation first.

Do not implement accounts, public matchmaking, shop, battle pass, campaign, large content sets, final art, or deep lore in the first milestone.

## Project skills
Use the project-local skills in `.opencode/skills/` when doing related work:
- `bw-game-dev-expert` for EVERY task: always-on senior game developer standard (game feel first, data-driven, typed GDScript, test-backed, minimal diffs).
- `bw-gdscript-guard` for GDScript/data-driven gameplay code quality checks.
- `bw-authority-check` for any change affecting damage, kills, pickups, construction, objectives, respawns, or match results.
- `bw-balance-check` for any combat/balance value changes in combat data or constants.
- `bw-netcode-expert` for Phase 2 networking: server authority extraction, transports, prediction/reconciliation, lag compensation, bandwidth.
- `bw-milestone-verify` after milestone work to verify the project remains launchable and tested.

## Verification
After each milestone:
- run the Godot project headless (`--headless --path . --quit`);
- run automated/unit checks (`-s res://tests/run_tests.gd`);
- verify the game remains launchable;
- document what was tested and any limitations in `docs/VERIFICATION_LOG.md`.
