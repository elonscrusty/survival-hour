local H = require("./Helpers")
local Products = require("../src/shared/Data/Products")
local TestCheckout = require("../src/server/Commerce/TestCheckout")

return {
	shipped_products_have_no_robux_ids = function(t)
		for _, p in Products.List do
			t.eq(p.robuxId, nil, p.id .. " must not ship with a borrowed/placeholder id")
		end
	end,

	grant_product_is_idempotent_per_purchase = function(t)
		local f, s = H.Farm()
		t.ok((f:GrantProduct("gold_small", "P1", H.T0)))
		t.eq(s.gold, 50)
		local ok, code = f:GrantProduct("gold_small", "P1", H.T0)
		t.ok(ok)
		t.eq(code, "already", "replayed receipt grants nothing")
		t.eq(s.gold, 50)
		t.ok((f:GrantProduct("gold_small", "P2", H.T0)))
		t.eq(s.gold, 100)
	end,

	passes_become_entitlements = function(t)
		local f, s = H.Farm()
		f:GrantProduct("x2cash", "P9", H.T0)
		t.ok(s.passes.x2cash)
		t.near(f:Snapshot(H.T0).mods.saleMult, 2, 1e-9)
	end,

	gold_items_cannot_be_granted_as_robux = function(t)
		local f, s = H.Farm()
		t.no((f:GrantProduct("buy_earn3", "P3", H.T0)))
		t.no((f:GrantProduct("nope", "P4", H.T0)))
		t.no((f:GrantProduct("gold_small", "", H.T0)))
		t.eq(s.gold, 0)
	end,

	gold_shop_charges_gold = function(t)
		local f, s = H.Farm(function(s)
			s.gold = 20
		end)
		t.ok(f:Apply({ type = "buyGoldItem", id = "buy_earn3" }, H.T0).ok)
		t.eq(s.gold, 0)
		t.eq(s.boosts.inventory.earn3, 1)
		t.eq(f:Apply({ type = "buyGoldItem", id = "buy_earn3" }, H.T0).code, "cant_afford_gold")
		t.eq(f:Apply({ type = "buyGoldItem", id = "gold_small" }, H.T0).code, "invalid", "robux item via gold route")
	end,

	test_checkout_success_cancel_fail = function(t)
		local f, s = H.Farm()
		local grant = function(id, pid)
			return f:GrantProduct(id, pid, H.T0)
		end
		local c = TestCheckout.new(Products, "success")
		local r = c:Buy("gold_medium", grant)
		t.ok(r.ok)
		t.eq(s.gold, 275)
		t.ok(next(s.receipts) ~= nil and string.sub(next(s.receipts), 1, 5) == "TEST-", "test purchase ids are marked")
		c.mode = "cancel"
		t.eq(c:Buy("gold_medium", grant).code, "cancelled")
		c.mode = "fail"
		t.eq(c:Buy("gold_medium", grant).code, "failed")
		t.eq(s.gold, 275, "no grant on cancel/fail")
		t.eq(c:Buy("buy_earn3", grant).code, "invalid")
	end,

	receipts_are_trimmed_but_passes_kept = function(t)
		local Economy = require("../src/shared/Logic/Economy")
		local _, s = H.Farm()
		s.receipts["PASS-1-2"] = 1
		for i = 1, 250 do
			s.receipts["P" .. i] = i
		end
		Economy.TrimReceipts(s, 200)
		local n = 0
		for _ in s.receipts do
			n += 1
		end
		t.eq(n, 201)
		t.ok(s.receipts["PASS-1-2"] ~= nil, "pass key kept")
		t.ok(s.receipts.P250 ~= nil and s.receipts.P1 == nil, "oldest dropped")
	end,
}
