local Format = require("../src/shared/Format")

return {
	short_small_values = function(t)
		t.eq(Format.Short(0), "0")
		t.eq(Format.Short(999), "999")
		t.eq(Format.Short(1.5), "1.5")
	end,
	short_suffixes = function(t)
		t.eq(Format.Short(1000), "1K")
		t.eq(Format.Short(1234), "1.23K")
		t.eq(Format.Short(12345), "12.3K")
		t.eq(Format.Short(123456), "123K")
		t.eq(Format.Short(5.6e9), "5.6B")
		t.eq(Format.Short(999999.9), "999K", "truncates, never overstates")
		t.eq(Format.Short(1e15), "1Qa")
		t.eq(Format.Short(-2500), "-2.5K")
	end,
	short_huge_and_bad = function(t)
		t.eq(Format.Short(0 / 0), "0", "NaN")
		t.eq(Format.Short(math.huge), "∞")
		t.ok(string.find(Format.Short(1e305), "e") ~= nil, "scientific beyond the table")
		t.eq(Format.Short(1e33), "1Dc")
	end,
	commas_and_duration = function(t)
		t.eq(Format.Commas(1234567), "1,234,567")
		t.eq(Format.Commas(100), "100")
		t.eq(Format.Duration(5), "5s")
		t.eq(Format.Duration(65), "1m 05s")
		t.eq(Format.Duration(3725), "1h 02m")
		t.eq(Format.Duration(-3), "0s")
	end,
}
