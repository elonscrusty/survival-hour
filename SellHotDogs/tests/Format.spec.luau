local B = require("../src/shared/Logic/BigNum")
local F = require("../src/shared/Logic/Format")

return {
	small_amounts_two_decimals = function(t)
		t.eq(F.cash(3.24), "$3.24")
		t.eq(F.cash(5.1), "$5.10")
		t.eq(F.cash(0), "$0.00")
		t.eq(F.cash(999.996), "$1,000")
	end,
	thousands_with_commas = function(t)
		t.eq(F.cash(4772), "$4,772")
		t.eq(F.cash(18816), "$18,816")
		t.eq(F.cash(19500), "$19,500")
	end,
	named_large = function(t)
		t.eq(F.cash(296.102e12), "$296.102 trillion")
		t.eq(F.cash(73.5e6), "$73.5 million")
		t.eq(F.cash(1e6), "$1 million")
		t.eq(F.amount(B.fromParts(2.85, 3 * 90 + 3)), "2.85 nonagintillion")
		t.eq(F.amount(B.fromParts(9.39807, 3 * 90 + 5)), "939.807 nonagintillion")
	end,
	illion_names = function(t)
		t.eq(F.illion(13), "tredecillion")
		t.eq(F.illion(17), "septendecillion")
		t.eq(F.illion(20), "vigintillion")
		t.eq(F.illion(26), "sexvigintillion")
		t.eq(F.illion(29), "novemvigintillion")
		t.eq(F.illion(100), "centillion")
	end,
	beyond_names_scientific = function(t)
		t.eq(F.cash(B.fromParts(1.5, 564)), "$1.5e564")
		t.eq(F.short(B.fromParts(1.5, 564)), "$1.5e564")
	end,
	short = function(t)
		t.eq(F.short(1.1e6), "$1.1M")
		t.eq(F.short(296.102e12), "$296.1T")
		t.eq(F.short(5.84), "$5.84")
	end,
	timer = function(t)
		t.eq(F.timer(1), "1s")
		t.eq(F.timer(0.8), "0.8s")
		t.eq(F.timer(0.2), "0.2s")
		t.eq(F.timer(75), "1m 15s")
	end,
}
