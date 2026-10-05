-- Robux products. Robux buys Coins, cosmetics and storage only, never race speed.
-- The owner fills in the ids after creating the products on the Creator Dashboard.
-- An entry with Id = nil is hidden from the shop.
local Products = {}

-- Developer products (can be bought many times).
Products.Dev = {
	{ Key = "Coins500", Name = "500 Coins", Robux = 25, Id = nil :: number?, Coins = 500 },
	{ Key = "Coins3000", Name = "3,000 Coins", Robux = 120, Id = nil :: number?, Coins = 3000 },
	{ Key = "Coins10000", Name = "10,000 Coins", Robux = 350, Id = nil :: number?, Coins = 10000 },
	{ Key = "RainbowTrail", Name = "Rainbow Trail", Robux = 99, Id = nil :: number?, Cosmetic = "TrailRainbow" },
	{ Key = "GalaxyPaint", Name = "Galaxy Paint", Robux = 79, Id = nil :: number?, Cosmetic = "PaintGalaxy" },
}

-- Game passes (bought once).
Products.Passes = {
	{ Key = "BigBarn", Name = "Big Barn (+36 pet slots)", Robux = 149, Id = nil :: number? },
}

return Products
