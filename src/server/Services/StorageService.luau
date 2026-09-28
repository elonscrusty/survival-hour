--!nonstrict
-- Player-built storage (Wooden Crate I, Reinforced Chest II, Metal Locker III,
-- Survival Safe IV). Capacity is in stack slots (Items[id].Stacks).
--
-- Raids (spec): enemies BREACH a storage to unlock it. Breaching never deletes
-- anything: once breached, any enemy can open it and take what fits in their pack.
-- The owner can RESECURE it (short hold + a few materials). Breach time depends on
-- the storage tier and the tool: any axe/pickaxe on low tiers, a Crowbar for Metal
-- Lockers, a Sledgehammer for Survival Safes, or a Breaching Charge on anything.
-- Breaches are loud: players nearby get a warning, the owner gets a direction.
-- All transfers go through StorageLedger (validated, single synchronous step).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Items = require(Shared:WaitForChild("Items"))
local Net = require(Shared:WaitForChild("Net"))
local Logic = Shared:WaitForChild("Logic")
local StorageLedger = require(Logic:WaitForChild("StorageLedger"))
local InventoryModel = require(Logic:WaitForChild("InventoryModel"))
local Models = Shared:WaitForChild("Models")
local Structures = require(Models:WaitForChild("Structures"))

local StorageService = {}

type Entry = { Store: StorageLedger.Store, Structure: any, Key: string, Tier: number, Breached: boolean }

local ctx: any
local byKey: { [string]: Entry } = {}
local viewers: { [Player]: string } = {} -- player -> storage key they have open
local lastAlert: { [string]: number } = {}
local S = Config.Storage

function StorageService.Init(c)
	ctx = c
	ctx.Util.Connect("StorageAction", "Interact", StorageService._onAction)
	ctx.ChannelService.OnPrompt("StorageOpen", StorageService._onOpen)
	ctx.ChannelService.OnPrompt("StorageSteal", StorageService._onEnemyPrompt)
	ctx.ChannelService.OnPrompt("StorageResecure", StorageService._onResecure)
	ctx.MatchService.On("MatchCleanup", function()
		byKey = {}
		viewers = {}
		lastAlert = {}
	end)
	ctx.Util.OnPlayerRemoving(function(p)
		viewers[p] = nil
	end)
end

local function roman(n: number): string
	return ({ "I", "II", "III", "IV", "V" })[n] or tostring(n)
end

function StorageService.Register(s: any)
	local def = Items[s.Id]
	local e: Entry = {
		Store = StorageLedger.New(def.Stacks or S.Capacity),
		Structure = s,
		Key = s.Key,
		Tier = def.Tier or 1,
		Breached = false,
	}
	byKey[s.Key] = e
	s.Model:SetAttribute("StorageKey", s.Key)
	local root = s.Model.PrimaryPart
	local open = ctx.ChannelService.MakePrompt(root, "StorageOpen", "Open", def.Name, S.InteractRange, "Team", s.Team)
	open:SetAttribute("StorageKey", s.Key)
	local enemy = ctx.ChannelService.MakePrompt(root, "StorageSteal", "Hold: Breach", "Enemy " .. def.Name, S.InteractRange, "Enemy", s.Team)
	enemy:SetAttribute("StorageKey", s.Key)
	enemy.KeyboardKeyCode = Enum.KeyCode.G
	local resecure = ctx.ChannelService.MakePrompt(root, "StorageResecure", "Hold: Resecure", def.Name, S.InteractRange, "Team", s.Team)
	resecure:SetAttribute("StorageKey", s.Key)
	resecure.KeyboardKeyCode = Enum.KeyCode.R
	resecure.UIOffset = Vector2.new(0, 72)
	resecure.Enabled = false
end

function StorageService.TeamStores(team: number): { StorageLedger.Store }
	local out = {}
	for _, e in byKey do
		if e.Structure.Team == team then
			table.insert(out, e.Store)
		end
	end
	return out
end

function StorageService.TeamTotals(team: number): { [string]: number }
	local totals = {}
	for _, id in InventoryModel.ResourceIds do
		totals[id] = 0
	end
	for _, st in StorageService.TeamStores(team) do
		for id, n in st.Items do
			totals[id] += n
		end
	end
	return totals
end

local function mode(p: Player, e: Entry): string
	if ctx.Util.Team(p) == e.Structure.Team then
		return "Owner"
	end
	return if e.Breached then "Loot" else "Locked"
end

