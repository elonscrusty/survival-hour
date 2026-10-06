-- Tiny test harness for the Luau CLI. Usage (from the project root):
--   luau tests/run.luau
-- Register every new spec in the list below.
-- Each spec returns a table of { name = function(t) ... end }.

local specs = {
	"./Data.spec",
	"./Rng.spec",
	"./PetMath.spec",
	"./Hatch.spec",
	"./Incubation.spec",
	"./Gameplay.spec",
	"./Fusion.spec",
	"./BattleEdges.spec",
	"./Economy.spec",
	"./Inventory.spec",
	"./Expedition.spec",
	"./Rewards.spec",
	"./Profile.spec",
	"./Trade.spec",
	"./RateLimiter.spec",
	"./Models.spec",
}

local passed, failed = 0, 0
local failures = {}

local function makeT(name)
	local t = {}
	function t.eq(a, b, msg)
		if a ~= b then
			error(string.format("%s: expected %s, got %s", msg or "eq", tostring(b), tostring(a)), 2)
		end
	end
	function t.ok(v, msg)
		if not v then
			error(msg or "expected truthy", 2)
		end
	end
	function t.no(v, msg)
		if v then
			error(msg or "expected falsy", 2)
		end
	end
	return t
end

for _, path in specs do
	local okLoad, spec = pcall(require, path)
	if not okLoad then
		failed += 1
		table.insert(failures, path .. " (load): " .. tostring(spec))
		continue
	end
	local names = {}
	for name in spec do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in names do
		local ok, err = pcall(spec[name], makeT(name))
		if ok then
			passed += 1
		else
			failed += 1
			table.insert(failures, path .. " :: " .. name .. " -> " .. tostring(err))
		end
	end
end

for _, f in failures do
	print("FAIL " .. f)
end
print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	error("tests failed")
end
