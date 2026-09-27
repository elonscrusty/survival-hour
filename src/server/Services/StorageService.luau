--!nonstrict
-- Shared team storage built by players. Teammates deposit/withdraw; enemies
-- can steal (3 s channel, interrupted by damage). All transfers go through
-- StorageLedger, which validates and moves resources in one synchronous step.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Logic = Shared:WaitForChild("Logic")
local StorageLedger = require(Logic:WaitForChild("StorageLedger"))
local InventoryModel = require(Logic:WaitForChild("InventoryModel"))

local StorageService = {}

type Entry = { Store: StorageLedger.Store, Structure: any, Key: string }

local ctx: any
local byKey: { [string]: Entry } = {}
local viewers: { [Player]: string } = {} -- player -> storage key they have open
local lastTheftAlert: { [string]: number } = {}

function StorageService.Init(c)
	ctx = c
	ctx.Util.Connect("StorageAction", "Interact", StorageService._onAction)
	ctx.ChannelService.OnPrompt("StorageOpen", StorageService._onOpen)
	ctx.ChannelService.OnPrompt("StorageSteal", StorageService._onOpen)
	ctx.MatchService.On("MatchCleanup", function()
		byKey = {}
		viewers = {}
	end)
	ctx.Util.OnPlayerRemoving(function(p)
		viewers[p] = nil
	end)
end

function StorageService.Register(s: any)
	local e: Entry = { Store = StorageLedger.New(Config.Storage.Capacity), Structure = s, Key = s.Key }
	byKey[s.Key] = e
	s.Model:SetAttribute("StorageKey", s.Key)
	local root = s.Model.PrimaryPart
	local open = ctx.ChannelService.MakePrompt(root, "StorageOpen", "Open", "Team Storage", Config.Storage.InteractRange, "Team", s.Team)
	open:SetAttribute("StorageKey", s.Key)
	local steal = ctx.ChannelService.MakePrompt(root, "StorageSteal", "Steal", "Enemy Storage", Config.Storage.InteractRange, "Enemy", s.Team)
	steal:SetAttribute("StorageKey", s.Key)
	steal.KeyboardKeyCode = Enum.KeyCode.G
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

local function send(p: Player, e: Entry)
	local mode = if ctx.Util.Team(p) == e.Structure.Team then "Owner" else "Steal"
	Net.FireClient("StorageSync", p, e.Key, e.Store.Items, mode, e.Store.Capacity)
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

function StorageService._onOpen(p: Player, prompt: ProximityPrompt)
	local key = prompt:GetAttribute("StorageKey") :: string?
	local e = key and byKey[key]
	if not e or not ctx.Util.IsAlive(p) then
		return
	end
	local isOwner = ctx.Util.Team(p) == e.Structure.Team
	if prompt:GetAttribute("Action") == "StorageSteal" and isOwner then
		return
	end
	if prompt:GetAttribute("Action") == "StorageOpen" and not isOwner then
		return
	end
	viewers[p] = e.Key
	send(p, e)
end

local function inRange(p: Player, e: Entry): boolean
	local model = e.Structure.Model
	return model.Parent ~= nil and ctx.Util.DistTo(p, model:GetPivot().Position) <= Config.Storage.InteractRange + 3
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
	if req.Action == "Close" then
		viewers[p] = nil
		return
	end
	if req.Action == "Steal" then
		if isOwner or type(req.Resource) ~= "string" or not InventoryModel.IsResource(req.Resource) then
			return
		end
		StorageService._beginSteal(p, e, req.Resource)
		return
	end
	if not isOwner then
		return
	end
	if req.Action == "DepositAll" then
		local moved = 0
		for _, id in InventoryModel.ResourceIds do
			moved += StorageLedger.Deposit(e.Store, inv, id, inv.Resources[id])
		end
		if moved == 0 then
			ctx.Util.Notify(p, if StorageLedger.Free(e.Store) == 0 then "Storage is full." else "Nothing to deposit.", "info")
		end
	elseif req.Action == "Deposit" or req.Action == "Withdraw" then
		if type(req.Resource) ~= "string" or not ctx.Util.IsInt(req.Count, 1, 200) then
			return
		end
		local moved
		if req.Action == "Deposit" then
			moved = StorageLedger.Deposit(e.Store, inv, req.Resource, req.Count)
		else
			moved = StorageLedger.Withdraw(e.Store, inv, req.Resource, req.Count)
			if moved == 0 and InventoryModel.FreeSpace(inv) == 0 then
				ctx.Util.Notify(p, "Your pack is full.", "warn")
			end
		end
	else
		return
	end
	ctx.InventoryService.Sync(p)
	StorageService.SyncTeam(e.Structure.Team)
end

function StorageService._beginSteal(p: Player, e: Entry, resource: string)
	if (e.Store.Items[resource] or 0) <= 0 then
		ctx.Util.Notify(p, "There's none of that to steal.", "info")
		return
	end
	local inv = ctx.InventoryService.Get(p)
	if not inv or InventoryModel.FreeSpace(inv) <= 0 then
		ctx.Util.Notify(p, "Your pack is full.", "warn")
		return
	end
	local model = e.Structure.Model
	ctx.ChannelService.Begin(p, {
		Kind = "Steal",
		Label = "Stealing " .. resource,
		Duration = Config.Storage.StealDuration,
		Range = Config.Storage.InteractRange,
		InterruptOnDamage = true,
		Action = "Steal",
		TargetKey = e.Key,
		Position = function()
			return if model.Parent and byKey[e.Key] then model:GetPivot().Position else nil
		end,
		OnComplete = function()
			local invNow = ctx.InventoryService.Get(p)
			if not invNow or not byKey[e.Key] then
				return
			end
			local got = StorageLedger.Withdraw(e.Store, invNow, resource, Config.Storage.StealAmount)
			if got > 0 then
				ctx.Util.Notify(p, string.format("Stole %d %s!", got, resource), "success")
				ctx.InventoryService.Sync(p)
				StorageService.SyncTeam(e.Structure.Team)
				send(p, e)
			end
		end,
	})
	local t = os.clock()
	if t - (lastTheftAlert[e.Key] or 0) > 8 then
		lastTheftAlert[e.Key] = t
		for _, mate in ctx.Util.TeamPlayers(e.Structure.Team) do
			Net.FireClient("MatchEvent", mate, "StorageRaided", { Pos = model:GetPivot().Position, ByTeam = ctx.Util.Team(p) })
		end
	end
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
