<#
.SYNOPSIS
    Builds the Concerned Sprint release candidate ZIP under artifacts/.

.DESCRIPTION
    Reads the version from VERSION, stages exactly the mod's redistributable
    files (mod/ConcernedSprint/README.md, CHANGELOG.md, Scripts/*.lua -- no
    loader binaries, no game content) into a ConcernedSprint/ folder shaped
    exactly like the Mods/ConcernedSprint/ a user drops into their UE4SS
    install, zips it, and writes a SHA-256 file and a manifest listing
    every file the zip contains.

    Reproducible: run it again and, source unchanged, the same six files
    go into the zip every time (Compress-Archive's own timestamp/ordering
    behavior isn't guaranteed byte-identical across runs, which is why
    validate_package.ps1 checks *contents*, not a whole-zip hash equal to
    a previously recorded one).

.EXAMPLE
    pwsh -File scripts/package.ps1
#>

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$version = (Get-Content -Path (Join-Path $repoRoot "VERSION") -Raw).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') {
    throw "VERSION file does not contain a plain x.y.z version string: '$version'"
}

$modSourceDir = Join-Path $repoRoot "mod\ConcernedSprint"
if (-not (Test-Path $modSourceDir)) {
    throw "Mod source directory not found: $modSourceDir"
}

$artifactsDir = Join-Path $repoRoot "artifacts"
New-Item -ItemType Directory -Path $artifactsDir -Force | Out-Null

$zipName = "ConcernedSprint-v$version.zip"
$zipPath = Join-Path $artifactsDir $zipName

$stagingRoot = Join-Path $env:TEMP "ConcernedSprint-package-staging-$([guid]::NewGuid())"
$stagingModDir = Join-Path $stagingRoot "ConcernedSprint"
New-Item -ItemType Directory -Path $stagingModDir -Force | Out-Null

try {
    Copy-Item -Path (Join-Path $modSourceDir "README.md") -Destination $stagingModDir -Force
    Copy-Item -Path (Join-Path $modSourceDir "CHANGELOG.md") -Destination $stagingModDir -Force
    Copy-Item -Path (Join-Path $modSourceDir "Scripts") -Destination $stagingModDir -Recurse -Force

    if (Test-Path $zipPath) {
        Remove-Item -Path $zipPath -Force
    }
    Compress-Archive -Path $stagingModDir -DestinationPath $zipPath -CompressionLevel Optimal

    $hash = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash.ToLower()
    $sha256Path = "$zipPath.sha256"
    "$hash  $zipName" | Set-Content -Path $sha256Path -Encoding ASCII -NoNewline
    Add-Content -Path $sha256Path -Value "" -Encoding ASCII

    $manifestPath = Join-Path $artifactsDir "ConcernedSprint-v$version.manifest.txt"
    $manifestLines = @(
        "Concerned Sprint release candidate manifest"
        "Version: $version"
        "Zip: $zipName"
        "SHA-256: $hash"
        ""
        "Contents:"
    )
    Get-ChildItem -Path $stagingModDir -Recurse -File | Sort-Object FullName | ForEach-Object {
        $relative = $_.FullName.Substring($stagingRoot.Length + 1).Replace('\', '/')
        $manifestLines += "  $relative ($($_.Length) bytes)"
    }
    $manifestLines -join "`r`n" | Set-Content -Path $manifestPath -Encoding ASCII

    Write-Output "Built: $zipPath"
    Write-Output "SHA-256: $hash"
    Write-Output "Manifest: $manifestPath"
}
finally {
    Remove-Item -Path $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
}
