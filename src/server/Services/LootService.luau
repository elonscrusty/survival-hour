--!nonstrict
-- Care packages (free daily + Robux-purchased, all public and contestable) and
-- hidden forest crates that restock each dawn.
--
-- Delivery queue (DECISIONS D25/D26):
--   * one free package per day, 20–40 s after dawn
--   * paid packages bought by day are queued immediately; bought at night they
--     wait for dawn (the shop says so before purchase)
--   * drops leave one at a time, QueueSpacing seconds apart, and never land
--     within 30 studs of another unopened package

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Products = require(Shared:WaitForChild("Products"))
local Net = require(Shared:WaitForChild("Net"))
local Loot = require(Shared:WaitForChild("Loot"))
local Models = Shared:WaitForChild("Models")
local LootModels = require(Models:WaitForChild("LootModels"))

local LootService = {}

type Package = { Id: number, Model: Model, Pos: Vector3, Landed: boolean, Opened: boolean, Source: string, Buyer: string? }
type Crate = { Id: number, Model: Model, Pos: Vector3, Spot: number }

local ctx: any
local queue: { { Source: string, Buyer: string?, BuyerId: number? } } = {}
local packages: { [number]: Package } = {}
local crates: { [number]: Crate } = {}
local usedSpots: { [number]: boolean } = {}
local lastSpots: { [number]: boolean } = {}
local nextId = 0
local lastDispatch = 0
local folder: Folder? = nil
local rng = Random.new()

