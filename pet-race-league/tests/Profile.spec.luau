local Profile = require("../src/shared/Logic/Profile")
local Config = require("../src/shared/Config")

return {
	default_has_starter_pet = function(t)
		local d = Profile.Default()
		t.eq(#d.Pets, 1)
		t.eq(d.Pets[1].Species, "Pup")
		t.eq(d.Equipped, d.Pets[1].Uid)
		t.eq(d.Coins, Config.StartCoins)
	end,
	sanitize_garbage = function(t)
		local d = Profile.Sanitize("nope")
		t.eq(#d.Pets, 1)
		local d2 = Profile.Sanitize({ Coins = -50, Trophies = 0 / 0, Pets = { { Uid = "x", Species = "Nope" } } })
		t.eq(d2.Coins, 0)
		t.eq(d2.Trophies, 0)
		t.eq(#d2.Pets, 1, "bad pet dropped, starter added")
	end,
	sanitize_round_trip = function(t)
		local d = Profile.Default()
		local fox = Profile.AddPet(d, "Fox")
		t.ok(fox ~= nil)
		d.Equipped = fox and fox.Uid
		d.Owned.TrailDust = true
		d.Owned.FakeThing = true
		d.Pets[1].Levels.Speed = 999
		local back = Profile.Sanitize(d)
		t.eq(#back.Pets, 2)
		t.eq(back.Equipped, fox and fox.Uid)
		t.eq(back.Owned.TrailDust, true)
		t.eq(back.Owned.FakeThing, nil)
		t.eq(back.Pets[1].Levels.Speed, Config.Stats.MaxLevel)
	end,
	sanitize_duplicate_uids = function(t)
		local d = Profile.Sanitize({ Pets = { { Uid = "a", Species = "Pup" }, { Uid = "a", Species = "Fox" } }, Equipped = "zzz" })
		t.eq(#d.Pets, 1)
		t.eq(d.Equipped, "a")
	end,
	capacity_and_full = function(t)
		local d = Profile.Default()
		for _ = 1, 100 do
			Profile.AddPet(d, "Kitty")
		end
		t.eq(#d.Pets, Config.Slots.Base)
		t.eq(Profile.AddPet(d, "Kitty"), nil)
		d.BigBarn = true
		t.ok(Profile.AddPet(d, "Kitty") ~= nil)
	end,
	uids_unique = function(t)
		local d = Profile.Default()
		local seen = {}
		for _ = 1, 10 do
			Profile.AddPet(d, "Bunny")
		end
		for _, p in d.Pets do
			t.ok(not seen[p.Uid])
			seen[p.Uid] = true
		end
	end,
	release_rules = function(t)
		local d = Profile.Default()
		local ok, _ = Profile.Release(d, d.Pets[1].Uid)
		t.ok(not ok, "can't release last pet")
		local fox = Profile.AddPet(d, "Fox") :: any
		ok = Profile.Release(d, d.Equipped :: string)
		t.ok(not ok, "can't release ridden pet")
		local ok2, species = Profile.Release(d, fox.Uid)
		t.ok(ok2)
		t.eq(species, "Fox")
		t.eq(#d.Pets, 1)
	end,
	receipts_once = function(t)
		local d = Profile.Default()
		t.ok(Profile.TakeReceipt(d, "r1"))
		t.ok(not Profile.TakeReceipt(d, "r1"))
		for i = 1, 60 do
			Profile.TakeReceipt(d, "x" .. i)
		end
		t.eq(#d.Receipts, 50)
	end,
}