local function send(p: Player, e: Entry)
	Net.FireClient("StorageSync", p, e.Key, e.Store.Items, mode(p, e), e.Store.Capacity, {
		Name = Items[e.Structure.Id].Name,
		Tier = e.Tier,
		Breached = e.Breached,
		SlotsUsed = StorageLedger.SlotsUsed(e.Store),
	})
end

local function refreshViewers(e: Entry)
	for p, key in viewers do
		if key == e.Key and p.Parent then
			send(p, e)
		end
	end
end

function StorageService.SyncTeam(team: number)
	for p, key in viewers do
		local e = byKey[key]
		if e and p.Parent then
			send(p, e)
		end
	end
	for _, p in ctx.Util.TeamPlayers(team) do
		ctx.CraftService.Push(p)
	end
end

local function setBreached(e: Entry, breached: boolean)
	e.Breached = breached
	Structures.SetBreached(e.Structure.Model, breached)
	local resecure = e.Structure.Model.PrimaryPart:FindFirstChild("StorageResecurePrompt")
	if resecure then
		resecure.Enabled = breached
	end
	local enemy = e.Structure.Model.PrimaryPart:FindFirstChild("StorageStealPrompt")
	if enemy then
		enemy.ActionText = if breached then "Loot" else "Hold: Breach"
	end
	refreshViewers(e)
end

function StorageService.IsBreached(key: string): boolean
	local e = byKey[key]
	return e ~= nil and e.Breached
end

-- Opening ------------------------------------------------------------------------------------

function StorageService._onOpen(p: Player, prompt: ProximityPrompt)
	local key = prompt:GetAttribute("StorageKey") :: string?
	local e = key and byKey[key]
	if not e or not ctx.Util.IsAlive(p) or ctx.Util.Team(p) ~= e.Structure.Team then
		return
	end
	viewers[p] = e.Key
	send(p, e)
end

-- Enemy prompt: loot if breached, else start breaching.
function StorageService._onEnemyPrompt(p: Player, prompt: ProximityPrompt)
	local key = prompt:GetAttribute("StorageKey") :: string?
	local e = key and byKey[key]
	if not e or not ctx.Util.IsAlive(p) or ctx.Util.Team(p) == e.Structure.Team then
		return
	end
	if e.Breached then
		viewers[p] = e.Key
		send(p, e)
		return
	end
	StorageService._beginBreach(p, e, prompt)
end

