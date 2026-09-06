# Changelog

## 0.1.2 - 2026-09-06 (release candidate; not gameplay-retested)

- Recovered two follow-up fixes committed after PR #9 merged: compare
  local-pawn identity by native address and validate the resolved pawn.
- Check cached sprint-component validity before accessing stamina.
  A component can become invalid between periodic pawn resolutions.
- Corrected the description of the BeginPlay filter: IsA with a string
  performs a class lookup; it does not avoid all object lookup.
- These corrections do not establish the cause of the reported native crash.

## 0.1.1 - 2026-09-06 (superseded before install)

- Unwrap the BeginPlay actor parameter and filter pawn events before
  resolving the local player. Later review fixes needed a separate PR
  because they were committed after this version's PR merged.
- Neither 0.1.1 nor 0.1.2 has been installed or gameplay-retested.

## 0.1.0 - 2026-09-06

- Unlimited sprint duration for the locally controlled player.
- Preserve normal movement speed and sprint controls.
- Ctrl+F9 toggles the feature; the setting is saved between sessions.
- Periodically rebind the sprint component when the local pawn changes.

Owner evidence: after an initial startup crash, the owner relaunched,
reached Cyclone Street and sprinted continuously for about 30 seconds.
The owner subsequently reported that in-game testing works fine.

### Compatibility and remaining checks

Observed game: Demonologist Steam app 1929610, build 25123233,
Unreal Engine 5.6.1 (5.6-CL-44394996).
Observed loader: UE4SS_v3.0.1-1125-g527a483b.

The intermittent native crash remains under investigation. Gameplay with
0.1.2, Ctrl+F9 behavior, saved toggle state, speed comparison and a
lobby/map transition remain to be individually verified. Multiplayer
host/client behavior has not been verified. See README.md for installation.
