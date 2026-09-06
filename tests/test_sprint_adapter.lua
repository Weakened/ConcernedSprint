local t = require("testkit")
t.set_file("test_sprint_adapter")

local Adapter = require("sprint_adapter")

-- Mock objects standing in for UE4SS UObject-shaped pawns/components: a
-- plain table with an IsValid() method and plain fields, matching the
-- exact surface sprint_adapter.lua is documented to use (see
-- docs.ue4ss.com's UObject:IsValid()/property-access examples, quoted in
-- docs/RUNTIME_DISCOVERY.md). These mocks prove our own adapter logic is
-- correct; they are not a claim about how the real game behaves -- see
-- docs/RUNTIME_DISCOVERY.md section 5 for what still needs an actual
-- in-game observation.

local function valid_component(overrides)
    local component = {
        MaximumStamina = 100.0,
        Stamina = 40.0,
    }
    for k, v in pairs(overrides or {}) do
        component[k] = v
    end
    component.IsValid = function() return true end
    return component
end

local function valid_pawn(component)
    return {
        BP_SprintComponent = component,
        IsValid = function() return true end,
    }
end

-- get_sprint_component --------------------------------------------------

t.test("get_sprint_component returns nil for a nil pawn", function()
    t.assert_nil(Adapter.get_sprint_component(nil))
end)

t.test("get_sprint_component returns nil when the pawn is invalid", function()
    local pawn = { IsValid = function() return false end }
    t.assert_nil(Adapter.get_sprint_component(pawn))
end)

t.test("get_sprint_component returns nil when IsValid() itself throws", function()
    local pawn = { IsValid = function() error("torn down object") end }
    t.assert_nil(Adapter.get_sprint_component(pawn))
end)

t.test("get_sprint_component returns nil when the pawn has no BP_SprintComponent", function()
    local pawn = { IsValid = function() return true end }
    t.assert_nil(Adapter.get_sprint_component(pawn))
end)

t.test("get_sprint_component returns nil when the component is invalid", function()
    local component = valid_component()
    component.IsValid = function() return false end
    local pawn = valid_pawn(component)
    t.assert_nil(Adapter.get_sprint_component(pawn))
end)

t.test("get_sprint_component returns the component when everything is valid", function()
    local component = valid_component()
    local pawn = valid_pawn(component)
    t.assert_eq(Adapter.get_sprint_component(pawn), component)
end)

-- apply -------------------------------------------------------------------

t.test("apply does nothing for a nil component", function()
    t.assert_false(Adapter.apply(nil))
end)

t.test("apply does not write when MaximumStamina is missing/wrong type", function()
    -- Table constructors drop nil-valued keys entirely, so the field is
    -- removed after construction to genuinely simulate "absent" rather
    -- than relying on `{ MaximumStamina = nil }` (a no-op in Lua).
    local component = valid_component()
    component.MaximumStamina = nil
    local result = Adapter.apply(component)
    t.assert_false(result)
    t.assert_eq(component.Stamina, 40.0, "Stamina must be untouched")
end)

t.test("apply does not write when Stamina is missing/wrong type", function()
    local component = valid_component({ Stamina = "not a number" })
    t.assert_false(Adapter.apply(component))
end)

t.test("apply does not write when Stamina is already at MaximumStamina", function()
    local component = valid_component({ Stamina = 100.0, MaximumStamina = 100.0 })
    local result = Adapter.apply(component)
    t.assert_false(result)
    t.assert_eq(component.Stamina, 100.0)
end)

t.test("apply does not write when Stamina is already above MaximumStamina", function()
    -- Defensive case: should not happen in the real game, but must not
    -- clamp downward -- this mod only ever prevents exhaustion, it never
    -- reduces a value the game set.
    local component = valid_component({ Stamina = 120.0, MaximumStamina = 100.0 })
    local result = Adapter.apply(component)
    t.assert_false(result)
    t.assert_eq(component.Stamina, 120.0)
end)

t.test("apply tops Stamina up to MaximumStamina when below it", function()
    local component = valid_component({ Stamina = 40.0, MaximumStamina = 100.0 })
    local result = Adapter.apply(component)
    t.assert_true(result)
    t.assert_eq(component.Stamina, 100.0)
end)

t.test("apply handles the write itself throwing", function()
    local component = valid_component({ Stamina = 40.0, MaximumStamina = 100.0 })
    local raw = { Stamina = component.Stamina, MaximumStamina = component.MaximumStamina, IsValid = component.IsValid }
    local proxy = setmetatable({}, {
        __index = raw,
        __newindex = function(_, key)
            error("simulated write failure for " .. tostring(key))
        end,
    })
    local result = Adapter.apply(proxy)
    t.assert_false(result)
end)

-- apply: per-access liveness guard (CS-DEF-001 hardening) -----------------
--
-- get_sprint_component() above only validates once, at bind time.
-- lifecycle.lua then holds and reuses that same cached reference for up
-- to a resolve interval (~3s) before re-resolving, so a pawn/level
-- transition inside that window can invalidate the underlying object
-- without the cached Lua reference itself changing. Independent review
-- confirmed against UE4SS's own source (LuaUObject.hpp's
-- `prepare_to_handle`, which backs plain property get/set) that a
-- property read/write only null-checks the stored pointer -- it does not
-- repeat the full liveness check `IsValid()` performs, so a stale-but-
-- non-nil cached reference could otherwise reach a real property access.
-- apply() now calls `component:IsValid()` immediately before every
-- individual read/write, not just once. These tests use a traced
-- component that counts property accesses, to prove apply() never even
-- attempts a read/write once invalid -- not just that it returns false.

-- Traced component: counts reads of MaximumStamina/Stamina and writes to
-- Stamina via __index/__newindex, and lets the test control what
-- IsValid() does (return true, return false, or throw) independently of
-- those counts.
local function make_traced_component(maxStamina, stamina, isValidFn)
    local raw = { MaximumStamina = maxStamina, Stamina = stamina }
    local trace = { reads = 0, writes = 0 }
    local component = setmetatable({}, {
        __index = function(_, key)
            if key == "IsValid" then
                return function() return isValidFn() end
            end
            if key == "MaximumStamina" or key == "Stamina" then
                trace.reads = trace.reads + 1
            end
            return raw[key]
        end,
        __newindex = function(_, key, value)
            if key == "Stamina" then
                trace.writes = trace.writes + 1
            end
            raw[key] = value
        end,
    })
    return component, trace
end

t.test("apply never reads or writes properties on a component invalidated since it was cached", function()
    local component, trace = make_traced_component(100, 40, function() return false end)

    local result = Adapter.apply(component)

    t.assert_false(result)
    t.assert_eq(trace.reads, 0, "must not read MaximumStamina or Stamina once invalid")
    t.assert_eq(trace.writes, 0, "must not write Stamina once invalid")
end)

t.test("apply never reads or writes properties when IsValid() itself throws", function()
    local component, trace = make_traced_component(100, 40, function() error("simulated liveness check failure") end)

    local result = Adapter.apply(component)

    t.assert_false(result)
    t.assert_eq(trace.reads, 0)
    t.assert_eq(trace.writes, 0)
end)

t.test("apply reads MaximumStamina/Stamina and writes exactly once when valid throughout", function()
    local component, trace = make_traced_component(100, 40, function() return true end)

    local result = Adapter.apply(component)

    t.assert_true(result)
    t.assert_eq(trace.writes, 1, "must write Stamina exactly once")
    t.assert_true(trace.reads >= 2, "must have read both MaximumStamina and Stamina")
end)
