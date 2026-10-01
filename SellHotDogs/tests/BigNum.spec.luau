local B = require("../src/shared/Logic/BigNum")

return {
	normalises = function(t)
		local a = B.new(1234.5)
		t.near(a.m, 1.2345, 1e-12)
		t.eq(a.e, 3)
		t.eq(B.new(0).m, 0)
	end,
	add_sub_small = function(t)
		local a = B.add(B.new(3.24), B.new(0.76))
		t.near(B.toNumber(a), 4, 1e-12)
		t.near(B.toNumber(B.sub(B.new(100), B.new(82.5))), 17.5, 1e-12)
	end,
	add_far_apart_keeps_larger = function(t)
		local a = B.add(B.fromParts(1, 500), B.new(5))
		t.eq(a.e, 500)
		t.near(a.m, 1, 1e-12)
	end,
	beyond_double_range = function(t)
		local w = B.fromParts(3.5, 564)
		local x = B.mul(w, B.fromParts(2, 100))
		t.eq(x.e, 664)
		t.near(x.m, 7, 1e-12)
		t.ok(B.gte(x, w))
		t.eq(B.toNumber(x), math.huge, "toNumber saturates")
		t.near(B.log10(x), 664 + math.log10(7), 1e-9)
	end,
	compare_signs_and_exponents = function(t)
		t.eq(B.cmp(B.new(-5), B.new(3)), -1)
		t.eq(B.cmp(B.new(-500), B.new(-3)), -1)
		t.eq(B.cmp(B.fromParts(1, 10), B.fromParts(9, 9)), 1)
		t.eq(B.cmp(B.new(7), B.new(7)), 0)
	end,
	pow_and_sqrt = function(t)
		local p = B.powN(42, 20)
		t.near(B.log10(p), 20 * math.log10(42), 1e-9)
		t.near(B.toNumber(B.sqrt(B.new(1e10))), 1e5, 1e-3)
		t.eq(B.powN(3.33, 0).m, 1)
	end,
	round_cents = function(t)
		t.near(B.toNumber(B.roundCents(B.new(1.905))), 1.91, 1e-9)
		t.near(B.toNumber(B.roundCents(B.new(0.004))), 0, 1e-12)
	end,
	sanitize_rejects_bad = function(t)
		t.eq(B.sanitize({ m = 0 / 0, e = 1 }), nil)
		t.eq(B.sanitize({ m = 1, e = math.huge }), nil)
		t.eq(B.sanitize("5"), nil)
		t.ok(B.sanitize({ m = 25, e = 0 }).e == 1, "renormalises")
	end,
	repeated_adds_stay_exact_in_cents = function(t)
		local a = B.zero
		for _ = 1, 1000 do
			a = B.roundCents(B.add(a, B.new(0.01)))
		end
		t.near(B.toNumber(a), 10, 1e-9)
	end,
}
