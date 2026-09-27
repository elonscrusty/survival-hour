--!nonstrict
-- Robux purchases (developer products).
--
-- Flow:
--   1. A gameplay service validates the request, then calls PurchaseService.Prompt
--      with an optional *intent* (e.g. { Target = userId } for a teammate revive).
--   2. Roblox calls ProcessReceipt. We apply the product to the buyer's profile as
--      a durable change (ProfileRules.ApplyReceipt: idempotent by PurchaseId) and
--      save. Only after a successful save do we return PurchaseGranted.
--   3. Registered consumers (revive, care package, bandage) then try to use the
--      new credit immediately. If they can't (target died, match ended, buyer
--      left), the credit simply stays in the profile (DECISIONS D8).
--
-- Nothing is granted from PromptProductPurchaseFinished (it's only used to
-- release UI locks when a prompt is cancelled).

local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Products = require(Shared:WaitForChild("Products"))
local ProfileRules = require(Shared:WaitForChild("Logic"):WaitForChild("ProfileRules"))

type Intent = { Key: string, Data: { [string]: any }, Time: number, OnCancel: (() -> ())? }

local PurchaseService = {}

local ctx: any
local pending: { [number]: Intent } = {} -- buyer userId -> latest intent
local consumers: { [string]: { (Player, any, { [string]: any }?) -> () } } = {}
local policy: { [Player]: { RandomRestricted: boolean } } = {}
local priceLevels: { [Player]: number } = {}

PurchaseService.EnforceGiftPriceLevels = true

function PurchaseService.Init(c)
	ctx = c
	MarketplaceService.ProcessReceipt = PurchaseService._processReceipt
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, productId: number, isPurchased: boolean)
		local intent = pending[userId]
		if intent and not isPurchased then
			local product = Products.ByKey[intent.Key]
			if product and product.ProductId == productId then
				pending[userId] = nil
				if intent.OnCancel then
					intent.OnCancel()
				end
			end
		end
	end)
	ctx.Util.OnPlayerAdded(function(player: Player)
		-- Paid random items policy (care packages are randomized; DECISIONS D27).
		local restricted = true
		local ok, info = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		if ok and type(info) == "table" then
			restricted = info.ArePaidRandomItemsRestricted == true
		elseif ctx.IsStudio then
			restricted = false
		end
		policy[player] = { RandomRestricted = restricted }
		player:SetAttribute("PaidRandomRestricted", restricted)
		-- Regional price level (never cached across sessions).
		local okLvl, levels = pcall(function()
			return (MarketplaceService :: any):GetUsersPriceLevelsAsync({ player.UserId })
		end)
		if okLvl and type(levels) == "table" then
			for _, entry in levels do
				if type(entry) == "table" then
					local uid = entry.UserId or entry.userId
					local lvl = entry.PriceLevel or entry.priceLevel
					if uid == player.UserId and type(lvl) == "number" then
						priceLevels[player] = lvl
					end
				end
			end
		end
	end)
	ctx.Util.OnPlayerRemoving(function(player: Player)
		policy[player] = nil
		priceLevels[player] = nil
		pending[player.UserId] = nil
	end)
end

-- Consumers are called after a successful grant for products of `kind`.
function PurchaseService.OnGranted(kind: string, fn: (Player, any, { [string]: any }?) -> ())
	consumers[kind] = consumers[kind] or {}
	table.insert(consumers[kind], fn)
end

function PurchaseService.PaidRandomAllowed(player: Player): boolean
	local p = policy[player]
	return p ~= nil and not p.RandomRestricted
end

-- Gift rule for teammate revives with regional pricing (DECISIONS D10).
function PurchaseService.GiftAllowed(payer: Player, receiver: Player): boolean
	if not PurchaseService.EnforceGiftPriceLevels or payer == receiver then
		return true
	end
	local a, b = priceLevels[payer], priceLevels[receiver]
	if a == nil or b == nil then
		return true -- API unavailable or regional pricing not in use
	end
	return a >= b
end

function PurchaseService.IsConfigured(key: string): boolean
	return Products.IsConfigured(key)
end

-- Starts a purchase. Returns ok, reason.
function PurchaseService.Prompt(player: Player, key: string, data: { [string]: any }?, onCancel: (() -> ())?): (boolean, string?)
	local product = Products.ByKey[key]
	if not product then
		return false, "Unknown product"
	end
	if product.Kind == "CarePackage" and not PurchaseService.PaidRandomAllowed(player) then
		return false, "Paid care packages are not available in your region"
	end
	if not ctx.Util.Allow(player, "Purchase") then
		return false, "Please wait a moment"
	end
	pending[player.UserId] = { Key = key, Data = data or {}, Time = os.clock(), OnCancel = onCancel }
	if product.ProductId == 0 then
		if ctx.DevEnabled then
			-- Clearly labelled development simulation. Never active in live servers.
			task.spawn(PurchaseService._simulate, player, product)
			return true, "simulated"
		end
		pending[player.UserId] = nil
		return false, "This product isn't set up yet"
	end
	MarketplaceService:PromptProductPurchase(player, product.ProductId)
	return true, nil
end

function PurchaseService._simulate(player: Player, product: any)
	task.wait(0.4)
	ctx.Util.Notify(player, "[DEV] Simulated purchase of '" .. product.Title .. "'. No Robux involved.", "dev")
	local fakeReceipt = {
		PlayerId = player.UserId,
		ProductId = -1,
		PurchaseId = "SIM-" .. HttpService:GenerateGUID(false),
		CurrencySpent = 0,
		_SimProduct = product,
	}
	PurchaseService._grant(player, product, fakeReceipt.PurchaseId)
end

function PurchaseService._processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local product = Products.ById[receipt.ProductId]
	if not product then
		warn("[PurchaseService] receipt for unmapped product", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		-- Roblox re-delivers when the buyer joins a server again.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local session = ctx.DataService.WaitFor(player, 30)
	if not session or not ctx.DataService.CanGrant(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok = PurchaseService._grant(player, product, receipt.PurchaseId)
	return if ok then Enum.ProductPurchaseDecision.PurchaseGranted else Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Applies + saves. Returns true when durable.
function PurchaseService._grant(player: Player, product: any, purchaseId: string): boolean
	local session = ctx.DataService.Get(player)
	if not session then
		return false
	end
	local status = ProfileRules.ApplyReceipt(session.Profile, purchaseId, product, Config.Data.ProcessedReceiptMemory)
	local saved = ctx.DataService.Save(player, false)
	if not saved then
		-- The receipt id is recorded in memory; the retry will find it and just save.
		return false
	end
	ctx.DataService.Push(player)
	if status == "Granted" then
		local intent = pending[player.UserId]
		local data: { [string]: any }? = nil
		if intent and intent.Key == product.Key and os.clock() - intent.Time < 600 then
			data = intent.Data
			pending[player.UserId] = nil
		end
		for _, fn in consumers[product.Kind] or {} do
			task.spawn(function()
				local okc, err = pcall(fn, player, product, data)
				if not okc then
					warn("[PurchaseService] consumer error:", err)
				end
			end)
		end
		if product.Kind == "Diamonds" or product.Kind == "Unlock" or product.Kind == "Upgrade" then
			ctx.Util.Notify(player, "Purchase complete: " .. product.Title, "success")
		end
	end
	return true
end

return PurchaseService
