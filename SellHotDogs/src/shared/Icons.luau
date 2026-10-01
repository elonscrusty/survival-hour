--!strict
-- Which picture represents each thing in the UI. Kit.icon shows, in order of preference:
-- the uploaded rendered icon (assets/icons/<model>.png -> AssetIds.Images), a live 3D preview of
-- the model in a ViewportFrame, or the emoji as a last resort.
local Icons: { [string]: { model: string, emoji: string } } = {
	-- businesses
	stand = { model = "HotDogStand", emoji = "🌭" },
	dash = { model = "DashShop", emoji = "🛵" },
	depot = { model = "DepotBuilding", emoji = "🚚" },
	trading = { model = "TradingFloor", emoji = "📈" },
	labs = { model = "LabBuilding", emoji = "🧪" },
	robotics = { model = "RoboticsFactory", emoji = "🤖" },
	republic = { model = "RepublicCapitol", emoji = "🏛️" },
	hotdogx = { model = "LaunchSite", emoji = "🚀" },
	-- powers / products
	manage = { model = "Clipboard", emoji = "📋" },
	runFaster = { model = "Sneaker", emoji = "👟" },
	stack = { model = "BookStack", emoji = "📚" },
	remoteBuy = { model = "RemoteControl", emoji = "📡" },
	expertPicker = { model = "Basket", emoji = "🧺" },
	speedUp = { model = "Stopwatch", emoji = "⏩" },
	x2investors = { model = "AlienInvestor", emoji = "👽" },
	forever = { model = "InfinityToken", emoji = "♾️" },
	rebirthNoReset = { model = "Ufo", emoji = "🛸" },
	cash1h = { model = "CashStack", emoji = "💵" },
	cash24h = { model = "MoneyBag", emoji = "💰" },
	cash7d = { model = "Coin", emoji = "🏦" },
	-- HUD buttons
	investors = { model = "AlienInvestor", emoji = "👽" },
	evolve = { model = "CosmicPortal", emoji = "🌀" },
	ascend = { model = "Staircase", emoji = "✨" },
	dashgame = { model = "DashArcade", emoji = "🏁" },
	shop = { model = "CashStack", emoji = "🛒" },
	powers = { model = "Sneaker", emoji = "⚡" },
	decorShop = { model = "PatioUmbrella", emoji = "🌳" },
	cash = { model = "Coin", emoji = "💲" },
	lock = { model = "Lock", emoji = "🔒" },
}

return Icons
