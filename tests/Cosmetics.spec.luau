local Cosmetics = require("../src/shared/Cosmetics")
local Classes = require("../src/shared/Classes")
local Perks = require("../src/shared/Perks")
local Products = require("../src/shared/Products")

-- Effect keys PowerupService understands (keep in sync).
local KNOWN_EFFECTS = {
	StaminaRegen = true, ToolWear = true, AxeSpeed = true, AxeWear = true, PickSpeed = true, PickWear = true, CaveSight = true,
	DrawSpeed = true, ExtraHide = true, TrackWildlife = true, QuietBrush = true, SearchSpeed = true, BonusSlots = true,
	ContainerSense = true, ExtraLoot = true, BreachSpeed = true, QuietBreach = true, BreachWear = true, BloodTrails = true,
	HurtCues = true, StaminaMax = true, HealSpeed = true, SprintSpeed = true, FireFuel = true, CraftSpeed = true,
	NightSight = true, WildlifeDamage = true, SecondWind = true,
}

return {
	prices_within_bands = function(t)
		for _, d in Cosmetics.List do
			local band = Cosmetics.Bands[d.Rarity]
			t.ok(band ~= nil, d.Id .. " rarity")
			if d.Price > 0 then
				t.ok(d.Price >= band[1] and d.Price <= band[2], d.Id .. " price " .. d.Price .. " in " .. d.Rarity .. " band")
			else
				t.ok(d.Level ~= nil or d.Id ~= "", d.Id .. " unsold item")
			end
			t.ok(table.find(Cosmetics.Types, d.Type) ~= nil, d.Id .. " type")
		end
	end,
	every_type_has_items = function(t)
		for _, typ in Cosmetics.Types do
			local n = 0
			for _, d in Cosmetics.List do
				if d.Type == typ and d.Price > 0 then
					n += 1
				end
			end
			t.ok(n > 0, typ .. " has sold items")
		end
	end,
	unique_ids = function(t)
		local seen = {}
		for _, d in Cosmetics.List do
			t.no(seen[d.Id], "dup " .. d.Id)
			seen[d.Id] = true
		end
	end,
	bundles_reference_real_items = function(t)
		for name, list in Cosmetics.Bundles do
			for _, id in list do
				t.ok(Cosmetics.ById[id] ~= nil, name .. " -> " .. id)
			end
		end
	end,
	class_and_perk_prices = function(t)
		local expect = { Survivor = 0, Lumberjack = 40, Miner = 50, Hunter = 75, Scavenger = 100, Raider = 150, Tracker = 200 }
		for id, price in expect do
			t.eq(Classes.ById[id].Price, price, id)
		end
		t.eq(#Perks.List, 10)
		for _, list in { Classes.List, Perks.List } do
			for _, d in list :: { any } do
				for k, v in d.Effects do
					t.ok(KNOWN_EFFECTS[k], d.Id .. " effect " .. k)
					t.ok(math.abs(v) <= 40, d.Id .. " effect size")
				end
				t.no(d.Effects.Damage or d.Effects.Health, d.Id .. " no raw power")
			end
		end
	end,
	robux_only_coins_and_bundles = function(t)
		local onSale = 0
		for _, p in Products.List do
			if Products.OnSale(p.Key) then
				onSale += 1
				t.ok(p.Kind == "Coins" or p.Kind == "Bundle", p.Key .. " on sale must be cosmetic-only")
				if p.Kind == "Bundle" then
					t.ok(Cosmetics.Bundles[p.Bundle or ""] ~= nil, p.Key .. " bundle exists")
				end
			end
		end
		t.ok(onSale >= 4, "coin packs on sale")
	end,
}
