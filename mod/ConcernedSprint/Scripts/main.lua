-- Concerned Sprint: infinite sprint duration for the locally controlled
-- player, original speed and controls unchanged, with an enable/disable
-- toggle (Ctrl+F9, persisted). See docs/RUNTIME_DISCOVERY.md for the
-- reflection evidence this is built on, including section 10 for why
-- pawn/component resolution is cached and rate-limited below rather than
-- re-resolved on every tick.
local UEHelpers = require("UEHelpers")
local Adapter = require("sprint_adapter")
local Config = require("config")

local TAG = "[ConcernedSprint]"
local CONFIG_PATH = "Mods/ConcernedSprint/enabled.txt"
local TICK_INTERVAL_MS = 300
-- While no valid local pawn/component is cached (menus, loading, between
-- lives), re-resolution attempts are throttled to this many ticks apart
-- instead of attempted every tick -- see docs/RUNTIME_DISCOVERY.md section 10.
local RESOLVE_COOLDOWN_TICKS = 10

local state = Config.load(CONFIG_PATH)
local lastStatus = nil
local cachedComponent = nil
local ticksSinceLastResolve = RESOLVE_COOLDOWN_TICKS -- resolve immediately on the first tick

-- Bounded, transition-only logging: prints once per state change instead
-- of once per tick, per the "useful, bounded logging" requirement.
local function log_status(status, detail)
    if status == lastStatus then
        return
    end
    lastStatus = status
    if status == "no_pawn" then
        print(string.format("%s No local pawn (menu or between lives); idle\n", TAG))
    elseif status == "no_component" then
        print(string.format("%s Local pawn has no BP_SprintComponent (class: %s); feature inactive for this pawn\n", TAG, tostring(detail)))
    elseif status == "attached" then
        print(string.format("%s Sprint adapter attached to local pawn\n", TAG))
    end
end

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

local function is_cached_component_valid()
    if not cachedComponent then
        return false
    end
    local ok, valid = pcall(function() return cachedComponent:IsValid() end)
    return ok and valid == true
end

-- Re-resolves the local pawn's sprint component and updates the cache.
-- `pawn`, if already known (e.g. from the BeginPlay hook below), is used
-- directly to avoid a redundant resolve_local_pawn() call.
local function refresh_cache(pawn)
    pawn = pawn or resolve_local_pawn()
    if not pawn then
        cachedComponent = nil
        log_status("no_pawn")
        return
    end

    local component = Adapter.get_sprint_component(pawn)
    if not component then
        cachedComponent = nil
        local classOk, className = pcall(function() return pawn:GetClass():GetFullName() end)
        log_status("no_component", classOk and className or "?")
        return
    end

    cachedComponent = component
    log_status("attached")
end

local function tick()
    if not state.enabled then
        return
    end

    if is_cached_component_valid() then
        Adapter.apply(cachedComponent)
        return
    end

    -- No valid cached component: rate-limit re-resolution attempts rather
    -- than searching for a pawn on every tick while idle at a menu or
    -- between lives (docs/RUNTIME_DISCOVERY.md section 10).
    ticksSinceLastResolve = ticksSinceLastResolve + 1
    if ticksSinceLastResolve < RESOLVE_COOLDOWN_TICKS then
        return
    end
    ticksSinceLastResolve = 0

    refresh_cache()
    if cachedComponent then
        Adapter.apply(cachedComponent)
    end
end

-- Immediate reaction to pawn spawn/replacement (map change, death/respawn,
-- spectator swap): a native, engine-wide hook on AActor::BeginPlay, fires
-- once per actor spawn -- not a scan, not per-frame. Filtered down to only
-- the local pawn before doing anything, and forces an immediate cache
-- refresh rather than waiting for the next throttled tick.
RegisterBeginPlayPostHook(function(Actor)
    local pawn = resolve_local_pawn()
    if pawn and Actor == pawn then
        ticksSinceLastResolve = RESOLVE_COOLDOWN_TICKS
        refresh_cache(pawn)
        if cachedComponent then
            Adapter.apply(cachedComponent)
        end
    end
end)

-- Sustained top-up while sprinting, at a fixed interval rather than every
-- frame. When a component is already cached this only touches that one
-- already-resolved reference (a plain property read/write); it does not
-- repeat the pawn/controller search every tick.
local loopHandle = LoopInGameThreadWithDelay(TICK_INTERVAL_MS, tick)

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
