local H = require("./Helpers")
local Migrations = require("../src/shared/Logic/Migrations")
local State = require("../src/shared/Logic/State")

return {
	current_version_passes_through = function(t)
		local s = State.New(H.T0)
		s.cash = 123
		local ok, d = Migrations.Migrate(s, H.T0)
		t.ok(ok)
		t.eq(d.cash, 123)
		t.eq(d.version, Migrations.CURRENT)
	end,

	v0_record_is_upgraded = function(t)
		-- SYNTHETIC v0 fixture (shape of pre-release saves)
		local old = { cash = 500, stock = 40, population = 30, egg = 2, gold = 9 }
		local ok, d = Migrations.Migrate(old, H.T0)
		t.ok(ok)
		t.eq(d.version, Migrations.CURRENT)
		t.eq(d.warehouse, 40, "stock renamed")
		t.eq(d.stock, nil)
		t.eq(d.cash, 500)
		t.eq(d.egg, 2)
		t.eq(#d.housing, 4, "missing lists filled")
		t.eq(d.housing[1].tier, 1)
		t.ok(d.settings.music ~= nil, "nested defaults filled")
	end,

	missing_nested_fields_filled_without_overwriting = function(t)
		local s = State.New(H.T0)
		s.settings = { music = false } -- older save without newer settings
		local ok, d = Migrations.Migrate(s, H.T0)
		t.ok(ok)
		t.eq(d.settings.music, false, "kept")
		t.eq(d.settings.flock, "normal", "added")
	end,

	newer_versions_are_refused = function(t)
		local s = State.New(H.T0)
		s.version = Migrations.CURRENT + 1
		local ok, why = Migrations.Migrate(s, H.T0)
		t.no(ok)
		t.eq(why, "newer")
	end,

	corrupt_records_are_refused = function(t)
		t.no((Migrations.Migrate("hello", H.T0)))
		t.no((Migrations.Migrate({ version = -3 }, H.T0)))
		t.no((Migrations.Migrate({ version = 1.5 }, H.T0)))
	end,

	impossible_numbers_repaired = function(t)
		local s = State.New(H.T0)
		s.cash = 0 / 0
		s.gold = -50
		s.population = math.huge
		s.housing[2].tier = 99
		s.housing[1].eggs = -4
		s.egg = 77
		s.common.feed = 0 / 0
		s.boosts.active = { { id = "earn3", endsAt = 0 / 0 }, "junk", { id = "lay2", endsAt = H.T0 + 5 } }
		local ok, d = Migrations.Migrate(s, H.T0)
		t.ok(ok)
		t.eq(d.cash, 0)
		t.eq(d.gold, 0)
		t.eq(d.population, 1e15)
		t.eq(d.housing[2].tier, 10)
		t.eq(d.housing[1].eggs, 0)
		t.eq(d.egg, 10)
		t.eq(d.common.feed, 0)
		t.eq(#d.boosts.active, 1)
	end,
}
