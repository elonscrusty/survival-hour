--!nonstrict
-- The lobby as a forest refuge (over a voxel forest floor with a stream and
-- ponds, built by WorldService): layered forest ring, lobby props (gathering deck, stalls, party area, ready arch, class stands),
-- signposts, lanterns and the Hall of Fame board. Mesh-first over the
-- procedural lobby, which keeps every collider, prompt and label.

local Build = require("./Build")
local Skins = require("./Skins")
local Decor = require("./Decor")

local Refuge = {}

-- Forest-refuge dressing for the lobby: layered forest ring, Blender ground
-- sections, lobby props and signposts. Everything is mesh-first with the
-- procedural lobby underneath (colliders, prompts and labels stay on it).
export type Water = { Ponds: { { X: number, Z: number, R: number } }, Stream: { { number } } }

function Refuge.Dress(folder: Instance, O: Vector3, readyCenter: Vector3, stations: { [string]: Model }, water: Water?): TextLabel?
	local board: TextLabel? = nil
	local rng = Random.new(1207)
	local deco = Instance.new("Folder")
	deco.Name = "Forest"
	deco.Parent = folder
	local function flatCF(pos: Vector3, facing: Vector3?): CFrame
		if facing then
			return CFrame.lookAt(pos, Vector3.new(facing.X, pos.Y, facing.Z))
		end
		return CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	end
	local function ringSpot(r0: number, r1: number): Vector3
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(r0, r1)
		return O + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	end
	local function clearOfStations(pos: Vector3): boolean
		for _, m in stations do
			if m.PrimaryPart and (m.PrimaryPart.Position - pos).Magnitude < 13 then
				return false
			end
		end
		-- keep out of the water
		if water then
			for _, pd in water.Ponds do
				if (pos - (O + Vector3.new(pd.X, 0, pd.Z))).Magnitude < pd.R + 4 then
					return false
				end
			end
			for _, pt in water.Stream do
				if (pos - (O + Vector3.new(pt[1], 0, pt[2]))).Magnitude < 7 then
					return false
				end
			end
		end
		-- keep the cross paths and the ready ring open
		local d = pos - O
		if math.abs(d.X) < 7 or math.abs(d.Z) < 7 then
			return false
		end
		return (pos - readyCenter).Magnitude > 16
	end
	-- Layered forest: tall canopy at the rim, a mid layer, then undergrowth.
	for _ = 1, 26 do
		local pos = ringSpot(56, 70)
		if not clearOfStations(pos) then
			continue
		end
		local kind = ({ "Spruce", "Spruce", "Aspen", "GiantTree" })[rng:NextInteger(1, 4)]
		Decor.Place(kind, flatCF(pos), rng, rng:NextNumber(0.8, 1.15), deco)
	end
	for _ = 1, 40 do
		local pos = ringSpot(44, 60)
		if clearOfStations(pos) then
			local kind = ({ "Bush", "Bush", "Fern", "FallenLog", "Boulder", "Stump", "Sapling" })[rng:NextInteger(1, 7)]
			Decor.Place(kind, flatCF(pos), rng, rng:NextNumber(0.8, 1.2), deco)
		end
	end
	for _ = 1, 70 do
		local pos = ringSpot(14, 58)
		if clearOfStations(pos) then
			local kind = ({ "Fern", "TallGrass", "FlowerPatch", "Mushrooms", "Pebbles", "LeafLitter", "MossPatch", "Twigs" })[rng:NextInteger(1, 8)]
			Decor.Place(kind, flatCF(pos), rng, 1, deco)
		end
	end
	-- Central gathering deck around the fire
	if Skins.Has("SM_Lobby_GatheringArea") then
		local v = Skins.Visual("SM_Lobby_GatheringArea")
		if v then
			v:PivotTo(CFrame.new(O + Vector3.new(0, -0.3, 0)))
			v.Name = "GatheringDeck"
			v.Parent = deco
			for _, seat in folder:GetChildren() do
				if seat.Name == "LogSeat" and seat:IsA("BasePart") then
					seat.Transparency = 1
				end
			end
		end
	end
	-- Stations get their Blender props (procedural counters stay as colliders)
	local DRESS = { Shop = "SM_Lobby_ShopDisplay", Party = "SM_Lobby_PartyArea", Locker = "SM_Lobby_ShopDisplay" }
	for name, mesh in DRESS do
		local m = stations[name]
		if m and m.PrimaryPart then
			local pos = m.PrimaryPart.Position
			Skins.Dress(m, mesh, { cf = flatCF(Vector3.new(pos.X, O.Y, pos.Z), O), keep = { Awning = name == "Locker" } })
		end
	end
	local shrine = stations.Classes
	if shrine and Skins.Has("SM_Lobby_PowerupStand") then
		for _, ped in shrine:GetChildren() do
			if ped.Name == "Pedestal" and ped:IsA("BasePart") then
				local v = Skins.Visual("SM_Lobby_PowerupStand")
				if v then
					v:PivotTo(flatCF(Vector3.new(ped.Position.X, O.Y, ped.Position.Z), O))
					v.Parent = shrine
					ped.Transparency = 1
				end
			end
		end
	end
	if Skins.Has("SM_Lobby_ReadyStation") then
		local v = Skins.Visual("SM_Lobby_ReadyStation")
		if v then
			v:PivotTo(flatCF(readyCenter + Vector3.new(0, 0, -12), O))
			v.Name = "ReadyArch"
			v.Parent = deco
		end
	end
	-- Outfitter mannequin (shows the look of outfits)
	local locker = stations.Locker
	if locker and locker.PrimaryPart then
		local base = locker.PrimaryPart.CFrame * CFrame.new(0, -1.7, 4)
		local body = Build.Model("Mannequin", locker)
		Build.Part({ Name = "Torso", Size = Vector3.new(2, 2, 1), CFrame = base * CFrame.new(0, 3, 0), Color = Color3.fromRGB(150, 50, 45), Material = Enum.Material.Fabric, Parent = body })
		Build.Part({ Name = "Legs", Size = Vector3.new(2, 2, 1), CFrame = base * CFrame.new(0, 1, 0), Color = Color3.fromRGB(60, 60, 70), Material = Enum.Material.Fabric, Parent = body })
		Build.Ball("Head", 1.3, base * CFrame.new(0, 4.7, 0), Color3.fromRGB(210, 190, 160), Enum.Material.Wood, body)
	end
	-- Hall of Fame board: live leaderboard surface
	local profile = stations.Profile
	if profile and profile.PrimaryPart then
		local counter = profile.PrimaryPart
		-- panel centre matches SM_Sign_Board_Panel (5 studs above its base), just in front of it
		local boardCF = counter.CFrame * CFrame.new(0, 3.3, 1.15)
		local boardPart = Build.Part({ Name = "Board", Size = Vector3.new(9, 4.5, 0.3), CFrame = boardCF, Color = Color3.fromRGB(70, 52, 36), Material = Enum.Material.WoodPlanks, Parent = profile })
		if Skins.Has("SM_Sign_Board") then
			Skins.Dress(profile, "SM_Sign_Board", { cf = counter.CFrame * CFrame.new(0, -1.7, 1.4), noHide = true, extra = true })
		end
		local sg = Instance.new("SurfaceGui")
		sg.Name = "Leaderboard"
		sg.Face = Enum.NormalId.Front
		sg.CanvasSize = Vector2.new(540, 270)
		sg.LightInfluence = 0.2
		sg.Parent = boardPart
		local tl = Instance.new("TextLabel")
		tl.Name = "Text"
		tl.Size = UDim2.fromScale(1, 1)
		tl.BackgroundTransparency = 1
		tl.Font = Enum.Font.GothamBold
		tl.TextColor3 = Color3.fromRGB(255, 225, 160)
		tl.TextScaled = true
		tl.Text = "HALL OF FAME\nMost wins — updating…"
		tl.Parent = sg
		board = tl
	end
	-- Signposts toward each station
	local SIGNS = {
		{ Dir = Vector3.new(1, 0, 0), Text = "→ TRADING POST" },
		{ Dir = Vector3.new(-1, 0, 0), Text = "→ CLASS SHRINE" },
		{ Dir = Vector3.new(0, 0, 1), Text = "→ PARTY" },
		{ Dir = Vector3.new(0, 0, -1), Text = "→ READY UP" },
		{ Dir = Vector3.new(1, 0, 1).Unit, Text = "→ OUTFITTER" },
		{ Dir = Vector3.new(-1, 0, 1).Unit, Text = "→ HALL OF FAME" },
	}
	for _, sgn in SIGNS do
		local pos = O + sgn.Dir * 19 + sgn.Dir:Cross(Vector3.yAxis) * 6.5
		-- the panel faces back toward the camp fire so it reads from the centre
		local cf = CFrame.lookAt(pos, pos - sgn.Dir)
		local post = Build.Part({ Name = "SignPost", Size = Vector3.new(0.5, 5, 0.5), CFrame = cf * CFrame.new(0, 2.5, 0), Color = Color3.fromRGB(96, 70, 46), Material = Enum.Material.Wood, Parent = deco })
		local panel = Build.Part({ Name = "SignPanel", Size = Vector3.new(3.5, 1.8, 0.2), CFrame = cf * CFrame.new(0, 3.6, -0.25), Color = Color3.fromRGB(150, 112, 74), Material = Enum.Material.WoodPlanks, Parent = deco, CanCollide = false })
		if Skins.Has("SM_Sign_Post") then
			local v = Skins.Visual("SM_Sign_Post")
			if v then
				v:PivotTo(cf)
				v.Parent = deco
				post.Transparency = 1
				panel.Transparency = 1
			end
		end
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front
		sg.CanvasSize = Vector2.new(350, 180)
		sg.LightInfluence = 0.3
		sg.Parent = panel
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.fromScale(1, 1)
		tl.BackgroundTransparency = 1
		tl.Font = Enum.Font.GothamBlack
		tl.TextColor3 = Color3.fromRGB(255, 236, 200)
		tl.TextStrokeTransparency = 0.5
		tl.TextScaled = true
		tl.Text = sgn.Text
		tl.Parent = sg
	end
	-- Lanterns along the paths (warm pools of light for the golden hour)
	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		for _, r in { 26, 44 } do
			for _, side in { -1, 1 } do
				local pos = O + dir * r + dir:Cross(Vector3.yAxis) * 6 * side
				local pole = Build.Cyl("LanternPole", 6, 0.35, CFrame.new(pos + Vector3.new(0, 3, 0)), Color3.fromRGB(70, 56, 44), Enum.Material.Wood, deco)
				local glow = Build.Part({ Name = "Lantern", Size = Vector3.new(0.8, 1, 0.8), CFrame = CFrame.new(pos + Vector3.new(0, 6.3, 0)), Color = Color3.fromRGB(255, 190, 110), Material = Enum.Material.Neon, Parent = deco, CanCollide = false })
				local light = Instance.new("PointLight")
				light.Color = Color3.fromRGB(255, 180, 110)
				light.Range = 14
				light.Brightness = 1.2
				light.Shadows = false
				light.Parent = glow
				pole.CanQuery = false
			end
		end
	end
	return board
end

return Refuge
