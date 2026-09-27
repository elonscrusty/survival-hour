--!strict
-- Central Robux developer-product mapping.
--
-- ProductId = 0 means "not configured": the purchase button is disabled in
-- live servers and only the clearly labelled DEV SIMULATED purchase works in
-- Studio. Create each product in Creator Hub (Monetization → Developer
-- Products) and paste its id here. See docs/SETUP.md.
--
-- SuggestedPrice is documentation only. The price shown to players is always
-- read live with MarketplaceService:GetProductInfoAsync, because regional
-- pricing can change it per player.

export type Product = {
	Key: string,
	ProductId: number,
	SuggestedPrice: number,
	Kind: string, -- Revive | CarePackage | Bandage | Diamonds | Unlock | Upgrade
	Tier: number?,
	Amount: number?,
	Powerup: string?,
	Level: number?,
	Title: string,
}

local Products = {}

local defs: { Product } = {
	{ Key = "Revive1", ProductId = 0, SuggestedPrice = 25, Kind = "Revive", Tier = 1, Title = "Revive (1st)" },
	{ Key = "Revive2", ProductId = 0, SuggestedPrice = 50, Kind = "Revive", Tier = 2, Title = "Revive (2nd)" },
	{ Key = "Revive3", ProductId = 0, SuggestedPrice = 100, Kind = "Revive", Tier = 3, Title = "Revive (3rd)" },
	{ Key = "Revive4", ProductId = 0, SuggestedPrice = 150, Kind = "Revive", Tier = 4, Title = "Revive (4th+)" },

	{ Key = "CarePackage", ProductId = 0, SuggestedPrice = 75, Kind = "CarePackage", Title = "Call Public Care Package" },
	{ Key = "Bandage", ProductId = 0, SuggestedPrice = 15, Kind = "Bandage", Amount = 1, Title = "Bandage" },

	{ Key = "Diamonds100", ProductId = 0, SuggestedPrice = 99, Kind = "Diamonds", Amount = 100, Title = "100 Diamonds" },
	{ Key = "Diamonds300", ProductId = 0, SuggestedPrice = 279, Kind = "Diamonds", Amount = 300, Title = "300 Diamonds" },
	{ Key = "Diamonds800", ProductId = 0, SuggestedPrice = 699, Kind = "Diamonds", Amount = 800, Title = "800 Diamonds" },
}

-- Powerup unlocks and challenge-skip upgrades (L2, L3) for each powerup.
local powerupPrices: { [string]: { number } } = {
	Trailblazer = { 99, 79, 149 },
	Craftsman = { 119, 99, 179 },
	Hunter = { 139, 109, 199 },
	Scavenger = { 159, 129, 239 },
	Climber = { 179, 149, 279 },
	Sharpshooter = { 219, 179, 329 },
}
for id, prices in powerupPrices do
	table.insert(defs, { Key = "Unlock_" .. id, ProductId = 0, SuggestedPrice = prices[1], Kind = "Unlock", Powerup = id, Level = 1, Title = "Unlock " .. id })
	table.insert(defs, { Key = "Upgrade_" .. id .. "_2", ProductId = 0, SuggestedPrice = prices[2], Kind = "Upgrade", Powerup = id, Level = 2, Title = id .. " Level 2" })
	table.insert(defs, { Key = "Upgrade_" .. id .. "_3", ProductId = 0, SuggestedPrice = prices[3], Kind = "Upgrade", Powerup = id, Level = 3, Title = id .. " Level 3" })
end

Products.List = defs
Products.ByKey = {} :: { [string]: Product }
Products.ById = {} :: { [number]: Product }

for _, p in defs do
	Products.ByKey[p.Key] = p
	if p.ProductId ~= 0 then
		assert(Products.ById[p.ProductId] == nil, "Duplicate developer product id " .. p.ProductId)
		Products.ById[p.ProductId] = p
	end
end

function Products.IsConfigured(key: string): boolean
	local p = Products.ByKey[key]
	return p ~= nil and p.ProductId ~= 0
end

function Products.ReviveKey(tier: number): string
	return "Revive" .. math.clamp(tier, 1, 4)
end

return Products
