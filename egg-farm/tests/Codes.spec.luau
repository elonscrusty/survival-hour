local H = require("./Helpers")
local Codes = require("../src/server/Data/Codes")

-- SYNTHETIC FIXTURE codes for this spec only.
local CODES = {
	FREEGOLD = { reward = { gold = 25 } },
	OLDCODE = { reward = { gold = 5 }, expires = H.T0 - 1 },
}

return {
	code_needs_tutorial = function(t)
		local f, s = H.Farm(nil, { codes = CODES })
		t.eq(f:Apply({ type = "redeemCode", text = "FREEGOLD" }, H.T0).code, "tutorial")
		t.eq(s.gold, 0)
	end,

	code_success_case_insensitive_once = function(t)
		local f, s = H.Farm(H.Done, { codes = CODES })
		local r = f:Apply({ type = "redeemCode", text = "freeGold" }, H.T0)
		t.eq(r.code, "code_ok")
		t.eq(r.ok, true, "success")
		t.eq(s.gold, 25)
		t.eq(f:Apply({ type = "redeemCode", text = "FREEGOLD" }, H.T0).code, "code_used")
		t.eq(s.gold, 25, "paid once")
	end,

	code_invalid_and_expired = function(t)
		local f, s = H.Farm(H.Done, { codes = CODES })
		t.eq(f:Apply({ type = "redeemCode", text = "NOPE" }, H.T0).code, "code_invalid")
		t.eq(f:Apply({ type = "redeemCode", text = "OLDCODE" }, H.T0).code, "code_expired")
		t.eq(f:Apply({ type = "redeemCode", text = "" }, H.T0).code, "code_invalid")
		t.eq(f:Apply({ type = "redeemCode", text = string.rep("A", 40) }, H.T0).code, "code_invalid")
		t.eq(s.gold, 0)
	end,

	code_without_server_table_is_invalid = function(t)
		local f = H.Farm(H.Done, {})
		t.eq(f:Apply({ type = "redeemCode", text = "FREEGOLD" }, H.T0).code, "code_invalid")
	end,

	shipped_codes_are_well_formed = function(t)
		local Boosts = require("../src/shared/Data/Boosts")
		for key, def in Codes do
			t.eq(key, string.upper(key), "uppercase key " .. key)
			t.ok(def.reward ~= nil, "reward " .. key)
			for id in def.reward.boosts or {} do
				t.ok(Boosts.ById[id] ~= nil, "boost id " .. id)
			end
		end
	end,
}
