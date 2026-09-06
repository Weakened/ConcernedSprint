# Concerned Sprint

A small Demonologist mod: unlimited sprint duration for the locally
controlled player, at the game's original speed, with an enable/disable
toggle. Nothing else — no speed boosts, no other trainer features.

Status: source and packaging are complete and tested; actual in-game play
verification (holding sprint past normal exhaustion, disabling mid-session,
map/lobby transitions during real gameplay) is a pending owner check, not
yet observed. See the repository's `docs/RUNTIME_DISCOVERY.md` for exactly
what has and hasn't been confirmed.

## Requirements

- Demonologist (Steam app 1929610), the same build this was built and
  tested against — see `CHANGELOG.md` for the exact build id and engine
  version.
- UE4SS, `experimental-latest` prerelease build `UE4SS_v3.0.1-1125-g527a483b`
  or newer from the same channel (UE4SS stable releases do not support this
  game's engine version). Install UE4SS first — see the repository's
  `docs/INSTALL.md` for the exact download, checksum and install steps.
  UE4SS is a separate project (MIT licensed, UE4SS-RE/RE-UE4SS) and is not
  bundled with this mod.

## Install

1. Install UE4SS per `docs/INSTALL.md` first, and confirm it's working
   (the game launches normally and `ue4ss\UE4SS.log` shows no fatal error).
2. Copy the `ConcernedSprint` folder from this package into UE4SS's `Mods`
   folder, so you end up with
   `<game>\Shivers\Binaries\Win64\ue4ss\Mods\ConcernedSprint\Scripts\main.lua`.
3. Add a line to `ue4ss\Mods\mods.txt`: `ConcernedSprint : 1`
4. Launch the game. `ue4ss\UE4SS.log` should show
   `Starting Lua mod 'ConcernedSprint'` followed by
   `[ConcernedSprint] Mod loaded, enabled=true (toggle with Ctrl+F9)`.

## Enable / disable

The mod starts enabled by default. Press `Ctrl+F9` in-game to toggle it;
the choice is written to
`ue4ss\Mods\ConcernedSprint\enabled.txt` and remembered next launch.
Disabling takes effect immediately — no restart needed — and does not
leave any modified value behind, since the mod only ever tops sprint
stamina back up to the game's own maximum rather than writing a value of
its own invention.

## Uninstall

Delete the `ue4ss\Mods\ConcernedSprint` folder and remove the
`ConcernedSprint : 1` line from `ue4ss\Mods\mods.txt`. This does not touch
UE4SS itself, any other mod, or any shared UE4SS configuration.

To remove UE4SS entirely as well (only needed if you don't use any other
UE4SS mods), delete `ue4ss\Mods\ConcernedSprint` as above, plus
`dwmapi.dll` and the `ue4ss` folder next to the game's executable.

## Scope

Only sprint duration is affected. Movement speed, sprint input, sanity,
and every other system are untouched. The mod only ever acts on the
locally controlled player's own pawn.
