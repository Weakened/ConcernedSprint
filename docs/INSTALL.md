# Install / uninstall

Two separate things get installed: UE4SS (the loader — a third-party,
MIT-licensed project, not part of this repository or the packaged mod
ZIP) and Concerned Sprint itself (this mod, which runs inside UE4SS).
Installing/uninstalling the mod never touches UE4SS itself or any other
mod; installing/uninstalling UE4SS never touches this mod's files.

All paths below are relative to the actual game executable's folder,
e.g. `C:\Program Files (x86)\Steam\steamapps\common\Demonologist\Shivers\Binaries\Win64\`
(the folder containing `Shivers-Win64-Shipping.exe`, **not** the top-level
`Demonologist` folder).

## 1. Install UE4SS

Required first; the mod does nothing without it.

- Download: `UE4SS_v3.0.1-1125-g527a483b.zip` from
  `https://github.com/UE4SS-RE/RE-UE4SS/releases/download/experimental-latest/UE4SS_v3.0.1-1125-g527a483b.zip`
- Verify SHA-256: `4f9762f812329a640c8cfa14444c2bb97ecc213b8320bd4c5433383c3eef48f7`
- License: MIT (Copyright (c) 2022 Narknon), included as `LICENSE` inside
  that zip.
- **Why this exact build and not a stable release:** UE4SS support for
  this game's engine version (Unreal Engine 5.6) only exists in the
  `experimental-latest` prerelease channel, not in any tagged stable
  release, as of this writing. See `docs/RUNTIME_DISCOVERY.md` sections 1-2
  for the full evidence. Because `experimental-latest` is a rolling tag
  that gets updated in place, re-downloading it later may give you a
  different build than the one pinned and tested here — if you want
  exactly what was tested, keep a copy of this specific zip rather than
  re-downloading from the rolling tag.
- Extract the zip, then copy into the game executable's folder:
  - `dwmapi.dll` (the proxy DLL — this is the only file that goes directly
    in that folder)
  - the whole `ue4ss` folder (contains `UE4SS.dll`, `UE4SS-settings.ini`,
    default mods, etc.)
- Launch the game once via Steam. Confirm it worked: `ue4ss\UE4SS.log`
  should exist and contain `Using engine version: 5.6` with no fatal
  "Engine version is not supported" error.

If you already have other UE4SS mods installed, this step may already be
done — just confirm the `ue4ss` folder and `dwmapi.dll` are present; don't
overwrite an existing UE4SS install with an older/different build without
checking what you already have.

## 2. Install Concerned Sprint

1. Download the release ZIP (`ConcernedSprint-v<version>.zip`) and verify
   its SHA-256 against the `.sha256` file next to it (see
   `docs/RELEASE.md` for how the RC was built, or verify against the hash
   posted on the tracker issue for this release).
2. Extract it. You'll get a `ConcernedSprint` folder.
3. Copy that folder into `ue4ss\Mods\`, so you end up with:
   `ue4ss\Mods\ConcernedSprint\Scripts\main.lua`
   `ue4ss\Mods\ConcernedSprint\README.md`
   `ue4ss\Mods\ConcernedSprint\CHANGELOG.md`
4. Open `ue4ss\Mods\mods.txt` in a text editor and add a new line:
   `ConcernedSprint : 1`
   (Add it as its own line; don't remove or reorder any existing lines —
   this preserves whatever other mods you already have configured.)
5. Launch the game. `ue4ss\UE4SS.log` should show
   `Starting Lua mod 'ConcernedSprint'` then
   `[ConcernedSprint] Mod loaded, enabled=true (toggle with Ctrl+F9)`,
   with no Lua error following either line.

## 3. Enable / disable

`Ctrl+F9` toggles it in-game. The setting is written to
`ue4ss\Mods\ConcernedSprint\enabled.txt` and reloaded on the next launch.
You can also hand-edit that file (`enabled=true` or `enabled=false`) before
launching if you prefer not to use the keybind. No restart or reload is
needed after toggling — see `docs/RUNTIME_DISCOVERY.md` section 4.6 for why.

## 4. Uninstall Concerned Sprint (keep UE4SS)

1. Delete the `ue4ss\Mods\ConcernedSprint` folder.
2. Remove the `ConcernedSprint : 1` line from `ue4ss\Mods\mods.txt`.

That's the entire footprint — nothing else is touched. UE4SS itself, its
settings, and any other mods are unaffected.

## 5. Uninstall UE4SS entirely (only if you don't use any other UE4SS mods)

1. Do step 4 above first.
2. Delete `dwmapi.dll` and the `ue4ss` folder from the game executable's
   folder.

This restores the game folder to its state before UE4SS was ever
installed — verified reproducible in `docs/RUNTIME_DISCOVERY.md` (SHA-256
of every pre-existing file identical before install and after uninstall,
across multiple install/uninstall cycles during development).
