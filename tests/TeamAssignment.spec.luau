local TA = require("../src/shared/Logic/TeamAssignment")

local function parties(sizes)
	local out = {}
	for i, s in sizes do
		table.insert(out, { Id = string.format("p%02d", i), Size = s })
	end
	return out
end

local function checkPacking(t, pk, expectTotal)
	t.ok(pk, "packing expected")
	t.eq(#pk.Teams, 4, "team count")
	local total, lo, hi = 0, math.huge, 0
	for i = 1, 4 do
		t.ok(pk.Sizes[i] >= 1, "team non-empty")
		t.ok(pk.Sizes[i] <= 4, "team cap")
		total += pk.Sizes[i]
		lo = math.min(lo, pk.Sizes[i])
		hi = math.max(hi, pk.Sizes[i])
	end
	t.eq(total, expectTotal, "total players")
	return hi - lo
end

return {
	eight_solos_even = function(t)
		local pk = TA.Pack(parties({ 1, 1, 1, 1, 1, 1, 1, 1 }), 4, 4)
		t.eq(checkPacking(t, pk, 8), 0, "spread")
	end,
	sixteen_solos_even = function(t)
		local s = {}
		for i = 1, 16 do
			s[i] = 1
		end
		local pk = TA.Pack(parties(s), 4, 4)
		t.eq(checkPacking(t, pk, 16), 0, "spread")
	end,
	four_parties_of_four = function(t)
		local pk = TA.Pack(parties({ 4, 4, 4, 4 }), 4, 4)
		t.eq(checkPacking(t, pk, 16), 0, "spread")
	end,
	mixed_parties_kept_together = function(t)
		local ps = parties({ 3, 2, 2, 1, 1, 1, 3, 2, 1 })
		local pk = TA.Pack(ps, 4, 4)
		checkPacking(t, pk, 16)
		-- every party appears exactly once
		local seen = {}
		for _, team in pk.Teams do
			for _, p in team do
				t.no(seen[p.Id], "party duplicated")
				seen[p.Id] = true
			end
		end
		t.eq(#ps, (function()
			local n = 0
			for _ in seen do
				n += 1
			end
			return n
		end)(), "all parties placed")
	end,
	impossible_two_fours = function(t)
		t.eq(TA.Pack(parties({ 4, 4 }), 4, 4), nil, "only two parties cannot fill four teams")
	end,
	impossible_five_threes = function(t)
		t.eq(TA.Pack(parties({ 3, 3, 3, 3, 3 }), 4, 4), nil, "5 x 3 cannot fit 4 teams of 4")
	end,
	select_waits_when_impossible = function(t)
		-- 4+4 = 8 players but only two parties: keep matchmaking.
		t.eq(TA.Select(parties({ 4, 4 }), 4, 4, 8), nil, "no match")
	end,
	select_below_min = function(t)
		t.eq(TA.Select(parties({ 1, 1, 1, 1, 1, 1, 1 }), 4, 4, 8), nil, "7 players < min 8")
	end,
	select_skips_blocking_party = function(t)
		-- 3,3,3,3 fill 12; the fifth 3 cannot fit, the solos can.
		local q = parties({ 3, 3, 3, 3, 3, 1, 1, 1, 1 })
		local pk = TA.Select(q, 4, 4, 8)
		checkPacking(t, pk, 16)
		local used = {}
		for _, team in pk.Teams do
			for _, p in team do
				used[p.Id] = true
			end
		end
		t.ok(used.p01 and used.p02 and used.p03 and used.p04, "oldest parties included")
		t.no(used.p05, "blocking party left in queue")
	end,
	select_prefers_oldest = function(t)
		local q = parties({ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 })
		local pk = TA.Select(q, 4, 4, 8)
		checkPacking(t, pk, 16)
		local used = {}
		for _, team in pk.Teams do
			for _, p in team do
				used[p.Id] = true
			end
		end
		for i = 1, 16 do
			t.ok(used[string.format("p%02d", i)], "oldest 16 selected")
		end
	end,
	select_uneven_nine = function(t)
		local pk = TA.Select(parties({ 2, 2, 2, 2, 1 }), 4, 4, 8)
		t.eq(checkPacking(t, pk, 9), 1, "spread 1 for 9 players")
	end,
	rebalance_after_leaver = function(t)
		-- team 4's only party disconnected; parties from other teams move over.
		local teams = { parties({ 1, 1 }), parties({ 2 }), parties({ 1, 1, 1 }), { { Id = "gone", Size = 0 } } }
		-- give unique ids
		local n = 0
		for _, list in teams do
			for _, p in list do
				n += 1
				p.Id = "x" .. n
			end
		end
		local out = TA.Rebalance(teams, 4)
		for i = 1, 4 do
			t.ok(#out[i] >= 1, "team " .. i .. " refilled")
		end
	end,
	large_queue_performance = function(t)
		local s = {}
		for i = 1, 60 do
			s[i] = (i % 4) + 1
		end
		local t0 = os.clock()
		local pk = TA.Select(parties(s), 4, 4, 8)
		t.ok(pk, "match from large queue")
		t.ok(os.clock() - t0 < 2, "select under 2s")
	end,
}
