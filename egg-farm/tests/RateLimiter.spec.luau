local RateLimiter = require("../src/shared/Logic/RateLimiter")
local Validate = require("../src/shared/Logic/Validate")

return {
	bucket_limits_bursts_and_refills = function(t)
		local l = RateLimiter.new(3, 1)
		t.ok(l:Allow("p", 0))
		t.ok(l:Allow("p", 0))
		t.ok(l:Allow("p", 0))
		t.no(l:Allow("p", 0), "burst exhausted")
		t.ok(l:Allow("p", 1), "refilled after 1s")
		t.no(l:Allow("p", 1))
	end,
	keys_are_independent = function(t)
		local l = RateLimiter.new(1, 1)
		t.ok(l:Allow("a", 0))
		t.ok(l:Allow("b", 0))
	end,
	clock_going_backwards_does_not_refill = function(t)
		local l = RateLimiter.new(1, 1)
		t.ok(l:Allow("a", 10))
		t.no(l:Allow("a", 5))
	end,
	validate_rejects_bad_numbers = function(t)
		t.no(Validate.Finite(0 / 0))
		t.no(Validate.Finite(math.huge))
		t.no(Validate.Finite("5"))
		t.no(Validate.Int(1.5, 0, 10))
		t.no(Validate.Int(-1, 0, 10))
		t.no(Validate.Int(11, 0, 10))
		t.ok(Validate.Int(3, 0, 10))
	end,
	validate_ids_and_text = function(t)
		t.ok(Validate.Id("shack_1"))
		t.no(Validate.Id(""))
		t.no(Validate.Id({}))
		t.no(Validate.Id("a b"))
		t.no(Validate.Id(string.rep("a", 100)))
		t.ok(Validate.Text("EGGS 2025!", 20))
		t.no(Validate.Text("bad\0code", 20))
	end,
}
