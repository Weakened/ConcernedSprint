-- Thin adapter around the verified game internals (see docs/RUNTIME_DISCOVERY.md
-- section 4). Pure logic: takes UE4SS-shaped objects as arguments and only
-- calls documented methods/property access on them (:IsValid(), plain member
-- read/write). No UE4SS globals are referenced here, which is what lets
-- tests/test_sprint_adapter.lua exercise this file with plain Lua tables
-- standing in for pawns/components, without the game or UE4SS present.

local M = {}

-- Returns pawn.BP_SprintComponent if `pawn` and the component are both
-- present and valid, else nil. Never throws: any unexpected shape (nil
-- pawn, dead/invalid pawn, a pawn class without a sprint component, an
-- invalid component) is treated as "nothing to do here" rather than an
-- error, per the "fail safely" requirement for menus/dead pawns/unknown
-- runtime layouts.
function M.get_sprint_component(pawn)
    if not pawn then
        return nil
    end

    local validOk, valid = pcall(function() return pawn:IsValid() end)
    if not validOk or not valid then
        return nil
    end

    local compOk, component = pcall(function() return pawn.BP_SprintComponent end)
    if not compOk or not component then
        return nil
    end

    local compValidOk, compValid = pcall(function() return component:IsValid() end)
    if not compValidOk or not compValid then
        return nil
    end

    return component
end

-- Protected liveness check, used immediately before every individual
-- property read/write in apply() below -- not just once at the top.
-- get_sprint_component() above only validates once, at bind time; the
-- caller (lifecycle.lua) then holds and reuses that same reference for up
-- to a resolve interval (~3s) before re-resolving. A pawn/level
-- transition inside that window can invalidate the underlying object
-- without the cached Lua reference changing: per UE4SS's own source at
-- the pinned commit, property get/set (`prepare_to_handle` in
-- LuaUObject.hpp) only null-checks the stored pointer -- it does not
-- repeat the full liveness check `IsValid()` performs (tracked-object
-- membership + reachability), and `NotifyUObjectDeleted`
-- (LuaUObject.cpp) removes a destroyed object from that liveness
-- tracking without ever touching an existing Lua wrapper's stored
-- pointer. So a stale-but-non-nil cached reference can silently pass
-- straight through to a native property read/write. `component:IsValid()`
-- is the only thing that actually re-checks liveness, hence calling it
-- immediately before each access rather than trusting the one check that
-- happened when this reference was first cached. Fails closed (treats
-- IsValid() itself throwing the same as it returning false) -- pcall
-- guards against a thrown error, but the underlying liveness gap this
-- guards against is not something a Lua-level pcall can substitute for.
local function is_valid(component)
    local ok, valid = pcall(function() return component:IsValid() end)
    return ok and valid == true
end

-- Tops `component`'s current Stamina up to its own MaximumStamina if it has
-- fallen below it. Never writes a mod-invented value -- only ever pushes
-- Stamina towards a ceiling the game itself already defines and continues
-- to manage (see docs/RUNTIME_DISCOVERY.md section 4.6), so there is
-- nothing to restore when this stops being called: the component's own
-- unmodified update loop resumes normal depletion on its own next tick.
-- Returns true if a write happened, false otherwise (including on any
-- unexpected failure -- this never throws). This does not, by itself,
-- prove or disprove any specific previously-reported crash's root cause
-- -- it closes a real gap found by independent review of the cached-
-- reference lifetime, evidenced directly against UE4SS's source.
function M.apply(component)
    if not component then
        return false
    end

    if not is_valid(component) then
        return false
    end
    local maxOk, maxStamina = pcall(function() return component.MaximumStamina end)
    if not maxOk or type(maxStamina) ~= "number" then
        return false
    end

    if not is_valid(component) then
        return false
    end
    local staminaOk, stamina = pcall(function() return component.Stamina end)
    if not staminaOk or type(stamina) ~= "number" then
        return false
    end

    if stamina >= maxStamina then
        return false
    end

    if not is_valid(component) then
        return false
    end
    local writeOk = pcall(function() component.Stamina = maxStamina end)
    return writeOk == true
end

return M
