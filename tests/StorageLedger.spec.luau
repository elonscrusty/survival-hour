local I = require("../src/shared/Logic/InventoryModel")
local S = require("../src/shared/Logic/StorageLedger")

local function inv()
	return I.New(30, 3, { Arrow = 30, Bullet = 24 })
end

local function conserved(t, invs, store, expected)
	local total = S.Total(store)
	for _, v in invs do
		total += I.ResourceTotal(v)
	end
	t.eq(total, expected, "resources conserved")
end

return {
	deposit_withdraw = function(t)
		local a, st = inv(), S.New(200)
		I.AddResource(a, "Wood", 20)
		t.eq(S.Deposit(st, a, "Wood", 50), 20, "deposit only what you carry")
		t.eq(S.Withdraw(st, a, "Wood", 5), 5)
		conserved(t, { a }, st, 20)
	end,
	withdraw_respects_carry_limit = function(t)
		local a, st = inv(), S.New(200)
		st.Items.Stone = 50
		I.AddResource(a, "Wood", 25)
		t.eq(S.Withdraw(st, a, "Stone", 50), 5)
		t.eq(st.Items.Stone, 45)
	end,
	storage_capacity = function(t)
		local a, st = inv(), S.New(10)
		I.AddResource(a, "Wood", 30)
		t.eq(S.Deposit(st, a, "Wood", 30), 10)
		t.eq(a.Resources.Wood, 20)
	end,
	simultaneous_withdraw_no_dupe = function(t)
		-- Two teammates (or a thief and an owner) request the same 8 stone.
		local a, b, st = inv(), inv(), S.New(200)
		st.Items.Stone = 8
		local got1 = S.Withdraw(st, a, "Stone", 8)
		local got2 = S.Withdraw(st, b, "Stone", 8)
		t.eq(got1 + got2, 8, "no duplication")
		conserved(t, { a, b }, st, 8)
	end,
	pay_combined_all_or_nothing = function(t)
		local a, st = inv(), S.New(200)
		I.AddResource(a, "Wood", 3)
		st.Items.Wood = 10
		st.Items.Stone = 1
		t.no(S.PayCombined({ Wood = 12, Stone = 2 }, a, { st }))
		t.eq(a.Resources.Wood, 3, "inventory untouched on failure")
		t.eq(st.Items.Wood, 10, "store untouched on failure")
		t.ok(S.PayCombined({ Wood = 12, Stone = 1 }, a, { st }))
		t.eq(a.Resources.Wood, 0, "pack used first")
		t.eq(st.Items.Wood, 1)
		t.eq(st.Items.Stone, 0)
	end,
	rejects_fractional_and_unknown = function(t)
		local a, st = inv(), S.New(200)
		I.AddResource(a, "Wood", 5)
		t.eq(S.Deposit(st, a, "Wood", 2.5), 0)
		t.eq(S.Deposit(st, a, "Gold", 1), 0)
		t.eq(S.Withdraw(st, a, "Wood", -1), 0)
	end,
}
