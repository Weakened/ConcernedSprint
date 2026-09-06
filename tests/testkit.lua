-- Minimal dependency-free test harness. No external Lua packages: the
-- whole point is that these tests run with nothing but the stock `lua`
-- interpreter, so they can run in CI without the game or UE4SS.

local M = {}
local tests = {}
local currentFile = "?"

function M.set_file(name)
    currentFile = name
end

function M.test(name, fn)
    tests[#tests + 1] = { file = currentFile, name = name, fn = fn }
end

function M.assert_eq(actual, expected, message)
    if actual ~= expected then
        error(string.format(
            "%s (expected %s, got %s)",
            message or "assert_eq failed",
            tostring(expected),
            tostring(actual)
        ), 2)
    end
end

function M.assert_true(value, message)
    if value ~= true then
        error(message or ("assert_true failed (got " .. tostring(value) .. ")"), 2)
    end
end

function M.assert_false(value, message)
    if value ~= false then
        error(message or ("assert_false failed (got " .. tostring(value) .. ")"), 2)
    end
end

function M.assert_nil(value, message)
    if value ~= nil then
        error(message or ("assert_nil failed (got " .. tostring(value) .. ")"), 2)
    end
end

-- Runs every registered test, prints a PASS/FAIL line for each, and
-- returns true only if all of them passed.
function M.run()
    local passCount, failCount = 0, 0
    for _, t in ipairs(tests) do
        local ok, err = pcall(t.fn)
        if ok then
            passCount = passCount + 1
            print(string.format("PASS  %s :: %s", t.file, t.name))
        else
            failCount = failCount + 1
            print(string.format("FAIL  %s :: %s\n      %s", t.file, t.name, tostring(err)))
        end
    end
    print(string.format("\n%d passed, %d failed, %d total", passCount, failCount, passCount + failCount))
    return failCount == 0
end

return M
