-- Tutorial reveal / advance rules (Logic/Tutorial) as the HUD relies on them.
local Tutorial = require("../src/shared/Logic/Tutorial")
local Economy = require("../src/shared/Logic/Economy")
local State = require("../src/shared/Logic/State")
local Contract = require("../src/shared/Contract")

local function farm()
	local s = State.New(1000)
	return Economy.new(s, {}), s
end

return {
	text_for_every_step = function(t)
		t.eq(#Contract.Tutorial, Tutorial.Steps, "one text per step")
		for i = 1, Tutorial.Steps do
			t.ok(type(Contract.Tutorial[i].text) == "string" and #Contract.Tutorial[i].text > 0)
		end
	end,
	reveals_progressively = function(t)
		local r1 = Tutorial.Reveals(1, false)
		t.ok(r1.spawn, "spawn always visible")
		t.no(r1.counters)
		t.no(r1.nav)
		t.ok(Tutorial.Reveals(2, false).counters)
		t.no(Tutorial.Reveals(4, false).shipping)
		t.ok(Tutorial.Reveals(5, false).shipping)
		t.no(Tutorial.Reveals(6, false).housing)
		t.ok(Tutorial.Reveals(7, false).housing)
		t.no(Tutorial.Reveals(7, false).nav, "nav stays hidden until done")
		local done = Tutorial.Reveals(99, true)
		for _, key in { "spawn", "counters", "shipping", "housing", "nav", "workers", "eggs" } do
			t.ok(done[key], key .. " revealed when done")
		end
	end,
	reveals_monotonic = function(t)
		local keys = { "spawn", "counters", "shipping", "housing", "nav", "workers", "eggs" }
		local prev = Tutorial.Reveals(1, false)
		for step = 2, Tutorial.Steps + 1 do
			local cur = Tutorial.Reveals(step, step > Tutorial.Steps)
			for _, k in keys do
				t.ok(not prev[k] or cur[k], "nothing is hidden again at step " .. step .. " (" .. k .. ")")
			end
			prev = cur
		end
	end,
	spawning_advances_step_one = function(t)
		local f, s = farm()
		t.eq(s.tutorial.step, 1)
		for i = 1, 25 do
			f:Apply({ type = "spawn", seq = i }, 1000 + i)
		end
		t.ok(s.tutorial.step >= 2, "spawn step done after 20 chickens")
		t.no(s.tutorial.done)
	end,
	auto_spawn_gated_by_tutorial = function(t)
		local f, s = farm()
		local r = f:Apply({ type = "setAutoSpawn", value = true, seq = 1 }, 1001)
		t.eq(r.code, "tutorial")
		s.tutorial.done = true
		t.ok(f:Apply({ type = "setAutoSpawn", value = true, seq = 2 }, 1002).ok)
	end,
	returning_player_skips_ahead = function(t)
		local _, s = farm()
		s.population = 50
		s.stats.spawned = 50
		s.stats.collected = 10
		s.stats.deposited = 10
		s.stats.sold = 10
		s.vehicles[1].tier = 2
		s.cash = 600
		s.housing[1].tier = 2
		t.ok(Tutorial.Update(s))
		t.ok(s.tutorial.done, "every check already met")
		t.no(Tutorial.Update(s), "no change once done")
	end,
	stops_at_unmet_step = function(t)
		local _, s = farm()
		s.population = 30
		s.stats.collected = 5
		Tutorial.Update(s)
		t.eq(s.tutorial.step, 3, "waits on the deposit step")
	end,
}
