-- Coin shop (cosmetics) and Robux purchases. Robux buys Coins, cosmetics and
-- storage only.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Cosmetics = require(Shared.Cosmetics)
local Products = require(Shared.Products)
local Profile = require(Shared.Logic.Profile)

local ShopService = {}

local ctx: any

local function byProductId(id: number)
	for _, p in Products.Dev do
		if p.Id == id then
			return p
		end
	end
	return nil
end

local function checkPasses(p: Player)
	local d = ctx.DataService.Get(p)
	if not d then
		return
	end
	for _, pass in Products.Passes do
		if pass.Id and pass.Key == "BigBarn" and not d.BigBarn then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(p.UserId, pass.Id :: number)
			end)
			if ok and owns then
				d.BigBarn = true
				ctx.DataService.Changed(p)
			end
		end
	end
end

function ShopService.Init(c)
	ctx = c
end

function ShopService.Start()
	ctx.Util.Connect("BuyCosmetic", 0.5, function(p: Player, id)
		local d = ctx.DataService.Get(p)
		local def = type(id) == "string" and Cosmetics.ById[id]
		if not d or not def then
			return
		end
		if d.Owned[id] then
			ctx.Util.Notify(p, "You already own that.", "Info")
			return
		end
		if not def.Price then
			ctx.Util.Notify(p, "That one is in the Robux shop.", "Info")
			return
		end
		if d.Coins < def.Price then
			ctx.Util.Notify(p, "You need " .. (def.Price - d.Coins) .. " more coins.", "Error")
			return
		end
		d.Coins -= def.Price
		d.Owned[id] = true
		ctx.DataService.Changed(p)
		ctx.Util.Notify(p, "Unlocked " .. def.Name .. "!", "Level")
	end)

	ctx.Util.Connect("TutorialDone", 2, function(p: Player)
		local d = ctx.DataService.Get(p)
		if d and not d.Tutorial then
			d.Tutorial = true
			ctx.DataService.Changed(p)
		end
	end)

	ctx.DataService.OnLoaded(function(p: Player)
		checkPasses(p)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(p, passId, bought)
		if bought then
			for _, pass in Products.Passes do
				if pass.Id == passId and pass.Key == "BigBarn" then
					local d = ctx.DataService.Get(p)
					if d then
						d.BigBarn = true
						ctx.DataService.Changed(p)
						ctx.Util.Notify(p, "Big Barn unlocked: +36 pet slots!", "Level")
					end
				end
			end
		end
	end)

	MarketplaceService.ProcessReceipt = function(info)
		local p = Players:GetPlayerByUserId(info.PlayerId)
		local d = p and ctx.DataService.Get(p)
		if not p or not d then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local product = byProductId(info.ProductId)
		if not product then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if not Profile.TakeReceipt(d, info.PurchaseId) then
			return Enum.ProductPurchaseDecision.PurchaseGranted -- already given
		end
		if product.Coins then
			d.Coins += product.Coins
			ctx.Util.Notify(p, "+" .. product.Coins .. " coins! Thank you!", "Coins")
		elseif product.Cosmetic then
			d.Owned[product.Cosmetic] = true
			ctx.Util.Notify(p, "Unlocked " .. product.Name .. "!", "Level")
		end
		ctx.DataService.Changed(p)
		ctx.DataService.SaveNow(p)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

return ShopService
