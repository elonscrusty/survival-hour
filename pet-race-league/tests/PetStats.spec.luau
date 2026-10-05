local PetStats = require("../src/shared/Logic/PetStats")
local Config = require("../src/shared/Config")

return {
	new_pet_level_one = function(t)
		local p = PetStats.New("p1", "Pup")
		for _, s in Config.Stats.Names do
			t.eq(p.Levels[s], 1)
			t.eq(p.Xp[s], 0)
		end
	end,
	xp_levels_up_and_carries = function(t)
		local p = PetStats.New("p1", "Pup")
		local need = PetStats.XpToNext(1)
		t.eq(PetStats.AddXp(p, "Speed", need + 3), 1)
		t.eq(p.Levels.Speed, 2)
		t.eq(p.Xp.Speed, 3)
	end,
	xp_caps_at_max = function(t)
		local p = PetStats.New("p1", "Pup")
		PetStats.AddXp(p, "Jump", 1e9)
		t.eq(p.Levels.Jump, Config.Stats.MaxLevel)
		t.eq(p.Xp.Jump, 0)
		t.eq(PetStats.AddXp(p, "Jump", 100), 0)
	end,
	bad_stat_ignored = function(t)
		local p = PetStats.New("p1", "Pup")
		t.eq(PetStats.AddXp(p, "Fly", 100), 0)
		t.eq(PetStats.AddXp(p, "Speed", -5), 0)
		t.eq(p.Levels.Fly, nil)
	end,
	training_beats_rarity = function(t)
		-- a fully trained Common must outrun an untrained Mythic
		local common = PetStats.New("a", "Pup")
		PetStats.AddXp(common, "Speed", 1e9)
		local mythic = PetStats.New("b", "Phoenix")
		t.ok(PetStats.Ride(common).WalkSpeed > PetStats.Ride(mythic).WalkSpeed * 1.8)
	end,
	rarity_bonus_is_small = function(t)
		local a = PetStats.New("a", "Pup")
		local b = PetStats.New("b", "Phoenix")
		PetStats.AddXp(a, "Speed", 1e9)
		PetStats.AddXp(b, "Speed", 1e9)
		local ratio = PetStats.Ride(b).WalkSpeed / PetStats.Ride(a).WalkSpeed
		t.ok(ratio <= 1.1 + 1e-9, "max rarity edge is 10%")
	end,
	dash_charges_grow_and_cap = function(t)
		local p = PetStats.New("a", "Pup")
		t.eq(PetStats.Ride(p).DashCharges, 1)
		PetStats.AddXp(p, "Stamina", 1e9)
		local r = PetStats.Ride(p)
		t.eq(r.DashCharges, Config.Ride.DashChargesMax)
		t.ok(r.DashRecharge >= Config.Ride.DashRechargeMin)
	end,
	max_speed_covers_dash = function(t)
		local p = PetStats.New("a", "Pup")
		t.near(PetStats.MaxSpeed(p), PetStats.Ride(p).WalkSpeed * Config.Ride.DashBoost)
		t.near(PetStats.MaxSpeed(nil), Config.Ride.OnFootSpeed * Config.Ride.DashBoost)
	end,
	base_pet_can_jump_first_hurdles = function(t)
		-- jump height = JumpPower^2 / (2 * gravity)
		local p = PetStats.New("a", "Pup")
		local h = PetStats.Ride(p).JumpPower ^ 2 / (2 * 196.2)
		t.ok(h > 4, "untrained pet clears 4-stud hurdles, got " .. h)
	end,
}
