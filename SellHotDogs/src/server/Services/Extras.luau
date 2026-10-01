--!strict
-- Side systems: ingredient pickups, phone offers, DogDash races, business names, Robux shop.
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local BigNum = require(Shared.Logic.BigNum)
local Config = require(Shared.Config)
local Dash = require(Shared.Logic.Dash)
local Economy = require(Shared.Logic.Economy)
local Format = require(Shared.Logic.Format)
local Game = require(Shared.Logic.Game)
local Layout = require(Shared.Layout)
local Names = require(Shared.Logic.Names)
local Phone = require(Shared.Logic.Phone)
local Products = require(Shared.Products)
local Data = require("./Data")
local GameService = require("./GameService")
local Models = require("./Models")
local World = require("./World")

local Extras = {}
local Cat = Economy.Catalog
local rng = Random.new()
local function roll(): number
	return rng:NextNumber()
end

---------------------------------------------------------------------------
-- Ingredient pickups: crates appear at the owner's racks; only the owner collects them.
---------------------------------------------------------------------------
local function spawnPickups()
	local cap = Cat.pickups.rackCapacity.value
	while true do
		task.wait(Cat.pickups.spawnEvery.value)
		for _, plot in World.plots do
			local owner = plot.owner
			local s = owner and Data.get(owner)
			if not s or not Game.bizOwned(s.profile, "stand") then
				continue
			end
			local folder = plot.folder:FindFirstChild("Pickups") :: Folder?
			if not folder then
				local f = Instance.new("Folder")
				f.Name = "Pickups"
				f.Parent = plot.folder
				folder = f
			end
			local f = folder :: Folder
			if #f:GetChildren() >= cap then
				continue
			end
			local rack = Layout.racks[rng:NextInteger(1, #Layout.racks)]
			local off = Vector3.new(rng:NextNumber(-3, 3), 0, if rack.X > 0 then -5 else 5)
			local bag = rng:NextNumber() < 0.2
			local m = Models.build(if bag then "MoneyBag" else "IngredientCrate")
			Models.place(m, plot.origin * CFrame.new(rack + Vector3.new(off.Z, 0, off.X)), f)
			local hit = Models.part(m, Vector3.new(4, 4, 4), plot.origin * CFrame.new(rack + Vector3.new(off.Z, 2, off.X)), Color3.new(1, 1, 1), { transparency = 1, collide = false, name = "Hit" })
			local taken = false
			hit.Touched:Connect(function(other)
				if taken then
					return
				end
				local pl = Players:GetPlayerFromCharacter(other.Parent)
				if pl ~= plot.owner or not pl then
					return
				end
				local ss = Data.get(pl)
				local root = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not ss or not root or (root.Position - hit.Position).Magnitude > Cat.pickups.pickupRange.value then
					return
				end
				taken = true
				local v = Game.collectPickup(ss.profile, if bag then 2 else 1) -- bags pay double
				GameService.notify(pl, "cash", { amount = v, source = "pickup", pos = hit.Position })
				m:Destroy()
				GameService.afterChange(ss)
				GameService.sync(ss)
			end)
		end
	end
end

---------------------------------------------------------------------------
-- Phone offers
---------------------------------------------------------------------------
local offerSeq = 0
local function phoneLoop()
	while true do
		task.wait(1)
		local now = os.time()
		for _, s in Data.sessions do
			local rt = s.rt
			rt.phoneNext = rt.phoneNext or now + Cat.phone.firstAfter.value
			local o = rt.offer
			if o and o.state == "open" and now > o.expires then
				o.state = "expired"
				GameService.notify(s.player, "phone", { offer = o, outcome = "expired" })
				rt.offer = nil
				rt.phoneNext = now + Cat.phone.every.value
			end
			if not rt.offer and now >= rt.phoneNext then
				offerSeq += 1
				local offer = Phone.newOffer(offerSeq, Game.incomeRate(s.profile, false), now, roll)
				rt.phoneNext = now + Cat.phone.every.value
				if offer then
					rt.offer = offer
					GameService.notify(s.player, "phone", { offer = offer, outcome = "new" })
				end
			end
		end
	end
end

GameService.register("phone", 0.3, function(s, id, action)
	local o = s.rt.offer
	if not o or o.id ~= id or type(action) ~= "string" then
		return
	end
	local outcome, amount = Phone.respond(o, action, os.time(), roll)
	if outcome == "invalid" then
		return
	end
	if outcome == "accepted" and amount then
		Game.earn(s.profile, amount)
		s.profile.stats.deals = (s.profile.stats.deals or 0) + 1
		GameService.notify(s.player, "cash", { amount = amount, source = "deal" })
		GameService.afterChange(s)
	end
	if o.state ~= "open" then
		s.rt.offer = nil
	end
	GameService.notify(s.player, "phone", { offer = o, outcome = outcome })
	GameService.sync(s)
end)

---------------------------------------------------------------------------
-- DogDash races (server-simulated)
---------------------------------------------------------------------------
GameService.register("dashStart", 1, function(s, pick, fraction)
	local p = s.profile
	if not Game.owns(p, "dash:dashgame") then
		return GameService.toast(s.player, "Buy DogDash the Game first", "error")
	end
	if s.rt.race then
		return
	end
	if os.clock() < (s.rt.raceCooldown or 0) then
		return GameService.toast(s.player, "The racers are resting", "error")
	end
	if type(pick) ~= "number" or type(fraction) ~= "number" then
		return
	end
	local bet = Dash.betAmount(p.cash, fraction)
	if not bet or bet.m <= 0 then
		return GameService.toast(s.player, "You need cash to bet", "error")
	end
	local race = Dash.new(pick, bet, roll)
	if not race then
		return
	end
	p.cash = BigNum.roundCents(BigNum.sub(p.cash, bet))
	s.rt.race = race
	s.rt.raceCooldown = os.clock() + Cat.dash.cooldown.value
	GameService.afterChange(s)
	GameService.sync(s)
	task.spawn(function()
		while s.rt.race == race and not race.winner and not s.rt.closing do
			task.wait(0.1)
			Dash.step(race, 0.1, roll)
			GameService.notify(s.player, "race", { pos = race.pos, pick = race.pick, winner = race.winner, cheers = race.cheers })
		end
		if s.rt.closing and not race.winner then
			return -- settled by the leave handler
		end
		if race.winner then
			local pay = Dash.payout(race)
			if pay.m > 0 then
				Game.earn(p, pay)
			end
			p.stats.races = (p.stats.races or 0) + 1
			GameService.notify(s.player, "raceEnd", { winner = race.winner, pick = race.pick, payout = pay, bet = race.bet })
			GameService.afterChange(s)
			GameService.sync(s)
		end
		s.rt.race = nil
	end)
end)

GameService.register("dashCheer", 0.08, function(s)
	local race = s.rt.race
	if race then
		Dash.cheer(race)
	end
end)

---------------------------------------------------------------------------
-- Business name (rule check + Roblox text filter; fails closed)
---------------------------------------------------------------------------
GameService.register("setName", 2, function(s, raw)
	if s.rt.naming then
		return
	end
	local clean, why = Names.clean(raw)
	if not clean then
		GameService.notify(s.player, "nameResult", { ok = false, msg = why })
		return
	end
	s.rt.naming = true
	local ok, filtered = pcall(function()
		local res = TextService:FilterStringAsync(clean, s.player.UserId, Enum.TextFilterContext.PublicChat)
		return res:GetNonChatStringForBroadcastAsync()
	end)
	s.rt.naming = false
	if not s.player.Parent then
		return
	end
	if not ok then
		GameService.notify(s.player, "nameResult", { ok = false, msg = "Couldn't check that name right now. Try again soon." })
		return
	end
	if filtered ~= clean then
		GameService.notify(s.player, "nameResult", { ok = false, msg = "That name isn't allowed. Try another!" })
		return
	end
	s.profile.name = clean
	GameService.notify(s.player, "nameResult", { ok = true, msg = "Renamed to " .. clean })
	GameService.afterChange(s)
	GameService.sync(s)
end)

---------------------------------------------------------------------------
-- Robux: receipts are idempotent (PurchaseId stored in the profile, saved before granting
-- is acknowledged). Mock purchases (Studio only) run the same handler with fake receipts.
---------------------------------------------------------------------------
local productByKey = Products.byKey
local keyByProductId: { [number]: string } = {}
local keyByPassId: { [number]: string } = {}
for _, p in Products.list do
	if p.id then
		if p.kind == "pass" then
			keyByPassId[p.id] = p.key
		else
			keyByProductId[p.id] = p.key
		end
	end
end

-- Shared grant path. Returns "granted" | "retry".
local function deliver(s: Data.Session, key: string, purchaseId: string): string
	local already = Game.hasReceipt(s.profile, purchaseId)
	local ok, msg = Game.grantProduct(s.profile, key, purchaseId)
	if not ok then
		warn("[Shop] could not grant", key, msg)
		return "retry"
	end
	if not already then
		GameService.notify(s.player, "purchase", { key = key, msg = msg })
		GameService.afterChange(s)
		GameService.sync(s)
	end
	-- the receipt is only acknowledged once it is safely stored
	if s.canSave and not Data.save(s, false) then
		return "retry"
	end
	if not s.canSave then
		-- save is disabled (load failed); do not acknowledge, Roblox will retry next visit
		return "retry"
	end
	return "granted"
end
Extras.deliver = deliver

MarketplaceService.ProcessReceipt = function(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local s = player and Data.get(player)
	local key = keyByProductId[info.ProductId]
	if not s or not key then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local r = deliver(s, key, tostring(info.PurchaseId))
	return if r == "granted" then Enum.ProductPurchaseDecision.PurchaseGranted else Enum.ProductPurchaseDecision.NotProcessedYet
end

local function checkPasses(s: Data.Session)
	for passId, key in keyByPassId do
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(s.player.UserId, passId)
		end)
		if ok and owns and not Game.hasReceipt(s.profile, "pass:" .. passId) then
			deliver(s, key, "pass:" .. passId)
		end
	end
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
	local s = Data.get(player)
	local key = keyByPassId[passId]
	if s and key and bought then
		deliver(s, key, "pass:" .. passId)
	end
end)

GameService.register("buyProduct", 1, function(s, key)
	local prod = if type(key) == "string" then productByKey[key] else nil
	if not prod then
		return
	end
	if Game.productOwned(s.profile, prod.key) then
		return GameService.toast(s.player, "You already own this", "info")
	end
	if not prod.id then
		return GameService.toast(s.player, "This item isn't on sale yet", "info")
	end
	if prod.kind == "pass" then
		MarketplaceService:PromptGamePassPurchase(s.player, prod.id)
	else
		MarketplaceService:PromptProductPurchase(s.player, prod.id)
	end
end)

local lastMock: { [number]: string } = {}
-- Studio-only test purchases. replay=true re-sends the previous receipt id (duplicate delivery);
-- fail=true simulates a failed grant (nothing changes, receipt not stored).
GameService.register("mockBuy", 0.3, function(s, key, replay, fail)
	if not (Config.MockPurchases and RunService:IsStudio()) then
		return
	end
	local prod = if type(key) == "string" then productByKey[key] else nil
	if not prod then
		return
	end
	if fail == true then
		GameService.toast(s.player, "Test purchase cancelled - nothing was charged or granted", "info")
		return
	end
	if Game.productOwned(s.profile, prod.key) and replay ~= true then
		return GameService.toast(s.player, "You already own this", "info")
	end
	local id = if replay == true and lastMock[s.player.UserId] then lastMock[s.player.UserId] else "mock-" .. HttpService:GenerateGUID(false)
	lastMock[s.player.UserId] = id
	local r = deliver(s, prod.key, id)
	print(string.format("[Shop][mock] %s key=%s receipt=%s -> %s", s.player.Name, prod.key, id, r))
	if replay == true then
		GameService.toast(s.player, "Duplicate receipt delivered - no second grant", "info")
	end
end)

-- Studio-only fast-forward hook for testers (never created in a live server):
--   game.ServerStorage.SHDDev:Invoke("cash", 1, 120)        -- cash = 1e120 for every player
--   game.ServerStorage.SHDDev:Invoke("lifetime", 3.08, 25)  -- lifetime cash (investors on offer)
--   game.ServerStorage.SHDDev:Invoke("investors", 1.5, 3)
--   game.ServerStorage.SHDDev:Invoke("evolutions", 12)
--   game.ServerStorage.SHDDev:Invoke("phone")               -- next phone offer now
--   game.ServerStorage.SHDDev:Invoke("offline", 3600)       -- run the returning-player flow as if away 1 hour
local function devHook()
	if not RunService:IsStudio() then
		return
	end
	local bf = Instance.new("BindableFunction")
	bf.Name = "SHDDev"
	bf.OnInvoke = function(cmd: string, a: number?, b: number?)
		for _, s in Data.sessions do
			local p = s.profile
			if cmd == "cash" then
				p.cash = BigNum.fromParts(a or 1, b or 0)
			elseif cmd == "lifetime" then
				p.lifetime = BigNum.fromParts(a or 1, b or 0)
			elseif cmd == "investors" then
				p.investors = BigNum.fromParts(a or 1, b or 0)
			elseif cmd == "evolutions" then
				p.evolutions = math.max(0, math.floor(a or 0))
			elseif cmd == "phone" then
				s.rt.offer = nil
				s.rt.phoneNext = os.time()
			elseif cmd == "offline" then
				p.lastSeen = os.time() - (a or 3600)
				Game.applyReturn(p, os.time())
				GameService.notify(s.player, "offline", { amount = p.pendingOffline })
			end
			GameService.afterChange(s)
			GameService.sync(s)
		end
		return "ok"
	end
	bf.Parent = game:GetService("ServerStorage")
end

function Extras.init()
	devHook()
	-- leaving mid-race: run it to the finish instantly and settle before the final save
	Data.onLeaving(function(s)
		local race = s.rt.race
		if race and not race.winner then
			local guard = 0
			while not race.winner and guard < 10000 do
				Dash.step(race, 0.1, roll)
				guard += 1
			end
			local pay = Dash.payout(race)
			if pay.m > 0 then
				Game.earn(s.profile, pay)
			end
			s.profile.stats.races = (s.profile.stats.races or 0) + 1
		end
		s.rt.race = nil
		s.rt.offer = nil
	end)
	task.spawn(spawnPickups)
	task.spawn(phoneLoop)
	GameService.onSessionLoaded(function(s)
		checkPasses(s)
	end)
	-- keep Format referenced for future toasts
	local _ = Format
end

return Extras
