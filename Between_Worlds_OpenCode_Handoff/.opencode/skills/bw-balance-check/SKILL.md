---
name: bw-balance-check
description: Use when changing any combat or balance values in `game_constants.gd`, `weapon_data.gd`, `armor_data.gd`, `pickup_data.gd`, or `block_data.gd` to keep Between Worlds aligned with frozen rules and provisional baselines.
---

# BW Balance Check

## Goal
Keep tuning aligned with frozen decisions and milestone baselines.

## Frozen Rules
- `MAX_HP = 100`
- Armor mitigation: Light `0.10`, Medium `0.20`, Heavy `0.30`
- Horizontal speed modifier: Light `+10%`, Medium `0%`, Heavy `-10%`
- Jump behavior is shared across Light/Medium/Heavy.
- Global headshot multiplier `1.5x`; no conventional one-shot headshot.
- Damage zones only: HEAD / BODY.
- Normal bullets deal damage only; no knockback.
- No automatic HP regeneration and no automatic armor regeneration.
- Pickups never exceed normal maximums.
- Equipment can only change on death.

## Formula
Final damage = base damage * zone multiplier * (1 - mitigation)

## Tuning Guardrails
1. Cross-check any new weapon against TTK and no-one-shot constraints relative to `MAX_HP` and zone multipliers.
2. Ensure armor mitigation stays fixed during a life.
3. Keep jump behavior shared across armor weights.
4. If values are provisional, mark them as provisional and note they need validation.

## Fast Checks
- `DamageService.max_shot_damage(base_damage)` should remain a guardrail reference.
- `DamageService.is_one_shot_possible(base_damage)` must remain false for the current rifle-tier weak-to-head hit expectations unless design changes.