function LootService.Init(c)
	ctx = c
	ctx.MatchService.On("MatchStarting", function(map)
		folder = Instance.new("Folder")
		folder.Name = "Loot"
		folder.Parent = map.Folder
		queue = {}
		packages = {}
		crates = {}
		usedSpots = {}
		lastSpots = {}
		LootService._restockCrates()
	end)
	ctx.MatchService.On("PhaseChanged", function(phase: string, day: number)
		if phase == "Day" then
			if day > 1 then
				LootService._restockCrates()
			end
			local delay = rng:NextNumber(Config.CarePackage.FreeDropDelayMin, Config.CarePackage.FreeDropDelayMax)
			task.delay(delay, function()
				if ctx.MatchService.Active and ctx.MatchService.Phase == "Day" then
					table.insert(queue, 1, { Source = "Free" })
				end
			end)
		elseif phase == "Night" and #queue > 0 then
			ctx.MatchService.Broadcast("PackagesQueued", { Count = #queue })
		end
	end)
	ctx.MatchService.On("MatchCleanup", function()
		queue = {}
		packages = {}
		crates = {}
		folder = nil
	end)
	ctx.ChannelService.OnPrompt("OpenPackage", LootService._onOpenPackage)
	ctx.ChannelService.OnPrompt("OpenCrate", LootService._onOpenCrate)
	ctx.Util.Connect("BuyInMatch", "Purchase", LootService._onBuy)
	ctx.PurchaseService.OnGranted("CarePackage", LootService._onPackageGranted)
end

function LootService.Start()
	while true do
		task.wait(1)
		if ctx.MatchService.Active and ctx.MatchService.Phase == "Day" and #queue > 0 then
			if os.clock() - lastDispatch >= Config.CarePackage.QueueSpacing then
				local entry = table.remove(queue, 1)
				if entry then
					lastDispatch = os.clock()
					LootService._drop(entry)
				end
			end
		end
	end
end

-- Care packages ---------------------------------------------------------------------------------

local function landingSpot(): Vector3?
	local map = ctx.MatchService.Map
	local candidates = table.clone(map.DropPoints)
	-- extra random spots near the centre ring and sector glades for variety
	for _ = 1, 8 do
		local a = rng:NextNumber() * math.pi * 2
		local d = rng:NextNumber(20, 60)
		local x, z = map.Origin.X + math.cos(a) * d, map.Origin.Z + math.sin(a) * d
		table.insert(candidates, Vector3.new(x, ctx.WorldService.GroundY(x, z), z))
	end
	for i = #candidates, 2, -1 do
		local j = rng:NextInteger(1, i)
		candidates[i], candidates[j] = candidates[j], candidates[i]
	end
	for _, pos in candidates do
		local ok = true
		for _, pk in packages do
			if not pk.Opened and (pk.Pos - pos).Magnitude < 30 then
				ok = false
				break
			end
		end
		if ok then
			for team = 1, Config.Match.TeamCount do
				local camp = ctx.CampService.GetCamp(team)
				if camp and (camp.FirePos - pos).Magnitude < Config.Build.ZoneRadius + 20 then
					ok = false
					break
				end
			end
		end
		if ok then
			local ground = ctx.WorldService.GroundY(pos.X, pos.Z)
			return Vector3.new(pos.X, ground, pos.Z)
		end
	end
	return nil
end

function LootService._drop(entry: { Source: string, Buyer: string?, BuyerId: number? })
	local pos = landingSpot()
	if not pos or not folder then
		table.insert(queue, 1, entry) -- retry later; never lose a paid drop
		return
	end
	nextId += 1
	local id = nextId
	local start = pos + Vector3.new(0, 160, 0)
	local model = LootModels.CarePackage(CFrame.new(start), folder)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local pk: Package = { Id = id, Model = model, Pos = pos, Landed = false, Opened = false, Source = entry.Source, Buyer = entry.Buyer }
	packages[id] = pk
	ctx.MatchService.Broadcast("CarePackage", {
		Id = id,
		X = pos.X,
		Z = pos.Z,
		Eta = workspace:GetServerTimeNow() + Config.CarePackage.FallTime,
		Source = entry.Source,
		Buyer = entry.Buyer,
	})
	-- Descend (server-driven, anchored)
	task.spawn(function()
		local steps = math.floor(Config.CarePackage.FallTime * 15)
		for i = 1, steps do
			if not model.Parent then
				return
			end
			local t = i / steps
			model:PivotTo(CFrame.new(start:Lerp(pos, t)) * CFrame.Angles(0, t * 2, math.sin(t * 20) * 0.03))
			task.wait(1 / 15)
		end
		if not model.Parent then
			return
		end
		-- Nudge anyone standing exactly on the landing spot so the box never lands inside them.
		for _, p in ctx.Util.MatchPlayers() do
			local r = ctx.Util.Root(p)
			if r and (r.Position - pos).Magnitude < 4 then
				local away = (r.Position - pos) * Vector3.new(1, 0, 1)
				away = if away.Magnitude > 0.1 then away.Unit else Vector3.new(1, 0, 0)
				r.CFrame += away * 4 + Vector3.new(0, 1, 0)
			end
		end
		model:PivotTo(CFrame.new(pos))
		LootModels.Land(model)
		pk.Landed = true
		ctx.Util.PlaySound("PackageLand", model.PrimaryPart)
		local prompt = ctx.ChannelService.MakePrompt(model.PrimaryPart, "OpenPackage", "Open", "Care Package", Config.CarePackage.OpenRange)
		prompt:SetAttribute("PackageId", id)
		ctx.MatchService.Broadcast("CarePackageLanded", { Id = id })
	end)
end

function LootService._onOpenPackage(p: Player, prompt: ProximityPrompt)
	local id = prompt:GetAttribute("PackageId") :: number?
	local pk = id and packages[id]
	if not pk or not pk.Landed or pk.Opened or not ctx.Util.IsAlive(p) or not p:GetAttribute("InMatch") then
		return
	end
	ctx.ChannelService.Begin(p, {
		Kind = "OpenPackage",
		Label = "Opening care package",
		Duration = Config.CarePackage.OpenTime,
		Range = Config.CarePackage.OpenRange,
		InterruptOnDamage = true,
		Action = "Open",
		TargetKey = id,
		Position = function()
			return if pk.Opened then nil else pk.Pos
		end,
		OnComplete = function()
			if pk.Opened then
				return
			end
			pk.Opened = true
			local rolls = Loot.RollCarePackage(function()
				return rng:NextNumber()
			end)
			local labels = {}
			for i, entry in rolls do
				table.insert(labels, entry.Label)
				for j, g in entry.Grants do
					local a = (i * 2.1 + j * 0.7)
					local off = Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(2.5, Config.CarePackage.LootScatter)
					ctx.InventoryService.SpawnPickup(g.Item, g.Count, pk.Pos + off + Vector3.new(0, 2, 0), nil, 300)
				end
			end
			ctx.Util.PlaySound("Open", pk.Model.PrimaryPart)
			Net.FireAll("Fx", "PackageOpen", { Pos = pk.Pos })
			pk.Model:Destroy()
			ctx.MatchService.Broadcast("CarePackageOpened", { Id = pk.Id, By = p.DisplayName, ByTeam = ctx.Util.Team(p) })
			ctx.Util.Notify(p, "Package contents: " .. table.concat(labels, ", "), "success")
		end,
	})
end

-- Purchases ---------------------------------------------------------------------------------------

function LootService._enqueuePaid(buyer: Player)
	table.insert(queue, { Source = "Paid", Buyer = buyer.DisplayName, BuyerId = buyer.UserId })
	local atDawn = ctx.MatchService.IsNight()
	ctx.MatchService.Broadcast("PackageCalled", { Buyer = buyer.DisplayName, AtDawn = atDawn, Position = #queue })
end

function LootService._onBuy(p: Player, req: any)
	if type(req) ~= "table" or not p:GetAttribute("InMatch") or not ctx.MatchService.IsPlaying() then
		return
	end
	if type(req.Kind) ~= "string" or not Products.OnSale(req.Kind) then
		ctx.Util.Notify(p, "That isn't sold — Survival Wars never sells gameplay advantages.", "info")
		return
	end
	if req.Kind == "CarePackage" then
		if not ctx.PurchaseService.PaidRandomAllowed(p) then
			ctx.Util.Notify(p, "Paid care packages aren't available in your region. The free daily package still drops for everyone!", "info")
			return
		end
		local session = ctx.DataService.Get(p)
		if session and session.Profile.Credits.CarePackage > 0 and ctx.DataService.CanGrant(p) then
			session.Profile.Credits.CarePackage -= 1
			task.spawn(ctx.DataService.Save, p, false)
			ctx.DataService.Push(p)
			LootService._enqueuePaid(p)
			return
		end
		local ok, why = ctx.PurchaseService.Prompt(p, "CarePackage", { MatchId = ctx.MatchService.MatchId })
		if not ok then
			ctx.Util.Notify(p, why or "Unavailable", "error")
		end
	elseif req.Kind == "Bandage" then
		local ok, why = ctx.PurchaseService.Prompt(p, "Bandage", { MatchId = ctx.MatchService.MatchId })
		if not ok then
			ctx.Util.Notify(p, why or "Unavailable", "error")
		end
	end
end

function LootService._onPackageGranted(p: Player)
	local session = ctx.DataService.Get(p)
	if p:GetAttribute("InMatch") and ctx.MatchService.IsPlaying() and session and session.Profile.Credits.CarePackage > 0 then
		session.Profile.Credits.CarePackage -= 1
		task.spawn(ctx.DataService.Save, p, false)
		ctx.DataService.Push(p)
		LootService._enqueuePaid(p)
	else
		ctx.Util.Notify(p, "Care package call saved as a credit — use it from the shop in your next match.", "info")
	end
end

-- Forest crates -------------------------------------------------------------------------------------

function LootService._restockCrates()
	local map = ctx.MatchService.Map
	if not map or not folder then
		return
	end
	local spots = map.Layout.CrateSpots
	local O = map.Origin
	for sector = 0, 4 do
		local want = if sector == 0 then Config.Crates.Center else Config.Crates.PerSector
		local have = 0
		for _, c in crates do
			if spots[c.Spot].Sector == sector then
				have += 1
			end
		end
		local options = {}
		for i, s in spots do
			if s.Sector == sector and not usedSpots[i] and not lastSpots[i] then
				table.insert(options, i)
			end
		end
		for i = #options, 2, -1 do
			local j = rng:NextInteger(1, i)
			options[i], options[j] = options[j], options[i]
		end
		for k = 1, math.min(want - have, #options) do
			local idx = options[k]
			local s = spots[idx]
			local x, z = s.X + O.X, s.Z + O.Z
			local pos = Vector3.new(x, ctx.WorldService.GroundY(x, z) - 0.1, z)
			nextId += 1
			local model = LootModels.ForestCrate(CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber() * 6.28, 0), folder)
			model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			local prompt = ctx.ChannelService.MakePrompt(model.PrimaryPart, "OpenCrate", "Open", "Supply Crate", Config.Crates.OpenRange)
			prompt:SetAttribute("CrateId", nextId)
			crates[nextId] = { Id = nextId, Model = model, Pos = pos, Spot = idx }
			usedSpots[idx] = true
		end
	end
	lastSpots = {}
end

function LootService._onOpenCrate(p: Player, prompt: ProximityPrompt)
	local id = prompt:GetAttribute("CrateId") :: number?
	local crate = id and crates[id]
	if not crate or not ctx.Util.IsAlive(p) or not p:GetAttribute("InMatch") then
		return
	end
	ctx.ChannelService.Begin(p, {
		Kind = "OpenCrate",
		Label = "Opening crate",
		Duration = Config.Crates.OpenTime,
		Range = Config.Crates.OpenRange,
		InterruptOnDamage = true,
		Action = "Open",
		Position = function()
			return if crates[crate.Id] then crate.Pos else nil
		end,
		OnComplete = function()
			if not crates[crate.Id] then
				return
			end
			crates[crate.Id] = nil
			usedSpots[crate.Spot] = nil
			lastSpots[crate.Spot] = true -- next restock picks a different spot
			local entry = Loot.Roll(Loot.Crate, function()
				return rng:NextNumber()
			end)
			for j, g in entry.Grants do
				local off = Vector3.new(math.cos(j * 2.1), 0, math.sin(j * 2.1)) * 2
				ctx.InventoryService.SpawnPickup(g.Item, g.Count, crate.Pos + off + Vector3.new(0, 1.5, 0))
			end
			ctx.Util.PlaySound("Open", crate.Model.PrimaryPart)
			crate.Model:Destroy()
			ctx.PowerupService.OnCrateOpened(p, crate.Id)
		end,
	})
end

function LootService.CratesNear(pos: Vector3, radius: number): { Vector3 }
	local out = {}
	for _, c in crates do
		if (c.Pos - pos).Magnitude <= radius then
			table.insert(out, c.Pos)
		end
	end
	return out
end

return LootService
