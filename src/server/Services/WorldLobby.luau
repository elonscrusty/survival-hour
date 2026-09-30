--!nonstrict
-- Lobby world for WorldService: the Refuge island (voxel terrain, stream, ponds), its props
-- and the lobby board. Installed onto WorldService by WorldService.luau (split out to keep
-- WorldService readable). Uses WorldService.LobbySpawn / LobbyBoard / LobbyWater fields.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Models = Shared:WaitForChild("Models")
local Build = require(Models:WaitForChild("Build"))
local Nature = require(Models:WaitForChild("Nature"))
local Camp = require(Models:WaitForChild("Camp"))
local Refuge = require(Models:WaitForChild("Refuge"))
local Skins = require(Models:WaitForChild("Skins"))

local terrain = workspace.Terrain

local function atomic(m: Model)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
end

return function(WorldService: any)
	-- Lobby -----------------------------------------------------------------------------------

	function WorldService.BuildLobby()
		local O = Config.Map.LobbyOrigin
		-- The lobby is small, so it's one Persistent model: sent whole on join, so the
		-- title-screen camera never shows trees streamed in before the ground under them.
		local folder = Instance.new("Model")
		folder.Name = "Lobby"
		folder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		folder.Parent = workspace

		-- Island base: voxel forest floor (grass, moss, leaf litter, dirt paths) with a
		-- stream and two ponds, over a rocky underside.
		WorldService._lobbyTerrain(O)
		for i = 0, 15 do
			local a = math.rad(i * 22.5)
			Build.Part({ Name = "UnderRock", Size = Vector3.new(24, 30, 24), CFrame = CFrame.new(O + Vector3.new(math.cos(a) * 50, -26, math.sin(a) * 50)) * CFrame.Angles(0.3, a, 0.2), Color = Color3.fromRGB(104, 100, 96), Material = Enum.Material.Rock, Parent = folder, CanCollide = false })
		end
		-- Edge trees and rail
		for i = 0, 27 do
			local a = math.rad(i * (360 / 28) + 6)
			local cf = CFrame.new(O + Vector3.new(math.cos(a) * 68, 0, math.sin(a) * 68))
			local m = if i % 3 == 0 then Nature.Oak(cf, 0.9, folder) elseif i % 3 == 1 then Nature.Pine(cf, 1, folder) else Nature.Birch(cf, 1, folder)
			atomic(m)
		end
		Build.Part({ Name = "Rail", Shape = Enum.PartType.Cylinder, Size = Vector3.new(60, 152, 152), CFrame = CFrame.new(O + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.rad(90)), Transparency = 1, CanCollide = false, Parent = folder })
		for i = 0, 35 do
			local a = math.rad(i * 10)
			Build.Part({ Name = "EdgeWall", Size = Vector3.new(14, 40, 2), CFrame = CFrame.lookAt(O + Vector3.new(math.cos(a) * 75, 18, math.sin(a) * 75), O + Vector3.new(0, 18, 0)), Transparency = 1, Parent = folder })
		end

		-- Central campfire (decor)
		local fire = Camp.Campfire(CFrame.new(O), Color3.fromRGB(255, 200, 120), folder)
		fire.Name = "LobbyFire"
		local ring = fire:FindFirstChild("SafeRing") :: BasePart?
		if ring then
			ring:Destroy()
		end
		-- four big log seats round the fire, stumps between them
		for i = 0, 3 do
			local a = math.rad(i * 90 + 45)
			local pos = O + Vector3.new(math.cos(a) * 9.5, 0, math.sin(a) * 9.5)
			local cf = CFrame.lookAt(pos, O) * CFrame.Angles(0, math.rad(90), 0) -- log runs across the view of the fire
			local logM = Build.Model("LogSeat", folder)
			local logP = Build.Part({ Name = "Log", Shape = Enum.PartType.Cylinder, Size = Vector3.new(8.8, 2.5, 2.5), CFrame = cf * CFrame.new(0, 1.25, 0), Color = Color3.fromRGB(128, 86, 54), Material = Enum.Material.Wood, Parent = logM })
			logM.PrimaryPart = logP
			if Skins.Has("SM_Lobby_BigLog") then
				Skins.Dress(logM, "SM_Lobby_BigLog", { cf = cf })
			end
		end
		for i = 0, 3 do
			local a = math.rad(i * 90)
			Build.Cyl("Stump", 1.6, 2.2, CFrame.new(O + Vector3.new(math.cos(a) * 11, 0.8, math.sin(a) * 11)), Color3.fromRGB(120, 84, 54), Enum.Material.Wood, folder)
		end

		-- Ready ring (stand inside to ready up)
		local readyCenter = O + Vector3.new(0, 0, -38)
		local readyPad = Build.Cyl("ReadyPad", 0.4, 22, CFrame.new(readyCenter + Vector3.new(0, 0.2, 0)), Color3.fromRGB(70, 90, 70), Enum.Material.Slate, folder)
		readyPad.Name = "ReadyPad"
		local glow = Build.Cyl("ReadyGlow", 0.2, 24, CFrame.new(readyCenter + Vector3.new(0, 0.1, 0)), Color3.fromRGB(120, 255, 160), Enum.Material.Neon, folder, false)
		glow.Name = "ReadyGlow"
		glow.Transparency = 0.35
		for i = 0, 7 do
			local a = math.rad(i * 45)
			local post = Build.Cyl("Torch", 5, 0.6, CFrame.new(readyCenter + Vector3.new(math.cos(a) * 12.5, 2.5, math.sin(a) * 12.5)), Color3.fromRGB(96, 66, 42), Enum.Material.Wood, folder)
			local flame = Instance.new("Fire")
			flame.Size = 2.5
			flame.Heat = 6
			flame.Parent = post
		end
		local sign = Build.Part({ Name = "ReadySign", Size = Vector3.new(16, 4, 0.5), CFrame = CFrame.new(readyCenter + Vector3.new(0, 9, -13)), Color = Color3.fromRGB(60, 44, 30), Material = Enum.Material.WoodPlanks, Parent = folder })
		Build.Label(sign, "STAND HERE TO READY UP", Vector3.new(0, 0, 0), Color3.fromRGB(180, 255, 190), 150)
		folder:SetAttribute("ReadyCenter", readyCenter)
		folder:SetAttribute("ReadyRadius", 11)

		-- Queue-zone look for the ring: hazard stripes, floor lettering, the live counter anchor
		Refuge.QueueZone(folder, readyCenter, 11)

		-- Stations: the lodge (Camp Store + Classes, west), leaderboards and challenges (east),
		-- Party board (south), Outfitter (SE)
		local function stationPrompt(part: BasePart, name: string, label: string, promptText: string)
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "StationPrompt"
			prompt.ActionText = promptText
			prompt.ObjectText = label
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt:SetAttribute("Station", name)
			prompt:SetAttribute("Action", "Station")
			prompt.Style = Enum.ProximityPromptStyle.Custom
			prompt.Parent = part
		end
		local function station(name: string, pos: Vector3, color: Color3, label: string, promptText: string)
			local m = Build.Model(name, folder)
			local counter = Build.Part({ Name = "Counter", Size = Vector3.new(10, 3.4, 3), CFrame = CFrame.lookAt(pos + Vector3.new(0, 1.7, 0), O + Vector3.new(0, 1.7, 0)), Color = Color3.fromRGB(120, 84, 54), Material = Enum.Material.WoodPlanks, Parent = m })
			for _, x in { -4.6, 4.6 } do
				Build.Part({ Name = "Post", Size = Vector3.new(0.8, 9, 0.8), CFrame = counter.CFrame * CFrame.new(x, 2.8, 1.2), Color = Color3.fromRGB(90, 62, 40), Material = Enum.Material.Wood, Parent = m })
			end
			Build.Part({ Class = "WedgePart", Name = "Awning", Size = Vector3.new(11, 1.6, 5), CFrame = counter.CFrame * CFrame.new(0, 7.6, 0) * CFrame.Angles(0, math.rad(180), 0), Color = color, Material = Enum.Material.Fabric, Parent = m })
			Build.Label(counter, label, Vector3.new(0, 9, 0), Color3.new(1, 1, 1), 120)
			m.PrimaryPart = counter
			stationPrompt(counter, name, label, promptText)
			return m
		end
		-- The lodge: Camp Store counter and the Class Hall, with a mannequin per class (R15 rigs
		-- built from a blank HumanoidDescription, so no uploaded assets; part figures if that fails)
		local Classes = require(Shared:WaitForChild("Classes"))
		local function mannequinRig(color: Color3): Model?
			local desc = Instance.new("HumanoidDescription")
			local head, legs = Build.Tint(color, 1.15), Build.Tint(color, 0.72)
			desc.HeadColor = head
			desc.TorsoColor = color
			desc.LeftArmColor = color
			desc.RightArmColor = color
			desc.LeftLegColor = legs
			desc.RightLegColor = legs
			local ok, rig = pcall(function()
				return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
			end)
			desc:Destroy()
			return if ok and typeof(rig) == "Instance" and rig:IsA("Model") then rig else nil
		end
		local hall = Refuge.ClassHall(folder, O, Classes.List :: any, mannequinRig)
		if hall.PrimaryPart then
			stationPrompt(hall.PrimaryPart, "Classes", "CLASS HALL", "Choose Class")
		end
		local shop = folder:FindFirstChild("Shop") :: Model
		if shop and shop.PrimaryPart then
			stationPrompt(shop.PrimaryPart, "Shop", "CAMP STORE", "Open Shop")
		end
		local party = station("Party", O + Vector3.new(0, 0, 40), Color3.fromRGB(110, 150, 230), "PARTY BOARD", "Manage Party")
		local locker = station("Locker", O + Vector3.new(30, 0, 30), Color3.fromRGB(190, 110, 200), "OUTFITTER", "Open Locker")
		-- Leaderboards in a row east of the fire, facing it, then the Daily Challenges board
		-- (drawn per player by the client)
		local leaders = Build.Model("Leaderboards", folder)
		local boards = {}
		for i, spec in { { "Kills", "MOST KILLS", -15 }, { "Wins", "MOST WINS", -1.5 }, { "Playtime", "MOST PLAYTIME", 12 } } do
			local pos = O + Vector3.new(44, 0, spec[3])
			local b = Refuge.Leaderboard(leaders, CFrame.lookAt(pos, pos - Vector3.xAxis), "Board_" .. spec[1], spec[2])
			boards[spec[1]] = b
			if i == 2 and b.PrimaryPart then
				leaders.PrimaryPart = b.PrimaryPart
				stationPrompt(b.PrimaryPart, "Profile", "LEADERBOARDS", "Profile & Rewards")
			end
		end
		local lfp = Build.Part({ Name = "Footprint", Size = Vector3.new(6, 16, 42), CFrame = CFrame.new(O + Vector3.new(44.5, 8, -1.5)), Transparency = 1, CanCollide = false, CanQuery = false, Parent = leaders })
		lfp.CastShadow = false
		WorldService.LobbyBoards = boards
		local boardPos = O + Vector3.new(44, 0, 26.5)
		local challenges = Refuge.ChallengeBoard(folder, CFrame.lookAt(boardPos, boardPos - Vector3.xAxis))
		if challenges.PrimaryPart then
			stationPrompt(challenges.PrimaryPart, "Profile", "DAILY CHALLENGES", "View Challenges")
		end
		local stations = {
			Shop = shop,
			Classes = hall,
			Party = party,
			Locker = locker,
			Profile = leaders,
			Board = challenges,
		}
		Refuge.Dress(folder, O, readyCenter, stations, WorldService.LobbyWater)
		-- Lantern fence round the plaza, open at the paths, water and buildings
		local W = WorldService.LobbyWater
		Refuge.Fence(folder, O, 60, function(pos: Vector3): boolean
			local d = pos - O
			if math.abs(d.X) < 8 or math.abs(d.Z) < 8 then
				return false
			end
			for _, pd in W.Ponds do
				if (pos - (O + Vector3.new(pd.X, 0, pd.Z))).Magnitude < pd.R + 5 then
					return false
				end
			end
			for _, pt in W.Stream do
				if (pos - (O + Vector3.new(pt[1], 0, pt[2]))).Magnitude < 9 then
					return false
				end
			end
			for _, st in stations do
				local fp = st and st:FindFirstChild("Footprint")
				if fp and fp:IsA("BasePart") and Refuge.InBox(fp, pos, 2) then
					return false
				end
			end
			return true
		end)

		-- Title
		local title = Build.Part({ Name = "Title", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(O + Vector3.new(0, 26, -50)), Transparency = 1, CanCollide = false, Parent = folder })
		local bb = Build.Label(title, "SURVIVAL HOUR", Vector3.new(0, 0, 0), Color3.fromRGB(255, 200, 120), 400)
		bb.Size = UDim2.fromOffset(700, 110)
		bb.AlwaysOnTop = false

		WorldService.LobbySpawn = CFrame.new(O + Vector3.new(0, 4, 18)) * CFrame.Angles(0, math.rad(180), 0)
		return folder
	end

	-- Lobby water: shared with Refuge so decorations keep out of it.
	WorldService.LobbyWater = {
		Ponds = { { X = 34, Z = -30, R = 9 }, { X = -36, Z = -26, R = 7 } },
		Stream = { { 58, -46 }, { 50, -41 }, { 43, -35 }, { 37, -32 } }, -- from the NE rim into the NE pond
	}

	-- Voxel island for the lobby. Surface at O.Y (4-stud aligned), 12 studs thick,
	-- rock underneath; clean grass with dirt cross paths; a
	-- stream falling off the edge into a pond; a second quiet pond.
	function WorldService._lobbyTerrain(O: Vector3)
		local R = 74
		-- same clean cartoon ground as the match map (bright grass, warm dirt, no grass blades)
		pcall(function()
			terrain.Decoration = false
			terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(104, 166, 70))
			terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(96, 156, 64))
			terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(146, 108, 70))
			terrain:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(128, 94, 60))
		end)
		-- body + rocky underside
		terrain:FillCylinder(CFrame.new(O + Vector3.new(0, -8, 0)), 16, R, Enum.Material.Ground)
		terrain:FillCylinder(CFrame.new(O + Vector3.new(0, -22, 0)), 12, R * 0.8, Enum.Material.Rock)
		terrain:FillCylinder(CFrame.new(O + Vector3.new(0, -32, 0)), 8, R * 0.5, Enum.Material.Rock)
		-- top layer: 4-stud cells, material from two noise fields
		local STEP = 4
		for x = -R, R, STEP do
			for z = -R, R, STEP do
				if x * x + z * z <= R * R then
					local mat = Enum.Material.Grass
					if math.abs(x) <= 5 or math.abs(z) <= 5 then
						mat = Enum.Material.Ground -- cross paths
					end
					if x * x + z * z < 15 * 15 then
						mat = Enum.Material.Ground -- packed earth round the fire
					end
					terrain:FillBlock(CFrame.new(O + Vector3.new(x, -2, z)), Vector3.new(STEP, 4, STEP), mat)
				end
			end
		end
		-- water: ponds and the stream (carved, then filled a little below the bank)
		local W = WorldService.LobbyWater
		for _, pd in W.Ponds do
			local c = O + Vector3.new(pd.X, 0, pd.Z)
			terrain:FillCylinder(CFrame.new(c + Vector3.new(0, -2.5, 0)), 5, pd.R + 2.5, Enum.Material.Mud)
			terrain:FillCylinder(CFrame.new(c + Vector3.new(0, -2, 0)), 4, pd.R, Enum.Material.Air)
			terrain:FillCylinder(CFrame.new(c + Vector3.new(0, -2.5, 0)), 3, pd.R, Enum.Material.Water)
			terrain:FillCylinder(CFrame.new(c + Vector3.new(0, -5, 0)), 2, pd.R, Enum.Material.Sand)
		end
		for i = 1, #W.Stream - 1 do
			local a = O + Vector3.new(W.Stream[i][1], 0, W.Stream[i][2])
			local b = O + Vector3.new(W.Stream[i + 1][1], 0, W.Stream[i + 1][2])
			local mid = (a + b) / 2
			local len = (b - a).Magnitude + 3
			local cf = CFrame.lookAt(mid, b)
			terrain:FillBlock(cf * CFrame.new(0, -1.5, 0), Vector3.new(8, 3, len), Enum.Material.Mud)
			terrain:FillBlock(cf * CFrame.new(0, -1, 0), Vector3.new(4.5, 2, len), Enum.Material.Air)
			terrain:FillBlock(cf * CFrame.new(0, -1.5, 0), Vector3.new(4.5, 1.5, len), Enum.Material.Water)
		end
	end

	-- Writes the plaza leaderboards (called by LobbyService): board key -> { { Name, Value } }.
	function WorldService.SetLeaderboards(rows: { [string]: { { Name: string, Value: string } } })
		for key, board in WorldService.LobbyBoards or {} do
			if board.Parent then
				Refuge.FillLeaderboard(board, rows[key] or {})
			end
		end
	end
end
