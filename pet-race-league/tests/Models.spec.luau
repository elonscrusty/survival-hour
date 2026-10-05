local Models = require("../src/shared/Models")
local Pets = require("../src/shared/Pets")
local Eggs = require("../src/shared/Eggs")

-- Names the game code asks Assets for (WorldService, TrackBuilder).
local PROPS = { "Tree_Round", "Tree_Pine", "Tree_Blossom", "Bush", "Rock", "Flowers", "Fence", "Pedestal", "SpeedGate", "PortalArch", "RaceArch", "Pillar", "Cloud", "TrophyStatue", "LampPost" }

local function petName(id: string): string
	return "Pet_" .. string.gsub(id, " ", "")
end

return {
	every_pet_has_a_model = function(t)
		for _, s in Pets.List do
			t.ok(Models[petName(s.Id)] ~= nil, s.Id)
		end
	end,
	every_egg_has_a_model = function(t)
		for _, e in Eggs.List do
			t.ok(Models["Egg_" .. e.Id] ~= nil, e.Id)
		end
	end,
	every_prop_has_a_model = function(t)
		for _, n in PROPS do
			t.ok(Models[n] ~= nil, n)
		end
	end,
	sizes_and_pivots_sane = function(t)
		for name, e in Models do
			for i = 1, 3 do
				t.ok(e.Size[i] > 0, name .. " size")
				t.ok(math.abs(e.Offset[i]) <= e.Size[i] / 2 + 0.01, name .. " pivot inside its box")
			end
			-- pivot is at the bottom: the box starts at the pivot height
			t.ok(math.abs(e.Offset[2] + e.Size[2] / 2) < 0.2, name .. " pivot at the bottom")
		end
	end,
	pet_models_match_riding_maths = function(t)
		-- the rider stands at Legs + Body height; the mesh must be at least that tall
		-- and not wildly taller (ears/horns add a bit)
		for _, s in Pets.List do
			local e = Models[petName(s.Id)]
			local back = s.Legs + s.Body[2]
			t.ok(e.Size[2] >= back, s.Id .. " shorter than its back")
			t.ok(e.Size[2] <= back + s.Head * 2.2, s.Id .. " much taller than expected")
		end
	end,
	pillar_fits_lane = function(t)
		local Tracks = require("../src/shared/Tracks")
		t.near(Models.Pillar.Size[3], Tracks.Width * 0.6, 0.01)
	end,
}
