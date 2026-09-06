# Building and validating a release candidate

Everything here is scripted and reproducible; none of it needs the game
running.

## Build

```powershell
pwsh -File scripts/package.ps1
```

Reads the version from `VERSION`, stages `mod/ConcernedSprint/README.md`,
`CHANGELOG.md` and `Scripts/*.lua` into a `ConcernedSprint/` folder (the
exact shape a user drops into `ue4ss\Mods\`), and writes to `artifacts/`
(git-ignored, never committed):

- `ConcernedSprint-v<version>.zip`
- `ConcernedSprint-v<version>.zip.sha256`
- `ConcernedSprint-v<version>.manifest.txt` (exact file list + hash)

## Validate

```powershell
pwsh -File scripts/validate_package.ps1
```

Checks the newest zip in `artifacts/` (or pass `-ZipPath` for a specific
one): required files present, no unexpected files, no loader binaries/game
content/logs/dumps/saves/secret-like strings, the zip's version matches
`VERSION` and is documented in `CHANGELOG.md`, and the recorded SHA-256
matches the zip's actual hash. Exits non-zero on any failure, with a
PASS/FAIL line per check. Verified to actually catch problems (not just
pass a good zip) by running it against a deliberately broken test zip
during development — see `docs/RUNTIME_DISCOVERY.md` section 12.

## Test install/uninstall against a disposable fixture

```powershell
pwsh -File scripts/test_install_fixture.ps1
```

Builds a throwaway fake `ue4ss\Mods\` folder (pre-populated with an
unrelated mod and existing `mods.txt` entries), installs the packaged zip
into it, uninstalls it, and checks: the other mod and its `mods.txt` line
were never touched, the new line was added and later removed cleanly, and
the fixture's file list after uninstall is byte-for-byte identical to
before install. Never touches the real game.

## Bumping the version

1. Update `VERSION`.
2. Add a new `## <version>` section to the top of
   `mod/ConcernedSprint/CHANGELOG.md`.
3. Re-run `scripts/package.ps1` then `scripts/validate_package.ps1`.
