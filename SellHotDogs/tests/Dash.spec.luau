local B = require("../src/shared/Logic/BigNum")
local Dash = require("../src/shared/Logic/Dash")

local function rng(seed)
	local s = seed
	return function()
		s = (s * 1103515245 + 12345) % 2147483648
		return s / 2147483648
	end
end

return {
	invalid_pick_rejected = function(t)
		t.eq(Dash.new(0, B.new(1), rng(1)), nil)
		t.eq(Dash.new(5, B.new(1), rng(1)), nil)
		t.eq(Dash.new(1.5, B.new(1), rng(1)), nil)
	end,
	bet_fractions = function(t)
		t.near(B.toNumber(Dash.betAmount(B.new(100), 2)), 25, 1e-9)
		t.eq(Dash.betAmount(B.new(100), 9), nil)
	end,
	race_finishes_with_one_winner = function(t)
		local r = Dash.new(2, B.new(10), rng(7))
		local w
		for _ = 1, 400 do
			w = Dash.step(r, 0.05, rng(r.t * 1000 // 1))
			if w then
				break
			end
		end
		t.ok(w and w >= 1 and w <= 4)
		t.ok(r.t < 15, "finishes in time")
	end,
	cheer_rate_capped = function(t)
		local r = Dash.new(1, B.new(10), rng(3))
		local counted = 0
		for _ = 1, 50 do
			if Dash.cheer(r) then
				counted += 1
			end
		end
		t.eq(counted, Dash.MAX_CHEERS_PER_SEC)
	end,
	cheering_improves_odds = function(t)
		local function wins(cheer)
			local w = 0
			for seed = 1, 300 do
				local g = rng(seed)
				local r = Dash.new(1, B.new(1), g)
				while not r.winner do
					if cheer then
						for _ = 1, 6 do
							Dash.cheer(r)
						end
					end
					Dash.step(r, 0.1, g)
				end
				if r.winner == 1 then
					w += 1
				end
			end
			return w
		end
		local plain, cheered = wins(false), wins(true)
		t.ok(cheered > plain, string.format("cheer %d vs plain %d", cheered, plain))
		t.ok(cheered < 300, "never a guaranteed win")
	end,
	payout_only_on_win = function(t)
		local r = Dash.new(1, B.new(10), rng(1))
		r.winner = 2
		t.eq(Dash.payout(r).m, 0)
		r.winner = 1
		t.near(B.toNumber(Dash.payout(r)), 35, 1e-9)
	end,
}
