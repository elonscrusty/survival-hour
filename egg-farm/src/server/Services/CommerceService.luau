--!nonstrict
-- Robux checkout. Two adapters:
--   * "roblox": MarketplaceService prompts + ProcessReceipt. Every product in Data/Products has
--     robuxId = nil until the owner creates their own passes/products, so the shop answers
--     "not_configured" and NEVER opens a checkout for an unconfigured item.
--   * "test":   Commerce/TestCheckout simulates success / cancel / fail (test place only). No
--     Roblox purchase prompt, no Robux, purchase ids prefixed "TEST-", memory-only saves.
-- Grants go through Economy.GrantProduct, which records the purchase id so a receipt delivered
-- twice can't grant twice.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Products = require(Shared.Data.Products)
local Validate = require(Shared.Logic.Validate)
local RateLimiter = require(Shared.Logic.RateLimiter)

local CommerceService = {}

local ctx
local testCheckout = nil
local limiter = RateLimiter.new(4, 0.5)
-- pass ids and developer product ids are separate Roblox id spaces: keep separate maps
local passById: { [number]: any } = {}
local productById: { [number]: any } = {}

for _, p in Products.List do
	if p.robuxId then
		if p.kind == "pass" then
			passById[p.robuxId] = p
		else
			productById[p.robuxId] = p
		end
	end
end

function CommerceService.Kind(): string
	return if testCheckout then "test" else "roblox"
end

function CommerceService.SetTestCheckout(checkout)
	testCheckout = checkout
end

local function grant(player: Player, productId: string, purchaseId: string): (boolean, string)
	local farm = ctx.FarmService.Get(player)
	if not farm then
		return false, "not_ready"
	end
	local ok, code = farm:GrantProduct(productId, purchaseId, ctx.FarmService.Now())
	ctx.FarmService.Push(player, true)
	return ok, code
end

local function onRequest(player: Player, req: any)
	if type(req) ~= "table" or not Validate.Id(req.productId) then
		return { ok = false, code = "invalid", message = "That item isn't valid." }
	end
	if not limiter:Allow(player, os.clock()) then
		return { ok = false, code = "rate_limited", message = "Slow down a little!" }
	end
	local p = Products.ById[req.productId]
	if not p or (p.kind ~= "pass" and p.kind ~= "product") then
		return { ok = false, code = "invalid", message = "That item isn't sold for Robux." }
	end
	local farm = ctx.FarmService.Get(player)
	if not farm then
		return { ok = false, code = "not_ready", message = "Your farm is still loading." }
	end
	if p.kind == "pass" and farm.state.passes[p.grant.pass] then
		return { ok = false, code = "owned", message = "You already own this!" }
	end
	if testCheckout then
		return testCheckout:Buy(p.id, function(id, purchaseId)
			return grant(player, id, purchaseId)
		end)
	end
	if not p.robuxId then
		return { ok = false, code = "not_configured", message = "This item isn't for sale yet." }
	end
	local ok = pcall(function()
		if p.kind == "pass" then
			MarketplaceService:PromptGamePassPurchase(player, p.robuxId)
		else
			MarketplaceService:PromptProductPurchase(player, p.robuxId)
		end
	end)
	if not ok then
		return { ok = false, code = "failed", message = "The store couldn't open. Try again later." }
	end
	return { ok = true, code = "prompted", message = "Complete the purchase in the Roblox window." }
end

-- Real receipts (developer products). Only returns PurchaseGranted after a save containing the
-- purchase id is confirmed, so a crash can't lose a paid grant.
local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local p = productById[receipt.ProductId]
	if not player or not p then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	local ok = grant(player, p.id, purchaseId)
	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local saved = ctx.DataService.WaitForSave(player, function(data)
		return data and data.receipts and data.receipts[purchaseId] ~= nil
	end, 20)
	return if saved then Enum.ProductPurchaseDecision.PurchaseGranted else Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Passes the player owns on Roblox (only configured ones; pcall because the API can fail).
function CommerceService.SyncPasses(player: Player)
	if testCheckout then
		return
	end
	for _, p in Products.List do
		if p.kind == "pass" and p.robuxId then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, p.robuxId)
			if ok and owns then
				grant(player, p.id, "PASS-" .. player.UserId .. "-" .. p.robuxId)
			end
		end
	end
end

function CommerceService.Init(c)
	ctx = c
	local remoteCommerce = Net.Get("Commerce") :: RemoteFunction
	remoteCommerce.OnServerInvoke = onRequest
	if not testCheckout then
		MarketplaceService.ProcessReceipt = processReceipt
		MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
			local p = passById[passId]
			if purchased and p and p.kind == "pass" then
				grant(player, p.id, "PASS-" .. player.UserId .. "-" .. passId)
			end
			local remoteFarmEvent = Net.Get("FarmEvent") :: RemoteEvent
			remoteFarmEvent:FireClient(player, "Checkout", {
				productId = p and p.id,
				status = if purchased then "ok" else "cancelled",
			})
		end)
		-- UI feedback only: the grant itself happens in ProcessReceipt
		MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
			local player = Players:GetPlayerByUserId(userId)
			local p = productById[productId]
			if player and p then
				local remote = Net.Get("FarmEvent") :: RemoteEvent
				remote:FireClient(player, "Checkout", { productId = p.id, status = if purchased then "ok" else "cancelled" })
			end
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		limiter:Forget(player)
	end)
	ctx.FarmService.OnReady(function(player)
		CommerceService.SyncPasses(player)
	end)
end

return CommerceService
