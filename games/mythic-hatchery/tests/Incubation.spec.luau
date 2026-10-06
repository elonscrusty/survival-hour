--!strict
local Incubation = require("../src/shared/Logic/Incubation")
local Types = require("../src/shared/Types")
local function item(): Types.EggItem return { Uid = "egg1", Egg = "MeadowEgg", Tier = 1 } end
return {
	["fast incubation halves duration and snapshots seed and luck"] = function(t: any)
		local slot = Incubation.New(item(), 100, 42, 2, true)
		t.eq(slot.StartAt, 100); t.eq(slot.EndAt, 130); t.eq(slot.Seed, 42); t.eq(slot.Luck, 2)
	end,
	["early hatching is refused"] = function(t: any)
		local slot = Incubation.New(item(), 100, 42, 2, false)
		t.eq(Incubation.Roll(slot, 159), nil); t.ok(Incubation.Roll(slot, 160) ~= nil)
	end,
	["hatch seed and captured luck remain deterministic"] = function(t: any)
		local slot = Incubation.New(item(), 100, 42, 2, false)
		local a = Incubation.Roll(slot, 160) :: { Species: string, Rarity: string, Element: string }; local b = Incubation.Roll(slot, 999) :: { Species: string, Rarity: string, Element: string }
		t.eq(a.Species, b.Species); t.eq(a.Rarity, b.Rarity); t.eq(a.Element, b.Element)
	end,
	["skip is charged only while unfinished and funds cover cost"] = function(t: any)
		local slot = Incubation.New(item(), 100, 42, 2, false)
		t.eq(Incubation.SkipCost(slot, 100), 3)
		t.no(Incubation.Skip(slot, 2, 100)); t.eq(slot.EndAt, 160)
		local ok, cost = Incubation.Skip(slot, 3, 100)
		t.ok(ok); t.eq(cost, 3); t.eq(slot.EndAt, 100)
		t.eq(Incubation.SkipCost(slot, 101), 0)
		t.no(Incubation.Skip(slot, 100, 101))
	end,
	["invalid timestamps cannot complete incubation"] = function(t: any)
		local slot = Incubation.New(item(), 100, 42, 2, false)
		t.eq(Incubation.Roll(slot, math.huge), nil); t.eq(Incubation.Roll(slot, 0 / 0), nil)
		t.no(Incubation.Skip(slot, 100, 0 / 0))
	end,
}
