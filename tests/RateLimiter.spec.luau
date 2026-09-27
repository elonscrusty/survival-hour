local R = require("../src/shared/Logic/RateLimiter")

return {
	burst_then_refill = function(t)
		local lim = R.New({ Default = { 2, 3 } })
		t.ok(R.Allow(lim, "p", "X", 0))
		t.ok(R.Allow(lim, "p", "X", 0))
		t.ok(R.Allow(lim, "p", "X", 0))
		t.no(R.Allow(lim, "p", "X", 0), "burst exhausted")
		t.ok(R.Allow(lim, "p", "X", 0.5), "refilled one token")
		t.no(R.Allow(lim, "p", "X", 0.5))
	end,
	per_key_isolation = function(t)
		local lim = R.New({ Default = { 1, 1 } })
		t.ok(R.Allow(lim, "a", "X", 0))
		t.ok(R.Allow(lim, "b", "X", 0))
		t.no(R.Allow(lim, "a", "X", 0))
	end,
	spam_blocked = function(t)
		local lim = R.New({ Default = { 10, 20 } })
		local allowed = 0
		for _ = 1, 1000 do
			if R.Allow(lim, "p", "Attack", 1) then
				allowed += 1
			end
		end
		t.eq(allowed, 20, "only burst allowed in one instant")
	end,
}
