--!strict
-- Shop catalog: this game's OWN products. Robux IDs are deliberately empty (nil): live commerce is
-- NOT configured. Fill in `robuxId` with your own game pass / developer product IDs after you
-- create them on the Creator Dashboard (README "Setting up the shop"). Never reuse another game's IDs.
-- Pass roles mirror reference pass categories (docs/REFERENCE_RESEARCH.md section 10); names,
-- prices and effects are DESIGN VALUES.
--
-- kind = "pass" (one-time, permanent) | "product" (consumable) | "gold" (buy with Gold Eggs)
-- tab  = "Featured" | "Passes" | "Gold" | "Cash"

export type Product = {
	id: string,
	kind: string,
	tab: string,
	name: string,
	desc: string,
	icon: string,
	robux: number?, -- display price for Robux items
	robuxId: number?, -- YOUR game pass / developer product id (nil = not configured)
	goldPrice: number?, -- price in Gold Eggs for kind = "gold"
	grant: { gold: number?, cashMinutes: number?, boosts: { [string]: number }?, pass: string? },
	featured: boolean?,
}

local list: { Product } = {
	-- Passes (permanent)
	{ id = "vip", kind = "pass", tab = "Passes", name = "VIP", desc = "Use 5 boosts at once and get a VIP chat tag", icon = "crown", robux = 249, grant = { pass = "vip" }, featured = true },
	{ id = "x2cash", kind = "pass", tab = "Passes", name = "x2 Cash", desc = "Double cash from every sale", icon = "cash", robux = 249, grant = { pass = "x2cash" }, featured = true },
	{ id = "x2chickens", kind = "pass", tab = "Passes", name = "x2 Chickens", desc = "Every spawn gives twice the chickens", icon = "chick", robux = 199, grant = { pass = "x2chickens" } },
	{ id = "x2gold", kind = "pass", tab = "Passes", name = "x2 Gold Eggs", desc = "Double Gold Eggs from quests, gifts and rebirths", icon = "gold", robux = 199, grant = { pass = "x2gold" } },
	{ id = "x2offline", kind = "pass", tab = "Passes", name = "x2 Offline Earnings", desc = "Silos earn twice as much while you're away", icon = "silo", robux = 79, grant = { pass = "x2offline" } },
	{ id = "cheap_upgrades", kind = "pass", tab = "Passes", name = "Cheap Upgrades", desc = "Common upgrades cost 50% less", icon = "lab", robux = 299, grant = { pass = "cheap_upgrades" } },
	{ id = "perma_silos", kind = "pass", tab = "Passes", name = "10 Permanent Silos", desc = "10 silos that survive every rebirth", icon = "silo", robux = 249, grant = { pass = "perma_silos" } },
	{ id = "worker_slots", kind = "pass", tab = "Passes", name = "+2 Worker Slots", desc = "Hire two extra workers", icon = "worker", robux = 349, grant = { pass = "worker_slots" } },
	{ id = "x2housing", kind = "pass", tab = "Passes", name = "x2 Housing Capacity", desc = "Every house holds twice the chickens", icon = "house", robux = 349, grant = { pass = "x2housing" } },
	{ id = "x2shipping", kind = "pass", tab = "Passes", name = "x2 Shipping Speed", desc = "Vehicles finish trips twice as fast", icon = "truck", robux = 199, grant = { pass = "x2shipping" } },
	{ id = "x2workers", kind = "pass", tab = "Passes", name = "x2 Worker Capacity", desc = "Workers carry twice the eggs", icon = "worker", robux = 249, grant = { pass = "x2workers" } },
	-- Gold Egg packs (Robux)
	{ id = "gold_small", kind = "product", tab = "Gold", name = "Handful of Gold Eggs", desc = "50 Gold Eggs", icon = "gold", robux = 49, grant = { gold = 50 } },
	{ id = "gold_medium", kind = "product", tab = "Gold", name = "Basket of Gold Eggs", desc = "275 Gold Eggs", icon = "gold", robux = 199, grant = { gold = 275 }, featured = true },
	{ id = "gold_large", kind = "product", tab = "Gold", name = "Crate of Gold Eggs", desc = "800 Gold Eggs", icon = "gold", robux = 499, grant = { gold = 800 } },
	-- Cash packs (Robux): scale with your farm's steady cash rate
	{ id = "cash_small", kind = "product", tab = "Cash", name = "Stack of Cash", desc = "30 minutes of farm earnings", icon = "cash", robux = 29, grant = { cashMinutes = 30 } },
	{ id = "cash_medium", kind = "product", tab = "Cash", name = "Bag of Cash", desc = "3 hours of farm earnings", icon = "cash", robux = 99, grant = { cashMinutes = 180 } },
	{ id = "cash_large", kind = "product", tab = "Cash", name = "Vault of Cash", desc = "12 hours of farm earnings", icon = "cash", robux = 299, grant = { cashMinutes = 720 } },
	-- Boosts for Gold Eggs (the Boosts menu SHOP tab and the Featured tab)
	{ id = "buy_earn3", kind = "gold", tab = "Featured", name = "Cash x3 Boost", desc = "20 min of triple cash", icon = "cash", goldPrice = 20, grant = { boosts = { earn3 = 1 } } },
	{ id = "buy_lay2", kind = "gold", tab = "Featured", name = "Laying x2 Boost", desc = "15 min of double laying", icon = "feed", goldPrice = 15, grant = { boosts = { lay2 = 1 } } },
	{ id = "buy_hatch10", kind = "gold", tab = "Featured", name = "Hatchery x10 Boost", desc = "10 min of 10x hatching", icon = "hatch", goldPrice = 15, grant = { boosts = { hatch10 = 1 } } },
	{ id = "buy_earn10", kind = "gold", tab = "Featured", name = "Cash x10 Boost", desc = "10 min of 10x cash", icon = "cash", goldPrice = 60, grant = { boosts = { earn10 = 1 } } },
	{ id = "buy_booster", kind = "gold", tab = "Featured", name = "Boost Booster", desc = "Doubles your other boosts for 10 min", icon = "booster", goldPrice = 45, grant = { boosts = { booster = 1 } } },
}

local byId: { [string]: Product } = {}
for _, p in list do
	byId[p.id] = p
end

return {
	List = list,
	ById = byId,
	Tabs = { "Featured", "Passes", "Gold", "Cash" },
	TabLabels = { Featured = "Featured", Passes = "Passes", Gold = "Gold Eggs", Cash = "Cash" },
}
