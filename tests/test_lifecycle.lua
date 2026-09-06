local t = require("testkit")
t.set_file("test_lifecycle")

local Lifecycle = require("lifecycle")

-- Fake pawn/component objects, same shape as tests/test_sprint_adapter.lua
-- uses. A `spy` table records what happened so tests can assert on
-- behavior (was a search performed? was a write attempted?) rather than
-- just final state.

local function make_component(stamina, maxStamina)
    return {
        Stamina = stamina,
        MaximumStamina = maxStamina,
        IsValid = function() return true end,
    }
end

-- `address` defaults to a fixed value so existing tests that don't care
-- about identity keep working; tests that specifically exercise identity
-- comparison (see "on_actor_begin_play" below) pass distinct addresses,
-- or build a second, independent wrapper table sharing the same address
-- to realistically simulate UE4SS constructing a fresh wrapper userdata
-- per access to the same underlying native object.
local function make_pawn(component, address)
    return {
        BP_SprintComponent = component,
        IsValid = function() return true end,
        GetClass = function() return { GetFullName = function() return "Class /Script/Engine.FakePawn" end } end,
        GetAddress = function() return address or 0x1000 end,
    }
end

-- A resolver spy: counts how many times it was actually called (i.e. how
-- many times lifecycle.lua performed a "search"), and returns whatever
-- `pawnQueue` says for each call (or the last entry once exhausted).
local function make_resolver(pawnQueue)
    local spy = { callCount = 0 }
    spy.resolve = function()
        spy.callCount = spy.callCount + 1
        local index = math.min(spy.callCount, #pawnQueue)
        return pawnQueue[index]
    end
    return spy
end

-- tick(): resolution frequency -------------------------------------------

t.test("tick does not resolve on every call -- only once per interval", function()
    local component = make_component(40, 100)
    local pawn = make_pawn(component)
    local resolver = make_resolver({ pawn })
    local state = Lifecycle.new(5, function() end)

    for _ = 1, 12 do
        Lifecycle.tick(state, resolver.resolve, true)
    end

    -- ticksSinceLastResolve starts pre-filled, so tick 1 resolves
    -- immediately; then every 5th tick after that (ticks 1, 6, 11): 3
    -- resolves across 12 ticks, not 12.
    t.assert_eq(resolver.callCount, 3)
end)

t.test("tick applies the cached component on ticks that don't re-resolve", function()
    local component = make_component(40, 100)
    local pawn = make_pawn(component)
    local resolver = make_resolver({ pawn })
    local state = Lifecycle.new(10, function() end)

    Lifecycle.tick(state, resolver.resolve, true) -- resolves + applies -> Stamina now 100
    t.assert_eq(component.Stamina, 100.0)

    component.Stamina = 55.0 -- simulate the game draining it again
    local applied = Lifecycle.tick(state, resolver.resolve, true) -- should NOT re-resolve (interval not elapsed), but still applies from cache
    t.assert_true(applied)
    t.assert_eq(component.Stamina, 100.0)
    t.assert_eq(resolver.callCount, 1, "should not have re-resolved yet")
end)

t.test("tick does nothing at all while disabled (bug fix: no work, no resolve)", function()
    local pawn = make_pawn(make_component(40, 100))
    local resolver = make_resolver({ pawn })
    local state = Lifecycle.new(1, function() end)

    local applied = Lifecycle.tick(state, resolver.resolve, false)
    t.assert_false(applied)
    t.assert_eq(resolver.callCount, 0)
end)

-- Bug fix: staleness is bounded even when the cache still looks "valid" --

t.test("tick eventually notices the local pawn changed, even without a new BeginPlay", function()
    local componentA = make_component(40, 100)
    local componentB = make_component(10, 100)
    local pawnA = make_pawn(componentA)
    local pawnB = make_pawn(componentB)
    -- Simulates PlayerController.Pawn silently pointing at a different,
    -- already-existing actor without a fresh BeginPlay for it.
    local resolver = make_resolver({ pawnA, pawnA, pawnB, pawnB })
    local state = Lifecycle.new(2, function() end)

    Lifecycle.tick(state, resolver.resolve, true) -- resolves pawnA (call 1)
    t.assert_eq(state.cachedComponent, componentA)

    Lifecycle.tick(state, resolver.resolve, true) -- cached, no resolve
    t.assert_eq(resolver.callCount, 1)

    Lifecycle.tick(state, resolver.resolve, true) -- interval elapsed -> re-resolve (call 2), still pawnA
    t.assert_eq(resolver.callCount, 2)

    Lifecycle.tick(state, resolver.resolve, true) -- cached again
    Lifecycle.tick(state, resolver.resolve, true) -- interval elapsed -> re-resolve (call 3): now pawnB
    t.assert_eq(resolver.callCount, 3)
    t.assert_eq(state.cachedComponent, componentB, "must have picked up the pawn change within one interval")
end)

-- on_local_pawn_begin_play(): the disabled-mod-still-writes bug ----------

t.test("on_local_pawn_begin_play does not write while disabled", function()
    local component = make_component(40, 100)
    local pawn = make_pawn(component)
    local state = Lifecycle.new(10, function() end)

    local applied = Lifecycle.on_local_pawn_begin_play(state, pawn, false)
    t.assert_false(applied)
    t.assert_eq(component.Stamina, 40.0, "must not write a value while the mod is disabled")
end)

t.test("on_local_pawn_begin_play still refreshes the cache while disabled", function()
    -- Bookkeeping should stay current even while disabled, so re-enabling
    -- later doesn't need to wait out a fresh resolve interval.
    local component = make_component(40, 100)
    local pawn = make_pawn(component)
    local state = Lifecycle.new(10, function() end)

    Lifecycle.on_local_pawn_begin_play(state, pawn, false)
    t.assert_eq(state.cachedComponent, component)
end)

t.test("on_local_pawn_begin_play writes when enabled", function()
    local component = make_component(40, 100)
    local pawn = make_pawn(component)
    local state = Lifecycle.new(10, function() end)

    local applied = Lifecycle.on_local_pawn_begin_play(state, pawn, true)
    t.assert_true(applied)
    t.assert_eq(component.Stamina, 100.0)
end)

-- Bounded, transition-only status reporting -------------------------------

t.test("onStatusChange fires once per transition, not once per tick", function()
    local calls = {}
    local pawn = make_pawn(make_component(40, 100))
    local resolver = make_resolver({ pawn })
    local state = Lifecycle.new(1, function(status) calls[#calls + 1] = status end)

    for _ = 1, 5 do
        Lifecycle.tick(state, resolver.resolve, true)
    end

    t.assert_eq(#calls, 1, "status is unchanged (always 'attached') across these ticks, so it must only report once")
    t.assert_eq(calls[1], "attached")
end)

t.test("onStatusChange reports no_pawn then attached as the pawn appears", function()
    local calls = {}
    local resolver = make_resolver({ nil, nil, make_pawn(make_component(40, 100)) })
    local state = Lifecycle.new(1, function(status) calls[#calls + 1] = status end)

    Lifecycle.tick(state, resolver.resolve, true)
    Lifecycle.tick(state, resolver.resolve, true) -- still no pawn: must not report "no_pawn" again
    Lifecycle.tick(state, resolver.resolve, true) -- now attached

    t.assert_eq(#calls, 2)
    t.assert_eq(calls[1], "no_pawn")
    t.assert_eq(calls[2], "attached")
end)

t.test("onStatusChange reports no_component for a pawn without a sprint component", function()
    local calls = {}
    local pawn = { IsValid = function() return true end } -- no BP_SprintComponent field
    local resolver = make_resolver({ pawn })
    local state = Lifecycle.new(1, function(status) calls[#calls + 1] = status end)

    Lifecycle.tick(state, resolver.resolve, true)

    t.assert_eq(#calls, 1)
    t.assert_eq(calls[1], "no_component")
end)

-- on_actor_begin_play(): CS-DEF-001 regression coverage -------------------
--
-- CS-DEF-001 found that BeginPlay fires for every actor in the game, not
-- just pawns, and an earlier version of main.lua called the expensive
-- local-player resolver unconditionally for every single one of them
-- (masked by a separate bug where the pawn-identity check never actually
-- matched, so this went unnoticed until real gameplay -- see
-- docs/RUNTIME_DISCOVERY.md's CS-DEF-001 section). These tests assert on
-- the resolver's call count, not just final state, specifically to catch
-- a regression back to "resolve on every actor" rather than "resolve only
-- for pawn-like actors".

local function make_pawn_like_checker(predicateResult)
    local spy = { callCount = 0 }
    spy.check = function(actor)
        spy.callCount = spy.callCount + 1
        return predicateResult
    end
    return spy
end

t.test("on_actor_begin_play never calls the expensive resolver for a non-pawn actor", function()
    local isPawnLike = make_pawn_like_checker(false)
    local resolver = make_resolver({ make_pawn(make_component(40, 100)) })
    local state = Lifecycle.new(10, function() end)
    local prop = { name = "SomeDoorProp" }

    local applied = Lifecycle.on_actor_begin_play(state, prop, isPawnLike.check, resolver.resolve, true)

    t.assert_false(applied)
    t.assert_eq(isPawnLike.callCount, 1, "the cheap check must run")
    t.assert_eq(resolver.callCount, 0, "the expensive local-player resolver must not run for a non-pawn actor")
end)

t.test("on_actor_begin_play calls the resolver for a pawn-like actor but does not write if it isn't the local pawn", function()
    local isPawnLike = make_pawn_like_checker(true)
    local localPawn = make_pawn(make_component(40, 100), 0x1000)
    local otherPawn = make_pawn(make_component(1, 1), 0x2000) -- pawn-like (e.g. an AI character), different address, so not the local player
    local resolver = make_resolver({ localPawn })
    local state = Lifecycle.new(10, function() end)

    local applied = Lifecycle.on_actor_begin_play(state, otherPawn, isPawnLike.check, resolver.resolve, true)

    t.assert_false(applied)
    t.assert_eq(resolver.callCount, 1, "pawn-like actors do warrant the identity check")
    t.assert_eq(localPawn.BP_SprintComponent.Stamina, 40.0, "must not touch the real local pawn's component")
end)

-- This is the regression test for the identity-comparison bug an
-- independent review found in an earlier version of this fix: comparing
-- `actor == pawn` directly failed in real UE4SS because a fresh wrapper
-- userdata is constructed on every independent access to the same
-- underlying native object, and neither UObject's wrapper type nor its
-- bases define custom equality. `actorFromBeginPlay` and
-- `pawnFromResolver` are deliberately two separate Lua tables (not the
-- same reference) sharing only the same GetAddress() value, to
-- realistically simulate that. This test would fail against a plain
-- `==` comparison even though it passed against the (unrealistic)
-- same-table mock the bug shipped with.
t.test("on_actor_begin_play attaches when the actor is the local pawn via two distinct wrapper objects sharing one address", function()
    local isPawnLike = make_pawn_like_checker(true)
    local component = make_component(40, 100)
    local sharedAddress = 0x5000
    local actorFromBeginPlay = make_pawn(component, sharedAddress)
    local pawnFromResolver = make_pawn(component, sharedAddress)
    local resolver = make_resolver({ pawnFromResolver })
    local state = Lifecycle.new(10, function() end)

    local applied = Lifecycle.on_actor_begin_play(state, actorFromBeginPlay, isPawnLike.check, resolver.resolve, true)

    t.assert_true(applied)
    t.assert_eq(component.Stamina, 100.0)
end)

t.test("on_actor_begin_play does not write for the local pawn while disabled (distinct wrapper objects, same address)", function()
    local isPawnLike = make_pawn_like_checker(true)
    local component = make_component(40, 100)
    local sharedAddress = 0x5000
    local actorFromBeginPlay = make_pawn(component, sharedAddress)
    local pawnFromResolver = make_pawn(component, sharedAddress)
    local resolver = make_resolver({ pawnFromResolver })
    local state = Lifecycle.new(10, function() end)

    local applied = Lifecycle.on_actor_begin_play(state, actorFromBeginPlay, isPawnLike.check, resolver.resolve, false)

    t.assert_false(applied)
    t.assert_eq(component.Stamina, 40.0)
end)

t.test("on_actor_begin_play treats a missing/throwing GetAddress as not the same object, not a crash", function()
    local isPawnLike = make_pawn_like_checker(true)
    local localPawn = make_pawn(make_component(40, 100), 0x1000)
    local weirdActor = { GetAddress = function() error("simulated GetAddress failure") end }
    local resolver = make_resolver({ localPawn })
    local state = Lifecycle.new(10, function() end)

    local applied = Lifecycle.on_actor_begin_play(state, weirdActor, isPawnLike.check, resolver.resolve, true)

    t.assert_false(applied)
    t.assert_eq(localPawn.BP_SprintComponent.Stamina, 40.0)
end)

t.test("on_actor_begin_play handles a nil actor safely", function()
    local isPawnLike = make_pawn_like_checker(true)
    local resolver = make_resolver({})
    local state = Lifecycle.new(10, function() end)

    local applied = Lifecycle.on_actor_begin_play(state, nil, isPawnLike.check, resolver.resolve, true)

    t.assert_false(applied)
    t.assert_eq(isPawnLike.callCount, 0, "must not even attempt the cheap check on a nil actor")
end)

t.test("on_actor_begin_play handles isPawnLike itself throwing", function()
    local resolver = make_resolver({ make_pawn(make_component(40, 100)) })
    local state = Lifecycle.new(10, function() end)
    local actor = { name = "WeirdActor" }

    local applied = Lifecycle.on_actor_begin_play(state, actor, function() error("simulated IsA failure") end, resolver.resolve, true)

    t.assert_false(applied)
    t.assert_eq(resolver.callCount, 0)
end)
