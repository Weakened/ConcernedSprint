# Concerned Sprint agent instructions

## Authority and scope
The user authorized a quick Demonologist infinite-sprint mod with issues completed by Claude using the Teamster-style autonomous workflow. This is a separate Unreal project, not a Valheim product. Follow CS-OPS-001 and the three ordered CS leaf issues.

Canonical tree: C:\\code\\ConcernedSprint. Verify git rev-parse --show-toplevel before mutations. One writer in this tree. Do not edit other repositories or interrupt their workers.

Read CLAUDE.md, docs/AUTONOMOUS_EXECUTION.md and the current issue before implementation. Preserve issue acceptance criteria and keep the product to infinite sprint at original speed, ordinary sprint controls, and an enable/disable setting.

## Workflow
- Work on the lowest-numbered unblocked CS leaf. Claim it with session/branch evidence.
- One issue per feat/cs-NNN-slug, fix/cs-NNN-slug, chore/cs-NNN-slug or docs/cs-NNN-slug branch and PR.
- Research the actual installed game and current official loader docs. Never invent class/property/function names or imply generic scaffolding is game-compatible.
- Use focused, meaningful checks for runtime behavior, lifecycle, configuration and packaging. Do not generate tests merely mirroring implementation.
- Obtain an independent read-only review, fix findings, merge ordinary PRs after criteria pass, close with exact evidence and continue immediately.
- No force-push, history rewrite, destructive Git, changing repository access, paid CI services, or public releases.
- Do not commit/distribute proprietary game binaries/assets, local SDK dumps, raw personal logs, saves, credentials or downloaded loader binaries. Reference pinned upstream loader releases with license information.
- Preserve existing game files/configs; any test deployment must have a precise reversible install/uninstall manifest. Do not alter existing saves or use public multiplayer sessions for tests.
- Preserve normal speed, interactions and non-stamina behavior. Apply only to the locally controlled pawn; do not assume multiplayer authority or claim untested peer compatibility.
- Missing/changed runtime targets must disable the feature with actionable diagnostics, not silently write speculative properties.
- Record runtime tests as pending until actually observed. Owner play-test and every public publication are human gates, after all independently completable work.