-- Breach method for the player's gear: returns seconds, a label and whether a charge is used.
function StorageService.BreachPlan(p: Player, tier: number): (number?, string, boolean)
	local inv = ctx.InventoryService.Get(p)
	if not inv then
		return nil, "", false
	end
	if (inv.Resources.BreachingCharge or 0) > 0 then
		return S.ChargeTime, "Breaching Charge", true
	end
	local best, bestMult = nil, 1.01
	local hasTool = false
	for _, slot in InventoryModel.SlotNames do
		local st = inv.Slots[slot]
		local def = st and Items[st.Id]
		if def and (def.BreachTool or def.ToolType) then
			hasTool = true
			local mult = if def.BreachTool then S.BreachToolMult[def.BreachTool] else 1
			if mult < bestMult then
				best, bestMult = def, mult
			end
		end
	end
	local need = S.BreachNeeds[tier]
	if need == "Crowbar" and not (best and (best.BreachTool == "Crowbar" or best.BreachTool == "Sledgehammer")) then
		return nil, "a Crowbar or better", false
	elseif need == "Sledgehammer" and not (best and best.BreachTool == "Sledgehammer") then
		return nil, "a Sledgehammer or a Breaching Charge", false
	elseif not hasTool then
		return nil, "an axe, pickaxe or breaching tool", false
	end
	local secs = S.BreachTimes[math.clamp(tier, 1, #S.BreachTimes)] * bestMult / ctx.PowerupService.BreachSpeedMult(p)
	return secs, if best then best.Name else "tool", false
end

local function alertBreach(p: Player, e: Entry, loud: boolean)
	local pos = e.Structure.Model:GetPivot().Position
	local t = os.clock()
	if t - (lastAlert[e.Key] or 0) < 6 and not loud then
		return
	end
	lastAlert[e.Key] = t
	local camp = ctx.CampService.GetCamp(e.Structure.Team)
	local dir = if camp then (pos - camp.FirePos) * Vector3.new(1, 0, 1) else Vector3.zero
	local bearingDeg = if dir.Magnitude > 0.1 then math.deg(math.atan2(dir.X, -dir.Z)) % 360 else nil
	for _, mate in ctx.Util.TeamPlayers(e.Structure.Team) do
		Net.FireClient("MatchEvent", mate, "StorageRaided", { Bearing = bearingDeg, Name = Items[e.Structure.Id].Name })
	end
	-- Raids are loud: anyone near hears it (no position, just that it's close).
	for _, other in ctx.Util.MatchPlayers() do
		if other ~= p and ctx.Util.Team(other) ~= e.Structure.Team and ctx.Util.DistTo(other, pos) <= S.NoiseRadius * ctx.PowerupService.BreachNoiseMult(p) then
			Net.FireClient("MatchEvent", other, "RaidNoise", { Loud = loud })
		end
	end
	ctx.Util.PlaySound(if loud then "Explosion" else "Breach", e.Structure.Model.PrimaryPart)
end

function StorageService._beginBreach(p: Player, e: Entry, prompt: ProximityPrompt?)
	local secs, how, useCharge = StorageService.BreachPlan(p, e.Tier)
	local def = Items[e.Structure.Id]
	if not secs then
		ctx.Util.Notify(p, def.Name .. " (Tier " .. roman(e.Tier) .. ") needs " .. how .. " to breach.", "error")
		return
	end
	local model = e.Structure.Model
	local noise = 0
	ctx.ChannelService.Begin(p, {
		Kind = "Breach",
		Label = string.format("Breaching the %s (%s)", def.Name, how),
		Duration = secs,
		Range = S.InteractRange,
		Hold = true,
		Prompt = prompt,
		InterruptOnDamage = true,
		MoveTolerance = 3,
		Action = if useCharge then "Gather" else "Breach",
		TargetKey = e.Key,
		Position = function()
			return if model.Parent and byKey[e.Key] then model:GetPivot().Position else nil
		end,
		CanContinue = function()
			noise += 1
			if noise % 20 == 0 then -- every ~2 s: banging on the lock
				alertBreach(p, e, false)
			end
			if e.Breached then
				return false, "Already breached."
			end
			return true
		end,
		OnComplete = function()
			if not byKey[e.Key] or e.Breached then
				return
			end
			local inv = ctx.InventoryService.Get(p)
			if useCharge then
				if not inv or InventoryModel.TakeResource(inv, "BreachingCharge", 1) ~= 1 then
					return
				end
				ctx.InventoryService.Sync(p)
				local pos = model:GetPivot().Position
				Net.FireAll("Fx", "StructureBreak", { Pos = pos, Id = "Explosion" })
				for _, other in ctx.Util.MatchPlayers() do
					if other ~= p and ctx.Util.DistTo(other, pos) <= S.ChargeRadius then
						ctx.CombatService.DamagePlayer(other, S.ChargeDamage, { Kind = "Explosion", By = p, Name = "Breaching Charge", Pos = pos })
					end
				end
			else
				local _, slot = ctx.InventoryService.EquippedItem(p)
				if slot then
					ctx.InventoryService.Wear(p, slot, 3 * ctx.PowerupService.BreachWear(p))
				end
			end
			setBreached(e, true)
			ctx.PowerupService.Tally(p, "Breaches", 1)
			ctx.EventService.Note("Raid")
			alertBreach(p, e, true)
			ctx.Util.NotifyTeam(e.Structure.Team, "⚠ Your " .. def.Name .. " was BREACHED! Resecure it (hold R at the storage).", "danger")
			ctx.Util.Notify(p, "Breached! Open it to loot.", "success")
			viewers[p] = e.Key
			send(p, e)
		end,
	})
	alertBreach(p, e, useCharge)
end

-- Resecuring -----------------------------------------------------------------------------------

function StorageService._onResecure(p: Player, prompt: ProximityPrompt)
	local key = prompt:GetAttribute("StorageKey") :: string?
	local e = key and byKey[key]
	if not e or not e.Breached or ctx.Util.Team(p) ~= e.Structure.Team or not ctx.Util.IsAlive(p) then
		return
	end
	local def = Items[e.Structure.Id]
	local cost = S.ResecureCost[def.Material or "Wood"] or S.ResecureCost.Wood
	local inv = ctx.InventoryService.Get(p)
	if not inv or not StorageLedger.CanPayCombined(cost, inv, StorageService.TeamStores(e.Structure.Team)) then
		local id, n = next(cost)
		ctx.Util.Notify(p, string.format("Resecuring needs %d %s.", n, Items[id].Name), "warn")
		return
	end
	local model = e.Structure.Model
	ctx.ChannelService.Begin(p, {
		Kind = "Resecure",
		Label = "Resecuring the " .. def.Name,
		Duration = S.ResecureTime,
		Range = S.InteractRange,
		Hold = true,
		Prompt = prompt,
		InterruptOnDamage = true,
		Action = "Chop",
		Position = function()
			return if model.Parent and byKey[e.Key] then model:GetPivot().Position else nil
		end,
		OnComplete = function()
			local invNow = ctx.InventoryService.Get(p)
			if not byKey[e.Key] or not e.Breached or not invNow then
				return
			end
			if not StorageLedger.PayCombined(cost, invNow, StorageService.TeamStores(e.Structure.Team)) then
				return
			end
			ctx.InventoryService.Sync(p)
			setBreached(e, false)
			-- kick enemy viewers out
			for viewer, vkey in viewers do
				if vkey == e.Key and ctx.Util.Team(viewer) ~= e.Structure.Team then
					viewers[viewer] = nil
					Net.FireClient("StorageSync", viewer, e.Key, nil, "Closed", 0)
				end
			end
			ctx.Util.Notify(p, "Storage resecured.", "success")
			StorageService.SyncTeam(e.Structure.Team)
		end,
	})
end

-- Transfers -----------------------------------------------------------------------------------

local function inRange(p: Player, e: Entry): boolean
	local model = e.Structure.Model
	return model.Parent ~= nil and ctx.Util.DistTo(p, model:GetPivot().Position) <= S.InteractRange + 3
end

function StorageService._onAction(p: Player, req: any)
	if type(req) ~= "table" or type(req.Key) ~= "string" or type(req.Action) ~= "string" then
		return
	end
	local e = byKey[req.Key]
	local inv = ctx.InventoryService.Get(p)
	if not e or not inv or not ctx.Util.IsAlive(p) or not inRange(p, e) then
		return
	end
	local isOwner = ctx.Util.Team(p) == e.Structure.Team
	local action: string = req.Action
	if action == "Close" then
		viewers[p] = nil
		return
	end
	-- Enemies may only take from a breached storage.
	local taking = action == "Withdraw" or action == "TakeAll"
	if not isOwner and not (e.Breached and taking) then
		return
	end
	if action == "DepositAll" then
		local moved = 0
		for _, id in InventoryModel.ResourceIds do
			moved += StorageLedger.Deposit(e.Store, inv, id, inv.Resources[id])
		end
		if moved == 0 then
			ctx.Util.Notify(p, if StorageLedger.Free(e.Store) == 0 then "Storage is full." else "Nothing to deposit.", "info")
		end
	elseif action == "TakeAll" then
		local moved = 0
		for _, id in InventoryModel.ResourceIds do
			moved += StorageLedger.Withdraw(e.Store, inv, id, e.Store.Items[id] or 0)
		end
		if moved == 0 then
			ctx.Util.Notify(p, "Your pack is full (or the storage is empty).", "info")
		end
	elseif action == "Deposit" or action == "Withdraw" then
		if type(req.Resource) ~= "string" or not ctx.Util.IsInt(req.Count, 1, 999) then
			return
		end
		local moved
		if action == "Deposit" then
			moved = StorageLedger.Deposit(e.Store, inv, req.Resource, req.Count)
		else
			moved = StorageLedger.Withdraw(e.Store, inv, req.Resource, req.Count)
			if moved == 0 and InventoryModel.SpaceFor(inv, req.Resource) == 0 then
				ctx.Util.Notify(p, "Your pack is full.", "warn")
			end
		end
	else
		return
	end
	ctx.InventoryService.Sync(p)
	if not isOwner then
		alertBreach(p, e, false)
	end
	refreshViewers(e)
	StorageService.SyncTeam(e.Structure.Team)
end

function StorageService.OnDestroyed(s: any, pos: Vector3)
	local e = byKey[s.Key]
	if not e then
		return
	end
	byKey[s.Key] = nil
	local contents = {}
	local any = false
	for id, n in e.Store.Items do
		if n > 0 then
			contents[id] = n
			any = true
		end
	end
	if any then
		ctx.InventoryService.SpawnBag(contents, pos, Config.Teams[s.Team].Color, "Spilled Storage")
	end
	for p, key in viewers do
		if key == s.Key then
			viewers[p] = nil
			Net.FireClient("StorageSync", p, s.Key, nil, "Closed", 0)
		end
	end
	StorageService.SyncTeam(s.Team)
end

return StorageService
