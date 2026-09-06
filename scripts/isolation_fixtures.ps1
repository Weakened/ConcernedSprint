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
    one up and drop it in verbatim, without hand-editing mods.txt during
    a live session.

    Tier 0 (vanilla) has no mods.txt at all -- that's the point -- so it's
    represented by its own README explaining the state, not a mods.txt.

.EXAMPLE
    pwsh -File scripts/isolation_fixtures.ps1
#>

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $repoRoot "artifacts\cs-def-001-isolation"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

# Tier 0: vanilla -- UE4SS not installed at all (dwmapi.dll absent, no
# ue4ss folder). This is what "dwmapi.dll.concernedsprint-disabled"
# already produces on the next launch; recorded here just so the full
# tier list is in one place.
$tier0Dir = Join-Path $outDir "0-vanilla"
New-Item -ItemType Directory -Path $tier0Dir -Force | Out-Null
@"
Tier 0: vanilla (no loader)

State: dwmapi.dll and the ue4ss\ folder are both absent from the game
executable directory. This is the current containment state (dwmapi.dll
renamed to dwmapi.dll.concernedsprint-disabled) -- no action needed to
reach this tier, it's already where the real install sits.

Purpose: confirms the game itself is stable with no loader at all, as a
baseline. Not expected to crash; if it does, the defect isn't UE4SS-related.
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

Purpose: confirms the pinned UE4SS build (experimental-latest,
UE4SS_v3.0.1-1125-g527a483b) itself is stable against this game with zero
Lua mods active. If this tier crashes, the defect is in the loader/game
combination itself, independent of any mod (including ConcernedSprint).
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

Purpose: the actual recommended shipping configuration (see
docs/INSTALL.md). RegisterKeyBind is a core UE4SS binding (confirmed
against UE4SS/src/Mod/LuaMod.cpp at the pinned commit -- it is registered
directly, not provided by the bundled "Keybinds" mod), so ConcernedSprint's
Ctrl+F9 toggle does not require any other mod to be enabled. If this tier
is stable where the full config (tier 3) was not, the crash involved
interaction with one of the other bundled mods, not ConcernedSprint alone.
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

Purpose: reproduces the exact mods.txt from the preserved crash evidence
(C:\code\ConcernedSprint\artifacts\crash-owner-20260906-131405\mods.txt),
now running the fixed ConcernedSprint build, to confirm the fix holds
under the same conditions the crash actually occurred in -- not just a
narrower, cleaner tier.
"@ | Set-Content (Join-Path $tier3Dir "README.txt")

Write-Output "Isolation tiers written to: $outDir"
Get-ChildItem -Path $outDir -Recurse -File | ForEach-Object { Write-Output "  $($_.FullName.Substring($outDir.Length + 1))" }
