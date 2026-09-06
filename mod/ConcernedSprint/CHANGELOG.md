# Changelog

## 0.1.2 — 2026-09-06 (release candidate, NOT installed, NOT retested)

Supersedes 0.1.1 before it was ever installed anywhere: 0.1.1's own
source fix landed correctly in its own PR, but a squash-merge
integrity gap meant two of its three commits (the ones fixing the
issues an independent review found in the first commit) never actually
reached `main`. That gap is corrected here, and this version adds one
further hardening fix found during that recovery work. **This version
has not been installed or retested against the actual game.** The
0.1.0 build the owner actually tested, and the currently-installed
loader state, are both left exactly as they were — see
`docs/RUNTIME_DISCOVERY.md` section 13 for the full history.

- Recovered: the pawn-identity fix in `on_actor_begin_play` (comparing
  by `GetAddress()` rather than `==`) and the accompanying
  `resolve_local_pawn()` validity check, both originally reviewed and
  merged as part of 0.1.1's own PR but lost in that PR's squash merge.
- Hardened: `sprint_adapter.lua`'s `apply()` now calls
  `component:IsValid()` immediately before every individual property
  read/write, not just once when the component was first cached.
  `get_sprint_component()` only validates at bind time, and the cached
  reference can be reused for several seconds afterward; per UE4SS's
  own source, a plain property read/write does not repeat that
  validity check the way `IsValid()` does, so a reference invalidated
  by a pawn/level transition inside that window could otherwise still
  reach a live property access. This closes that gap; it does not by
  itself prove or disprove the root cause of any specific previously
  reported crash.
- Corrected: `actor:IsA("Pawn")` (used to filter `BeginPlay` events
  before the expensive local-player search) is not a "local-only,
  zero-cost" check as earlier documentation claimed — passing a string
  to `IsA` resolves it to a class via `StaticFindObject` on every call,
  per UE4SS's own source. It remains far cheaper than the search it
  guards, which is the actual reason the ordering matters.

## 0.1.1 — 2026-09-06 (release candidate, superseded before install)

Fixed a defect (CS-DEF-001) found by the v0.1.0 owner smoke test, which
crashed with a native access violation during real gameplay. See 0.1.2
above: this version's source fix was correct as reviewed, but a
squash-merge gap meant part of it never reached `main`, so 0.1.2
supersedes it rather than this version ever being installed.

- Fixed: the `BeginPlay` hook never unwrapped its actor parameter
  (`:get()`), so its "is this the local pawn" check could never match.
  This was silent in menu-only testing but meant an expensive,
  uncached local-player search ran unconditionally on every single
  actor's `BeginPlay` during real gameplay, not just pawns.
- Filtered on `actor:IsA("Pawn")` before ever performing that search.
  Regression-tested by asserting on how often the search runs, not
  just on final behavior.
- `docs/INSTALL.md` now recommends disabling UE4SS's bundled extras
  (cheat manager, console mods, BP mod loader, keybinds) for a
  Concerned Sprint-only install; none of them are required for this
  mod's own functionality.

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
