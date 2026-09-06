local t = require("testkit")
t.set_file("test_config")

local Config = require("config")

-- These tests use real file I/O against a temp path (not a mock of `io`):
-- io.open/read/write/close are stock Lua, identical inside and outside
-- UE4SS (confirmed in docs/RUNTIME_DISCOVERY.md's CS-002 research against
-- UE4SS's own bundled mods, which use the same calls the same way), so
-- there is nothing UE4SS-specific left to fake here.

local function temp_path(name)
    return os.tmpname() .. "_" .. name
end

local function cleanup(path)
    os.remove(path)
end

t.test("load defaults to enabled when no config file exists", function()
    local path = temp_path("missing.txt")
    cleanup(path) -- os.tmpname() creates the file; remove it so it's truly missing
    local state = Config.load(path)
    t.assert_true(state.enabled)
end)

t.test("save then load round-trips enabled=true", function()
    local path = temp_path("roundtrip_true.txt")
    Config.save(path, { enabled = true })
    local state = Config.load(path)
    t.assert_true(state.enabled)
    cleanup(path)
end)

t.test("save then load round-trips enabled=false", function()
    local path = temp_path("roundtrip_false.txt")
    Config.save(path, { enabled = false })
    local state = Config.load(path)
    t.assert_false(state.enabled)
    cleanup(path)
end)

t.test("load tolerates a malformed file by defaulting to enabled", function()
    local path = temp_path("malformed.txt")
    local file = io.open(path, "w")
    file:write("this is not a config file\n")
    file:close()
    local state = Config.load(path)
    t.assert_true(state.enabled)
    cleanup(path)
end)

t.test("load is case-insensitive on the boolean word", function()
    local path = temp_path("case.txt")
    local file = io.open(path, "w")
    file:write("enabled=FALSE\n")
    file:close()
    local state = Config.load(path)
    t.assert_false(state.enabled)
    cleanup(path)
end)

t.test("save reports failure for an unwritable path instead of throwing", function()
    -- A directory path can never be opened for writing as a file.
    local unwritablePath = os.tmpname()
    os.remove(unwritablePath)
    -- Recreate it as a directory-shaped path by pointing at a path with no
    -- existing parent directory, which io.open reports as failure (nil)
    -- rather than throwing, on every platform Lua's io library supports.
    local result = Config.save(unwritablePath .. "/no/such/dir/enabled.txt", { enabled = true })
    t.assert_false(result)
end)
