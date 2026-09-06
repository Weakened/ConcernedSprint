# Concerned Sprint

Infinite sprint for Demonologist, by The Concerned Cat.
Sprint for as long as you like using the game's normal speed and controls.

**Ctrl+F9 turns infinite sprint on or off.** It starts enabled. Your choice
is saved in `ue4ss\Mods\ConcernedSprint\enabled.txt` for the next launch.
Turning it off stops stamina top-ups; normal drain resumes from your current
stamina. Turning it back on resumes top-ups without restarting.

## Requirements

Observed with Demonologist Steam build **25123233**, Unreal Engine **5.6.1**.
Install the separate, MIT-licensed UE4SS loader first. The pinned build is
**UE4SS_v3.0.1-1125-g527a483b.zip**; other builds have not been verified.

[Download the pinned UE4SS build](https://github.com/UE4SS-RE/RE-UE4SS/releases/download/experimental-latest/UE4SS_v3.0.1-1125-g527a483b.zip)

Loader SHA-256:
`4f9762f812329a640c8cfa14444c2bb97ecc213b8320bd4c5433383c3eef48f7`

This is a rolling upstream release; keep your verified copy. If the exact
asset is unavailable, another build's compatibility is unverified.

## Install

Close the game before changing files. The destination below is
`Demonologist\Shivers\Binaries\Win64`, containing
`Shivers-Win64-Shipping.exe`.

1. From the loader ZIP, copy `dwmapi.dll` and the complete `ue4ss` folder
   into that destination. If UE4SS is already installed, preserve its
   files/settings and check the existing build before replacing anything.
2. From this mod ZIP, copy `ConcernedSprint` into `ue4ss\Mods`.
   The main script should be at
   `ue4ss\Mods\ConcernedSprint\Scripts\main.lua`.
3. Add `ConcernedSprint : 1` on its own line in `ue4ss\Mods\mods.txt`,
   preserving all existing entries.
4. Launch through Steam. Use your normal sprint key; **Ctrl+F9** toggles
   infinite sprint. Status messages appear in `ue4ss\UE4SS.log`.

UE4SS's bundled extra mods are not required for Concerned Sprint or its
toggle. Keep existing mod settings if other mods rely on them.

## Uninstall

Close the game, delete `ue4ss\Mods\ConcernedSprint`, and remove only its
`ConcernedSprint : 1` entry from `mods.txt`. This preserves the loader
and other mods. If you use no other UE4SS mods, you may also remove
`dwmapi.dll` and the entire `ue4ss` folder; that removes all contained mods.

## Test status and known issue

The owner tested **0.1.0** on Cyclone Street and sprinted continuously for
about 30 seconds after relaunch. One earlier launch crashed in UE4SS; its
cause remains unproven. **0.1.2** adds lifecycle checks but has not yet
been gameplay-retested, so it is not a confirmed crash fix.
Toggle persistence and map/lobby transitions have not been individually
confirmed in gameplay. Multiplayer host/client behavior is unverified.
