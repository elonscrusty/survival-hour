local PurchaseState = require("../src/shared/Logic/PurchaseState")
local Prices = require("../src/shared/Logic/Prices")
local State = require("../src/shared/Logic/State")

local C = PurchaseState.Compute

return {
	affordable_and_unaffordable = function(t)
		local a = C({ price = 100, balance = 100, now = 0 })
		t.eq(a.state, "affordable")
		t.ok(a.canRequest)
		local u = C({ price = 101, balance = 100, now = 0 })
		t.eq(u.state, "unaffordable")
		t.no(u.canRequest)
		t.eq(u.code, "cant_afford")
		t.eq(C({ price = 5, balance = 1, currency = "gold", now = 0 }).code, "cant_afford_gold")
	end,
	recomputes_from_balance = function(t)
		local input = { price = 250, balance = 10, now = 0 }
		t.eq(C(input).state, "unaffordable")
		input.balance = 300 -- next snapshot
		t.eq(C(input).state, "affordable", "no stale affordability")
	end,
	loading_wins = function(t)
		local o = C({ price = 1, balance = 999, busy = true, now = 0, lastRejectAt = 0 })
		t.eq(o.state, "loading")
		t.no(o.canRequest, "no duplicate requests while in flight")
	end,
	rejected_then_back_to_live = function(t)
		t.eq(C({ price = 1, balance = 5, lastRejectAt = 10, now = 10.5 }).state, "rejected")
		t.no(C({ price = 1, balance = 5, lastRejectAt = 10, now = 10.5 }).canRequest)
		local after = C({ price = 1, balance = 5, lastRejectAt = 10, now = 10 + PurchaseState.REJECT_SHOW + 0.01 })
		t.eq(after.state, "affordable", "re-enabled after a rejection")
		t.ok(after.canRequest)
		t.eq(C({ price = 1, balance = 5, lastRejectAt = 20, now = 10 }).state, "affordable", "clock went backwards")
	end,
	owned_max_locked = function(t)
		t.eq(C({ owned = true, price = 10, balance = 99, now = 0 }).state, "owned")
		t.eq(C({ reason = "slot_taken", balance = 0, now = 0 }).state, "owned")
		t.eq(C({ reason = "claimed", balance = 0, now = 0 }).state, "owned")
		t.eq(C({ reason = "max_level", balance = 0, now = 0 }).state, "max")
		t.eq(C({ reason = "locked", balance = 0, now = 0 }).state, "locked")
		t.eq(C({ reason = "slot_locked", balance = 0, now = 0 }).state, "locked")
		t.eq(C({ reason = "tutorial", balance = 0, now = 0 }).code, "tutorial")
		t.eq(C({ reason = "invalid", balance = 0, now = 0 }).state, "unavailable")
		t.eq(C({ balance = 0, now = 0 }).state, "unavailable", "nil price without reason")
	end,
	robux_and_free = function(t)
		t.eq(C({ price = 249, currency = "robux", balance = 0, now = 0 }).state, "affordable")
		t.eq(C({ price = 0, balance = 0, now = 0 }).state, "affordable", "free claim")
	end,
	captions = function(t)
		t.eq(PurchaseState.Caption("max"), "MAX")
		t.eq(PurchaseState.Caption("owned"), "OWNED")
		t.eq(PurchaseState.Caption("affordable"), nil)
		t.ok(PurchaseState.IsRejection({ ok = false, code = "cant_afford" }))
		t.no(PurchaseState.IsRejection({ ok = false, code = "busy" }))
		t.no(PurchaseState.IsRejection({ ok = false, code = "cancelled" }), "player closed the Robux prompt")
		t.ok(PurchaseState.IsRejection({ ok = false, code = "not_configured" }))
		t.no(PurchaseState.IsRejection({ ok = true, code = "ok" }))
	end,
	with_real_prices = function(t)
		local s = State.New(0)
		local price, code = Prices.UpgradeHouse(s, 1)
		t.eq(code, "ok")
		t.eq(C({ price = price, reason = code, balance = 0, now = 0 }).state, "unaffordable")
		s.cash = price :: number
		t.eq(C({ price = price, reason = code, balance = s.cash, now = 0 }).state, "affordable")
		local p2, c2 = Prices.BuyHouse(s, 3)
		t.eq(C({ price = p2, reason = c2, balance = 1e9, now = 0 }).state, "locked", "slot 3 before slot 2")
		local p3, c3 = Prices.BuyHouse(s, 1)
		t.eq(C({ price = p3, reason = c3, balance = 1e9, now = 0 }).state, "owned")
	end,
}
