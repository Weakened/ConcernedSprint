# Runtime discovery (CS-001, CS-002, CS-003, CS-DEF-001)

## Current audit status - 2026-09-06

Owner PASS applies to installed **0.1.0**: successful relaunch, Cyclone
Street reached and about 30 seconds of continuous sprint. The owner later
reported that in-game testing works fine. The installed Lua hashes match
the original staged 0.1.0; the verified dwmapi.dll proxy is present/enabled.
**0.1.2** is the current source candidate and has not been installed or
gameplay-retested. The earlier native crash's cause remains unproven.
See [the short remaining checklist](OWNER_SMOKE_TEST.md). Historical
discovery/menu tests below are not additional owner gameplay passes.

Evidence for the installed Demonologist build, the selected UE4SS loader, and the
real sprint/stamina hook. All findings below come from direct inspection of the
locally licensed install and a reversible, isolated UE4SS probe run against it
(session `claude-bg-f2f50a48`, 2026-09-06). No class, property or function name
in this document is guessed; each one was read from either the game's own file
version resource or from UE4SS reflection/SDK data generated against the live
process. Sections 1-6 are CS-001 (discovery); 7-11 are CS-002
(implementation and its own runtime verification); 12 is CS-003 (packaging
and install/uninstall validation); 13 is CS-DEF-001 (the v0.1.0 owner smoke
test crash: investigation, fix, and what remains unproven).

## 1. Installed game and engine

| Fact | Value | Source |
|---|---|---|
| Install path | `C:\Program Files (x86)\Steam\steamapps\common\Demonologist` | local filesystem |
| Steam app id | 1929610 | `steamapps\appmanifest_1929610.acf` |
| Installed build id | `25123233` | `appmanifest_1929610.acf` (`buildid`), matches kickoff notes |
| Game executable | `Shivers\Binaries\Win64\Shivers-Win64-Shipping.exe` (166,362,624 bytes) | filesystem |
| Engine version | **Unreal Engine 5.6.1** | executable's file-version resource: `FileVersion`/`ProductVersion` = `++UE5+Release-5.6-CL-44394996`, `ProductName` = `Demonologist`, `CompanyName` = `Clock Wizard Games` |
| Engine version (runtime-confirmed) | `5.6` | UE4SS `UE4SS.log`: `[PS] Found EngineVersion: 5.6` and `Using engine version: 5.6` at loader init (see §3) |

The engine version was read two independent ways — statically from the shipping
exe's PE version resource, and again at runtime by UE4SS's own pattern scanner —
and both agree. This confirms the developer's "2.0" Steam announcement (UE5.6
upgrade) referenced in the tracker.

## 2. Loader selection

