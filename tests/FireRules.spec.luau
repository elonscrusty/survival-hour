local F = require("../src/shared/Logic/FireRules")

-- Mirrors Config.Fire (Config itself needs Roblox types, so the numbers are repeated here).
local T = {
	StartFuel = 0.5,
	FullFuelSeconds = { 480, 540, 600, 660, 720 },
	FuelPerWood = 0.02,
	SnuffTimes = { 8, 10, 12, 15, 20 },
	ProtectedNights = 2,
	MaxLevel = 5,
	Upgrades = {
		[2] = { Wood = 32, Stone = 18 },
		[3] = { Wood = 64, Stone = 36, Scrap = 15 },
		[4] = { Wood = 128, Stone = 72, Scrap = 40, Iron = 12 },
		[5] = { Wood = 256, Stone = 144, Scrap = 80, Iron = 32, RareComponent = 1 },
	},
}

local function near(t, a, b, msg)
	t.ok(math.abs(a - b) < 1e-6, (msg or "near") .. ": " .. tostring(a) .. " vs " .. tostring(b))
end

return {
	starts_half_full_four_minutes = function(t)
		local f = F.New(T)
		t.eq(f.Level, 1)
		near(t, F.SecondsLeft(f, T), 240, "half of 8 min")
	end,
	burns_out_permanently = function(t)
		local f = F.New(T)
		t.no(F.Burn(f, 239, T))
		t.ok(F.Burn(f, 2, T), "goes out at 0")
		t.ok(f.Out)
		t.eq(F.WoodAccepted(f, 10, T), 0, "can't refuel a dead fire")
		F.AddWood(f, 10, T)
		t.eq(f.Fuel, 0, "not relit")
		t.no(F.Burn(f, 5, T), "only reports once")
	end,
	wood_is_two_percent = function(t)
		local f = F.New(T)
		F.AddWood(f, 1, T)
		near(t, f.Fuel, 0.52)
		t.eq(F.WoodAccepted(f, 100, T), 24, "24 more fills it")
		t.eq(F.WoodAccepted(f, 3, T), 3, "limited by what you carry")
		F.AddWood(f, 30, T)
		t.eq(f.Fuel, 1, "clamped")
		t.eq(F.WoodAccepted(f, 5, T), 0)
	end,
	firekeeper_multiplier = function(t)
		local f = F.New(T)
		F.AddWood(f, 1, T, 1.25)
		near(t, f.Fuel, 0.525)
	end,
	snuff_times_by_level = function(t)
		local f = F.New(T)
		for lvl, s in { 8, 10, 12, 15, 20 } do
			f.Level = lvl
			t.eq(F.SnuffTime(f, T), s)
		end
	end,
	no_snuffing_nights_one_two = function(t)
		t.no(F.SnuffAllowed("Day", 1, T))
		t.no(F.SnuffAllowed("Night", 1, T))
		t.no(F.SnuffAllowed("Night", 2, T))
		t.no(F.SnuffAllowed("Day", 3, T), "day 3 is before night 3")
		t.ok(F.SnuffAllowed("Night", 3, T), "night 3 opens it")
		t.ok(F.SnuffAllowed("Day", 4, T), "then day too")
		t.ok(F.SnuffAllowed("Night", 9, T))
		t.no(F.SnuffAllowed("Intro", 5, T))
	end,
	upgrade_by_contribution = function(t)
		local f = F.New(T)
		local taken, up = F.Contribute(f, { Wood = 20, Stone = 30 }, T)
		t.eq(taken.Wood, 20)
		t.eq(taken.Stone, 18, "only what's still needed")
		t.no(up)
		t.eq(F.Remaining(f, T).Wood, 12)
		t.eq(F.Remaining(f, T).Stone, nil)
		f.Fuel = 0.4
		taken, up = F.Contribute(f, { Wood = 50 }, T)
		t.eq(taken.Wood, 12)
		t.ok(up)
		t.eq(f.Level, 2)
		near(t, f.Fuel, 0.4, "fuel fraction kept")
		near(t, F.SecondsLeft(f, T), 0.4 * 540)
		t.eq(F.Remaining(f, T).Scrap, 15, "L3 needs scrap")
	end,
	max_level_and_out = function(t)
		local f = F.New(T)
		f.Level = 5
		t.no(F.CanUpgrade(f, T))
		local taken = F.Contribute(f, { Wood = 999 }, T)
		t.eq(next(taken), nil)
		local g = F.New(T)
		g.Out = true
		t.no(F.CanUpgrade(g, T), "dead fires can't be upgraded")
	end,
}
