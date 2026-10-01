local B = require("../src/shared/Logic/BigNum")
local Phone = require("../src/shared/Logic/Phone")

local function seq(list)
	local i = 0
	return function()
		i += 1
		return list[(i - 1) % #list + 1]
	end
end

return {
	no_offer_without_income = function(t)
		t.eq(Phone.newOffer(1, B.zero, 0, seq({ 0.5 })), nil)
	end,
	accept_grants_amount = function(t)
		local o = Phone.newOffer(1, B.new(10), 0, seq({ 0 }))
		t.near(B.toNumber(o.amount), 600, 1e-9, "60 s of $10/s")
		local r, amt = Phone.respond(o, "accept", 1, seq({ 0 }))
		t.eq(r, "accepted")
		t.near(B.toNumber(amt), 600, 1e-9)
		t.eq(Phone.respond(o, "accept", 2, seq({ 0 })), "closed", "no double accept")
	end,
	raise_better_then_final_then_walk = function(t)
		local o = Phone.newOffer(1, B.new(10), 0, seq({ 0 }))
		t.eq(Phone.respond(o, "raise", 1, seq({ 0.9 })), "better")
		t.near(B.toNumber(o.amount), 750, 1e-9)
		t.eq(Phone.respond(o, "raise", 2, seq({ 0.3 })), "final")
		t.ok(o.final)
		t.eq(Phone.respond(o, "raise", 3, seq({ 0.9 })), "walked")
		t.eq(o.state, "walked")
	end,
	raise_can_walk_immediately = function(t)
		local o = Phone.newOffer(1, B.new(10), 0, seq({ 0 }))
		t.eq(Phone.respond(o, "raise", 1, seq({ 0.1 })), "walked")
	end,
	decline_and_expiry = function(t)
		local o = Phone.newOffer(1, B.new(10), 0, seq({ 0 }))
		t.eq(Phone.respond(o, "decline", 1, seq({ 0 })), "declined")
		local o2 = Phone.newOffer(2, B.new(10), 0, seq({ 0 }))
		t.eq(Phone.respond(o2, "accept", 1000, seq({ 0 })), "expired")
	end,
	invalid_action = function(t)
		local o = Phone.newOffer(1, B.new(10), 0, seq({ 0 }))
		t.eq(Phone.respond(o, "steal", 1, seq({ 0 })), "invalid")
		t.eq(o.state, "open")
	end,
}
