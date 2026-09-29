--!nonstrict
-- Studio-only developer commands (never active in live servers: ctx.DevEnabled
-- requires RunService:IsStudio()). Used by the DEV panel on the client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared:WaitForChild("Items"))
local Config = require(Shared:WaitForChild("Config"))

local DevService = {}

local ctx: any

function DevService.Init(c)
	ctx = c
	if not ctx.DevEnabled then
		return
	end
	ctx.Util.Connect("DevCommand", "Default", DevService._onCommand)
end

function DevService._onCommand(p: Player, cmd: any, arg: any)
	if not ctx.DevEnabled or type(cmd) ~= "string" then
		return
	end
	local M = ctx.MatchService
	if cmd == "StartMatch" then
		if M.Active then
			return
		end
		local assignment = {}
		local t = 0
		for _, pl in Players:GetPlayers() do
			t = (t % 4) + 1
			assignment[pl] = t
		end
		task.spawn(M.Begin, assignment, nil)
	elseif cmd == "SkipPhase" then
		M.SkipPhase()
	elseif cmd == "GiveResources" then
		for _, id in { "Stick", "Stone", "Wood", "Plant", "Leather", "Rope", "Scrap", "Iron", "Coal" } do
			ctx.InventoryService.AddResource(p, id, 20)
		end
	elseif cmd == "GiveItem" and type(arg) == "string" and Items[arg] then
		local def = Items[arg]
		local n = if def.Kind == "Ammo" then 20 elseif def.Kind == "Consumable" then 3 elseif def.Kind == "Resource" then 10 else 1
		local _, displaced = ctx.InventoryService.Give(p, arg, n)
		if displaced then
			local root = ctx.Util.Root(p)
			if root then
				ctx.InventoryService.SpawnPickup(displaced.Id, 1, root.Position + Vector3.new(3, 0, 0), displaced)
			end
		end
	elseif cmd == "FillCanteen" then
		local inv = ctx.InventoryService.Get(p)
		local st = inv and inv.Slots.Utility
		if st and st.Id == "Canteen" then
			st.Filled = true
			ctx.InventoryService.Sync(p)
		end
	elseif cmd == "BenchLevel" and type(arg) == "number" then
		ctx.CampService.SetLevel(ctx.Util.Team(p), math.clamp(math.floor(arg), 1, 5))
		ctx.CraftService.Push(p)
	elseif cmd == "Extinguish" and type(arg) == "number" then
		M.ExtinguishFire(math.clamp(math.floor(arg), 1, 4), nil)
	elseif cmd == "AnimalLineup" then
		DevService._lineup(p)
	elseif cmd == "SpawnAnimal" and type(arg) == "string" and ctx.WildlifeService.Species[arg] then
		local root = ctx.Util.Root(p)
		if root then
			ctx.WildlifeService._spawn(arg, root.Position + root.CFrame.LookVector * 30)
		end
	elseif cmd == "ForceEvent" and type(arg) == "string" and Config.Events.Weights[arg] then
		ctx.EventService.Force(arg)
	elseif cmd == "DropPackage" then
		ctx.LootService._drop({ Source = "Free" })
	elseif cmd == "Damage" then
		ctx.CombatService.DamagePlayer(p, 25, { Kind = "Environment" })
	elseif cmd == "Kill" then
		local hum = ctx.Util.Humanoid(p)
		if hum then
			hum.Health = 0
		end
	elseif cmd == "Diamonds" then
		local s = ctx.DataService.Get(p)
		if s then
			s.Profile.Diamonds += 100
			ctx.DataService.Push(p)
		end
	elseif cmd == "CompleteChallenges" then
		local s = ctx.DataService.Get(p)
		if s then
			for _, stat in { "Resources", "Animals", "Pois", "Nights", "Crafts", "Chests", "DamageDealt", "Predators", "BenchUpgrades", "Breaches" } do
				s.Profile.Stats[stat] = 999999
			end
			ctx.DataService.Push(p)
		end
	elseif cmd == "EndMatch" then
		if M.Active then
			M.End(ctx.Util.Team(p))
		end
	end
end

-- Studio check of the animal meshes: every species frozen in a row in front of the
-- player (a buck and a doe for the deer), labelled, on the ground. Replaces the last row.
function DevService._lineup(p: Player)
	local root = ctx.Util.Root(p)
	if not root then
		return
	end
	local Animals = require(game:GetService("ReplicatedStorage").Shared.Models.Animals)
	local old = workspace:FindFirstChild("DevAnimalLineup")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "DevAnimalLineup"
	folder.Parent = workspace
	local list = { { "Wolf" }, { "Bear" }, { "Boar" }, { "Deer", true }, { "Deer", false }, { "Rabbit" }, { "Bat" } }
	local look = CFrame.lookAt(root.Position, root.Position + root.CFrame.LookVector * Vector3.new(1, 0, 1))
	for i, spec in list do
		local ok, m = pcall(Animals.Build, spec[1], spec[2])
		if ok and m then
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
				end
			end
			local spot = (look * CFrame.new((i - 4) * 9, 0, -22)).Position
			local ground = ctx.WorldService.RaycastGround(spot, { folder, p.Character })
			local hum = m:FindFirstChildOfClass("Humanoid")
			local rootPart = m.PrimaryPart
			local lift = (if hum then hum.HipHeight else 3) + (if rootPart then rootPart.Size.Y / 2 else 0)
			m:PivotTo(CFrame.lookAt(Vector3.new(spot.X, (ground and ground.Y or spot.Y) + lift, spot.Z), root.Position * Vector3.new(1, 0, 1) + Vector3.new(0, (ground and ground.Y or spot.Y) + lift, 0)))
			m.Name = spec[1] .. (if spec[2] == true then " (buck)" elseif spec[2] == false then " (doe)" else "")
			m.Parent = folder
			local tag = Instance.new("BillboardGui")
			tag.Size = UDim2.fromOffset(120, 24)
			tag.StudsOffset = Vector3.new(0, 4, 0)
			tag.AlwaysOnTop = true
			local t = Instance.new("TextLabel")
			t.Size = UDim2.fromScale(1, 1)
			t.BackgroundTransparency = 1
			t.TextScaled = true
			t.TextColor3 = Color3.new(1, 1, 1)
			t.TextStrokeTransparency = 0.3
			t.Text = m.Name
			t.Parent = tag
			tag.Parent = m.PrimaryPart
		else
			warn("[Dev] lineup: couldn't build", spec[1], m)
		end
	end
end

return DevService
