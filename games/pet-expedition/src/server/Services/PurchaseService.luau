--!nonstrict
-- Robux purchases.
--   * Developer products: MarketplaceService.ProcessReceipt. Each PurchaseId
--     is granted once (stored in the profile) and only reported as granted
--     after the profile is saved, so a failed save means Roblox retries
--     instead of the player losing the purchase.
--   * Game passes: checked with UserOwnsGamePassAsync on join and granted
--     right away from PromptGamePassPurchaseFinished.
--   * DevPurchase: Studio only, for items whose Id is still 0.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Products = require(Shared:WaitForChild("Products"))
local Logic = Shared:WaitForChild("Logic")
local Economy = require(Logic:WaitForChild("Economy"))
local Profile = require(Logic:WaitForChild("Profile"))

local PurchaseService = {}

local ctx: any
local granting: { [string]: boolean } = {} -- PurchaseIds being processed right now

function PurchaseService.Init(c)
	ctx = c
	ctx.DataService.OnLoaded(PurchaseService._onLoaded)
	MarketplaceService.ProcessReceipt = PurchaseService._processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local pass = Products.PassById[passId]
		local s = ctx.DataService.Get(player)
		if pass and s then
			PurchaseService.GrantPass(player, s, pass.Key)
		end
	end)

	ctx.Util.Function("DevPurchase", function(player, s, key)
		if not RunService:IsStudio() then
			return ctx.Util.Fail("Only available in Studio")
		end
		if not ctx.Util.IsStr(key, 32) then
			return ctx.Util.Fail("Unknown item")
		end
		local pass = Products.PassByKey[key]
		if pass then
			if pass.Id ~= 0 then
				return ctx.Util.Fail("This pass has a real id: buy it normally")
			end
			PurchaseService.GrantPass(player, s, pass.Key)
			return { ok = true }
		end
		local product = Products.ByKey[key]
		if product then
			if product.Id ~= 0 then
				return ctx.Util.Fail("This product has a real id: buy it normally")
			end
			PurchaseService.GrantProduct(player, s, product)
			return { ok = true }
		end
		return ctx.Util.Fail("Unknown item")
	end)
end

function PurchaseService._onLoaded(player: Player, s)
	task.spawn(function()
		local changed = false
		for _, pass in Products.Passes do
			if pass.Id ~= 0 and not s.Profile.Passes[pass.Key] then
				local ok, owns = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
				end)
				if ok and owns then
					s.Profile.Passes[pass.Key] = true
					changed = true
				end
			end
		end
		if changed then
			ctx.StateService.Dirty(player)
		end
	end)
end

function PurchaseService.GrantPass(player: Player, s, key: string)
	if s.Profile.Passes[key] then
		return
	end
	s.Profile.Passes[key] = true
	local pass = Products.PassByKey[key]
	ctx.Util.Notify(player, "Purchased", { Name = if pass then pass.Name else key })
	ctx.StateService.Dirty(player)
	task.spawn(ctx.DataService.SaveNow, player)
end

-- Gives a product's contents (no dedupe here; see _processReceipt).
function PurchaseService.GrantProduct(player: Player, s, product: Products.Product)
	if product.Kind == "Gems" then
		Economy.AddGems(s.Profile, product.Amount or 0)
	elseif product.Kind == "Boost" and product.Boost then
		ctx.BoostService.Apply(player, s, product.Boost)
	elseif product.Kind == "ServerLuck" then
		ctx.BoostService.ServerLuck(player.DisplayName)
	else
		warn("[PurchaseService] unknown product kind", product.Kind)
	end
	ctx.Util.Notify(player, "Purchased", { Name = product.Name })
	ctx.StateService.Dirty(player)
end

function PurchaseService._processReceipt(receipt)
	local NotYet = Enum.ProductPurchaseDecision.NotProcessedYet
	local Granted = Enum.ProductPurchaseDecision.PurchaseGranted
	local product = Products.ById[receipt.ProductId]
	if not product then
		warn("[PurchaseService] receipt for unknown product id", receipt.ProductId)
		return NotYet
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return NotYet -- granted when they next join
	end
	local s = ctx.DataService.WaitFor(player, 30)
	if not s or s.State == "Failed" or s.LockLost then
		return NotYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	-- The same receipt can arrive again while we're still saving it.
	if granting[purchaseId] then
		return NotYet
	end
	granting[purchaseId] = true
	local ok, result = pcall(function()
		if not Profile.HasReceipt(s.Profile, purchaseId) then
			PurchaseService.GrantProduct(player, s, product)
			Profile.RecordReceipt(s.Profile, purchaseId, os.time())
		end
		if s.State == "Memory" then
			return Granted
		end
		return if ctx.DataService.SaveNow(player) then Granted else NotYet
	end)
	granting[purchaseId] = nil
	if not ok then
		warn("[PurchaseService] receipt error:", result)
		return NotYet
	end
	return result
end

return PurchaseService
