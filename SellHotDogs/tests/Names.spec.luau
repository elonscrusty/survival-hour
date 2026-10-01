local Names = require("../src/shared/Logic/Names")

return {
	accepts_normal = function(t)
		t.eq(Names.clean("  Carter's   Dogs! "), "Carter's Dogs!")
	end,
	rejects_short_and_long = function(t)
		t.eq(Names.clean("ab"), nil)
		t.eq(Names.clean(string.rep("a", Names.MAX + 1)), nil)
		t.eq(Names.clean(string.rep("a", 500)), nil)
		t.eq(Names.clean(string.rep("a", Names.MAX)), string.rep("a", Names.MAX))
	end,
	rejects_odd_characters = function(t)
		t.eq(Names.clean("<b>hi</b>"), nil)
		t.eq(Names.clean("dogs\n\nnew"), "dogsnew")
		t.eq(Names.clean("emoji \u{1F32D}"), nil)
		t.eq(Names.clean(42), nil)
	end,
	default_fits = function(t)
		local n = Names.default("AVeryLongDisplayNameIndeed")
		t.ok(#n <= Names.MAX, n)
		t.ok(Names.clean(n) ~= nil)
	end,
}
