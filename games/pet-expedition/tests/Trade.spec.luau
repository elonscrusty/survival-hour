-- Trading state machine and atomic swap.
local Trade = require("../src/shared/Logic/Trade")
local Inventory = require("../src/shared/Logic/Inventory")
local Profile = require("../src/shared/Logic/Profile")
local Economy = require("../src/shared/Logic/Economy")
local Config = require("../src/shared/Config")

local NOW = 1_800_000_000

local function setup()
	local a, b = Profile.Default(), Profile.Default()
	a.Gems, b.Gems = 500, 100
	local ua, ub = {}, {}
	for i = 1, 4 do
		ua[i] = Inventory.Add(a, { Id = "Fox" }).Uid
		ub[i] = Inventory.Add(b, { Id = "Owl" }).Uid
	end
	local t = Trade.New("T1", 1, "Ann", 2, "Bob")
	local profiles = { [1] = a, [2] = b }
	local function profileOf(userId)
		return profiles[userId]
	end
	return t, a, b, ua, ub, profileOf
end

local function readyBoth(t, now)
	assert(Trade.SetReady(t, 1, true, now))
	assert(Trade.SetReady(t, 2, true, now))
end

local function snapshot(p)
	local uids = {}
	for _, pet in p.Pets do
		table.insert(uids, pet.Uid .. ":" .. pet.Id)
	end
	return table.concat(uids, ",") .. "|" .. p.Gems .. "|" .. table.concat(p.Equipped, ",")
end

