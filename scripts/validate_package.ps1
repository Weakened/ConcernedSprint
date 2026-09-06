<#
.SYNOPSIS
    Validates a Concerned Sprint release candidate ZIP.

.DESCRIPTION
    Checks, against the built zip: the exact required file set is present
    (compared by path, not just count -- a required file swapped for an
    unexpected one with the same name-count is still caught), each
    required .lua file actually compiles as Lua source (not just a file
    with a matching name/extension -- catches a renamed binary), no
    forbidden content is present (loader binaries, game assets, logs,
    dumps, secrets), the version in the zip filename matches VERSION and
    is documented in CHANGELOG.md, and the recorded SHA-256 matches the
    zip's actual hash. Exits 0 if every check passes, 1 otherwise, with a
    PASS/FAIL line per check -- usable as a CI-style gate.

.PARAMETER ZipPath
    Path to the zip to validate. Defaults to the newest
    artifacts/ConcernedSprint-v*.zip.

.EXAMPLE
    pwsh -File scripts/validate_package.ps1
#>

param(
    [string]$ZipPath
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$artifactsDir = Join-Path $repoRoot "artifacts"

if (-not $ZipPath) {
    $latest = Get-ChildItem -Path $artifactsDir -Filter "ConcernedSprint-v*.zip" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $latest) {
        Write-Output "FAIL  no ConcernedSprint-v*.zip found in $artifactsDir -- run scripts/package.ps1 first"
        exit 1
    }
    $ZipPath = $latest.FullName
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

if (-not (Test-Path $ZipPath)) {
    Write-Output "FAIL  zip exists -- not found: $ZipPath"
    exit 1
}
Write-Output "Validating: $ZipPath"

$zipFileName = Split-Path -Leaf $ZipPath
$versionMatch = [regex]::Match($zipFileName, '^ConcernedSprint-v(\d+\.\d+\.\d+)\.zip$')
Check "zip filename matches ConcernedSprint-v<version>.zip" $versionMatch.Success $zipFileName
$zipVersion = if ($versionMatch.Success) { $versionMatch.Groups[1].Value } else { $null }

$fileVersion = (Get-Content -Path (Join-Path $repoRoot "VERSION") -Raw).Trim()
Check "zip version matches VERSION file ($fileVersion)" ($zipVersion -eq $fileVersion) "zip says $zipVersion"

$changelog = Get-Content -Path (Join-Path $repoRoot "mod\ConcernedSprint\CHANGELOG.md") -Raw
Check "version is documented in CHANGELOG.md" ($changelog -match [regex]::Escape("## $fileVersion")) "no '## $fileVersion' heading found"

$sha256Path = "$ZipPath.sha256"
if (Test-Path $sha256Path) {
    $recorded = (Get-Content -Path $sha256Path -Raw).Trim().Split(' ')[0].ToLower()
    $actual = (Get-FileHash -Path $ZipPath -Algorithm SHA256).Hash.ToLower()
    Check "recorded SHA-256 matches the zip's actual hash" ($recorded -eq $actual) "recorded=$recorded actual=$actual"
} else {
    Check "SHA-256 file exists ($sha256Path)" $false "not found"
}

$extractDir = Join-Path $env:TEMP "ConcernedSprint-validate-$([guid]::NewGuid())"
Expand-Archive -Path $ZipPath -DestinationPath $extractDir -Force
try {
    $modDir = Join-Path $extractDir "ConcernedSprint"
    Check "zip's top-level folder is named ConcernedSprint" (Test-Path $modDir) "expected $modDir"

    $requiredFiles = @(
        "README.md",
        "CHANGELOG.md",
        "Scripts\main.lua",
        "Scripts\sprint_adapter.lua",
        "Scripts\config.lua",
        "Scripts\lifecycle.lua"
    )
    foreach ($rel in $requiredFiles) {
        $full = Join-Path $modDir $rel
        Check "required file present: $rel" (Test-Path $full) "not found at $full"
    }

    # Compares actual relative paths against the required set, not just a
    # count -- a count-only check would pass if a required file were
    # swapped out for an equal number of unexpected ones.
    $actualRelativePaths = Get-ChildItem -Path $extractDir -Recurse -File | ForEach-Object {
        $_.FullName.Substring($extractDir.Length + 1)
    }
    $expectedRelativePaths = $requiredFiles | ForEach-Object { "ConcernedSprint\$_" }
    $unexpectedPaths = Compare-Object -ReferenceObject $expectedRelativePaths -DifferenceObject $actualRelativePaths |
        Where-Object { $_.SideIndicator -eq "=>" } | Select-Object -ExpandProperty InputObject
    Check "no unexpected files beyond the required set" ($unexpectedPaths.Count -eq 0) ("found: " + ($unexpectedPaths -join ', '))

    $forbiddenPatterns = @('*.dll', '*.exe', '*.pak', '*.log', '*.dmp', '*.usmap', '*.jmap', 'UE4SS*', '*CXXHeaderDump*', '*.sav')
    $forbiddenFound = @()
    foreach ($pattern in $forbiddenPatterns) {
        $forbiddenFound += Get-ChildItem -Path $extractDir -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue
    }
    Check "no loader binaries, game content, logs, dumps or saves present" ($forbiddenFound.Count -eq 0) ("found: " + (($forbiddenFound | Select-Object -ExpandProperty Name -Unique) -join ', '))

    foreach ($rel in $requiredFiles) {
        $full = Join-Path $modDir $rel
        if (Test-Path $full) {
            $content = Get-Content -Path $full -Raw
            $hasSecretLike = $content -match '(?i)(api[_-]?key|password|secret|token)\s*='
            Check "no secret-like content in $rel" (-not $hasSecretLike) "matched a secret-like pattern"
        }
    }

    # File-extension/name checks above only prove a file called
    # "Scripts\main.lua" exists, not that it actually contains Lua source
    # rather than, say, a renamed binary. Compiling each required .lua
    # file with the real Lua compiler (parse-only) is a lightweight,
    # meaningful proof that it's genuinely Lua text: a PE/binary payload
    # cannot parse as Lua.
    $luacCommand = Get-Command luac -ErrorAction SilentlyContinue
    if ($luacCommand) {
        $luaFiles = $requiredFiles | Where-Object { $_ -like "*.lua" }
        foreach ($rel in $luaFiles) {
            $full = Join-Path $modDir $rel
            if (Test-Path $full) {
                & luac -p $full 2>$null
                Check "$rel is valid Lua source (luac -p)" ($LASTEXITCODE -eq 0) "luac -p rejected this file -- it may not be real Lua source"
            }
        }
    } else {
        Check "luac is available to verify .lua files are real Lua source" $false "luac not found on PATH -- install Lua (see docs/RELEASE.md) to get this check; required-file-present checks above only prove a file with that name exists, not that its content is genuine Lua"
    }
}
finally {
    Remove-Item -Path $extractDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output ""
if ($failures -eq 0) {
    Write-Output "All checks passed."
    exit 0
} else {
    Write-Output "$failures check(s) failed."
    exit 1
}
