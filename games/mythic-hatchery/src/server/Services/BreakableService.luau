--!nonstrict
-- Breakables: coin piles, crates, chests, gem rocks and big chests spawned in
-- each island's zones (up to Area.MaxBreakables). Players aim their equipped
-- pets at one with SetTarget; every Config.PetDamageInterval each player's
-- pets deal (total power * Config.PetDamagePerPower) damage. When a breakable
-- breaks, coins and gems are split by damage dealt, pets earn XP, and the
-- model respawns somewhere in the island after Config.BreakableRespawn.
-- Auto Farm (pass + setting) picks the nearest breakable on an opened island.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Areas = require(Shared:WaitForChild("Areas"))
local Models = require(Shared:WaitForChild("Models"))
local Logic = Shared:WaitForChild("Logic")
local Economy = require(Logic:WaitForChild("Economy"))
local Inventory = require(Logic:WaitForChild("Inventory"))
local Rewards = require(Logic:WaitForChild("Rewards"))
local Schema = require(Logic:WaitForChild("Schema"))

local BreakableService = {}

local ctx: any
local folder: Folder
local random = Random.new()
local nextId = 0
local breakables: { [string]: any } = {}
local countByArea: { [string]: number } = {}
local targets: { [Player]: string } = {}

-- Footprint radius per kind (studs, from the model's width). Two breakables
-- spawn at least radiusA + radiusB + GAP apart so they never overlap.
local RADIUS: { [string]: number } = {
	CoinPile = 2,
	Crate = 2.5,
	Chest = 3,
	GemRock = 2.5,
	BigChest = 4.5,
}
local DEFAULT_RADIUS = 3
local GAP = 1
local PICK_TRIES = 10 -- retry cap per spawn

local function radiusOf(kind: string): number
	return RADIUS[kind] or DEFAULT_RADIUS
end
local EDGE = 4 -- keep this far inside a zone's edge
local BROKEN_RADIUS = 250 -- players this close see the break effect
local LEASH = 25 -- extra studs past MaxTargetDistance before pets are recalled

function BreakableService.Init(c)
	ctx = c
	local existing = workspace:FindFirstChild("Breakables")
	if existing then
		existing:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Breakables"
	folder.Parent = workspace

	ctx.Util.OnPlayerRemoving(function(p)
		targets[p] = nil
		for _, b in breakables do
			b.Damage[p] = nil
		end
	end)

	ctx.Util.Event("SetTarget", function(player, s, id)
		if id == nil or id == "" then
			BreakableService.ClearTarget(player)
			return
		end
		if not ctx.Util.IsStr(id, 32) then
			return
		end
		local b = breakables[id]
		if not b then
			return
		end
		if not s.Profile.Areas[b.Area] then
			ctx.Util.Toast(player, "Open this island first", "bad")
			return
		end
		if ctx.Util.DistTo(player, b.Position) > Config.MaxTargetDistance then
			return
		end
		BreakableService.SetTarget(player, id)
	end)
end

function BreakableService.Start()
	for _, area in Areas.List do
		countByArea[area.Id] = 0
		for _ = 1, area.MaxBreakables do
			BreakableService._spawn(area.Id)
		end
	end
	while true do
		task.wait(Config.PetDamageInterval)
		local ok, err = pcall(BreakableService._tick)
		if not ok then
			warn("[BreakableService] tick failed:", err)
		end
	end
end

function BreakableService.SetTarget(player: Player, id: string)
	targets[player] = id
	player:SetAttribute("Target", id)
end

function BreakableService.ClearTarget(player: Player)
	if targets[player] ~= nil then
		targets[player] = nil
	end
	if player.Parent ~= nil and player:GetAttribute("Target") ~= "" then
		player:SetAttribute("Target", "")
	end
end

function BreakableService.Get(id: string): any
	return breakables[id]
end

-- Spawning ----------------------------------------------------------------------

local function pickKind(area: Areas.Area): Areas.Breakable
	local total = 0
	for _, k in area.Breakables do
		total += k.Weight
	end
	local roll = random:NextNumber() * total
	for _, k in area.Breakables do
		roll -= k.Weight
		if roll < 0 then
			return k
		end
	end
	return area.Breakables[1]
end

local function pickPosition(areaId: string, kind: string): Vector3?
	local zones = ctx.WorldService.Info.Zones[areaId]
	if not zones or #zones == 0 then
		return nil
	end
	local totalArea = 0
	for _, z in zones do
		totalArea += math.max(1, z.Size.X * z.Size.Z)
	end
	local radius = radiusOf(kind)
	for _ = 1, PICK_TRIES do
		local roll = random:NextNumber() * totalArea
		local zone = zones[1]
		for _, z in zones do
			roll -= math.max(1, z.Size.X * z.Size.Z)
			if roll < 0 then
				zone = z
				break
			end
		end
		local inset = math.max(EDGE, radius + GAP)
		local hx = math.max(0, zone.Size.X / 2 - inset)
		local hz = math.max(0, zone.Size.Z / 2 - inset)
		local pos = zone.Center + Vector3.new(random:NextNumber(-hx, hx), 0, random:NextNumber(-hz, hz))
		local clear = true
		for _, b in breakables do
			if b.Area == areaId and (b.Position - pos).Magnitude < radius + radiusOf(b.Kind) + GAP then
				clear = false
				break
			end
		end
		if clear then
			return pos
		end
	end
	return nil
end

function BreakableService._spawn(areaId: string)
	local area = Areas.ById[areaId]
	if not area or (countByArea[areaId] or 0) >= area.MaxBreakables then
		return
	end
	local kind = pickKind(area)
	local pos = pickPosition(areaId, kind.Kind)
	if not pos then
		-- Zone crowded right now: try again later (only if the island has zones).
		local zones = ctx.WorldService.Info.Zones[areaId]
		if zones and #zones > 0 then
			task.delay(random:NextNumber(5, 10), BreakableService._spawn, areaId)
		end
		return
	end
	local ok, model = pcall(Models.Breakable, kind.Kind, areaId)
	if not ok or typeof(model) ~= "Instance" or not model:IsA("Model") then
		warn("[BreakableService] Models.Breakable failed:", model)
		return
	end
	nextId += 1
	local id = "B" .. nextId
	local hp = math.max(1, math.floor(kind.Hp * area.CoinMult))
	model.Name = kind.Kind
	model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0))
	model:SetAttribute("Id", id)
	model:SetAttribute("Kind", kind.Kind)
	model:SetAttribute("Area", areaId)
	model:SetAttribute("Hp", hp)
	model:SetAttribute("MaxHp", hp)
	CollectionService:AddTag(model, "Breakable")
	model.Parent = folder
	breakables[id] = {
		Id = id,
		Kind = kind.Kind,
		Area = areaId,
		Model = model,
		Position = pos,
		Hp = hp,
		MaxHp = hp,
		Coins = kind.Coins * area.CoinMult,
		Gems = kind.Gems or 0,
		Damage = {},
	}
	countByArea[areaId] = (countByArea[areaId] or 0) + 1
