# Install and uninstall

The ZIP contains a self-contained [player README](../mod/ConcernedSprint/README.md)
with the pinned loader download/checksum, exact folders, **Ctrl+F9**,
configuration and complete removal steps. Those instructions are included
in the package so users do not need access to this source repository.

The destination is the executable folder:
`Demonologist\Shivers\Binaries\Win64`, not the top-level game folder.
UE4SS is a separate MIT-licensed dependency and is not bundled with the mod.

## Preserve an existing installation

Close the game before changing files. Back up the mod folder, `mods.txt`
and any loader files/settings you plan to replace. Record their paths and
hashes. Update only this mod's files and its own `mods.txt` entry.
Restore the backed-up files to roll back, preserving unrelated entries.

For a fresh installation used only for Concerned Sprint, bundled extras
may be disabled in `mods.txt`: CheatManagerEnablerMod, ConsoleCommandsMod,
ConsoleEnablerMod, BPML_GenericFunctions, BPModLoaderMod and Keybinds.
Concerned Sprint's keybind uses core UE4SS functionality. A minimal mod
list reduces variables when diagnosing a crash; it is not a proven fix
for the reported intermittent failure. Preserve extras other mods need.

Removing only the ConcernedSprint folder and its entry preserves UE4SS.
Removing the whole `ue4ss` folder also removes every mod contained in it.

## Current owner installation

The owner-verified install is still 0.1.0, with the loader enabled.
The source candidate is 0.1.2 and is uninstalled/unretested.
See [owner test evidence](OWNER_SMOKE_TEST.md) before deploying a candidate.
