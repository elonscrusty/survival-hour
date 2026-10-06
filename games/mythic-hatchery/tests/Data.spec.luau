-- Catalogue integrity: eggs, pets and areas reference each other correctly.
local Pets = require("../src/shared/Pets")
local Eggs = require("../src/shared/Eggs")
local Areas = require("../src/shared/Areas")
local Config = require("../src/shared/Config")

return {
	["every egg's odds sum to 100 and name real pets"] = function(t)
		for _, e in Eggs.List do
			local sum = 0
			for _, o in e.Odds do
				t.ok(Pets.ById[o.Pet], e.Id .. " names unknown pet " .. o.Pet)
				t.eq(Pets.ById[o.Pet].Egg, e.Id, o.Pet .. " egg field")
				sum += o.Weight
			end
			t.ok(math.abs(sum - 100) < 1e-6, e.Id .. " odds sum " .. sum)
		end
	end,
	["every egg-sourced pet is in its egg"] = function(t)
		for _, p in Pets.List do
			t.ok(table.find(Config.Rarities, p.Rarity), p.Id .. " rarity")
			t.ok(Areas.ById[p.Area], p.Id .. " area")
			if p.Egg then
				local found = false
				for _, o in Eggs.ById[p.Egg].Odds do
					found = found or o.Pet == p.Id
				end
				t.ok(found, p.Id .. " missing from " .. p.Egg)
			else
				t.eq(p.Source, "Expedition", p.Id .. " source")
			end
		end
	end,
	["areas reference real eggs and expedition pets"] = function(t)
		for i, a in Areas.List do
			t.eq(a.Index, i, a.Id .. " index")
			t.ok(Eggs.ById[a.Egg], a.Id .. " egg")
			local ep = Pets.ById[a.ExpeditionPet]
			t.ok(ep and ep.Source == "Expedition" and ep.Area == a.Id, a.Id .. " expedition pet")
			if i > 1 then
				t.ok(a.GateCost > Areas.List[i - 1].GateCost, a.Id .. " gate cost grows")
			end
		end
	end,
}
