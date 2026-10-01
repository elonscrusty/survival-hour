-- Egg Farm test harness for the Luau CLI. Usage (from egg-farm/):
--   luau tests/run.luau
-- Each spec returns a table of { name = function(t) ... end }. Register new specs below.
-- Specs run against the real modules in src/ (string requires work both here and in Roblox).

local specs = {
	"./Format.spec",
	"./Persistence.spec",
	"./RateLimiter.spec",
	"./MenuRouter.spec",
	"./PurchaseState.spec",
	"./Tutorial.spec",
	"./Economy.spec",
	"./Conservation.spec",
	"./Validation.spec",
	"./Progression.spec",
	"./Rewards.spec",
	"./Boosts.spec",
	"./Codes.spec",
	"./Migrations.spec",
	"./Commerce.spec",
	"./LargeNumbers.spec",
	"./PlotRegistry.spec",
	"./Flock.spec",
	"./Plots.spec",
}

local passed, failed = 0, 0
local failures = {}

local function fmt(v)
	if type(v) == "number" then
		return string.format("%.17g", v)
	end
	return tostring(v)
end

local function makeT()
	local t = {}
	function t.eq(a, b, msg)
		if a ~= b then
			error(string.format("%s: expected %s, got %s", msg or "eq", fmt(b), fmt(a)), 2)
		end
	end
	function t.near(a, b, eps, msg)
		if type(a) ~= "number" or math.abs(a - b) > (eps or 1e-9) then
			error(string.format("%s: expected ~%s, got %s", msg or "near", fmt(b), fmt(a)), 2)
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

local only = ...
for _, path in specs do
	if only and not string.find(path, only, 1, true) then
		continue
	end
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
		local ok, err = pcall(spec[name], makeT())
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
