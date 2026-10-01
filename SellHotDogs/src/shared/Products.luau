--!strict
-- The new game's own Robux products. IDs are nil until Carter creates them on the Creator
-- Dashboard for the published Sell Hot Dogs experience (docs/LIVE_SETUP.md). Never reuse the
-- reference game's IDs. Live prices come from MarketplaceService:GetProductInfo at runtime.
-- key = Game.grantProduct key; kind "pass" = Game Pass (one-time), "product" = Developer Product.
export type Product = { key: string, kind: string, id: number?, icon: string, blurb: string }

local Products: { Product } = {
	{ key = "speedUp", kind = "pass", id = nil, icon = "⏩", blurb = "Every business runs x2 faster, forever." },
	{ key = "x2investors", kind = "pass", id = nil, icon = "👽", blurb = "Twice the Alien Investors every rebirth." },
	{ key = "manage", kind = "pass", id = nil, icon = "📋", blurb = "Manage every business from one menu." },
	{ key = "remoteBuy", kind = "pass", id = nil, icon = "📡", blurb = "Buy the next upgrade from anywhere." },
	{ key = "expertPicker", kind = "product", id = nil, icon = "🧺", blurb = "Permanent Expert Collector level." },
	{ key = "runFaster", kind = "product", id = nil, icon = "👟", blurb = "Permanent Run Faster level." },
	{ key = "stack", kind = "product", id = nil, icon = "📚", blurb = "Permanent Stack Upgrade level." },
	{ key = "forever", kind = "product", id = nil, icon = "♾️", blurb = "Pick one upgrade to keep through every reset." },
	{ key = "rebirthNoReset", kind = "product", id = nil, icon = "🛸", blurb = "Collect your investors without resetting." },
	{ key = "cash1h", kind = "product", id = nil, icon = "💵", blurb = "1 hour of profit instantly." },
	{ key = "cash24h", kind = "product", id = nil, icon = "💰", blurb = "24 hours of profit instantly." },
	{ key = "cash7d", kind = "product", id = nil, icon = "🏦", blurb = "7 days of profit instantly." },
}

local byKey: { [string]: Product } = {}
for _, p in Products do
	byKey[p.key] = p
end

return {
	list = Products,
	byKey = byKey,
}
