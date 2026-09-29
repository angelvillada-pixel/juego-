---
name: bw-gdscript-guard
description: Use when reading or modifying Godot GDScript gameplay code (scripts under `src/`, autoloads, tests) to enforce typed, data-driven, testable implementation consistent with Between Worlds conventions.
---

# BW GDScript Guard

## Goal
Keep gameplay code typed, data-driven, and testable in Godot 4.7.2 / GDScript.

## Use When
- Editing `src/**/*.gd`, gameplay services, or unit tests.
- Adding/modifying `/src/data/*_data.gd` definitions.

## Rules
1. Prefer `class_name` + `extends` matching file intent.
2. Keep tunable values in `src/data/` or `src/core/game_constants.gd`, not scene-specific logic.
3. Do not duplicate combat formulas (`DamageService`) in weapons; share the rule.
4. Keep server-critical rules in pure singleton/service form so they can be reused by authoritative server later.
5. Keep signals explicit (`emit_signal` when codebase uses that convention).
6. When adding/moving gameplay code, update `AGENTS.md` if workflow or structure changed.
7. Do not add code-only docs; add behavior or update tests where appropriate.

## Quick Check Commands
- Verify project file: `godot --headless --path . --quit`
- Run unit tests when GUT is configured: run existing test suite via project docs.
