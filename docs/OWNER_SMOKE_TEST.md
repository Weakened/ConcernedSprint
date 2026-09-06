# Owner test evidence and remaining checks

## Recorded PASS: installed 0.1.0

On 2026-09-06, after an initial UE4SS startup crash, the owner successfully
relaunched, reached Cyclone Street and sprinted continuously for about
30 seconds. The owner subsequently reported that in-game testing works fine.
The installed Lua files were checked against the original staged 0.1.0
and matched. The verified loader proxy is present and enabled.

Package validation and reversible install/uninstall fixture checks are
separate automated evidence; they do not establish gameplay stability.

## Current candidate: 0.1.2

0.1.2 recovers follow-up fixes and checks cached component validity.
It has not been installed or gameplay-retested. The known native crash's
cause remains unproven. Keep the working 0.1.0 install until a coordinated
test of the new candidate.

For that test, close the game, back up the existing mod folder and
`mods.txt`, then follow [installation instructions](INSTALL.md) with
`artifacts/ConcernedSprint-v0.1.2.zip` and its matching SHA-256 sidecar.

- [ ] Launch 0.1.2, enter a match and sprint for at least a minute.
      Compare walk/sprint speed with normal play.
- [ ] Press **Ctrl+F9**: stamina should drain normally. Press it again:
      unlimited sprint should resume. Relaunch once with it disabled to
      check the saved setting, then turn it back on.
- [ ] Return to the lobby and start another match; confirm sprint still works.

If a crash recurs, preserve that run's logs locally and record the result
on issue #8. Do not share account identifiers or raw dumps publicly.
Isolation configurations are optional diagnostic references, not completed
tests or a required four-tier owner checklist.

Multiplayer host/client behavior has not been verified; no compatibility
claim is made for an untested mode.