return {
	["happy path swaps pets and gems"] = function(t)
		local tr, a, b, ua, ub = setup()
		t.ok(Trade.SetOffer(tr, 1, a, { ua[1], ua[2] }, 50), "offer a")
		t.ok(Trade.SetOffer(tr, 2, b, { ub[1] }, 0), "offer b")
		readyBoth(tr, NOW)
		t.eq(tr.Status, "Confirming", "confirming")
		t.no(Trade.Due(tr, NOW + Config.TradeConfirmSeconds - 0.1), "countdown running")
		t.ok(Trade.Due(tr, NOW + Config.TradeConfirmSeconds), "due")
		local plan, err = Trade.Execute(tr, a, b)
		t.ok(plan, err)
		t.eq(tr.Status, "Done", "done")
		t.eq(#a.Pets, 3, "a: 4 - 2 + 1")
		t.eq(#b.Pets, 5, "b: 4 - 1 + 2")
		t.eq(a.Gems, 450, "a gems")
		t.eq(b.Gems, 150, "b gems")
		t.ok(a.Index.Owl, "a discovered owl")
		t.ok(b.Index.Fox, "b discovered fox")
		t.no(Inventory.Find(a, ua[1]), "gone from a")
		-- Received pets have fresh uids, unique in the new owner's inventory.
		local seen = {}
		for _, pet in b.Pets do
			t.no(seen[pet.Uid], "unique " .. pet.Uid)
			seen[pet.Uid] = true
		end
		t.no(Trade.Execute(tr, a, b), "can't execute twice")
	end,
	["any offer change resets ready"] = function(t)
		local tr, a, b, ua = setup()
		Trade.SetOffer(tr, 1, a, { ua[1] }, 0)
		readyBoth(tr, NOW)
		t.eq(tr.Status, "Confirming", "confirming")
		Trade.SetOffer(tr, 1, a, { ua[1], ua[2] }, 0)
		t.eq(tr.Status, "Open", "back to open")
		t.no(tr.Sides[1].Ready, "a unready")
		t.no(tr.Sides[2].Ready, "b unready")
		t.no(Trade.Due(tr, NOW + 100), "not due")
		t.no(Trade.Execute(tr, a, b), "can't execute when open")
		Trade.SetReady(tr, 1, true, NOW)
		Trade.SetReady(tr, 2, true, NOW)
		Trade.SetReady(tr, 2, false, NOW)
		t.eq(tr.Status, "Open", "unready cancels countdown")
	end,
	["empty trades can't be readied"] = function(t)
		local tr = setup()
		t.no(Trade.SetReady(tr, 1, true, NOW), "nothing offered")
	end,
	["offers reject locked, busy, unknown, duplicate and too many pets"] = function(t)
		local tr, a, _, ua = setup()
		Inventory.Lock(a, ua[1], true)
		t.no(Trade.SetOffer(tr, 1, a, { ua[1] }, 0), "locked")
		a.Expeditions["1"] = { Area = "Meadow", Duration = "Short", Pets = { ua[2] }, StartAt = 0, EndAt = 1, Seed = 1 }
		t.no(Trade.SetOffer(tr, 1, a, { ua[2] }, 0), "busy")
		t.no(Trade.SetOffer(tr, 1, a, { "ghost" }, 0), "unknown")
		t.no(Trade.SetOffer(tr, 1, a, { ua[3], ua[3] }, 0), "duplicate")
		local many = {}
		for _ = 1, Config.TradeMaxPets + 1 do
			table.insert(many, Inventory.Add(a, { Id = "Puppy" }).Uid)
		end
		t.no(Trade.SetOffer(tr, 1, a, many, 0), "too many")
		t.no(Trade.SetOffer(tr, 1, a, { [1] = ua[3], [3] = ua[4] }, 0), "holey list")
		t.no(Trade.SetOffer(tr, 1, a, "x", 0), "not a list")
		t.no(Trade.SetOffer(tr, 3, a, {}, 0), "stranger")
	end,
	["gem offers are validated"] = function(t)
		local tr, a = setup()
		t.no(Trade.SetOffer(tr, 1, a, {}, -1), "negative")
		t.no(Trade.SetOffer(tr, 1, a, {}, 1.5), "fraction")
		t.no(Trade.SetOffer(tr, 1, a, {}, 0 / 0), "nan")
		t.no(Trade.SetOffer(tr, 1, a, {}, math.huge), "inf")
		t.no(Trade.SetOffer(tr, 1, a, {}, 501), "more than owned")
		t.no(Trade.SetOffer(tr, 1, a, {}, "5"), "string")
		a.Gems = Config.TradeMaxGems * 2
		t.no(Trade.SetOffer(tr, 1, a, {}, Config.TradeMaxGems + 1), "over trade cap")
		t.ok(Trade.SetOffer(tr, 1, a, {}, Config.TradeMaxGems), "at cap")
	end,
	["changes after ready make the swap fail without side effects"] = function(t)
		local cases = {
			function(a, ua)
				Inventory.Delete(a, { ua[1] })
			end,
			function(a, ua)
				Inventory.Lock(a, ua[1], true)
			end,
			function(a, ua)
				a.Expeditions["1"] = { Area = "Meadow", Duration = "Short", Pets = { ua[1] }, StartAt = 0, EndAt = 1, Seed = 1 }
			end,
			function(a)
				a.Gems = 10
			end,
		}
		for i, change in cases do
			local tr, a, b, ua, ub = setup()
			Trade.SetOffer(tr, 1, a, { ua[1] }, 50)
			Trade.SetOffer(tr, 2, b, { ub[1] }, 10)
			readyBoth(tr, NOW)
			change(a, ua)
			local beforeA, beforeB = snapshot(a), snapshot(b)
			local plan, err = Trade.Execute(tr, a, b)
			t.no(plan, "case " .. i .. " should fail")
			t.ok(err, "reason " .. i)
			t.eq(snapshot(a), beforeA, "a untouched " .. i)
			t.eq(snapshot(b), beforeB, "b untouched " .. i)
		end
	end,
	["storage overflow blocks the swap"] = function(t)
		local tr, a, b, ua, ub = setup()
		while Inventory.FreeSpace(b) > 0 do
			Inventory.Add(b, { Id = "Puppy" })
		end
		Trade.SetOffer(tr, 1, a, { ua[1], ua[2] }, 0)
		Trade.SetOffer(tr, 2, b, { ub[1] }, 0)
		readyBoth(tr, NOW)
		local before = #b.Pets
		t.no(Trade.Execute(tr, a, b), "b has no room for a net gain")
		t.eq(#b.Pets, before, "unchanged")
		-- An even swap is fine even when full.
		local tr2 = Trade.New("T2", 1, "Ann", 2, "Bob")
		Trade.SetOffer(tr2, 1, a, { ua[1] }, 0)
		Trade.SetOffer(tr2, 2, b, { ub[1] }, 0)
		readyBoth(tr2, NOW)
		t.ok(Trade.Execute(tr2, a, b), "1 for 1 when full")
		t.eq(#b.Pets, Economy.MaxStorage(b), "still full")
	end,
	["equipped pets leave the equip list; received pets arrive unlocked"] = function(t)
		local tr, a, b, ua, ub = setup()
		Inventory.Equip(a, ua[1], true)
		Trade.SetOffer(tr, 1, a, { ua[1] }, 0)
		Trade.SetOffer(tr, 2, b, { ub[1] }, 0)
		readyBoth(tr, NOW)
		t.ok(Trade.Execute(tr, a, b), "swap")
		t.eq(#a.Equipped, 0, "unequipped")
		for _, pet in b.Pets do
			t.no(pet.Locked, "unlocked")
		end
	end,
	["cancel closes the trade"] = function(t)
		local tr, a = setup()
		Trade.Cancel(tr)
		t.eq(tr.Status, "Cancelled", "cancelled")
		t.no(Trade.SetOffer(tr, 1, a, {}, 0), "closed")
		t.no(Trade.SetReady(tr, 1, true, NOW), "closed ready")
	end,
	["view shows each side from its own perspective"] = function(t)
		local tr, a, b, ua, _, profileOf = setup()
		Trade.SetOffer(tr, 1, a, { ua[1] }, 5)
		Trade.SetOffer(tr, 2, b, {}, 7)
		readyBoth(tr, NOW)
		local va = Trade.View(tr, 1, NOW + 1, profileOf)
		local vb = Trade.View(tr, 2, NOW + 1, profileOf)
		t.eq(va.Me.UserId, 1, "a me")
		t.eq(va.Them.UserId, 2, "a them")
		t.eq(vb.Me.UserId, 2, "b me")
		t.eq(#va.Me.Pets, 1, "pet shown")
		t.eq(va.Me.Pets[1].Id, "Fox", "pet data")
		t.eq(vb.Them.Gems, 5, "gems shown")
		t.eq(va.Countdown, Config.TradeConfirmSeconds - 1, "countdown")
		t.eq(va.Status, "Confirming", "status")
		t.eq(Trade.View(tr, 3, NOW, profileOf), nil, "stranger")
	end,
}
