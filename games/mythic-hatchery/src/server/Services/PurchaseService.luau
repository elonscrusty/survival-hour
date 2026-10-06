--!strict
-- Robux purchases.
--   * Developer products: MarketplaceService.ProcessReceipt. Each PurchaseId
--     is granted once (stored in the profile) and only reported as granted
--     after the profile is saved, so a failed save means Roblox retries
--     instead of the player losing the purchase.
--   * Game passes: checked with UserOwnsGamePassAsync on join; after
--     PromptGamePassPurchaseFinished the purchase is confirmed with
--     UserOwnsGamePassAsync (retried) before granting.
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

-- Luck items are paid random-item boosts. Players whose policy restricts paid
-- random items can't buy them; if a receipt still arrives (bought before the
-- policy answered, or from another device) they get gems instead so nobody
-- pays for nothing.
PurchaseService.LuckPass = "Lucky"
PurchaseService.LuckProductGems = {
	BoostLuck = 400,
	ServerLuck = 1000,
} :: { [string]: number }

function PurchaseService.IsLuckItem(key: string): boolean
	return key == PurchaseService.LuckPass or PurchaseService.LuckProductGems[key] ~= nil
end

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
		if not pass then
			return
		end
		-- Don't trust the event alone: confirm ownership with Roblox.
		for attempt = 1, 4 do
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if ok then
				local s = ctx.DataService.Get(player)
				if owns and s then
					PurchaseService.GrantPass(player, s, pass.Key)
				end
				return
			end
			task.wait(attempt * 2)
		end
		warn("[PurchaseService] couldn't confirm pass", pass.Key, "for", player.UserId, "- it will be checked on next join")
	end)

	ctx.Util.Function("DevPurchase", function(player, s, key)
		if not RunService:IsStudio() then
			return ctx.Util.Fail("Only available in Studio")
		end
		if not ctx.Util.IsStr(key, 32) then
			return ctx.Util.Fail("Unknown item")
		end
		if PurchaseService.IsLuckItem(key) and ctx.StateService.PaidRandomRestricted(s) then
			return ctx.Util.Fail("Luck items aren't available for your account")
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
					ctx.DataService.Touch(s)
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
	ctx.DataService.Touch(s)
	local pass = Products.PassByKey[key]
	ctx.Util.Notify(player, "Purchased", { Name = if pass then pass.Name else key })
	ctx.StateService.Dirty(player)
	task.spawn(ctx.DataService.SaveNow, player)
end

-- Gives a product's contents (no dedupe here; see _processReceipt).
function PurchaseService.GrantProduct(player: Player, s, product: Products.Product)
	local swapGems = PurchaseService.LuckProductGems[product.Key]
	if swapGems and ctx.StateService.PaidRandomRestricted(s) then
		Economy.AddGems(s.Profile, swapGems)
		ctx.Util.Notify(player, "Purchased", { Name = tostring(swapGems) .. " Gems (luck items aren't available for your account)" })
		ctx.StateService.Dirty(player)
		return
	end
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
	if not s or ctx.DataService.ReadOnly(s) then
		return NotYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	-- Luck products depend on the player's policy: don't decide (gems vs the
	-- boost) before PolicyService has answered.
	if PurchaseService.LuckProductGems[product.Key] then
		local deadline = os.clock() + 20
		while not s.PolicyKnown and os.clock() < deadline and player.Parent ~= nil do
			task.wait(0.5)
		end
		if not s.PolicyKnown then
			return NotYet
		end
	end
	-- The same receipt can arrive again while we're still saving it.
	if granting[purchaseId] then
		return NotYet
	end
	granting[purchaseId] = true
	local ok, result = pcall(function()
		if not Profile.HasReceipt(s.Profile, purchaseId) then
			PurchaseService.GrantProduct(player, s, product)
			Profile.RecordReceipt(s.Profile, purchaseId, os.time())
			ctx.DataService.Touch(s)
		end
		if s.State == "Memory" then
			return Granted
		end
		-- True only if a completed write includes this receipt.
		return if ctx.DataService.SaveSession(s) then Granted else NotYet
	end)
	granting[purchaseId] = nil
	if not ok then
		warn("[PurchaseService] receipt error:", result)
		return NotYet
	end
	return result
end

return PurchaseService
