-- Catalogue integrity: eggs, species, elements, areas and shop data reference each other correctly.
local Species = require("../src/shared/Species")
local Elements = require("../src/shared/Elements")
local Eggs = require("../src/shared/Eggs")
local Areas = require("../src/shared/Areas")
local Potions = require("../src/shared/Potions")
local Cosmetics = require("../src/shared/Cosmetics")
local Config = require("../src/shared/Config")
local Products = require("../src/shared/Products")
local Gameplay = require("../src/shared/Gameplay")

local function sum(t)
	local s = 0
	for _, w in t do
		s += w.Weight
	end
	return s
end

return {
	["egg weight tables sum to 100 and name real things"] = function(t)
		for _, e in Eggs.List do
			t.ok(math.abs(sum(e.Species) - 100) < 1e-6, e.Id .. " species sum")
			t.ok(math.abs(sum(e.Rarity) - 100) < 1e-6, e.Id .. " rarity sum")
			for _, w in e.Species do
				local s = Species.ById[w.Id]
				t.ok(s and not s.Hybrid, e.Id .. " species " .. w.Id)
			end
			for _, w in e.Rarity do
				t.ok(table.find(Config.Rarities, w.Id), e.Id .. " rarity " .. w.Id)
			end
			if e.Element then
				t.ok(math.abs(sum(e.Element) - 100) < 1e-6, e.Id .. " element sum")
				for _, w in e.Element do
					t.ok(Elements.ById[w.Id], e.Id .. " element " .. w.Id)
				end
			else
				t.ok(Areas.ById[e.Area].Element ~= "", e.Id .. " needs an element table or an elemental island")
			end
			t.ok(Areas.ById[e.Area], e.Id .. " area")
			t.ok(e.IncubateSeconds > 0, e.Id .. " incubation")
		end
	end,
	["limited eggs have a window and edition"] = function(t)
		for _, e in Eggs.List do
			if e.Kind == "Limited" then
				t.ok(e.StartAt and e.EndAt and e.EndAt > e.StartAt and e.Edition, e.Id)
				t.no(Eggs.OnSale(e, e.StartAt - 1), e.Id .. " before")
				t.ok(Eggs.OnSale(e, e.StartAt), e.Id .. " during")
				t.no(Eggs.OnSale(e, e.EndAt), e.Id .. " after")
			end
		end
		t.no(Eggs.OnSale(Eggs.ById.FusedEgg, 0), "fused never on sale")
	end,
	["areas reference real eggs and elements"] = function(t)
		for i, a in Areas.List do
			t.eq(a.Index, i, a.Id .. " index")
			t.eq(Eggs.ById[a.Egg].Area, a.Id, a.Id .. " egg")
			t.ok(a.Element == "" or Elements.ById[a.Element], a.Id .. " element")
			if i > 1 then
				t.ok(a.GateCost > Areas.List[i - 1].GateCost, a.Id .. " gate cost grows")
			end
		end
	end,
	["elements form one beats-cycle"] = function(t)
		local seen = {}
		for _, e in Elements.List do
			t.ok(Elements.ById[e.Beats] and e.Beats ~= e.Id, e.Id .. " beats")
			t.no(seen[e.Beats], e.Beats .. " beaten twice")
			seen[e.Beats] = true
			t.eq(Areas.ById[e.Area].Element, e.Id, e.Id .. " home island")
		end
	end,
	["hybrids have two different base parents and resolve both ways"] = function(t)
		for _, s in Species.List do
			if s.Hybrid then
				local p = s.Parents
				t.ok(p and #p == 2 and p[1] ~= p[2], s.Id)
				t.ok(not Species.ById[p[1]].Hybrid and not Species.ById[p[2]].Hybrid, s.Id .. " parents base")
				t.eq(Species.Hybrid(p[1], p[2]), s.Id)
				t.eq(Species.Hybrid(p[2], p[1]), s.Id)
			end
		end
		t.eq(Species.Hybrid("Dragon", "Dragon"), nil)
	end,
	["level gameplay and shop data are sane"] = function(t)
		t.eq(Gameplay.Battle.TeamSize, 3)
		t.ok(Gameplay.MaxLevel > 1)
		for _, quest in Config.QuestPool do
			t.no(quest.Kind == "Care" or quest.Kind == "Race" or quest.Kind == "Break", "removed task")
		end
		t.eq(Products.PassByKey.AutoFarm, nil)
		t.eq(Products.PassByKey.RingChampion, nil)
		t.eq(Config.Boosts.Growth2x.Name, "2x Battle XP")
		for _, p in Potions.List do
			t.ok(p.Gems > 0, p.Id)
		end
		for _, c in Cosmetics.List do
			t.ok(table.find(Cosmetics.Slots, c.Slot) and c.Coins > 0, c.Id)
		end
		for _, r in Config.Rarities do
			t.ok(Config.RarityPower[r], r)
		end
	end,
}
