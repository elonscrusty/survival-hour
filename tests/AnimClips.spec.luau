local A = require("../src/shared/Logic/AnimClips")

local function player(over)
	local s = { Action = nil, Item = "Fists", Held = "Fists", Heavy = false, Elapsed = 0, Blocking = false, Drawing = false, DrawAge = 0 }
	for k, v in over or {} do
		s[k] = v
	end
	return s
end

local function animal(over)
	local s = { Species = "Wolf", Tele = nil, TeleAge = 99, Speed = 0 }
	for k, v in over or {} do
		s[k] = v
	end
	return s
end

return {
	idle_player_has_no_clip = function(t)
		t.eq(#A.Player(player()).Clips, 0)
	end,
	attacks_pick_by_item_and_expire = function(t)
		t.eq(A.Player(player({ Action = "Attack", Elapsed = 0.1 })).Clips[1], "SwingLight")
		t.eq(A.Player(player({ Action = "Attack", Item = "StoneAxe", Elapsed = 0.1 })).Clips[1], "SwingHeavy")
		t.eq(A.Player(player({ Action = "Attack", Item = "Spear", Elapsed = 0.1 })).Clips[1], "SpearThrust")
		t.ok(A.Player(player({ Action = "Attack", Elapsed = 0.1 })).OneShot)
		t.eq(#A.Player(player({ Action = "Attack", Elapsed = 1 })).Clips, 0, "swing over")
		t.eq(#A.Player(player({ Action = "Attack", Item = "Bow", Elapsed = 0.1 })).Clips, 0, "bow release stays procedural")
	end,
	guard_and_draw_win_over_actions = function(t)
		t.eq(A.Player(player({ Action = "Chop", Blocking = true })).Clips[1], "Block")
		t.eq(A.Player(player({ Held = "Bow", Drawing = true, DrawAge = 0.2 })).Clips[1], "BowDraw")
		t.eq(A.Player(player({ Held = "Bow", Drawing = true, DrawAge = 2 })).Clips[1], "BowHold")
		t.eq(A.Player(player({ Held = "Crossbow", Drawing = true })).Clips[1], "CrossbowAim")
	end,
	channels_emotes_and_poses = function(t)
		local breach = A.Player(player({ Action = "Breach" }))
		t.eq(breach.Clips[1], "Breach")
		t.eq(breach.Clips[2], "Chop", "falls back to Chop")
		t.eq(A.Player(player({ Action = "Steal" })).Clips[1], "Search")
		t.eq(A.Player(player({ Action = "Eat", Elapsed = 0.5 })).Clips[1], "Eat")
		t.eq(#A.Player(player({ Action = "Eat", Elapsed = 2 })).Clips, 0)
		t.eq(A.Player(player({ Action = "Emote", Item = "EmoteCampfire", Elapsed = 1 })).Clips[1], "EmoteWarmHands")
		t.eq(A.Player(player({ Action = "Victory", Item = "PoseThrone", Elapsed = 3 })).Clips[1], "VictoryThrone")
	end,
	every_mapped_clip_is_listed = function(t)
		local known = {}
		for _, n in A.PlayerClips do
			known[n] = true
		end
		for _, n in A.AnimalClips do
			known[n] = true
		end
		local states = {
			player({ Action = "Attack", Elapsed = 0.1 }), player({ Action = "Attack", Heavy = true, Elapsed = 0.1 }),
			player({ Action = "Attack", Item = "Spear", Elapsed = 0.1 }), player({ Blocking = true }),
			player({ Held = "Bow", Drawing = true }), player({ Held = "Bow", Drawing = true, DrawAge = 5 }), player({ Held = "Crossbow", Drawing = true }),
		}
		for _, a in { "Chop", "Breach", "Mine", "Gather", "Fill", "Pour", "Bandage", "Craft", "Build", "Feed", "Eat", "Open", "Steal" } do
			table.insert(states, player({ Action = a }))
		end
		for _, e in { "EmoteWave", "EmoteFlex", "EmoteCampfire" } do
			table.insert(states, player({ Action = "Emote", Item = e, Elapsed = 1 }))
		end
		for _, e in { "PoseTorch", "PoseAxe", "PoseThrone" } do
			table.insert(states, player({ Action = "Victory", Item = e, Elapsed = 1 }))
		end
		for _, s in states do
			for _, n in A.Player(s).Clips do
				t.ok(known[n], "unlisted player clip " .. n)
			end
		end
	end,
	animals_by_species_and_state = function(t)
		t.eq(#A.Animal(animal()).Clips, 0, "idle stays procedural")
		t.eq(A.Animal(animal({ Speed = 4 })).Clips[1], "WolfWalk")
		t.eq(A.Animal(animal({ Speed = 14 })).Clips[1], "WolfRun")
		t.eq(A.Animal(animal({ Species = "Deer", Speed = 14 })).Clips[1], "QuadRun")
		t.eq(A.Animal(animal({ Species = "Bear", Tele = "Roar", TeleAge = 0.3 })).Clips[1], "BearRoar")
		local dead = A.Animal(animal({ Species = "Bear", Tele = "Dead", TeleAge = 3 }))
		t.eq(dead.Clips[1], "BearDeath")
		t.ok(dead.Hold)
		t.eq(#A.Animal(animal({ Species = "Bat", Speed = 10 })).Clips, 0, "bats stay procedural")
		t.eq(A.Animal(animal({ Tele = "Strike", TeleAge = 0.1, Speed = 4 })).Clips[1], "WolfWalk")
	end,
	gait_has_hysteresis = function(t)
		t.eq(A.Animal(animal({ Speed = 7.5 })).Clips[1], "WolfWalk", "not fast enough to start running")
		t.eq(A.Animal(animal({ Speed = 7.5, Gait = "Run" })).Clips[1], "WolfRun", "keeps running just under the threshold")
		t.eq(A.Animal(animal({ Speed = 6, Gait = "Run" })).Clips[1], "WolfWalk")
		t.eq(A.Animal(animal({ Speed = 0.8, Gait = "Walk" })).Clips[1], "WolfWalk", "keeps walking while slowing")
		t.eq(#A.Animal(animal({ Speed = 0.8 })).Clips, 0)
	end,
	first_uploaded_candidate_wins = function(t)
		local p = A.Player(player({ Action = "Breach" }))
		t.eq(A.First(p, {}), nil)
		t.eq(A.First(p, { Chop = 11 }), "Chop")
		t.eq(A.First(p, { Chop = 11, Breach = 22 }), "Breach")
		t.eq(A.First(p, { Breach = 0 }), nil, "0 is not an id")
	end,
}
