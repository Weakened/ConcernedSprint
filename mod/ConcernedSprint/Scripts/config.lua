-- Plain-text config persistence, using only Lua's standard `io` library
-- (confirmed available in UE4SS's Lua runtime: it's used the same way by
-- UE4SS's own bundled BPModLoaderMod and ConsoleCommandsMod). Pure file
-- I/O with no UE4SS globals, so it is testable standalone.

local M = {}

-- Default state when no config file exists yet (fresh install): the mod's
-- entire purpose is infinite sprint, so it starts enabled.
local DEFAULTS = { enabled = true }

function M.load(path)
    local file = io.open(path, "r")
    if not file then
        return { enabled = DEFAULTS.enabled }
    end

    local content = file:read("*a") or ""
    file:close()

    local value = content:match("enabled%s*=%s*(%a+)")
    if value == nil then
        return { enabled = DEFAULTS.enabled }
    end

    return { enabled = (value:lower() == "true") }
end

-- Returns true on success, false if the file could not be written (e.g.
-- read-only install location) -- callers should log this, not throw.
function M.save(path, state)
    local file = io.open(path, "w")
    if not file then
        return false
    end
    file:write(string.format("enabled=%s\n", tostring(state.enabled == true)))
    file:close()
    return true
end

return M
