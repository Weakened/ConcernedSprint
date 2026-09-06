# Runtime discovery (CS-001)

Evidence for the installed Demonologist build, the selected UE4SS loader, and the
real sprint/stamina hook. All findings below come from direct inspection of the
locally licensed install and a reversible, isolated UE4SS probe run against it
(session `claude-bg-f2f50a48`, 2026-09-06). No class, property or function name
in this document is guessed; each one was read from either the game's own file
version resource or from UE4SS reflection/SDK data generated against the live
process.

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
assumed:

- **Not yet observed:** the local player's `BP_SprintComponent.Stamina` value
  actually depleting during a live sprint, or `OnTired` firing at zero. This
  needs a spawned pawn in an active game/lobby. Reaching that state requires
  navigating Demonologist's menu/lobby flow, which this session did not
  attempt — an autonomous agent blindly driving 3D game menus with no visual
  feedback risks unintended actions (e.g. an online session) and cannot verify
  it landed correctly; single-player is confirmed available (Steam community
  discussion) for whenever a human or a future visually-driven session runs
  this. CS-002/CS-003 should record this explicitly as pending until an actual
  play session confirms it.
- **Not yet captured:** `ABP_PlayerCharacter_C`'s exact `/Game/...` asset path
  (its class layout is confirmed; see §4.2).
- Disabling behavior: the intended design is described in §4.6 (stop the
  top-up, the component's own unmodified loop resumes normal depletion
  immediately, nothing persisted). It is not yet implemented or observed —
  the hook has not been written yet, only the interception target and design
  identified.

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
