-- Tiny test harness for the Luau CLI. Usage (from pet-race-league/tests):
--   luau run.luau
-- Each spec returns a table of { name = function(t) ... end }.

local specs = {
	"./Hatch.spec",
	"./PetStats.spec",
	"./Profile.spec",
	"./RaceRules.spec",
	"./TrackLayout.spec",
	"./AssetFit.spec",
	"./Models.spec",
}

local passed, failed = 0, 0

local function makeT()
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
	function t.near(a, b, eps, msg)
		if math.abs(a - b) > (eps or 1e-6) then
			error(string.format("%s: expected ~%s, got %s", msg or "near", tostring(b), tostring(a)), 2)
		end
	end
	return t
end

for _, path in specs do
	local spec = require(path) :: any
	local names = {}
	for name in spec do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in names do
		local ok, err = pcall(spec[name], makeT())
		if ok then
			passed += 1
		else
			failed += 1
			print("FAIL " .. path .. " " .. name .. ": " .. tostring(err))
		end
	end
end

print(string.format("%d passed, %d failed", passed, failed))
