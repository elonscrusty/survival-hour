-- Per player, per remote token buckets.
local RateLimiter = require("../src/shared/Logic/RateLimiter")

local LIMIT = { Rate = 2, Burst = 3 }

return {
	["burst then refuse"] = function(t)
		local l = RateLimiter.New()
		for i = 1, 3 do
			t.ok(RateLimiter.Allow(l, "p1", "Hatch", LIMIT, 0), "call " .. i)
		end
		t.no(RateLimiter.Allow(l, "p1", "Hatch", LIMIT, 0), "4th refused")
	end,
	["refills over time up to burst"] = function(t)
		local l = RateLimiter.New()
		for _ = 1, 3 do
			RateLimiter.Allow(l, "p1", "Hatch", LIMIT, 0)
		end
		t.no(RateLimiter.Allow(l, "p1", "Hatch", LIMIT, 0.2), "not yet")
		t.ok(RateLimiter.Allow(l, "p1", "Hatch", LIMIT, 0.5), "one token back")
		t.no(RateLimiter.Allow(l, "p1", "Hatch", LIMIT, 0.5), "used")
		local ok = 0
		for _ = 1, 10 do
			if RateLimiter.Allow(l, "p1", "Hatch", LIMIT, 100) then
				ok += 1
			end
		end
		t.eq(ok, 3, "capped at burst after a long pause")
	end,
	["owners and names are independent"] = function(t)
		local l = RateLimiter.New()
		for _ = 1, 3 do
			RateLimiter.Allow(l, "p1", "Hatch", LIMIT, 0)
		end
		t.ok(RateLimiter.Allow(l, "p2", "Hatch", LIMIT, 0), "other player")
		t.ok(RateLimiter.Allow(l, "p1", "Equip", LIMIT, 0), "other remote")
		RateLimiter.Forget(l, "p1")
		t.ok(RateLimiter.Allow(l, "p1", "Hatch", LIMIT, 0), "forgotten owner starts fresh")
	end,
	["clock going backwards doesn't mint tokens"] = function(t)
		local l = RateLimiter.New()
		for _ = 1, 3 do
			RateLimiter.Allow(l, "p1", "Hatch", LIMIT, 10)
		end
		t.no(RateLimiter.Allow(l, "p1", "Hatch", LIMIT, 5), "earlier time")
		t.no(RateLimiter.Allow(l, "p1", "Hatch", LIMIT, 10.1), "still empty")
	end,
}