end

-- Damage ------------------------------------------------------------------------

local function nearest(player: Player, s): string?
	local pos = ctx.Util.Position(player)
	if not pos then
		return nil
	end
	local best, bestDist = nil, Config.MaxTargetDistance
	for id, b in breakables do
		if s.Profile.Areas[b.Area] then
			local d = (b.Position - pos).Magnitude
			if d < bestDist then
				best, bestDist = id, d
			end
		end
	end
	return best
end

function BreakableService._tick()
	local hit: { [string]: boolean } = {}
	for _, player in Players:GetPlayers() do
		local s = ctx.DataService.Get(player)
		if not s then
			continue
		end
		local id = targets[player]
		local b = id and breakables[id]
		if id and (not b or not s.Profile.Areas[b.Area]
			or ctx.Util.DistTo(player, b.Position) > Config.MaxTargetDistance + LEASH) then
			BreakableService.ClearTarget(player)
			b = nil
		end
		if not b and s.Profile.Passes.AutoFarm and s.Profile.Settings.AutoFarm == true then
			local auto = nearest(player, s)
			if auto then
				BreakableService.SetTarget(player, auto)
				b = breakables[auto]
			end
		end
		if not b or b.Hp <= 0 then
			continue
		end
		local damage = Inventory.EquippedPower(s.Profile) * Config.PetDamagePerPower
		if not Schema.IsFinite(damage) or damage <= 0 then
			continue
		end
		local applied = math.min(damage, b.Hp)
		b.Hp -= applied
		b.Damage[player] = (b.Damage[player] or 0) + applied
		hit[b.Id] = true
	end
	for id in hit do
		local b = breakables[id]
		if b then
			if b.Hp <= 0 then
				BreakableService._break(b)
			else
				b.Model:SetAttribute("Hp", math.ceil(b.Hp))
			end
		end
	end
end

function BreakableService._break(b)
	breakables[b.Id] = nil
	countByArea[b.Area] = math.max(0, (countByArea[b.Area] or 1) - 1)
	-- Split by damage among contributors still here (Logic/Economy.SplitBreak:
	-- exact gem total, credit only for >= 5% of the damage).
	local who: { Player } = {}
	local damage: { number } = {}
	for player, dmg in b.Damage do
		if player.Parent ~= nil and ctx.DataService.Get(player) then
			table.insert(who, player)
			table.insert(damage, dmg)
		end
	end
	local shares = Economy.SplitBreak(damage, b.Coins, b.Gems)
	local now = os.time()
	for i, player in who do
		local s = ctx.DataService.Get(player)
		local share = shares[i]
		local p = s.Profile
		local coins = Economy.AddCoins(p, share.Coins * ctx.StateService.CoinMult(s), true)
		-- Breakable gems are capped per player per rolling hour (Auto Farm
		-- must not turn into a gem printer).
		local gemsAllowed = Economy.CapRolling(s.BreakGemLog, os.clock(), share.Gems, Config.BreakGemsPerHour, 3600)
		local gems = Economy.AddGems(p, gemsAllowed)
		if share.Credit then
			p.Stats.Broken = math.min(Schema.MaxStat, p.Stats.Broken + 1)
			Rewards.AddQuestProgress(p, "Break", 1, now)
			ctx.PetService.GiveXp(player, s, Config.XpPerBreak)
		end
		Rewards.AddQuestProgress(p, "Coins", coins, now)
		if coins > 0 or gems > 0 then
			ctx.Util.Notify(player, "Reward", {
				Coins = if coins > 0 then coins else nil,
				Gems = if gems > 0 then gems else nil,
				Position = b.Position,
			})
		end
		ctx.StateService.Dirty(player)
	end
	local info = { Id = b.Id, Kind = b.Kind, Position = b.Position }
	for _, player in Players:GetPlayers() do
		if b.Damage[player] or ctx.Util.DistTo(player, b.Position) <= BROKEN_RADIUS then
			ctx.Util.Notify(player, "Broken", info)
		end
		if targets[player] == b.Id then
			BreakableService.ClearTarget(player)
		end
	end
	b.Model:Destroy()
	local lo, hi = Config.BreakableRespawn[1], Config.BreakableRespawn[2]
	task.delay(random:NextNumber(lo, hi), BreakableService._spawn, b.Area)
end

return BreakableService
