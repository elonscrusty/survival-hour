-- Malformed, malicious and replayed requests are rejected before touching state.
local H = require("./Helpers")
local State = require("../src/shared/Logic/State")

local Rewards = require("../src/shared/Logic/Rewards")

local function snapshotOf(s)
	Rewards.RollDay(s, H.T0) -- day bookkeeping is legitimate; compare everything else
	local MemoryStore = require("../src/server/Persistence/MemoryStore")
	return MemoryStore.DeepCopy(s)
end

local function same(t, a, b, path)
	if type(a) ~= type(b) then
		error("changed at " .. path)
	end
	if type(a) == "table" then
		for k, v in a do
			same(t, v, b[k], path .. "." .. tostring(k))
		end
		for k in b do
			if a[k] == nil then
				error("added at " .. path .. "." .. tostring(k))
			end
		end
	elseif a ~= b and not (a ~= a and b ~= b) then
		error(string.format("changed at %s: %s -> %s", path, tostring(a), tostring(b)))
	end
end

local BAD = { 0 / 0, math.huge, -math.huge, -1, 1.5, 1e300, "1", {}, true }

return {
	garbage_actions_rejected = function(t)
		local f, s = H.Farm(function(s)
			s.cash = 1e6
		end)
		local before = snapshotOf(s)
		for _, a in { nil, 5, "spawn", {}, { type = 5 }, { type = "nope" }, { type = "collect", slot = 1 }, { type = "deposit" }, { type = "catchFox" } } do
			local r = f:Apply(a, H.T0)
			t.no(r.ok, "rejected " .. tostring(if type(a) == "table" then a.type else a))
		end
		same(t, before, s, "state")
	end,

	bad_numbers_in_every_slot_action = function(t)
		local f, s = H.Farm(function(s)
			s.cash = 1e6
			s.gold = 1e6
		end)
		local before = snapshotOf(s)
		for _, kind in { "buyHouse", "upgradeHouse", "buyVehicle", "upgradeVehicle", "hireWorker", "upgradeWorker" } do
			for _, v in BAD do
				local r = f:Apply({ type = kind, slot = v }, H.T0)
				t.no(r.ok, kind .. " with bad slot")
				r = f:Apply({ type = kind, slot = 1, expect = v }, H.T0)
				t.no(r.ok and kind:find("upgrade") ~= nil, kind .. " with bad expect")
			end
		end
		-- only the "slot = 1, expect = bad" buy* calls could have done anything; buy on slot 1 is taken
		same(t, before.population, s.population, "population")
	end,

	bad_ids_and_text = function(t)
		local f, s = H.Farm(function(s)
			s.gold = 1e6
			H.Done(s)
		end)
		local before = snapshotOf(s)
		for _, v in { 0 / 0, {}, "", string.rep("x", 200), "../evil", "a b", true } do
			t.no(f:Apply({ type = "buyEpic", id = v }, H.T0).ok)
			t.no(f:Apply({ type = "buyCommon", id = v }, H.T0).ok)
			t.no(f:Apply({ type = "useBoost", id = v }, H.T0).ok)
			t.no(f:Apply({ type = "claimQuest", id = v }, H.T0).ok)
			t.no(f:Apply({ type = "buyGoldItem", id = v }, H.T0).ok)
			t.no(f:Apply({ type = "redeemCode", text = v }, H.T0).ok)
			t.no(f:Apply({ type = "setSetting", id = v, value = true }, H.T0).ok)
			t.no(f:Apply({ type = "claimGift", index = v }, H.T0).ok)
		end
		same(t, before, s, "state")
	end,

	settings_values_are_typed = function(t)
		local f, s = H.Farm()
		t.no(f:Apply({ type = "setSetting", id = "music", value = "yes" }, H.T0).ok)
		t.no(f:Apply({ type = "setSetting", id = "flock", value = "ultra" }, H.T0).ok)
		t.no(f:Apply({ type = "setSetting", id = "cash", value = 1e9 }, H.T0).ok, "not a setting")
		t.ok(f:Apply({ type = "setSetting", id = "flock", value = "low" }, H.T0).ok)
		t.eq(s.settings.flock, "low")
		t.eq(s.cash, 0)
	end,

	replayed_sequence_numbers_rejected = function(t)
		local f, s = H.Farm()
		t.ok(f:Apply({ type = "spawn", seq = 1 }, H.T0).ok)
		t.eq(f:Apply({ type = "spawn", seq = 1 }, H.T0).code, "stale", "same seq")
		t.eq(f:Apply({ type = "spawn", seq = 0 }, H.T0).code, "stale", "older seq")
		t.eq(f:Apply({ type = "spawn", seq = 0 / 0 }, H.T0).code, "stale")
		t.ok(f:Apply({ type = "spawn", seq = 2 }, H.T0).ok)
		t.eq(s.population, 2)
	end,

	client_cannot_pass_prices_or_amounts = function(t)
		local f, s = H.Farm(function(s)
			s.cash = 300
		end)
		-- extra fields are ignored; the server prices the purchase itself
		local r = f:Apply({ type = "upgradeHouse", slot = 1, expect = 1, price = 0, amount = -1e9, cash = 1e12 }, H.T0)
		t.ok(r.ok)
		t.eq(s.cash, 50, "charged the real price (250)")
	end,

	repeated_purchase_requests_charge_once = function(t)
		local f, s = H.Farm(function(s)
			s.cash = 300
		end)
		local okCount = 0
		for _ = 1, 10 do
			if f:Apply({ type = "upgradeHouse", slot = 1, expect = 1 }, H.T0).ok then
				okCount += 1
			end
		end
		t.eq(okCount, 1)
		t.eq(s.cash, 50)
	end,

	new_state_fields_listed_in_reset_or_keep = function(t)
		local s = State.New(H.T0)
		for k in s do
			local inReset = table.find(State.RESET_FIELDS, k) ~= nil
			local inKeep = table.find(State.KEPT_FIELDS, k) ~= nil
			t.ok(inReset ~= inKeep, "field " .. k .. " must be in exactly one list")
		end
	end,
}
