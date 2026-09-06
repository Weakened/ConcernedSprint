-- Pure state-machine logic for tracking the locally controlled pawn's
-- sprint component across ticks and BeginPlay events. No UE4SS globals:
-- pawn resolution and status reporting are both injected as functions, so
-- this is testable standalone with fakes (tests/test_lifecycle.lua).
--
-- Why this exists as its own module rather than living inline in
-- main.lua: the caching and rate-limited re-resolution here is a direct,
-- evidenced fix for a real UE4SS crash found during CS-002's runtime
-- testing (see docs/RUNTIME_DISCOVERY.md section 10) and for two logic
-- bugs an independent review found in an earlier version of this file
-- being inline in main.lua -- (1) a disabled mod could still write a
-- stamina value from the BeginPlay path, and (2) a cached component could
-- go silently stale forever if the local pawn ever changed without a new
-- BeginPlay firing for it. Both are fixed here and covered by tests.
local Adapter = require("sprint_adapter")

local M = {}

-- resolveIntervalTicks: how many tick() calls apart actual pawn
-- (re)resolution is attempted -- both when nothing is cached (idle at a
-- menu) and, to bound staleness, even when something already is. See
-- docs/RUNTIME_DISCOVERY.md section 10 for why this isn't every tick.
-- onStatusChange(status, detail): called only when status actually
-- changes ("no_pawn" | "no_component" | "attached"), not every tick.
function M.new(resolveIntervalTicks, onStatusChange)
    return {
        cachedComponent = nil,
        lastStatus = nil,
        ticksSinceLastResolve = resolveIntervalTicks, -- resolve on the first tick, not after waiting a full interval
        resolveIntervalTicks = resolveIntervalTicks,
        onStatusChange = onStatusChange or function() end,
    }
end

local function report(state, status, detail)
    if status == state.lastStatus then
        return
    end
    state.lastStatus = status
    state.onStatusChange(status, detail)
end

local function refresh(state, pawn)
    local component = Adapter.get_sprint_component(pawn)
    state.cachedComponent = component
    if not pawn then
        report(state, "no_pawn")
    elseif not component then
        report(state, "no_component", pawn)
    else
        report(state, "attached")
    end
end

-- Call once per timer tick. `resolvePawn` (a zero-arg function returning
-- the current local pawn or nil) is only invoked when a (re)resolve is
-- actually due, not on every call -- that's the whole point of caching.
-- Returns true if a top-up write was attempted this tick.
function M.tick(state, resolvePawn, enabled)
    if not enabled then
        return false
    end

    state.ticksSinceLastResolve = state.ticksSinceLastResolve + 1
    if state.ticksSinceLastResolve >= state.resolveIntervalTicks then
        state.ticksSinceLastResolve = 0
        refresh(state, resolvePawn())
    end

    if state.cachedComponent then
        return Adapter.apply(state.cachedComponent)
    end
    return false
end

-- Call from the BeginPlay hook once `pawn` is confirmed to be the current
-- local pawn. Always refreshes the cache (cheap bookkeeping, keeps status
-- logging accurate even while disabled) but only ever attempts a write
-- while `enabled` -- this is the fix for the disabled-mod-still-writes
-- bug noted above. Returns true if a top-up write was attempted.
function M.on_local_pawn_begin_play(state, pawn, enabled)
    state.ticksSinceLastResolve = 0
    refresh(state, pawn)
    if enabled and state.cachedComponent then
        return Adapter.apply(state.cachedComponent)
    end
    return false
end

-- Call from a BeginPlay hook for *any* actor (BeginPlay fires for every
-- actor in the game, not just pawns). `actor` must already be unwrapped
-- from any hook-parameter wrapper by the caller (see main.lua and
-- docs/RUNTIME_DISCOVERY.md CS-DEF-001 findings on RemoteUnrealParam).
--
-- `isPawnLike(actor)` is a cheap, local-only check (e.g. `actor:IsA("Pawn")`)
-- that must return true before `resolvePawn()` -- a full local-player
-- search -- is ever invoked. This ordering is deliberate and
-- security/stability relevant, not a style choice: BeginPlay fires for
-- every actor (props, effects, AI, pickups -- typically far more of these
-- than pawns), and `resolvePawn` is expensive and, per CS-DEF-001's
-- investigation, was previously being invoked unconditionally for every
-- single one of them because a missing parameter unwrap made the
-- intended pawn check silently never match. Returns true if a top-up
-- write was attempted.
function M.on_actor_begin_play(state, actor, isPawnLike, resolvePawn, enabled)
    if not actor then
        return false
    end

    local pawnLikeOk, pawnLike = pcall(isPawnLike, actor)
    if not pawnLikeOk or not pawnLike then
        return false
    end

    local pawn = resolvePawn()
    if not pawn or actor ~= pawn then
        return false
    end

    return M.on_local_pawn_begin_play(state, pawn, enabled)
end

return M