UE4SS stable `v3.0.1` (released 2024-02-14) predates UE 5.6 entirely. UE 5.6
support was added upstream in [UE4SS-RE/RE-UE4SS#977](https://github.com/UE4SS-RE/RE-UE4SS/pull/977)
("Added support for 5.6", fixes [#972](https://github.com/UE4SS-RE/RE-UE4SS/issues/972)),
merged 2025-08-22. That fix has **not** been included in any tagged stable
release; it only ships in the rolling `experimental-latest` prerelease.

| Fact | Value |
|---|---|
| Loader | UE4SS, rolling `experimental-latest` prerelease |
| Pinned build | `UE4SS_v3.0.1-1125-g527a483b.zip` (git describe: v3.0.1 + 1125 commits, commit `527a483b`) |
| Download URL | `https://github.com/UE4SS-RE/RE-UE4SS/releases/download/experimental-latest/UE4SS_v3.0.1-1125-g527a483b.zip` |
| Asset published | 2026-09-05T20:02:59Z (per GitHub release API) |
| SHA-256 (verified) | `4f9762f812329a640c8cfa14444c2bb97ecc213b8320bd4c5433383c3eef48f7` |
| License | MIT, Copyright (c) 2022 Narknon — confirmed both via GitHub's repo license API and the `LICENSE` file bundled inside the downloaded zip (byte-identical text) |
| Upstream's own caveat | Release notes for this PR: "Basic support for 5.6. Does not support Utf8String in any capacity. Boot and dumpers (except UHT) work." |

This is a provisional/experimental loader by upstream's own description, not a
stable tagged release. It is pinned by exact filename/commit, not by a floating
tag, so a future `experimental-latest` update will not silently change what
ships.

Install layout (confirmed by both the pinned release's own notes and
`docs.ue4ss.com`'s "Load Priority Order" section, and reproduced exactly by
extracting the zip):

```
Shivers\Binaries\Win64\
    dwmapi.dll              <- proxy DLL only file added outside ue4ss\
    ue4ss\
        UE4SS.dll
        UE4SS-settings.ini
        UE4SS.log
        LICENSE
        Mods\
            mods.txt
            ...built-in mods...
```

## 3. Reversible install probe — runtime evidence

A backup manifest was recorded before any change: file listing and SHA-256 of
every pre-existing file directly under `Shivers\Binaries\Win64\` (the `exe`,
`tbb12.dll`, `tbbmalloc.dll`, plus the untouched `D3D12\`/`DML\` vendor-redist
subfolders). The loader was installed additively (only `dwmapi.dll` and a new
`ue4ss\` folder were added; nothing pre-existing was overwritten), the game was
launched twice via Steam (`steam.exe -applaunch 1929610`) for probing, then
fully uninstalled by deleting those two added paths.

**Result: fully reversible.** Post-uninstall SHA-256 of the three pre-existing
files is byte-identical to the pre-install baseline (both columns below are
the actual values read at each point in time, not a single asserted figure):

| File | SHA-256 before install | SHA-256 after uninstall |
|---|---|---|
| `Shivers-Win64-Shipping.exe` | `ee3ff0f135481b5a540b296a26700541c198fbfa7dc347985b26c8ba87432f6e` | `ee3ff0f135481b5a540b296a26700541c198fbfa7dc347985b26c8ba87432f6e` |
| `tbb12.dll` | `5fdf9e1d91ce4b03cb6742d551538010ce995b430f4c28b2a1d664fabb46ad89` | `5fdf9e1d91ce4b03cb6742d551538010ce995b430f4c28b2a1d664fabb46ad89` |
| `tbbmalloc.dll` | `0bd90f4831d625613ca5f5279cce892413e6542590f8a8d95b7c46ac04e10a2a` | `0bd90f4831d625613ca5f5279cce892413e6542590f8a8d95b7c46ac04e10a2a` |

No save data was touched (single-player, main-menu only, no online lobby was
created).

**Observed runtime evidence** (from `UE4SS.log`, loader run against the real
process — this is not a static/offline claim):

```
[PS] Found EngineVersion: 5.6
[PS] Found BuildConfiguration: Shipping
Using engine version: 5.6
...
Starting Lua mod 'StaminaProbe'
[Lua] [StaminaProbe] Mod loaded
```

No "Engine version is not supported" fatal error occurred (the failure mode
reported by other UE4SS users on stable releases against UE 5.6 titles, e.g.
comments on upstream issue #972). The loader attached, scanned, and ran a
custom Lua mod against the live process. This confirms the loader/engine
compatibility claim in §2 with actual runtime behavior, not just release notes.

## 4. Stamina/sprint system — reflection evidence

Discovery method: a read-only Lua probe mod (`Mods/StaminaProbe`, full source
kept out of git per policy, available in the PR description) was loaded by
UE4SS at game start. It (a) scanned every live `UObject` for names containing
`stamina`/`sprint`/`exhaust`/`fatigue` via the Lua `ForEachUObject` global, and
(b) called UE4SS's native `GenerateSDK()` dumper, which writes one C++-style
header per loaded class to `CXXHeaderDump/` — this is UE4SS's own SDK
generator, not hand-transcribed output, so property names, types and struct
offsets below are machine-generated from the game's actual reflection data.

### 4.1 The stamina/sprint component

Package: `/Game/Furkan/BASE/Blueprints/Components/SprintComponent/BP_SprintComponent`
Class: `BP_SprintComponent_C` (Blueprint-generated, extends `UActorComponent`)

```cpp
class UBP_SprintComponent_C : public UActorComponent
{
    double MaximumStamina;                          // 0x00C0
    double Stamina;                                  // 0x00C8
    bool   IsSprinting;                               // 0x00D0
    FBP_SprintComponent_COnSprintingStatusUpdated OnSprintingStatusUpdated; // 0x00D8
    float  StaminaValueChangeTime;                    // 0x00E8
    FTimerHandle StaminaChangeTimer;                   // 0x00F0
    double StaminaValueChangeRateBySeconds;            // 0x00F8
    bool   IsResting;                                  // 0x0100
    FBP_SprintComponent_COnTired OnTired;              // 0x0108
    bool   bIsSprintingBlocked;                        // 0x0118

    void   SetSprintBlocked(bool bBlock);
    double GetStaminaValueAddMultiplier();
    bool   CanSprint();
    void   InitializeStaminaComponent();
    void   UpdateStaminaValue();
    void   SetUpdateStaminaTimer();
    void   RequestCancelSprint();
    void   RequestDoSprint();
    void   ReceiveBeginPlay();
    void   ReceiveTick(float DeltaSeconds);
    void   OnTired__DelegateSignature();
    void   OnSprintingStatusUpdated__DelegateSignature(bool IsSprinting);
};
```

This is a purpose-built stamina system (dedicated `UpdateStaminaValue`/
`SetUpdateStaminaTimer`/`GetStaminaValueAddMultiplier` functions and an
`OnTired` delegate that fires on exhaustion), not a generic or guessed
placeholder.

### 4.2 How the local player character references it

Package: `/Game/Furkan/BASE/Blueprints/Characters/Player/BP_BasePlayerCharacter`
Class: `BP_BasePlayerCharacter_C` (extends `ABP_BasicCharacter_C` → `ABP_PrimitiveCharacter_C`)

Relevant excerpt (from the same `GenerateSDK()` dump):

```cpp
class ABP_BasePlayerCharacter_C : public ABP_BasicCharacter_C
{
    class UBP_SprintComponent_C* BP_SprintComponent;   // 0x08E8
    ...
    void GetCharacterSprintingSpeed(double& Speed);
    void GetCharacterWalkSpeed(double& Speed);
    void InpActEvt_IA_Sprint_K2Node_EnhancedInputActionEvent_10(...);
    void InpActEvt_IA_Sprint_K2Node_EnhancedInputActionEvent_9(...);
    void InpActEvt_IA_Sprint_K2Node_EnhancedInputActionEvent_8(...);
    void BndEvt__BP_BasePlayerCharacter_BP_SprintComponent_K2Node_ComponentBoundEvent_1_OnTired__DelegateSignature();
    void BndEvt__BP_BasePlayerCharacter_BP_SprintComponent_K2Node_ComponentBoundEvent_0_OnSprintingStatusUpdated__DelegateSignature(bool IsSprinting);
};
```

So the property path from a possessed pawn is simply
`Pawn.BP_SprintComponent.Stamina` / `Pawn.BP_SprintComponent.MaximumStamina`
(standard UE4SS Lua property access, `UObject.MemberName`). Sprint input is
bound through three Enhanced Input events on `IA_Sprint`
(`/Game/Furkan/BASE/Input/InputActions/IA_Sprint`), i.e. the game uses UE5
Enhanced Input, not legacy input — confirmed by the `InputAction` object
matching in the live scan and by these bound-event function names. Movement
speed (`GetCharacterSprintingSpeed`/`GetCharacterWalkSpeed`) is a separate,
untouched code path — nothing about the stamina system changes speed values.

The actual gameplay pawn class is `ABP_PlayerCharacter_C`, which extends
`ABP_BasePlayerCharacter_C` (confirmed via `GenerateSDK()`'s class hierarchy
line: `class ABP_PlayerCharacter_C : public ABP_BasePlayerCharacter_C`) and
therefore inherits `BP_SprintComponent` unchanged. Its exact `/Game/...`
package path was not independently captured this session (only its class name
and member layout were, via the SDK dump) — noted here as a pending detail
rather than guessed.

### 4.3 Pawn replacement (death → spectator)

Package: `/Game/Furkan/BASE/Blueprints/Characters/Player/BP_SpectatorCharacter`
Class: `BP_SpectatorCharacter_C` — **also** extends `ABP_BasePlayerCharacter_C`,
so it also inherits a `BP_SprintComponent`. This was independently confirmed
both in the live `ForEachUObject` scan (a `BP_SprintComponent_GEN_VARIABLE`
default sub-object under `BP_SpectatorCharacter_C`) and in its `GenerateSDK()`
header. Practically: because both the live gameplay pawn and the
death/spectator pawn share the same base class and the same sprint-component
property name, a mod that operates generically on "whatever class the local
`PlayerController.Pawn` currently is, if it has a `BP_SprintComponent`
property" needs no special-casing for the death→spectator transition — it
naturally becomes a safe no-op on classes without that property, and picks
the component back up automatically on any future pawn/level change.

### 4.4 Local-pawn identification (chosen approach)

Not guessed — verified against the actual UE4SS Lua API docs
(`docs.ue4ss.com`, `RE-UE4SS/docs/lua-api.md` on GitHub, fetched directly) and
exercised at runtime:

- `UEHelpers:GetPlayerController()` (bundled `Mods/shared/UEHelpers/UEHelpers.lua`)
  returns the local player's `PlayerController`. `.Pawn` on it is the locally
  controlled pawn — this is the standard, documented pattern
  (`docs/guides/creating-a-lua-mod.md`'s own worked example uses exactly this).
- `RegisterBeginPlayPostHook(callback)` is a native, engine-wide hook on
  `AActor::BeginPlay` (`HookBeginPlay = 1` in `UE4SS-settings.ini`, on by
  default) — it fires for every actor, so filtering `Actor == PlayerController.Pawn`
  inside the callback reliably catches (re)possession on level load, death/
  respawn, and pawn replacement without polling.
- This was exercised for real: the probe mod registered this hook at startup
  and the loader logged its native hook registration successfully
  (`[UE4SS.BeginPlay.LuaModImpl] Added prehook/posthook`). The local player's
  pawn did not spawn during this session (see §5 — reaching a live match needs
  human/owner interaction), so the callback firing *for the local pawn
  specifically* remains pending runtime evidence, not yet observed.

### 4.5 A real UE4SS/UE5.6 binding limitation found along the way

Iterating `BP_SprintComponent_C`'s properties one-by-one via the Lua
`ForEachProperty` API crashed after exactly one property (`UberGraphFrame`,
a Blueprint-internal property, not stamina-related):

```
ForEachProperty error on BlueprintGeneratedClass .../BP_SprintComponent.BP_SprintComponent_C:
...main.lua:33: [Lua::call_function] lua_pcall returned LUA_ERRRUN => attempt to call a nil value
stack traceback:
    [C]: in method 'ForEachProperty'
```

This is consistent with this build's own documented caveat for 5.6 support
("basic support... boot and dumpers work") — some property type on this class
isn't fully Lua-bindable yet in this experimental build. The outer `pcall`
around the call caught it cleanly (no crash of the mod or game), and it is why
§4.1's property list was captured via `GenerateSDK()`'s native C++ dumper
instead, which does not go through the same per-property Lua callback and
completed without error. **Practical consequence for CS-002:** implement
stamina access via direct named property access (`Component.Stamina`,
`Component.MaximumStamina`, UE4SS's documented `__index`/`__newindex`/
`GetPropertyValue`/`SetPropertyValue`, all simple `double`/`bool` reads) rather
than enumerating all properties on the class — the specific properties needed
are plain doubles and a bool, not the type that crashed enumeration.

### 4.6 Planned disable/restore behavior (design, not yet implemented)

CS-002 has not been implemented yet, so this is a design description, not an
observed result — but the shape of it follows directly from §4.1's evidence
and does not require guessing anything new:

- `BP_SprintComponent_C` already owns its own depletion/regen loop
  (`SetUpdateStaminaTimer` / `UpdateStaminaValue`, driven by
  `StaminaChangeTimer` and `StaminaValueChangeRateBySeconds`) — this is
  vanilla game logic that keeps running regardless of the mod. The mod is not
  expected to replace or own this loop; it only needs to counteract its
  effect while enabled.
- The intended hook is therefore additive and non-destructive: while enabled,
  periodically (or on a hook into `UpdateStaminaValue`) re-set `Stamina` back
  toward `MaximumStamina` for the locally controlled pawn's
  `BP_SprintComponent`, and/or hook `CanSprint()` to bypass the depletion
  gate. Nothing about `MaximumStamina`, `StaminaValueChangeRateBySeconds`, or
  the walk/sprint speed getters (`GetCharacterWalkSpeed`/
  `GetCharacterSprintingSpeed`) would be modified — those stay exactly as the
  game defines them, satisfying "preserve normal speed" from the issue scope.
- **Disabling** is therefore just "stop doing the periodic top-up / stop
  intercepting `CanSprint()`". Nothing needs to be written back or restored,
  because nothing the mod touches is ever set to a mod-invented value —
  `Stamina` is only ever pushed toward `MaximumStamina`, a value the game
  itself already defines and continues to manage. On the very next timer tick
  after disabling, the component's own unmodified `UpdateStaminaValue` resumes
  depleting `Stamina` normally, with no reload/restart required.
- None of this reads or writes anything persisted to disk (no save file, no
  config the game owns), so there is no save-state or persistence concern —
  confined entirely to the live in-memory component instance for the current
  pawn, which is naturally discarded on pawn/level change like any other
  actor component.
- This remains a design description until CS-002 actually implements and
  tests it; §5 tracks the runtime observation of it as still pending.

## 5. What remains pending (owner/runtime gate)

Per AGENTS.md, unobserved runtime checks stay explicitly pending rather than
assumed. Status below is as of CS-001; §7-11 record what CS-002 additionally
observed (some of these items were narrowed, not eliminated — see the
forward references).

- **Not yet observed:** the local player's `BP_SprintComponent.Stamina` value
  actually depleting during a live sprint, or `OnTired` firing at zero. This
  needs a spawned pawn in an active game/lobby. Reaching that state requires
  navigating Demonologist's menu/lobby flow, which this session did not
  attempt — an autonomous agent blindly driving 3D game menus with no visual
  feedback risks unintended actions (e.g. an online session) and cannot verify
  it landed correctly; single-player is confirmed available (Steam community
  discussion) for whenever a human or a future visually-driven session runs
  this. CS-002/CS-003 should record this explicitly as pending until an actual
  play session confirms it. **Update, CS-002 (§9):** the adapter was observed
  attaching to a real, live `BP_SprintComponent` and applying without error;
  actual depletion-during-active-sprint is still unobserved (menu context, not
  gameplay) and remains a CS-003 item.
- **Not yet captured:** `ABP_PlayerCharacter_C`'s exact `/Game/...` asset path
  (its class layout is confirmed; see §4.2). Still not captured after CS-002.
- Disabling behavior: the intended design is described in §4.6 (stop the
  top-up, the component's own unmodified loop resumes normal depletion
  immediately, nothing persisted). It is not yet implemented or observed —
  the hook has not been written yet, only the interception target and design
  identified. **Update, CS-002:** now implemented (§7) and covered by unit
  tests (§8); the keybind toggle's registration is confirmed live (§9) but an
  actual keypress-triggered toggle was not confirmed (§9 notes why) and
  in-match observation remains a CS-003 item.

## 6. Reproduction

1. Verify the installed build: read `buildid` from
   `steamapps\appmanifest_1929610.acf`; read the file-version resource of
   `Shivers-Win64-Shipping.exe`.
2. Download `UE4SS_v3.0.1-1125-g527a483b.zip` from the URL in §2, verify its
   SHA-256, extract it.
3. Back up (list + hash) everything already in `Shivers\Binaries\Win64\`.
4. Copy `dwmapi.dll` and the `ue4ss\` folder from the extracted zip into
   `Shivers\Binaries\Win64\`. Add a Lua mod under `ue4ss\Mods\` with a
   `scripts\main.lua` and enable it in `ue4ss\Mods\mods.txt`.
5. Launch via `steam.exe -applaunch 1929610`; read `ue4ss\UE4SS.log` and, if
   `GenerateSDK()` was called, `ue4ss\CXXHeaderDump\*.hpp`.
6. To uninstall: close the game, delete `dwmapi.dll` and the `ue4ss\` folder;
   verify the remaining files' hashes against the step-3 baseline.

## 7. CS-002 implementation

`mod/ConcernedSprint/Scripts/` contains the mod, split so the decision logic
is testable without the game:

- `sprint_adapter.lua` — pure functions only. `get_sprint_component(pawn)`
  walks `pawn.BP_SprintComponent` (§4.2) and validates it via `:IsValid()`,
  returning `nil` on any nil/invalid/unexpected shape rather than throwing.
  `apply(component)` reads `Stamina`/`MaximumStamina` (§4.1) and writes
  `Stamina = MaximumStamina` only when `Stamina < MaximumStamina`. It never
  writes a value the game didn't already define as the ceiling — see §4.6 for
  why that makes disabling a no-restore-needed no-op. Every UE4SS call is
  wrapped in `pcall`.
- `config.lua` — plain-text `enabled=true|false` persistence via stock Lua
  `io.open`/`io.read`/`io.write` (confirmed available in UE4SS's Lua runtime:
  UE4SS's own bundled `BPModLoaderMod` and `ConsoleCommandsMod` use `io.open`
  the same way). Defaults to `enabled=true` when no config file exists yet.
- `lifecycle.lua` — pure state machine (no UE4SS globals; pawn resolution and
  status reporting are both injected as functions) that caches the resolved
  sprint component and rate-limits re-resolution (§10), only writes while
  enabled, and reports status transitions only when they actually change.
  Extracted into its own testable module specifically in response to an
  independent review of an earlier version of this PR that found two real
  bugs living inline in `main.lua`: (1) the `BeginPlay`-triggered path wrote
  a stamina value even while the mod was disabled, and (2) a cached
  component that stayed technically `:IsValid()` but no longer matched the
  actual current local pawn (e.g. a pawn swap that doesn't re-trigger
  `BeginPlay`, such as a pre-existing spectator pawn) could go stale
  indefinitely because nothing ever re-checked it. Both are fixed here — see
  the module's own comments and §8/§10 for how they're specifically tested
  and mitigated.
- `main.lua` — the only file that touches UE4SS globals. Wires
  `RegisterBeginPlayPostHook` (immediate reaction to pawn spawn/replacement,
  §4.4) and a bounded interval timer to `lifecycle.lua`'s `tick`/
  `on_local_pawn_begin_play`, plus a `Ctrl+F9` `RegisterKeyBind` toggle that
  persists through `config.lua` and a `ModRef.OnUnload` that cancels the
  timer.

## 8. Unit test evidence (non-game)

`tests/run_tests.lua` runs `sprint_adapter.lua`, `config.lua` and
`lifecycle.lua` against a minimal dependency-free harness
(`tests/testkit.lua`) using nothing but the stock `lua` interpreter (Lua
5.4.6, matching the version UE4SS itself embeds — confirmed via a `lua-5.4`
path in `UE4SS-RE/RE-UE4SS`'s own `deps/` directory) — no game, no UE4SS, no
network:

```
31 passed, 0 failed, 31 total
```

Covers every state/config/lifecycle case in CS-002's acceptance criteria: nil
pawn, invalid pawn, `IsValid()` itself throwing, missing/invalid component,
missing or wrong-typed `Stamina`/`MaximumStamina`, stamina already at or
above the maximum (must not write), the write itself throwing, config
load/save round-trips including a malformed file and an unwritable path
(and, after review, actually exercising case-insensitivity on `TRUE`/`True`,
not only `FALSE` — see below), and the `lifecycle.lua` cases directly
targeting the two bugs above: a disabled mod attempts zero writes and zero
pawn searches: an enabled mod resolving-then-caching a component still
applies it on ticks that don't re-resolve; and a local pawn that changes
without a new `BeginPlay` is still picked up within one resolve interval
rather than left stale forever.

Two real bugs were caught and fixed during this work, both found by tests
or by the process of writing them:
- Not in the adapter, but in a test: `{ MaximumStamina = nil }` in a Lua
  table constructor never sets the key at all (a no-op), so the intended
  "field is missing" case silently wasn't exercised until the test was
  rewritten to delete the field from an already-built table instead.
- The independent-review-driven `lifecycle.lua` bugs described in §7 above.
  A third review finding — the config case-insensitivity test only checked
  `enabled=FALSE`, which passes identically even if `:lower()` were deleted,
  since anything not exactly `"true"` already evaluates false — was also
  fixed by adding tests against `TRUE`/`True`, the only values where
  lowercasing actually matters.

This proves the mod's own decision logic is correct against every case
listed. It does **not** prove UE4SS's real Lua bindings behave identically
against the actual game — that is what §9 covers, and it is intentionally
kept separate per CS-002's "do not treat mocked tests as proof of
compatibility."

## 9. Runtime verification against the live process

Same reversible install/probe method as §3 (backup, hash-verified
install/uninstall; see §10 for one addition this round). The real
`ConcernedSprint` mod (not a probe) was deployed and launched via Steam.

**Property writes work end-to-end**, closing a gap §4.5 left open (CS-001
only exercised reads): a temporary, session-only probe mod
(`WritabilityProbe`, not part of the shipped mod) used the exact
`Engine.MaxParticleResize` example from `docs.ue4ss.com`'s own docs —
read (`0`) → write (`4`) → read back (`4`) → restore (`0`) — all against the
live process:

```
[WritabilityProbe] Engine.MaxParticleResize before write: 0
[WritabilityProbe] Engine.MaxParticleResize after write: 4
[WritabilityProbe] WRITE VERIFIED: property write took effect and read back correctly
[WritabilityProbe] Restored Engine.MaxParticleResize to 0
```

**The mod loaded and ran cleanly**, with no Lua errors, across every launch
this round. Its `require("UEHelpers")` / `require("sprint_adapter")` /
`require("config")` sibling-relative requires resolved correctly (matching
the pattern observed in UE4SS's own bundled `ConsoleCommandsMod`), and
`RegisterBeginPlayPostHook`, `LoopInGameThreadWithDelay`, `RegisterKeyBind`,
and `ModRef.OnUnload` all registered without error.

**Local-pawn resolution and bounded logging were both observed working
correctly, not just designed that way.** At the main menu, the locally
controlled pawn resolved to a plain engine `DefaultPawn` (menu background
camera, not the gameplay character) — the adapter correctly found it has no
`BP_SprintComponent` and logged that once:

```
[ConcernedSprint] Local pawn has no BP_SprintComponent (class: Class /Script/Engine.DefaultPawn); feature inactive for this pawn
```

That line did not repeat again despite the mod running for minutes afterward
at a 300ms tick interval (100s of ticks) — direct confirmation the
transition-only logging design (§7) actually suppresses per-tick spam in the
real process, not just in the unit tests.

**The adapter attached to a real, live `BP_SprintComponent`.** A few seconds
after the local player's `CheatManager` was constructed (i.e. once the
PlayerController environment was further along), resolution found a
different pawn that does have the component, and logged the transition with
no error following it — meaning `sprint_adapter.apply()` executed against a
real `BP_SprintComponent` instance without throwing:

```
[ConcernedSprint] Sprint adapter attached to local pawn
```

This is the strongest evidence gathered so far that the mod's actual
integration works, short of observing stamina hold steady through an active
sprint in a real match (still pending — see §11; the pawn here was a menu
context, not gameplay, so there is no meaningful "was it sprinting"
observation to make yet).

### 9.1 Keybind toggle: registration confirmed, keypress inconclusive

`RegisterKeyBind(Key.F9, {ModifierKey.CONTROL}, ...)` registered without
error (part of the clean mod-load evidence above). An actual `Ctrl+F9`
keypress was attempted via Windows `SendKeys` against the focused game
window; the process stayed alive and responsive afterward, but no
`[ConcernedSprint] Enabled/Disabled` log line appeared, so the toggle itself
was not confirmed to fire. `UE4SS.log` (CS-001, §3) shows `Input source set
to: Win32Async`, consistent with UE4SS polling raw keyboard state rather than
reading the Windows message queue that `SendKeys` posts to — a known general
limitation of synthetic input against this class of input handling, not
specific to this mod. A real keypress (owner/future visually-driven session)
remains the way to confirm this.

## 10. A UE4SS stability issue found, diagnosed, and mitigated

The first two runs this round — the real `ConcernedSprint` mod, initial
design (§7 without the §9-driven revision below) — both crashed:

| Run | Mods active | Result |
|---|---|---|
| 1 | ConcernedSprint + WritabilityProbe | Crashed ~40s after mod load |
| 2 | ConcernedSprint only | Crashed ~30s after mod load |
| 3 (control) | none (ConcernedSprint disabled in `mods.txt`) | Stable 180s+ |
| 4 | ConcernedSprint, revised (caches the resolved component; only re-resolves the local pawn every ~10 ticks while nothing valid is cached, instead of every tick) | Stable 180s+ |
| 5 | ConcernedSprint, after extracting the caching logic into `lifecycle.lua` and fixing the two bugs an independent review found (§7) | Stable 150s+, mod loaded and attached to a real `BP_SprintComponent` cleanly (§9), no new crash reports |

Both crashes were `EXCEPTION_ACCESS_VIOLATION reading address 0x0000000000000010`
(Windows crash dumps, `%LOCALAPPDATA%\Shivers\Saved\Crashes\`), byte-identical
in shape: the same ~22-frame call stack entirely inside `UE4SS.dll`, then a
few `Shivers-Win64-Shipping` frames, then `kernel32`/`ntdll`. The shipping
build has no debug symbols, so no function names are available — only module
names and offsets. Both times, `UE4SS.log` ends within about a second of the
same internal UE4SS lifecycle event:

```
[HashTables] Self test passed (5376 classes with instances)
[HashTables] Searcher pools and GUObjectArray listeners retired
```

— UE4SS switching its internal object lookups from iterating `GUObjectArray`
directly over to a faster hash-table cache (`UE4SS-settings.ini`'s own
comments describe this exact transition: *"The cache is dropped at runtime
once `FUObjectHashTables` passes its self test, since the tables replace
it"*). Trying the documented escape hatch for this
(`bForceGUObjectArrayForIteration = true`, whose own comment says *"Set to
true if hash table iteration is causing crashes"*) did **not** prevent the
crash — same signature, similar timing — so this is not simply that switch.

The differential that did matter: run 3 (control, no custom mod at all) sailed
through that exact transition and stayed stable; runs 1-2 (the original
polling design, which unconditionally called
`UEHelpers:GetPlayerController()` → `.Pawn` on every single 300ms timer tick,
menu or not) crashed at almost exactly that point both times; run 4 (same
mod, but the timer only touches an already-cached object reference and only
attempts a fresh `UEHelpers:GetPlayerController()`/pawn search once every
~10 ticks while idle, instead of every tick) did not crash. `main.lua` was
revised to that caching design specifically because of this evidence. Run 5
re-confirms this held after the logic moved into `lifecycle.lua` and the two
bugs in §7 were fixed — the fixes changed *when* resolution and writes
happen (gating writes on `enabled`, bounding staleness with a periodic
re-check) but not the core "don't search every tick" property this section
is about, and stability was re-observed, not just assumed to carry over.

**Read this evidence carefully rather than as a proof.** Five runs (2
crashed, 3 stable) is a real, reproducible-so-far pattern, not a coincidence
dismissed after one retry — but it is not exhaustive, and the shipping
build's stripped symbols mean the true root cause inside `UE4SS.dll` could
not be identified, only correlated. What can be said with confidence: this
is a UE4SS-internal crash (the entire relevant call stack is inside
`UE4SS.dll`, not the game or this mod's Lua code, which had already finished
running well before both crashes), it is consistent with this being an
experimental prerelease build against a UE version it only claims "basic
support" for (§2), and reducing how often Lua code calls into UE4SS's
object-search machinery during the game's first ~30 seconds measurably
improved observed stability. The unit-tested adapter/config/lifecycle logic
(§8) is unaffected either way — this is a loader-environment risk, not a
defect in this mod's own decision logic.

## 11. What remains pending after CS-002

- Stamina holding steady through an actual, active sprint in a real match —
  needs a spawned gameplay pawn while actively sprinting, which needs a
  human or a future visually-driven session to reach (§5, §9). Everything
  independently verifiable without that has been: the hook mechanism, the
  property read/write path, local-pawn resolution, bounded logging, and
  attachment to a real live component.
- The `Ctrl+F9` toggle firing from an actual keypress (§9.1) — registration
  is confirmed, the keypress-to-effect path is not.
- The UE4SS stability finding in §10 is a correlation from 5 runs, not a
  proven root cause; residual crash risk during the first ~30 seconds after
  launch cannot be ruled out to zero with an experimental-build loader.
- An independent review of this PR found two real logic bugs in an earlier
  version of the caching/lifecycle code (disabled-mod-still-writes; cache
  staleness with no upper bound) — both fixed and covered by new
  `lifecycle.lua` unit tests (§7, §8), and re-verified stable against the
  live process (§10, run 5). Noted here rather than silently folded in,
  since it's relevant review history for whoever reads this next.
- `ABP_PlayerCharacter_C`'s exact `/Game/...` path (§4.2), still not needed
  by the implementation (which resolves whatever pawn is actually possessed
  at runtime rather than hard-coding a class path) but still not captured.

## 12. CS-003 packaging and validation evidence

Scripts (`scripts/package.ps1`, `scripts/validate_package.ps1`,
`scripts/test_install_fixture.ps1`) and full usage are documented in
`docs/RELEASE.md`; this section is the evidence that a specific run of
them actually worked, not just that they exist.

**Package build.** `scripts/package.ps1` was run against version `0.1.0`
(from `VERSION`). It produced `artifacts/ConcernedSprint-v0.1.0.zip`
containing exactly `README.md`, `CHANGELOG.md`, and
`Scripts/{main,sprint_adapter,config,lifecycle}.lua` under a
`ConcernedSprint/` root — no loader binaries, no game content. That
specific build's SHA-256 was `95598b28de3893220d096f58a0dd57a196c24d51b2f2b2917bc90c32d7806bc1`
— recorded here as evidence this run happened, not as a value to rely on:
rebuilding from identical source happened to reproduce this exact hash
when tried a second time here, but the zip format's own metadata (e.g.
timestamps) is not something `scripts/package.ps1` pins deliberately, so
that stability isn't guaranteed across machines, .NET versions, or future
changes to the script. The authoritative hash for whatever you actually
have is always the `.sha256` file `scripts/package.ps1` writes alongside
that specific zip, which is what `scripts/validate_package.ps1` and
`docs/OWNER_SMOKE_TEST.md` check against — never a hash hardcoded in this
document.

**Validator actually validates, both directions.** `validate_package.ps1`
against the real build: 22/22 checks passed (17 in the version described
in the original PR; 5 more added responding to the independent review
below). To confirm the validator isn't just rubber-stamping, it was also
run against a deliberately broken test zip (wrong version, wrong recorded
hash, three required files missing, an extra `UE4SS.dll` planted inside
it) built only for this check and discarded afterward — every one of
those 7 problems was caught and reported by name, exit code 1. Both runs
are what "reproducible validation" means here: the same script, same
pass/fail logic, correctly distinguishing a good build from a bad one.

**Independent review found two real gaps in the validator itself, both
fixed.** An adversarial review (documented in full on PR #7) went further
than the deliberately-broken-zip test above and specifically tried to
fool the validator rather than just break the build:
1. It replaced `Scripts\main.lua`'s content with 16 bytes of fake PE
   binary data, keeping the filename, extension, and file count
   identical, and rebuilt the zip's SHA-256 to match. The validator (as
   originally written) reported "All checks passed" — every check up to
   that point only confirmed a file *named* `main.lua` existed, never
   that its content was actually Lua.
2. It removed `Scripts\lifecycle.lua` and added an unrelated
   `Scripts\extra_unexpected.lua`, keeping the total file count at 6. The
   "no unexpected files" check (as originally written) only compared
   counts, so it passed despite a real required file being missing and
   a real unexpected file being present (the separate per-file
   `required file present` check still caught the missing file
   independently, so overall validation still correctly failed exit 1 —
   but that check-level gap was real).

Both were fixed in `validate_package.ps1`: the "no unexpected files"
check now compares actual relative file paths against the required list
(so a same-count swap is caught by name, not just missed by count), and
each required `.lua` file is now additionally compiled with `luac -p`
(parse-only) — a real PE/binary payload cannot parse as Lua, so this
directly closes gap 1. Re-running both exact attack scenarios above
against the fixed script: attack 1 now fails on
`Scripts\main.lua is valid Lua source (luac -p)`; attack 2 now fails on
`no unexpected files beyond the required set` with the exact unexpected
path named, in addition to the pre-existing missing-file check. The
review also caught that this PR's own description contained the literal
substring "does not close #4" — GitHub's issue-auto-close matching is a
plain keyword scan that doesn't understand negation, so that phrasing
would have auto-closed issue #4 on merge despite saying the opposite;
the PR body was reworded to avoid the trigger phrase entirely and the
auto-close link was confirmed removed (`closingIssuesReferences: []`)
before merge.

**Disposable fixture install/uninstall.** `test_install_fixture.ps1`
builds a throwaway fake `ue4ss\Mods\` folder (pre-populated with an
unrelated mod and existing `mods.txt` entries) entirely under the OS temp
directory — never touches the real game. All 8 checks passed: install
added exactly the `ConcernedSprint` folder and one `mods.txt` line without
disturbing the pre-existing mod or its line; uninstall removed exactly
what install added; the fixture's file list after uninstall was compared
programmatically (not just eyeballed) against its pre-install state and
found identical.

**Real local install/uninstall, from the packaged zip (not the dev source
tree).** Same reversible method as CS-001/CS-002 (backup + hash every
pre-existing file, install additively, verify, uninstall, re-verify
hashes match) — except this time the mod files came from *extracting the
built zip*, the actual artifact a user would download, not copied
directly from `mod/ConcernedSprint/`. Results:
- Mod loaded cleanly (`[ConcernedSprint] Mod loaded, enabled=true`), no
  Lua errors.
- Same correct behavior observed as CS-002: resolved a menu `DefaultPawn`
  correctly (logged once), then attached to a real live
  `BP_SprintComponent` with no error, stable 150s+ (no new crash report).
- Both uninstall paths tested against the real install: mod-only
  uninstall (delete `ConcernedSprint` folder, remove its `mods.txt` line)
  left the pre-existing `BPModLoaderMod` entry and folder untouched; full
  uninstall (also removing `dwmapi.dll`/`ue4ss\`) restored the three
  pre-existing files' SHA-256 to the exact original baseline.

**What this does and doesn't show.** All of the above is startup,
packaging-integrity, and non-destructive-installation evidence — real,
but not gameplay. §11's pending items (stamina holding through an actual
sprint, the `Ctrl+F9` keypress path, map/lobby transitions during real
play) are unchanged by this section and remain the content of
`docs/OWNER_SMOKE_TEST.md`.

## 13. CS-DEF-001: owner smoke test crashed — investigation and fix

One v0.1.0 startup attempt crashed. The owner subsequently relaunched and
successfully sprinted on Cyclone Street. Issue #8 tracks the intermittent
failure; source corrections and owner success do not prove its cause.

### 13.1 What happened

`EXCEPTION_ACCESS_VIOLATION reading address 0xffffffffffffffff`, 44
seconds after launch, on the `GameThread`, with the engine's own hang
detector separately flagging that same thread as stuck
(`Misc.IsStuck=true`, matching `StuckThreadId`). Native call stack: ~30
frames entirely inside `UE4SS.dll` (no symbols available — shipping
build, no PDB published for this loader), then a handful of
`Shivers-Win64-Shipping` frames, then `kernel32`/`ntdll`. A run of offsets
repeats twice in slightly different order partway through the UE4SS
frames — consistent with, but not proof of, a recursive/re-entrant call
pattern. Full native offsets and the crash dump itself are preserved
locally only (`C:\code\ConcernedSprint\artifacts\crash-owner-20260906-131405`,
git-ignored) — not reproduced here per policy against putting minidumps
or personal identifiers in source control. The mods active at crash time,
per that preserved evidence: `CheatManagerEnablerMod`, `ConsoleCommandsMod`,
`ConsoleEnablerMod`, `BPML_GenericFunctions`, `BPModLoaderMod`, `Keybinds`,
and `ConcernedSprint` — i.e. every UE4SS bundled default plus this mod,
not an isolated configuration.

The source investigation did not reproduce this crash in a fresh run.
Temporary proxy disabling was historical containment; the verified proxy
was later restored and is enabled. Preserve the current working install.

### 13.2 Source comparison: delayed-action scheduling

The obvious first suspect was Concerned Sprint's own periodic timer
(`main.lua`'s `LoopInGameThreadWithDelay` call, wired to `lifecycle.lua`'s
rate-limited resolution — see §10). Upstream's own issue tracker
(`UE4SS-RE/RE-UE4SS`) documents multiple confirmed, maintainer-acknowledged
defects in exactly this subsystem: a same-thread vector-reallocation bug
when a delayed action self-reschedules while `std::erase_if` is still
draining the action list ([#1180](https://github.com/UE4SS-RE/RE-UE4SS/issues/1180),
closed 2026-08-23), and a related cross-thread Lua-registry race (analyzed
in the same thread; contained but not fully fixed by
[PR #1375](https://github.com/UE4SS-RE/RE-UE4SS/pull/1375), merged into
main before the pinned commit). One reported symptom in that thread is the
identical error string: *"Access violation reading location
0xFFFFFFFFFFFFFFFF."*

This looked like a strong match on error string alone — but reading the
actual `process_delayed_actions`/`LoopInGameThreadWithDelay` implementation
in `UE4SS/src/Mod/LuaMod.cpp` **at the exact pinned commit** (527a483b,
confirmed 72 commits ahead of PR #1375's merge commit, i.e. including it)
shows a more defensive design than the older code discussed in that
issue: ready actions are snapshotted under a mutex into a separate list,
executed outside the lock with a `m_is_currently_executing_game_action`
re-entrancy guard, and looping actions are re-armed by mutating the
existing vector entry in place — not by inserting a new entry — before
`std::erase_if` runs, also under the same lock. This does not match the
"self-reschedule inserts into the vector `erase_if` is still iterating"
shape the upstream issue describes. This static comparison did not find that particular older vulnerable
pattern in the pinned code. It does not rule out a scheduler/native fault
or establish the cause of the owner's crash.

### 13.3 Found: a real bug in how `main.lua` handled its `BeginPlay` hook parameter

`RegisterBeginPlayPostHook`'s own documentation page states that callback
parameters "must be retrieved via `Param:Get()`" — but its own worked
example never actually uses the parameter (`print("BeginPlayPostHook")`),
so nothing in the docs demonstrates this in practice. Reading UE4SS's own
bundled `CheatManagerEnablerMod` (installed alongside Concerned Sprint at
crash time) confirmed the real pattern: it hooks
`PlayerController:ClientRestart` and immediately does
`local PlayerController = self:get()` before touching the parameter at
all. Reading `LuaUObject.cpp` at the pinned commit confirms why this
matters: `RegisterBeginPlayPostHook`'s native dispatcher wraps the actor
pointer in a fresh `RemoteUnrealParam` on every single call
(`LuaType::RemoteUnrealParam::construct(lua, &Context, ...)`), and
`RemoteUnrealParam` defines no custom equality metamethod of its own
(`setup_metamethods` is an empty function) — so comparing the raw,
un-unwrapped parameter against anything relies on Lua's default userdata
identity comparison, which a fresh wrapper object can never satisfy. The
class's own documentation independently states that even calling
`:IsValid()` directly on it is "nonsensical" and deliberately unsupported.

v0.1.0's `main.lua` compared the raw hook parameter directly
(`Actor == pawn`), never calling `:get()`. Consequence: the intended
"is this actor the local pawn" check could never actually match — the
`RegisterBeginPlayPostHook` fast-path was silently dead code for the
entire v0.1.0 release. This alone doesn't crash anything (Lua's default
`==` across mismatched userdata just returns `false`), which is exactly
why CS-002's menu-idle testing (§9-10) never revealed it: the mod still
*appeared* to work correctly, because the separate rate-limited timer
path in `lifecycle.lua` was doing all the real work.

### 13.4 The consequence that matters: unconditional expensive work on every actor's `BeginPlay`

Because the pawn-identity check could never short-circuit anything, the
full body of the hook — including `resolve_local_pawn()`, which calls
`UEHelpers:GetPlayerController()` — ran to completion on **every single
actor's `BeginPlay`**, not just pawns. Reading `UEHelpers.lua` at the
pinned commit shows `GetPlayerController()` itself calls `FindAllOf`
(every matching instance, not `FindFirstOf`) over `PlayerController` (or,
if that finds nothing, `Controller`), with no caching of its own, then
loops the results checking `IsLocalPlayerController()`. With
`bUseUObjectArrayCache=false` (already the pinned setting — see §10; not
a new finding here), each of those calls is an uncached, un-short-circuited
scan.

CS-002's own stability testing (§10) only ever ran this at a main menu,
where very few actors spawn. Real gameplay spawns actors continuously —
props, pickups, AI, effects — and, per this bug, *every one of them*
triggered a full uncached player-controller scan, for the entire 44-second
session, alongside every other bundled mod's own hooks sharing the same
dispatch machinery (§13.1's mod list). This is a large, real, previously
invisible difference between what CS-002 tested and what actually
happened during the owner's session — precisely the gap issue #8 warns
against papering over with "premature mitigation claims from earlier
150-second menu runs."

This is presented as a strong contributing factor, evidenced directly
from source and from the mismatch between what CS-002 tested and what
production load actually looked like — not as a proven, symbolicated root
cause. No debugger or matching symbols were available to identify the
exact faulting instruction (see §13.7), so the precise mechanism by which
this sustained load produced this specific access violation remains
unconfirmed. What is confirmed is that this bug caused unconditional,
uncached, high-frequency load on exactly the class of UE4SS machinery
(object search, hook dispatch) that upstream's own tracker documents
repeated concurrency/stability issues in.

### 13.5 A second, deeper instance of the same bug class, caught by independent review

The first fix committed to this PR added `ActorParam:get()` (§13.3) but
still compared the result directly (`actor == pawn`). An independent
review of the PR traced both sides of that comparison through UE4SS's own
source at the pinned commit — `:get()` on an object parameter and an
ordinary property read like `playerController.Pawn` both end up
constructing a wrapper through the same underlying path
(`push_objectproperty` → `auto_construct_object` → `AActor::construct`)
— and found that `AActor`'s own wrapper type is *also* one of the classes
with no custom equality (`AActor::setup_metamethods` is empty, with the
source's own comment stating so directly; its base
`UObjectBase::setup_metamethods` registers `Index`/`NewIndex`/`Call` but
never `Eq`), and that wrapper construction allocates fresh userdata on
every call with no interning. In other words: fixing the outer
`RemoteUnrealParam` unwrap (§13.3) was necessary but not sufficient — the
*same* "fresh wrapper per access, no custom equality" problem recurs one
level down, on the plain actor/pawn comparison itself, and `actor == pawn`
was still very likely always `false` in real UE4SS even after the first
fix, for the same underlying reason.

The corrected comparison uses `GetAddress()` — a UE4SS-documented method
returning the underlying native pointer as a plain Lua number, which
compares by value regardless of how many independent wrapper objects
reference it — instead of `==`. This is implemented as `same_object()` in
`lifecycle.lua` and used by `on_actor_begin_play`. The regression test for
this specifically constructs *two separate Lua tables* sharing only the
same fake address (`tests/test_lifecycle.lua`,
`"...via two distinct wrapper objects sharing one address"`), rather than
passing one table as both the hook actor and the resolved pawn — the
review noted that reusing the same table was itself a test-realism bug
that let the broken `==` version pass despite not working in real UE4SS.
That mistake is recorded here deliberately: a mock that's more convenient
than the real API it stands in for can hide exactly the bug it should
catch.

A second, focused review specifically re-checked the `GetAddress()` fix
itself, rather than assuming it was correct just because it addressed the
first review's finding. It confirmed, from `GetAddress()`'s actual
implementation at the pinned commit
(`lua.set_integer(reinterpret_cast<uintptr_t>(...))` — a plain integer
read fresh from the wrapper's stored pointer, in
`UE4SS/include/LuaType/LuaUObject.hpp`), that this is both correct and
the only sanctioned identity mechanism UE4SS's Lua API exposes (no
`__eq`, no `IsSameObject` anywhere in the docs). It also found one real,
minor hardening gap: `GetAddress()` itself performs no validity check
(unlike `UObject:IsValid()`, which checks null/pending-kill/liveness),
and `main.lua`'s `resolve_local_pawn()` returned `playerController.Pawn`
without calling `:IsValid()` on it — not exploitable at this call site
(the pawn is used synchronously, no GC window), but inconsistent with
`sprint_adapter.lua`'s own `get_sprint_component`, which already
validates its pawn argument. Fixed by adding the same check to
`resolve_local_pawn()`.

### 13.6 The fix

Two changes, both in `mod/ConcernedSprint/Scripts/`:

- `main.lua` now calls `ActorParam:get()` before doing anything else with
  the `BeginPlay` hook's actor parameter, matching the documented
  requirement and UE4SS's own bundled-mod usage.
- The BeginPlay handling logic moved into a new, unit-tested function,
  `lifecycle.lua`'s `on_actor_begin_play`, which requires
  `actor:IsA("Pawn")` to pass *before* the expensive `resolve_local_pawn()`
  search is ever invoked. Most `BeginPlay` events are for non-pawn actors
  and are now filtered out without touching that search at all.
  **Correction (§13.9):** an earlier version of this document described
  `IsA(string)` as "cheap, local-only" — that's not accurate; it resolves
  the class name via `StaticFindObject` internally on every call, per
  UE4SS's own source. It's still one single, targeted lookup rather than
  a full `PlayerController` enumeration, which is the real reason the
  ordering matters, not zero cost.

`tests/test_lifecycle.lua` adds regression coverage asserting on the
*resolver's call count*, not just final state — specifically so a
regression back to "resolve on every actor" would fail a test even if it
didn't happen to produce a visibly wrong result — plus, per §13.5, the
identity comparison is regression-tested with two distinct wrapper
objects sharing one address, not one table reused as both sides. 38
tests pass in total (`lua tests/run_tests.lua`).

Also changed, per issue #8's explicit instruction to isolate a minimal
configuration: `docs/INSTALL.md` now recommends disabling UE4SS's bundled
extras (`CheatManagerEnablerMod`, `ConsoleCommandsMod`, `ConsoleEnablerMod`,
`BPML_GenericFunctions`, `BPModLoaderMod`, `Keybinds`) for a Concerned
Sprint-only install. Confirmed against `LuaMod.cpp` at the pinned commit
that `RegisterKeyBind` is a core UE4SS binding registered directly in
engine code, not something the bundled `Keybinds` mod provides — so this
mod's own `Ctrl+F9` toggle does not depend on any of them.
`scripts/isolation_fixtures.ps1` generates the four `mods.txt` tiers
(vanilla / bare loader / loader + only ConcernedSprint / current full
config matching the crash) as inert reference files under
`artifacts/cs-def-001-isolation/`, ready for a coordinated retest without
hand-editing `mods.txt` live.

### 13.7 What remains unproven

The exact native fault was not symbolicated; matching symbols and a
debugger were not available during investigation. Source review found
logic/lifetime defects but did not prove the crash's root cause.
The owner-verified build is 0.1.0. Candidate 0.1.2 has not been installed
or gameplay-retested. Issues #8 and #4 remain open for those checks.
The loader is enabled on the current installation.

### 13.8 Candidate test and optional diagnosis

After coordinating a test, close the game and back up the current mod
and configuration before replacing files. The loader is already enabled;
verify its actual state instead of following historical rename steps.
Use the short [owner checklist](OWNER_SMOKE_TEST.md) for 0.1.2.
If a crash recurs, retain evidence locally and use the inert isolation
fixtures only as diagnostic references, preserving third-party settings.
A successful run is evidence of that run, not proof an intermittent
failure is eliminated. Record actual results without account identifiers.

### 13.9 Follow-up fixes committed after the earlier merge

PR #9 merged at 18:56:57Z on 2026-09-06. The identity fix (83fad97)
was committed at 19:05:32Z and the pawn-validity fix (f773205) at
19:15:48Z, after that merge. They therefore required another PR.
PR #10 recovers those commits and adds the cached-component guard.
The recovered state was compared with f773205 before further changes.
Compare the final merged tree with the reviewed commit when integrating.
### 13.10 Further hardening found during the recovery audit: cached component liveness in `apply()`

Independent review during the recovery work above (§13.9) found a third
real gap, in code untouched by either of the two `BeginPlay`-hook fixes:
`sprint_adapter.lua`'s `apply()` reads `MaximumStamina`, reads `Stamina`,
and writes `Stamina` on whatever component reference it's given, with no
liveness check of its own. `get_sprint_component()` validates the
component once, when `lifecycle.lua` first caches it — but that cached
reference is then reused for up to a resolve interval (~3 seconds, §10)
before the next re-resolve, and a pawn/level transition inside that
window can invalidate the underlying object without the cached Lua
reference itself changing.

Verified directly against UE4SS's source at the pinned commit (files
fetched locally for this specific check, not committed to this repo):
- `IsValid()` (`LuaUObject.hpp`, the `UObjectBase` template's member
  functions) performs a real liveness check: the stored pointer is
  non-null, is not the library's own "invalid" sentinel, is still present
  in the global tracked-object map, and is not marked unreachable.
- Plain property get/set (`LuaUObject.hpp`'s `prepare_to_handle`, which
  backs ordinary `component.Stamina`-style access) only checks that the
  stored pointer is non-null before proceeding to dereference it
  (`object->GetClassPrivate()` and onward) — it does not repeat any of
  `IsValid()`'s other checks.
- `get_remote_cpp_object()` (`LuaObject.hpp`) returns the wrapper's
  stored pointer completely unchanged — nothing refreshes or re-validates
  it on access.
- `NotifyUObjectDeleted` (`LuaUObject.cpp`) removes a destroyed object
  from the global tracked-object map (the thing `IsValid()` consults) but
  never touches any existing Lua wrapper's own stored pointer.

Net effect: a Lua-side reference to a since-destroyed component can
remain non-nil and pass straight through a plain property read or write
into what is, at the native level, a stale pointer — exactly the class of
problem this whole investigation has been chasing, just in a third
location neither `BeginPlay`-hook fix touched. A `pcall` around the
property access does not substitute for this: it protects against a
thrown Lua error, not against native code successfully dereferencing
memory it should not.

**Fix:** `apply()` now calls `component:IsValid()` (wrapped in its own
`pcall`, failing closed if it throws) immediately before each of the
three property operations, not once at the top — the "smallest guard"
that directly closes the gap without touching `get_sprint_component()`'s
existing bind-time validation or `lifecycle.lua`'s resolve-interval
timing. New tests in `tests/test_sprint_adapter.lua` use a traced
component (property reads/writes counted via `__index`/`__newindex`) to
prove `apply()` never even attempts a read or write once invalid or once
`IsValid()` itself throws — not merely that it returns `false` — plus a
matching traced test confirming the expected reads and exactly one write
still happen when the component is valid throughout. 41 tests pass in
total.

This closes a real, evidenced gap in the cached-reference lifetime. It
does **not** prove or disprove the root cause of the specific crash that
opened this issue (§13.1) — that remains exactly as unproven as §13.7
already states, and the retest plan in §13.8 is unchanged by this
addition.
