--!nonstrict
-- Free-placement base building with server validation, structure health,
-- damage states, repair, gates and spikes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Items = require(Shared:WaitForChild("Items"))
local Recipes = require(Shared:WaitForChild("Recipes"))
local Logic = Shared:WaitForChild("Logic")
local PlacementRules = require(Logic:WaitForChild("PlacementRules"))
local StorageLedger = require(Logic:WaitForChild("StorageLedger"))
local Models = Shared:WaitForChild("Models")
local Structures = require(Models:WaitForChild("Structures"))

local BuildService = {}

export type Structure = {
	Id: string,
	Team: number,
	Model: Model,
	Health: number,
	Max: number,
	Rect: PlacementRules.Rect,
	EnemyDamage: number, -- repairable HP that came from enemies (Craftsman challenge)
	Builder: number,
	Key: string,
}

local ctx: any
local structures: { [Model]: Structure } = {}
local folder: Folder? = nil
local spikeTouch: { [string]: number } = {}
local counter = 0

function BuildService.Init(c)
	ctx = c
	ctx.Util.Connect("PlaceStructure", "Build", BuildService._onPlace)
	ctx.ChannelService.OnPrompt("Gate", BuildService._onGate)
	ctx.MatchService.On("MatchStarting", function(map)
		folder = Instance.new("Folder")
		folder.Name = "Structures"
		folder.Parent = map.Folder
	end)
	ctx.MatchService.On("MatchCleanup", function()
		structures = {}
		folder = nil
		spikeTouch = {}
	end)
end

