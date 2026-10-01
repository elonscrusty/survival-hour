-- Unit tests for the pure game rules (Luau CLI, no Roblox engine).
--   luau tests/run.luau        (from the SellHotDogs folder: cd tests && luau run.luau)
local specs = {
	"./BigNum.spec",
	"./Format.spec",
	"./Economy.spec",
	"./Game.spec",
	"./Prestige.spec",
	"./Profile.spec",
	"./Receipts.spec",
	"./Phone.spec",
	"./Dash.spec",
	"./Names.spec",
}

local passed, failed = 0, 0
local failures = {}

local function makeT()
	local t = {}
	function t.eq(a, b, msg)
		if a ~= b then
			error(string.format("%s: expected %s, got %s", msg or "eq", tostring(b), tostring(a)), 2)
		end
	end
	function t.near(a, b, tol, msg)
		if math.abs(a - b) > (tol or 1e-9) then
			error(string.format("%s: expected ~%s, got %s", msg or "near", tostring(b), tostring(a)), 2)
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
