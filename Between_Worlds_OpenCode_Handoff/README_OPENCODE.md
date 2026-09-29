# Between Worlds — OpenCode Handoff

This folder is the handoff package for building the game with OpenCode.

## Files
- `AGENTS.md` — persistent repository rules for OpenCode.
- `docs/MASTER_DESIGN.md` — agent-readable master design.
- `docs/Between_Worlds_Master_Design_v1_0.docx` — human-readable master document.
- `docs/DECISIONS.md` — frozen design decisions.
- `docs/OPEN_QUESTIONS.md` — unresolved items that are not blockers.
- `OPENCODE_FIRST_TASK.md` — the first implementation task.

## Recommended workflow
1. Put this package at the root of a new Git repository.
2. Open the repository in OpenCode.
3. Run `/init` if the repository has no useful `AGENTS.md`; review the result rather than blindly replacing the supplied rules.
4. Ask OpenCode to read `AGENTS.md` and the three docs in `docs/`.
5. Ask it to execute `OPENCODE_FIRST_TASK.md`.
6. Require it to stop after the first playable vertical slice and report tests/results before expanding scope.

OpenCode's current documentation recommends repository-level `AGENTS.md` for persistent project guidance, and supports an `opencode.json` `instructions` field for reusable instruction files.
