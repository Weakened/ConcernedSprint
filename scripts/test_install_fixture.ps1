<#
.SYNOPSIS
    Tests install/uninstall of the packaged mod against a disposable,
    fake UE4SS Mods/ fixture -- never touches the real game.

.DESCRIPTION
    Builds a throwaway directory shaped like a real ue4ss\Mods\ folder,
    pre-populated with a fake unrelated mod and a mods.txt with existing
    entries (to prove install/uninstall doesn't disturb anything else),
    then: installs the packaged zip's ConcernedSprint folder into it,
    verifies the other mod and its mods.txt line are untouched and the
    new line was added correctly, uninstalls, and verifies the fixture is
    back to byte-identical file lists for everything that isn't
    ConcernedSprint itself. Exits 0 on pass, 1 on failure.

.EXAMPLE
    pwsh -File scripts/test_install_fixture.ps1
#>

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$artifactsDir = Join-Path $repoRoot "artifacts"

$zip = Get-ChildItem -Path $artifactsDir -Filter "ConcernedSprint-v*.zip" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $zip) {
    Write-Output "FAIL  no ConcernedSprint-v*.zip found in $artifactsDir -- run scripts/package.ps1 first"
    exit 1
}

$failures = 0
function Check($name, [bool]$ok, $detail) {
    if ($ok) {
        Write-Output "PASS  $name"
    } else {
        Write-Output "FAIL  $name -- $detail"
        $script:failures++
    }
}

$fixtureRoot = Join-Path $env:TEMP "cs-fixture-$([guid]::NewGuid())"
$modsDir = Join-Path $fixtureRoot "ue4ss\Mods"
New-Item -ItemType Directory -Path "$modsDir\SomeOtherMod\Scripts" -Force | Out-Null
"print('SomeOtherMod loaded')" | Set-Content "$modsDir\SomeOtherMod\Scripts\main.lua" -NoNewline

$originalModsTxt = @(
    "SomeOtherMod : 1"
    "AnotherExistingMod : 0"
    ""
    "; Built-in keybinds, do not move up!"
    "Keybinds : 1"
)
$originalModsTxt -join "`r`n" | Set-Content "$modsDir\mods.txt" -NoNewline

try {
    # Snapshot everything except what we're about to add, to compare
    # against after install+uninstall.
    $preExistingFiles = Get-ChildItem -Path $modsDir -Recurse -File |
        ForEach-Object { $_.FullName.Substring($modsDir.Length + 1) } | Sort-Object

    # --- Install ---
    $extractDir = Join-Path $env:TEMP "cs-fixture-extract-$([guid]::NewGuid())"
    Expand-Archive -Path $zip.FullName -DestinationPath $extractDir -Force
    Copy-Item -Path (Join-Path $extractDir "ConcernedSprint") -Destination "$modsDir\ConcernedSprint" -Recurse -Force
    Add-Content -Path "$modsDir\mods.txt" -Value "`r`nConcernedSprint : 1"
    Remove-Item -Path $extractDir -Recurse -Force

    Check "ConcernedSprint installed" (Test-Path "$modsDir\ConcernedSprint\Scripts\main.lua") "main.lua missing after install"
    Check "pre-existing mod untouched by install" (Test-Path "$modsDir\SomeOtherMod\Scripts\main.lua") "SomeOtherMod missing after install"

    $modsTxtAfterInstall = Get-Content "$modsDir\mods.txt" -Raw
    Check "mods.txt keeps existing lines after install" (
        $modsTxtAfterInstall -match [regex]::Escape("SomeOtherMod : 1") -and
        $modsTxtAfterInstall -match [regex]::Escape("AnotherExistingMod : 0") -and
        $modsTxtAfterInstall -match [regex]::Escape("Keybinds : 1")
    ) "an existing mods.txt line went missing"
    Check "mods.txt gained exactly the new ConcernedSprint line" ($modsTxtAfterInstall -match [regex]::Escape("ConcernedSprint : 1")) "new line not found"

    # --- Uninstall ---
    Remove-Item -Path "$modsDir\ConcernedSprint" -Recurse -Force
    $modsTxtLines = Get-Content "$modsDir\mods.txt" | Where-Object { $_ -notmatch "^ConcernedSprint\s*:" }
    $modsTxtLines -join "`r`n" | Set-Content "$modsDir\mods.txt" -NoNewline

    Check "ConcernedSprint folder removed by uninstall" (-not (Test-Path "$modsDir\ConcernedSprint")) "folder still present"

    $postUninstallFiles = Get-ChildItem -Path $modsDir -Recurse -File |
        ForEach-Object { $_.FullName.Substring($modsDir.Length + 1) } | Sort-Object
    $diff = Compare-Object -ReferenceObject $preExistingFiles -DifferenceObject $postUninstallFiles
    Check "file list after uninstall matches pre-install exactly" ($null -eq $diff) ("diff: " + ($diff | Out-String))

    $modsTxtAfterUninstall = Get-Content "$modsDir\mods.txt" -Raw
    Check "mods.txt has no leftover ConcernedSprint line after uninstall" ($modsTxtAfterUninstall -notmatch "ConcernedSprint") "leftover reference found"
    Check "mods.txt still has the pre-existing lines after uninstall" (
        $modsTxtAfterUninstall -match [regex]::Escape("SomeOtherMod : 1") -and
        $modsTxtAfterUninstall -match [regex]::Escape("AnotherExistingMod : 0") -and
        $modsTxtAfterUninstall -match [regex]::Escape("Keybinds : 1")
    ) "an existing mods.txt line was lost by uninstall"
}
finally {
    Remove-Item -Path $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output ""
if ($failures -eq 0) {
    Write-Output "All fixture install/uninstall checks passed."
    exit 0
} else {
    Write-Output "$failures check(s) failed."
    exit 1
}
