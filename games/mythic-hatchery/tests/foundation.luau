--!strict
-- Focused conversion checks. Whole-project checks still run through run.luau.
local specs: { any } = {
	require("./Hatch.spec"), require("./Incubation.spec"), require("./Gameplay.spec"), require("./Fusion.spec"), require("./BattleEdges.spec"),
}
local passed, failed = 0, 0
local t: any = {}
function t.eq(a: any, b: any, msg: string?)
	assert(a == b, (msg or "eq") .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end
function t.ok(v: any, msg: string?) assert(v, msg or "expected truthy") end
function t.no(v: any, msg: string?) assert(not v, msg or "expected falsy") end
for _, spec in specs do
	local names: { string } = {}
	for name in spec do table.insert(names, name) end
	table.sort(names)
	for _, name in names do
		local ok, err = pcall(spec[name], t)
		if ok then passed += 1 else failed += 1; print("FAIL " .. name .. ": " .. tostring(err)) end
	end
end
print(string.format("%d passed, %d failed", passed, failed))
assert(failed == 0, "Foundation tests failed")
