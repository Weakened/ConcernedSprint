# Changelog

## 0.1.0 — 2026-09-06 (release candidate)

Initial release candidate.

- Unlimited sprint duration for the locally controlled player; original
  movement speed and sprint controls unchanged.
- Enable/disable toggle (`Ctrl+F9`), persisted across sessions.
- Handles map changes, death/respawn and spectator pawn swaps.

### Tested against

- Demonologist, Steam app 1929610, build id `25123233`, engine
  `++UE5+Release-5.6-CL-44394996` (Unreal Engine 5.6.1).
- UE4SS `experimental-latest` prerelease, build
  `UE4SS_v3.0.1-1125-g527a483b` (SHA-256
  `4f9762f812329a640c8cfa14444c2bb97ecc213b8320bd4c5433383c3eef48f7`).

Full discovery and verification evidence: `docs/RUNTIME_DISCOVERY.md` in
the source repository.

### Known limitations

- UE4SS `experimental-latest` is a prerelease build; see
  `docs/RUNTIME_DISCOVERY.md` section 10 for a UE4SS-internal stability
  issue observed and mitigated during testing (residual risk during the
  first ~30 seconds after launch is not fully ruled out).
- Actual in-match play verification (stamina holding through an active
  sprint, disabling/toggling mid-session, map transitions during real
  gameplay) is a pending owner check — see the repository's owner smoke
  test checklist.
