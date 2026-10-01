-- MemoryStore + SaveGuard rules. These are offline adapter tests, not Roblox DataStore validation.
local MemoryStore = require("../src/server/Persistence/MemoryStore")

local now = 0
local function clock()
	return now
end
local function template()
	return { version = 1, cash = 0 }
end

return {
	new_player_gets_template = function(t)
		local s = MemoryStore.new(template, clock)
		local r = s:Load("u1", "A")
		t.ok(r.ok and r.isNew, "fresh key is new")
		t.eq(r.handle.data.cash, 0)
	end,

	failed_load_returns_no_profile = function(t)
		local s = MemoryStore.new(template, clock)
		local r = s:Load("u1", "A")
		r.handle.data.cash = 500
		s:Release(r.handle)
		s.failLoads = 1
		local bad = s:Load("u1", "B")
		t.no(bad.ok, "load fails")
		t.eq(bad.handle, nil, "no default profile handed out")
		t.eq(s:Peek("u1").cash, 500, "stored progress untouched")
		local good = s:Load("u1", "B")
		t.eq(good.handle.data.cash, 500, "retry loads real data")
	end,

	conflicting_session_is_refused = function(t)
		local s = MemoryStore.new(template, clock)
		local a = s:Load("u1", "A")
		a.handle.data.cash = 42
		s:Save(a.handle)
		local b = s:Load("u1", "B")
		t.no(b.ok, "second server refused while A holds the lock")
		t.eq(b.reason, "locked")
		t.eq(s:Peek("u1").cash, 42)
	end,

	stale_lock_stolen_after_timeout_keeps_last_save = function(t)
		now = 0
		local s = MemoryStore.new(template, clock)
		s.stealAfter = 30
		local a = s:Load("u1", "A")
		a.handle.data.cash = 7
		s:Save(a.handle)
		now = 100 -- server A crashed without releasing
		local b = s:Load("u1", "B")
		t.ok(b.ok, "stale lock stolen")
		t.eq(b.handle.data.cash, 7, "last saved progress kept")
		a.handle.data.cash = 999
		local ok = s:Save(a.handle)
		t.no(ok, "old session can no longer write")
		t.eq(s:Peek("u1").cash, 7)
	end,

	interrupted_save_keeps_last_good_copy_and_retries = function(t)
		local s = MemoryStore.new(template, clock)
		local a = s:Load("u1", "A")
		a.handle.data.cash = 10
		s:Save(a.handle)
		a.handle.data.cash = 20
		s.failSaves = 1
		local ok = s:Save(a.handle)
		t.no(ok, "save interrupted")
		t.eq(s:Peek("u1").cash, 10, "last good copy intact")
		ok = s:Save(a.handle)
		t.ok(ok, "retry succeeds")
		t.eq(s:Peek("u1").cash, 20)
	end,

	release_unlocks_and_reconnect_restores = function(t)
		local s = MemoryStore.new(template, clock)
		local a = s:Load("u1", "A")
		a.handle.data.cash = 33
		s:Release(a.handle)
		t.no(a.handle.active)
		local again = s:Load("u1", "C")
		t.ok(again.ok and not again.isNew)
		t.eq(again.handle.data.cash, 33)
	end,

	stored_copy_is_isolated_from_live_table = function(t)
		local s = MemoryStore.new(template, clock)
		local a = s:Load("u1", "A")
		a.handle.data.cash = 1
		s:Save(a.handle)
		a.handle.data.cash = 2 -- not saved yet
		t.eq(s:Peek("u1").cash, 1)
	end,
}
