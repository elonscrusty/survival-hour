local TrackLayout = require("../src/shared/Logic/TrackLayout")
local Tracks = require("../src/shared/Tracks")
local Config = require("../src/shared/Config")
local RaceRules = require("../src/shared/Logic/RaceRules")

local GRAVITY = 196.2

return {
	length_is_sum = function(t)
		for _, tr in Tracks.List do
			local sum = 0
			for _, s in tr.Segments do
				sum += s.L
			end
			t.eq(TrackLayout.Build(tr.Segments).Length, sum)
		end
	end,
	checkpoints_increase_and_skip_gaps = function(t)
		for _, tr in Tracks.List do
			local l = TrackLayout.Build(tr.Segments)
			for i = 2, #l.Checkpoints do
				t.ok(l.Checkpoints[i].X > l.Checkpoints[i - 1].X)
				t.ok(TrackLayout.FloorAt(l, l.Checkpoints[i].X + 1) ~= nil, tr.Id .. " checkpoint " .. i .. " has floor after it")
			end
		end
	end,
	ramps_and_steps_change_height = function(t)
		local l = TrackLayout.Build({ { Kind = "Straight", L = 10 }, { Kind = "Ramp", L = 20, Rise = 10 }, { Kind = "Steps", L = 30, Count = 3, Rise = 2 } })
		t.near(TrackLayout.FloorAt(l, 5) :: number, 0)
		t.near(TrackLayout.FloorAt(l, 20) :: number, 5)
		t.near(TrackLayout.FloorAt(l, 35) :: number, 12)
		t.near(TrackLayout.FloorAt(l, 59) :: number, 16)
		t.eq(l.MaxY, 16)
	end,
	gaps_have_no_floor = function(t)
		local l = TrackLayout.Build({ { Kind = "Straight", L = 10 }, { Kind = "Gap", L = 8 }, { Kind = "Straight", L = 10 } })
		t.eq(TrackLayout.FloorAt(l, 14), nil)
		t.eq(#l.Checkpoints, 2, "start + after first straight only")
	end,
	zones = function(t)
		local l = TrackLayout.Build({ { Kind = "Boost", L = 10 }, { Kind = "Mud", L = 10 }, { Kind = "Straight", L = 10 } })
		t.eq(TrackLayout.ZoneAt(l, 5), "Boost")
		t.eq(TrackLayout.ZoneAt(l, 15), "Mud")
		t.eq(TrackLayout.ZoneAt(l, 25), nil)
	end,
	checkpoint_at = function(t)
		local l = TrackLayout.Build(Tracks.List[1].Segments)
		t.eq(TrackLayout.CheckpointAt(l, -5), 1)
		t.eq(TrackLayout.CheckpointAt(l, l.Length + 10), #l.Checkpoints)
	end,
	first_track_doable_untrained = function(t)
		-- An untrained Pup (speed 20, jump 46) must be able to clear every gap and
		-- hurdle on the first track so new players can finish a race.
		local R = Config.Ride
		local airtime = 2 * R.BaseJump / GRAVITY
		local reach = airtime * R.BaseSpeed * R.DashBoost
		local height = R.BaseJump ^ 2 / (2 * GRAVITY)
		for _, s in Tracks.List[1].Segments do
			if s.Kind == "Gap" then
				t.ok(reach > s.L, "gap " .. s.L .. " vs reach " .. reach)
			elseif s.Kind == "Hurdles" then
				t.ok(height > (s.H or 0) + 0.5, "hurdle " .. tostring(s.H))
			elseif s.Kind == "Steps" then
				t.ok(height > (s.Rise or 0) + 0.5)
			end
		end
	end,
	max_pet_clears_everything = function(t)
		local R = Config.Ride
		local speed = (R.BaseSpeed + (Config.Stats.MaxLevel - 1) * R.SpeedPerLevel)
		local jump = (R.BaseJump + (Config.Stats.MaxLevel - 1) * R.JumpPerLevel)
		local reach = 2 * jump / GRAVITY * speed
		local height = jump ^ 2 / (2 * GRAVITY)
		for _, tr in Tracks.List do
			for _, s in tr.Segments do
				if s.Kind == "Gap" then
					t.ok(reach > s.L * 1.3, tr.Id .. " gap " .. s.L)
				elseif s.Kind == "Hurdles" then
					t.ok(height > (s.H or 0) + 1, tr.Id .. " hurdle")
				elseif s.Kind == "Steps" then
					t.ok(height > (s.Rise or 0) + 1, tr.Id .. " step")
				end
			end
		end
	end,
	medal_times_reasonable = function(t)
		for _, tr in Tracks.List do
			local l = TrackLayout.Build(tr.Segments)
			local m = RaceRules.MedalTimes(l.Length)
			t.ok(m.Bronze < Config.Race.TimeLimit * 0.6, tr.Id .. " bronze fits in time limit")
		end
	end,
}
