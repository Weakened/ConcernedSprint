-- Entry point: `lua tests/run_tests.lua` from anywhere. Runs the mod's
-- pure-logic unit tests with nothing but the stock Lua interpreter -- no
-- game, no UE4SS, no network. Exits 0 if every test passed, 1 otherwise,
-- so it can be used as a CI check.
--
-- What this does and does not prove: it proves sprint_adapter.lua and
-- config.lua behave correctly against every state/config/lifecycle case
-- listed in CS-002's acceptance criteria (nil/invalid pawns, missing
-- component, wrong-typed properties, already-full stamina, write
-- failures, malformed/missing config). It does NOT prove UE4SS's real Lua
-- bindings behave the same way against the actual game -- that is tracked
-- separately in docs/RUNTIME_DISCOVERY.md as pending runtime evidence, per
-- CS-002's "do not treat mocked tests as proof of compatibility".

local scriptDir = debug.getinfo(1, "S").source:match("@(.*[/\\])") or "./"
package.path = scriptDir .. "?.lua;"
    .. scriptDir .. "../mod/ConcernedSprint/Scripts/?.lua;"
    .. package.path

require("test_sprint_adapter")
require("test_config")

local testkit = require("testkit")
local allPassed = testkit.run()

os.exit(allPassed and 0 or 1)
