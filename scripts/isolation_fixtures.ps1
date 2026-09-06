<#
.SYNOPSIS
    Generates the four mods.txt isolation tiers for CS-DEF-001's retest
    plan, as inert reference files -- does not touch any real game
    install or launch anything.

.DESCRIPTION
    CS-DEF-001 requires isolating vanilla / bare-loader / loader-with-
    minimal-ConcernedSprint / current-full-config before a coordinated
    owner retest, to narrow whether other bundled mods participate in the
    crash. This script writes each tier's exact mods.txt content (and a
    short description of what's enabled) under
    artifacts/cs-def-001-isolation/ (git-ignored) so the retest can pick
    one up as a reference. Preserve unrelated entries rather than replacing
    an existing mods.txt wholesale. Change the real install only with the game closed.

    Tier 0 (vanilla) has no mods.txt at all -- that's the point -- so it's
    represented by its own README explaining the state, not a mods.txt.

.EXAMPLE
    pwsh -File scripts/isolation_fixtures.ps1
#>

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $repoRoot "artifacts\cs-def-001-isolation"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

# Tier 0 is a future diagnostic state, not the owner's current state.
# Disabling a verified injection proxy preserves the complete loader tree.
$tier0Dir = Join-Path $outDir "0-vanilla"
New-Item -ItemType Directory -Path $tier0Dir -Force | Out-Null
@"
Tier 0: vanilla (no loader)

Reference state: no UE4SS injection. The current owner install has its
verified dwmapi.dll enabled. To test this tier later, close the game,
back up/hash the proxy and reversibly rename only that verified proxy.
Preserve the ue4ss folder and all mod/configuration files; restore the
proxy afterward. This script does not apply any changes to the game.

Purpose: collect a no-loader baseline if diagnosing a recurring crash.
A result from one run alone does not prove or disprove a root cause.
"@ | Set-Content (Join-Path $tier0Dir "README.txt")

# Tier 1: bare loader -- UE4SS installed, nothing enabled in mods.txt at
# all (not even UE4SS's own bundled default mods).
$tier1Dir = Join-Path $outDir "1-bare-loader"
New-Item -ItemType Directory -Path $tier1Dir -Force | Out-Null
@"
CheatManagerEnablerMod : 0
ConsoleCommandsMod : 0
ConsoleEnablerMod : 0
SplitScreenMod : 0
LineTraceMod : 0
BPML_GenericFunctions : 0
BPModLoaderMod : 0



; Built-in keybinds, do not move up!
Keybinds : 0
"@ | Set-Content (Join-Path $tier1Dir "mods.txt")
@"
Tier 1: bare loader (UE4SS installed, everything disabled)

Purpose: gather evidence with the pinned loader and no Lua mods active.
This is a reference configuration for a controlled test, not a stability
claim. Preserve unrelated mod entries and configuration when preparing it.
"@ | Set-Content (Join-Path $tier1Dir "README.txt")

# Tier 2: loader + only ConcernedSprint (the isolated, minimal production
# configuration this fix's docs/INSTALL.md now recommends).
$tier2Dir = Join-Path $outDir "2-minimal-concernedsprint"
New-Item -ItemType Directory -Path $tier2Dir -Force | Out-Null
@"
CheatManagerEnablerMod : 0
ConsoleCommandsMod : 0
ConsoleEnablerMod : 0
SplitScreenMod : 0
LineTraceMod : 0
BPML_GenericFunctions : 0
BPModLoaderMod : 0



; Built-in keybinds, do not move up!
Keybinds : 0

ConcernedSprint : 1
"@ | Set-Content (Join-Path $tier2Dir "mods.txt")
@"
Tier 2: loader + only ConcernedSprint

Purpose: gather evidence with only ConcernedSprint active. Its Ctrl+F9
binding uses core UE4SS functionality and does not need the bundled
Keybinds mod. Differences between repeated runs may help narrow causes;
one successful run does not prove a cross-mod interaction caused the crash.
"@ | Set-Content (Join-Path $tier2Dir "README.txt")

# Tier 3: current full config -- exactly what the owner had installed
# when the crash occurred (from the preserved evidence's mods.txt).
$tier3Dir = Join-Path $outDir "3-current-full-config"
New-Item -ItemType Directory -Path $tier3Dir -Force | Out-Null
@"
CheatManagerEnablerMod : 1
ConsoleCommandsMod : 1
ConsoleEnablerMod : 1
SplitScreenMod : 0
LineTraceMod : 0
BPML_GenericFunctions : 1
BPModLoaderMod : 1



; Built-in keybinds, do not move up!
Keybinds : 1

ConcernedSprint : 1
"@ | Set-Content (Join-Path $tier3Dir "mods.txt")
@"
Tier 3: current full config (matches the crash)

Purpose: reference the recorded enabled-mod list at crash time. The
original settings are preserved locally. A later test of the new mod
under similar conditions is evidence, not proof of crash elimination.
Do not overwrite unrelated user entries to reproduce this list.
"@ | Set-Content (Join-Path $tier3Dir "README.txt")

Write-Output "Isolation tiers written to: $outDir"
Get-ChildItem -Path $outDir -Recurse -File | ForEach-Object { Write-Output "  $($_.FullName.Substring($outDir.Length + 1))" }
