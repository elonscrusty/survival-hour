-- Deterministic random numbers.
local Rng = require("../src/shared/Logic/Rng")

return {
	["same seed gives the same sequence"] = function(t)
		local a, b = Rng.New(12345), Rng.New(12345)
		for _ = 1, 50 do
			t.eq(a:Next(), b:Next(), "sequence")
		end
	end,
	["different seeds differ"] = function(t)
		local a, b = Rng.New(1), Rng.New(2)
		local same = 0
		for _ = 1, 20 do
			if a:Next() == b:Next() then
				same += 1
			end
		end
		t.ok(same < 20, "sequences should differ")
	end,
	["values stay in [0, 1)"] = function(t)
		local r = Rng.New(987654321)
		for _ = 1, 5000 do
			local v = r:Next()
			t.ok(v >= 0 and v < 1, "range " .. v)
		end
	end,
	["bad seeds are normalised"] = function(t)
		for _, seed in { 0, -5, 0 / 0, math.huge, -math.huge, 2147483647, 1.5e300 } do
			local r = Rng.New(seed)
			t.ok(r.State >= 1 and r.State < Rng.Modulus, "state for " .. tostring(seed))
			local v = r:Next()
			t.ok(v >= 0 and v < 1, "value for " .. tostring(seed))
		end
	end,
	["Int is inclusive and handles swapped bounds"] = function(t)
		local r = Rng.New(42)
		local seen = {}
		for _ = 1, 2000 do
			local v = r:Int(1, 4)
			t.ok(v >= 1 and v <= 4 and v == math.floor(v), "int range")
			seen[v] = true
		end
		t.ok(seen[1] and seen[4], "both ends reached")
		for _ = 1, 100 do
			local v = r:Int(5, 2)
			t.ok(v >= 2 and v <= 5, "swapped")
		end
		t.eq(r:Int(3, 3), 3, "single value")
	end,
	["Chance edge cases"] = function(t)
		local r = Rng.New(7)
		for _ = 1, 100 do
			t.no(r:Chance(0), "0")
			t.no(r:Chance(-1), "negative")
			t.no(r:Chance(0 / 0), "nan")
			t.ok(r:Chance(1), "1")
			t.ok(r:Chance(5), "over 1")
		end
	end,
	["distribution is roughly uniform"] = function(t)
		local r = Rng.New(2024)
		local buckets = { 0, 0, 0, 0 }
		local n = 20000
		for _ = 1, n do
			local b = math.floor(r:Next() * 4) + 1
			buckets[b] += 1
		end
		for i = 1, 4 do
			t.ok(math.abs(buckets[i] / n - 0.25) < 0.02, "bucket " .. i .. " " .. buckets[i])
		end
	end,
	["Hash is stable and order sensitive"] = function(t)
		t.eq(Rng.Hash("quests", 100), Rng.Hash("quests", 100), "stable")
		t.ok(Rng.Hash("quests", 100) ~= Rng.Hash("quests", 101), "day matters")
		t.ok(Rng.Hash("a", "b") ~= Rng.Hash("b", "a"), "order matters")
		local h = Rng.Hash()
		t.ok(h >= 1 and h < Rng.Modulus, "empty hash valid")
	end,
}