function BuildService.FromPart(part: Instance): Structure?
	local m = part:FindFirstAncestorOfClass("Model")
	while m do
		local s = structures[m]
		if s then
			return s
		end
		-- (not m.Parent:FindFirstAncestorOfClass: that skips m.Parent itself,
		-- so parts of nested models like a gate's Door never resolved)
		m = m:FindFirstAncestorOfClass("Model")
	end
	return nil
end

function BuildService.TeamStructures(team: number): { Structure }
	local out = {}
	for _, s in structures do
		if s.Team == team then
			table.insert(out, s)
		end
	end
	return out
end

local function limitUsed(team: number, limit: string): number
	local n = 0
	for _, s in structures do
		if s.Team == team and Items[s.Id].Limit == limit then
			n += 1
		end
	end
	return n
end

-- Placement ---------------------------------------------------------------------------------

function BuildService.Validate(p: Player, id: string, pos: Vector3, yaw: number): (boolean, string?, Vector3?)
	local def = Items[id]
	local recipe = Recipes.ByResult[id]
	if not def or def.Kind ~= "Structure" or not recipe then
		return false, "Unknown structure"
	end
	local team = ctx.Util.Team(p)
	local camp = ctx.CampService.GetCamp(team)
	if not camp then
		return false, "No camp"
	end
	if ctx.CampService.GetLevel(team) < recipe.Level then
		return false, "Requires workbench level " .. recipe.Level
	end
	local root = ctx.Util.Root(p)
	if not root then
		return false, "Not spawned"
	end
	if (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude > Config.Build.MaxPlaceDistance then
		return false, "Too far away"
	end
	local size = def.Size :: Vector3
	local rect: PlacementRules.Rect = { X = pos.X, Z = pos.Z, HX = size.X / 2, HZ = size.Z / 2, Yaw = -yaw }
	local existing = {}
	for _, r in camp.StaticRects do
		table.insert(existing, r)
	end
	for _, s in structures do
		table.insert(existing, s.Rect)
	end
	local limitName = def.Limit or "Wall"
	local ok, why = PlacementRules.Check(rect, {
		Fire = { X = camp.FirePos.X, Z = camp.FirePos.Z },
		ZoneRadius = Config.Build.ZoneRadius,
		Clearances = camp.Clearances,
		Existing = existing,
		LimitUsed = limitUsed(team, limitName),
		LimitMax = Config.Build.Limits[limitName] or 10,
	})
	if not ok then
		return false, why
	end
	-- Terrain: sample the footprint corners; reject steep or water spots.
	local heights = {}
	for _, c in PlacementRules.Corners(rect) do
		table.insert(heights, ctx.WorldService.GroundY(c[1], c[2]))
	end
	table.insert(heights, ctx.WorldService.GroundY(pos.X, pos.Z))
	local lo, hi = math.huge, -math.huge
	for _, h in heights do
		lo = math.min(lo, h)
		hi = math.max(hi, h)
	end
	if hi - lo > 3 then
		return false, "Ground is too uneven"
	end
	local groundY = lo
	-- Characters / animals inside the footprint
	local cf = CFrame.new(pos.X, groundY + size.Y / 2, pos.Z) * CFrame.Angles(0, math.rad(yaw), 0)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { workspace.Terrain }
	for _, part in workspace:GetPartBoundsInBox(cf, size + Vector3.new(1, 0, 1), params) do
		if ctx.Util.PlayerFromPart(part) then
			return false, "Someone is standing there"
		end
		if ctx.WildlifeService.FromPart(part) then
			return false, "An animal is in the way"
		end
	end
	return true, nil, Vector3.new(pos.X, groundY, pos.Z)
end

function BuildService._onPlace(p: Player, req: any)
	if type(req) ~= "table" or type(req.Id) ~= "string" or not ctx.Util.IsVec3(req.Pos) or not ctx.Util.IsFinite(req.Yaw) then
		return
	end
	if not p:GetAttribute("InMatch") or not ctx.Util.IsAlive(p) or not ctx.MatchService.IsPlaying() then
		return
	end
	local yaw = math.floor(req.Yaw / Config.Build.RotateStep + 0.5) * Config.Build.RotateStep % 360
	local ok, why, ground = BuildService.Validate(p, req.Id, req.Pos, yaw)
	if not ok or not ground then
		ctx.Util.Notify(p, why or "Can't build there.", "error")
		Net.FireClient("MatchEvent", p, "BuildResult", { Ok = false, Reason = why })
		return
	end
	local team = ctx.Util.Team(p)
	local recipe = Recipes.ByResult[req.Id]
	local inv = ctx.InventoryService.Get(p)
	if not inv or not StorageLedger.PayCombined(recipe.Cost, inv, ctx.StorageService.TeamStores(team)) then
		ctx.Util.Notify(p, "Not enough materials (your pack + team storage).", "error")
		Net.FireClient("MatchEvent", p, "BuildResult", { Ok = false, Reason = "Materials" })
		return
	end
	ctx.InventoryService.Sync(p)
	ctx.StorageService.SyncTeam(team)
	BuildService.Spawn(req.Id, team, ground, yaw, p)
	Net.FireClient("MatchEvent", p, "BuildResult", { Ok = true, Id = req.Id })
end

function BuildService.Spawn(id: string, team: number, ground: Vector3, yaw: number, builder: Player?): Structure
	local def = Items[id]
	local cf = CFrame.new(ground) * CFrame.Angles(0, math.rad(yaw), 0)
	local model = Structures.Build(id, cf, Config.Teams[team].Color, folder)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	counter += 1
	local size = def.Size :: Vector3
	local s: Structure = {
		Id = id,
		Team = team,
		Model = model,
		Health = def.Health :: number,
		Max = def.Health :: number,
		Rect = { X = ground.X, Z = ground.Z, HX = size.X / 2, HZ = size.Z / 2, Yaw = -yaw },
		EnemyDamage = 0,
		Builder = if builder then builder.UserId else 0,
		Key = "S" .. counter,
	}
	structures[model] = s
	model:SetAttribute("Team", team)
	model:SetAttribute("Structure", id)
	model:SetAttribute("Health", s.Health)
	model:SetAttribute("MaxHealth", s.Max)
	ctx.Util.PlaySound("Build", model.PrimaryPart)
	if id == "Gate" then
		local door = model:FindFirstChild("Door") :: Model
		ctx.ChannelService.MakePrompt(door.PrimaryPart :: BasePart, "Gate", "Open / Close", "Gate", 10, "Team", team)
	elseif id == "Spikes" then
		local hurt = model:FindFirstChild("Hurt") :: BasePart
		hurt.Touched:Connect(function(part)
			BuildService._spikeTouch(s, part)
		end)
	elseif id == "StorageBox" then
		ctx.StorageService.Register(s)
	end
	return s
end

-- Damage / repair -----------------------------------------------------------------------------

function BuildService.Damage(s: Structure, amount: number, attacker: Player?): boolean
	if not structures[s.Model] or amount <= 0 then
		return false
	end
	if attacker and ctx.Util.Team(attacker) == s.Team then
		return false -- friendly fire off for structures
	end
	local dealt = math.min(s.Health, amount)
	s.Health -= dealt
	s.EnemyDamage += dealt
	s.Model:SetAttribute("Health", math.ceil(s.Health))
	Structures.ApplyDamageState(s.Model, s.Health / s.Max)
	ctx.Util.PlaySound("HitStructure", s.Model.PrimaryPart)
	if attacker then
		Net.FireClient("HitFeedback", attacker, "Structure", math.floor(dealt + 0.5), s.Model:GetPivot().Position)
	end
	if s.Health <= 0 then
		BuildService.Destroy(s, attacker)
	end
	return true
end

function BuildService.Destroy(s: Structure, by: Player?)
	if not structures[s.Model] then
		return
	end
	structures[s.Model] = nil
	local pos = s.Model:GetPivot().Position
	if s.Id == "StorageBox" then
		ctx.StorageService.OnDestroyed(s, pos)
	end
	Net.FireAll("Fx", "StructureBreak", { Pos = pos, Id = s.Id })
	ctx.Util.PlaySound("Break", s.Model.PrimaryPart)
	s.Model:Destroy()
	ctx.Util.NotifyTeam(s.Team, "Your " .. Items[s.Id].Name .. " was destroyed" .. (if by then " by " .. by.DisplayName else "") .. "!", "danger")
end

function BuildService.Repair(p: Player, s: Structure)
	if ctx.Util.Team(p) ~= s.Team then
		return
	end
	if s.Health >= s.Max then
		ctx.Util.Notify(p, "Already at full health.", "info")
		return
	end
	local def = Items[s.Id]
	local cost = Recipes.Repair.Cost[def.Material or "Wood"]
	local free = ctx.PowerupService.ConsumeFreeRepair(p)
	if not free then
		local inv = ctx.InventoryService.Get(p)
		if not inv or not StorageLedger.PayCombined(cost, inv, ctx.StorageService.TeamStores(s.Team)) then
			local need = next(cost)
			ctx.Util.Notify(p, "Repairing needs 1 " .. tostring(need) .. " per swing.", "warn")
			return
		end
		ctx.InventoryService.Sync(p)
		ctx.StorageService.SyncTeam(s.Team)
	end
	local amount = math.min(s.Max - s.Health, s.Max * Recipes.Repair.RepairFraction * ctx.PowerupService.RepairMult(p))
	s.Health += amount
	local fromEnemy = math.min(amount, s.EnemyDamage)
	s.EnemyDamage -= fromEnemy
	s.Model:SetAttribute("Health", math.ceil(s.Health))
	Structures.ApplyDamageState(s.Model, s.Health / s.Max)
	ctx.Util.PlaySound("Repair", s.Model.PrimaryPart)
	Net.FireClient("HitFeedback", p, "Repair", math.floor(amount + 0.5), s.Model:GetPivot().Position)
	if fromEnemy > 0 then
		ctx.PowerupService.OnRepair(p, fromEnemy)
	end
end

-- Gates -------------------------------------------------------------------------------------------

function BuildService._onGate(p: Player, prompt: ProximityPrompt)
	local s = BuildService.FromPart(prompt)
	if not s or s.Id ~= "Gate" or ctx.Util.Team(p) ~= s.Team or not ctx.Util.IsAlive(p) then
		return
	end
	local open = not s.Model:GetAttribute("Open")
	if not open then
		-- Don't close on top of someone.
		local root = s.Model.PrimaryPart :: BasePart
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { s.Model }
		for _, part in workspace:GetPartBoundsInBox(root.CFrame, root.Size, params) do
			if ctx.Util.PlayerFromPart(part) then
				ctx.Util.Notify(p, "Someone is in the gateway.", "warn")
				return
			end
		end
	end
	Structures.SetGateOpen(s.Model, open)
	ctx.Util.PlaySound("Build", s.Model.PrimaryPart)
end

-- Spikes -------------------------------------------------------------------------------------------

function BuildService._spikeTouch(s: Structure, part: BasePart)
	if not structures[s.Model] then
		return
	end
	local victim = ctx.Util.PlayerFromPart(part)
	if victim then
		if ctx.Util.Team(victim) == s.Team then
			return
		end
		local key = s.Key .. ":" .. victim.UserId
		local t = os.clock()
		if t - (spikeTouch[key] or 0) < 1 then
			return
		end
		spikeTouch[key] = t
		local owner = Players:GetPlayerByUserId(s.Builder)
		ctx.CombatService.DamagePlayer(victim, Items.Spikes.Damage :: number, { Kind = "Spike", By = if owner and ctx.Util.Team(owner) == s.Team then owner else nil, Name = "Spikes", Pos = s.Model:GetPivot().Position })
		-- Spikes wear a little each time they bite.
		BuildService.Damage(s, 4, nil)
		return
	end
	local animal = ctx.WildlifeService.FromPart(part)
	if animal then
		local key = s.Key .. ":A" .. tostring(animal.Id)
		local t = os.clock()
		if t - (spikeTouch[key] or 0) < 1 then
			return
		end
		spikeTouch[key] = t
		ctx.WildlifeService.Damage(animal, Items.Spikes.Damage :: number, nil)
	end
end

return BuildService
