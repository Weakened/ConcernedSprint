-- Concerned Sprint: infinite sprint duration for the locally controlled
-- player, original speed and controls unchanged, with an enable/disable
-- toggle (Ctrl+F9, persisted). See docs/RUNTIME_DISCOVERY.md for the
-- reflection evidence this is built on. All caching/rate-limiting/
-- disable-gating logic lives in lifecycle.lua (unit-tested); this file is
-- only the UE4SS wiring around it.
local UEHelpers = require("UEHelpers")
local Config = require("config")
local Lifecycle = require("lifecycle")

local TAG = "[ConcernedSprint]"
local CONFIG_PATH = "Mods/ConcernedSprint/enabled.txt"
local TICK_INTERVAL_MS = 300
local RESOLVE_INTERVAL_TICKS = 10 -- ~3s at 300ms; see lifecycle.lua / docs/RUNTIME_DISCOVERY.md section 10

local state = Config.load(CONFIG_PATH)

local function log_status(status, detail)
    if status == "no_pawn" then
        print(string.format("%s No local pawn (menu or between lives); idle\n", TAG))
    elseif status == "no_component" then
        local classOk, className = pcall(function() return detail:GetClass():GetFullName() end)
        print(string.format("%s Local pawn has no BP_SprintComponent (class: %s); feature inactive for this pawn\n", TAG, classOk and className or "?"))
    elseif status == "attached" then
        print(string.format("%s Sprint adapter attached to local pawn\n", TAG))
    end
end

local lifecycleState = Lifecycle.new(RESOLVE_INTERVAL_TICKS, log_status)

-- UEHelpers:GetPlayerController() returns the LOCAL PlayerController in a
-- client context (docs.ue4ss.com's own worked example uses exactly this
-- pattern for "the player"); .Pawn on it is whichever pawn that controller
-- currently possesses.
local function resolve_local_pawn()
    local pcOk, playerController = pcall(function() return UEHelpers:GetPlayerController() end)
    if not pcOk or not playerController then
        return nil
    end

    local pcValidOk, pcValid = pcall(function() return playerController:IsValid() end)
    if not pcValidOk or not pcValid then
        return nil
    end

    local pawnOk, pawn = pcall(function() return playerController.Pawn end)
    if not pawnOk then
        return nil
    end

    return pawn
end

-- Immediate reaction to pawn spawn/replacement (map change, death/respawn,
-- spectator swap): a native, engine-wide hook on AActor::BeginPlay, fires
-- once per actor spawn -- not a scan, not per-frame.
--
-- The callback parameter is a RemoteUnrealParam wrapper, not a usable
-- actor reference directly -- docs.ue4ss.com's own text for this hook
-- says non-primitive parameters "must be retrieved via Param:Get()",
-- and UE4SS's own bundled CheatManagerEnablerMod does exactly this
-- (`local PlayerController = self:get()`) before using a hook parameter.
-- An earlier version of this file compared the raw wrapper directly
-- (`Actor == pawn`), which per RemoteUnrealParam's own documented
-- semantics (a fresh wrapper object every call, no custom equality) does
-- not compare as intended -- see docs/RUNTIME_DISCOVERY.md's CS-DEF-001
-- section for the full evidence. Unwrapping first is what makes the
-- pawn-identity check below actually work.
RegisterBeginPlayPostHook(function(ActorParam)
    local actorOk, actor = pcall(function() return ActorParam:get() end)
    if not actorOk or not actor then
        return
    end
    Lifecycle.on_actor_begin_play(
        lifecycleState,
        actor,
        function(a) return a:IsA("Pawn") end,
        resolve_local_pawn,
        state.enabled
    )
end)

-- Sustained top-up while sprinting, at a fixed interval rather than every
-- frame. Pawn/component resolution itself is further rate-limited inside
-- lifecycle.lua; most ticks only touch an already-cached property.
local loopHandle = LoopInGameThreadWithDelay(TICK_INTERVAL_MS, function()
    Lifecycle.tick(lifecycleState, resolve_local_pawn, state.enabled)
end)

-- Toggle + persist. Takes effect on the very next tick (<= TICK_INTERVAL_MS)
-- or immediately via the BeginPlay hook above; no reload/restart needed in
-- either direction. Disabling requires no restore step because nothing
-- mod-invented is ever written -- see sprint_adapter.lua and
-- docs/RUNTIME_DISCOVERY.md section 4.6.
RegisterKeyBind(Key.F9, { ModifierKey.CONTROL }, function()
    state.enabled = not state.enabled
    local saved = Config.save(CONFIG_PATH, state)
    print(string.format(
        "%s %s (Ctrl+F9)%s\n",
        TAG,
        state.enabled and "Enabled" or "Disabled",
        saved and "" or " [config save failed, change is session-only]"
    ))
end)

ModRef.OnUnload = function()
    if loopHandle then
        pcall(function() CancelDelayedAction(loopHandle) end)
    end
    print(string.format("%s Unloaded\n", TAG))
end

print(string.format("%s Mod loaded, enabled=%s (toggle with Ctrl+F9)\n", TAG, tostring(state.enabled)))
