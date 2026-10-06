--!strict
-- Robux catalogue. Id = 0 means "not created yet": the buy button shows
-- "Coming soon" in live servers. In Studio, purchases of unconfigured items
-- are simulated so every flow can be tested (PurchaseService). Create each
-- item in Creator Hub and paste its id here (docs/SETUP.md).
--
-- Price is the suggested Robux price (documentation; the real price is read
-- live with MarketplaceService so regional pricing is respected).

export type Pass = { Key: string, Id: number, Price: number, Name: string, Blurb: string }
export type Product = {
	Key: string,
	Id: number,
	Price: number,
	Name: string,
	Kind: string, -- "Gems" | "Boost" | "ServerLuck"
	Amount: number?, -- gems
	Boost: string?, -- Config.Boosts key
}

local Products = {}

Products.Passes = {
	{ Key = "HatchSlots", Id = 0, Price = 249, Name = "+2 Hatch Slots", Blurb = "Incubate 2 more eggs at the same time." },
	{ Key = "FastIncubation", Id = 0, Price = 299, Name = "2x Incubation", Blurb = "Eggs hatch twice as fast." },
	{ Key = "VipTrader", Id = 0, Price = 199, Name = "VIP Trader", Blurb = "Bigger trade window (16 creatures), shorter trade cooldown and a gold VIP badge in trades." },
	{ Key = "VIP", Id = 0, Price = 199, Name = "VIP", Blurb = "+20% coins, VIP chat tag and a golden name." },
	{ Key = "Lucky", Id = 0, Price = 349, Name = "Lucky", Blurb = "1.5x chance for rarer creatures from every egg." },
	{ Key = "MoreEquip", Id = 0, Price = 249, Name = "+3 Creatures Out", Blurb = "Take 3 more creatures with you." },
	{ Key = "MoreExpeditions", Id = 0, Price = 199, Name = "+2 Expedition Slots", Blurb = "Run 2 more expeditions at the same time." },
	{ Key = "AutoFarm", Id = 0, Price = 249, Name = "Auto Farm", Blurb = "Your creatures attack the nearest treasure on their own." },
	{ Key = "BigBackpack", Id = 0, Price = 99, Name = "Big Stable", Blurb = "+150 creature storage." },
	{ Key = "RingChampion", Id = 0, Price = 299, Name = "Ring Champion", Blurb = "+1 creature fights for you in the Creature Ring." },
} :: { Pass }

Products.Products = {
	{ Key = "Gems250", Id = 0, Price = 49, Name = "250 Gems", Kind = "Gems", Amount = 250 },
	{ Key = "Gems550", Id = 0, Price = 99, Name = "550 Gems", Kind = "Gems", Amount = 550 },
	{ Key = "Gems1500", Id = 0, Price = 249, Name = "1,500 Gems", Kind = "Gems", Amount = 1500 },
	{ Key = "Gems3300", Id = 0, Price = 499, Name = "3,300 Gems", Kind = "Gems", Amount = 3300 },
	{ Key = "Gems7000", Id = 0, Price = 999, Name = "7,000 Gems", Kind = "Gems", Amount = 7000 },
	{ Key = "Gems19000", Id = 0, Price = 2499, Name = "19,000 Gems", Kind = "Gems", Amount = 19000 },
	{ Key = "BoostCoins", Id = 0, Price = 49, Name = "2x Coins (30 min)", Kind = "Boost", Boost = "Coins2x" },
	{ Key = "BoostGrowth", Id = 0, Price = 49, Name = "2x Growth (30 min)", Kind = "Boost", Boost = "Growth2x" },
	{ Key = "BoostLuck", Id = 0, Price = 79, Name = "2x Luck (30 min)", Kind = "Boost", Boost = "Luck2x" },
	{ Key = "ServerLuck", Id = 0, Price = 199, Name = "Server Luck (15 min)", Kind = "ServerLuck" },
} :: { Product }

Products.PassByKey = {} :: { [string]: Pass }
Products.PassById = {} :: { [number]: Pass }
for _, p in Products.Passes do
	Products.PassByKey[p.Key] = p
	if p.Id ~= 0 then
		Products.PassById[p.Id] = p
	end
end

Products.ByKey = {} :: { [string]: Product }
Products.ById = {} :: { [number]: Product }
for _, p in Products.Products do
	Products.ByKey[p.Key] = p
	if p.Id ~= 0 then
		assert(Products.ById[p.Id] == nil, "duplicate product id " .. p.Id)
		Products.ById[p.Id] = p
	end
end

return Products
