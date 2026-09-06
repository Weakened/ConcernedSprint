# Owner smoke test

Everything independently verifiable without actually playing the game has
been done (source, packaging, install/uninstall, and as much runtime
verification as is safe without live gameplay — see
`docs/RUNTIME_DISCOVERY.md`). What's left needs an actual play session.
This is deliberately short.

## Setup

1. Follow `docs/INSTALL.md` to install UE4SS, then Concerned Sprint
   (`artifacts/ConcernedSprint-v0.1.0.zip` — verify its SHA-256 against
   `ConcernedSprint-v0.1.0.zip.sha256` first).
2. Launch the game.

## Checklist

- [ ] **Launch**: `ue4ss\UE4SS.log` shows `[ConcernedSprint] Mod loaded,
      enabled=true` with no error after it. Game reaches the main menu
      normally.
- [ ] **Sprint past normal exhaustion**: start a game (single-player is
      the mode independently confirmed reachable so far — see the note
      below on multiplayer), hold sprint well past when it would normally
      run out. It should not run out while the mod is enabled.
- [ ] **Original speed unchanged**: sprint and walk speed both feel exactly
      as before installing the mod.
- [ ] **Toggle/disable**: press `Ctrl+F9`. `UE4SS.log` should show
      `[ConcernedSprint] Disabled (Ctrl+F9)`. Sprint should now exhaust
      normally again, with no restart needed. Press `Ctrl+F9` again to
      re-enable and confirm it comes back.
- [ ] **Map/lobby transition**: change map, die/respawn, or return to
      lobby and start a new game. The mod should keep working on the new
      pawn without needing to relaunch (check `UE4SS.log` for a fresh
      `[ConcernedSprint] Sprint adapter attached to local pawn` line and no
      errors around the transition).
- [ ] **Uninstall**: follow `docs/INSTALL.md` section 4. Confirm the game
      launches normally afterward with no trace of the mod in the log.

## Multiplayer

Only single-player is confirmed reachable/safe by this development
process (see `docs/RUNTIME_DISCOVERY.md` section 5 for why an automated
session didn't attempt online lobbies). If you test in a multiplayer
lobby, note here which mode (public/private, host/join) and how many
players — don't assume it behaves the same as single-player until it's
actually been tried, since the mod only ever acts on the locally
controlled player's own pawn and hasn't been observed in a networked
session.

## If something's wrong

Check `ue4ss\UE4SS.log` for `[ConcernedSprint]` lines and any Lua error
immediately after one. File it against CS-OPS-001 with the relevant log
excerpt.
