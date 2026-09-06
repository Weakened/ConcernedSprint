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

-- Tops `component`'s current Stamina up to its own MaximumStamina if it has
-- fallen below it. Never writes a mod-invented value -- only ever pushes
-- Stamina towards a ceiling the game itself already defines and continues
-- to manage (see docs/RUNTIME_DISCOVERY.md section 4.6), so there is
-- nothing to restore when this stops being called: the component's own
-- unmodified update loop resumes normal depletion on its own next tick.
-- Returns true if a write happened, false otherwise (including on any
-- unexpected failure -- this never throws).
function M.apply(component)
    if not component then
        return false
    end

    local maxOk, maxStamina = pcall(function() return component.MaximumStamina end)
    if not maxOk or type(maxStamina) ~= "number" then
        return false
    end

    local staminaOk, stamina = pcall(function() return component.Stamina end)
    if not staminaOk or type(stamina) ~= "number" then
        return false
    end

    if stamina >= maxStamina then
        return false
    end

    local writeOk = pcall(function() component.Stamina = maxStamina end)
    return writeOk == true
end

return M
