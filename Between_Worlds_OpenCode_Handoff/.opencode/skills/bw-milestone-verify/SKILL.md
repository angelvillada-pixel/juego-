---
name: bw-milestone-verify
description: Use after completing any milestone-sized work, and before calling a milestone done, to verify Between Worlds remains runnable and its important gameplay rules are covered by tests or reproducible checks.
---

# BW Milestone Verify

## Goal
Verify the game remains launchable and the milestone rules are testable before closing work.

## Verification Steps
1. **Launch Check**
   - Run the project headless to confirm startup validity: `godot --headless --path . --quit`

2. **Existing Test Coverage**
   - Ensure tests exist for key gameplay rules:
     - Armor/mitigation math
     - Damage and headshot multiplier behavior
     - Respawn flow
     - Pickup max caps
     - Construction/grid placement rules
     - Map layout determinism

3. **Milestone Smoke Checks**
   - Player can spawn, move, aim, and fire with the prototype weapons.
   - Light/Medium/Heavy movement differences remain visible.
   - Blocks can be placed/destroyed within grid rules.
   - Respawn returns the player to the match quickly.
   - Match-win condition remains functional.

4. **Docs Update Discipline**
   - If project behavior, structure, workflow, or any tracked milestone changed, update `AGENTS.md`.

## Output Expectation
- Report: runnable status, test coverage summary, and limitations found.
