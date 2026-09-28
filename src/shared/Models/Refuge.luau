--!nonstrict
-- The lobby as a forest refuge (over a voxel forest floor with a stream and
-- ponds, built by WorldService): layered forest ring, lobby props (gathering deck, stalls, party area, ready arch, class stands),
-- signposts, lanterns and the Hall of Fame board. Mesh-first over the
-- procedural lobby, which keeps every collider, prompt and label.

local Build = require("./Build")
local Skins = require("./Skins")
local Decor = require("./Decor")
local ItemModels = require("./ItemModels")

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
			-- big stations (the Class Hall) mark their whole ground plan with a Footprint box
			local fp = m:FindFirstChild("Footprint")
			if fp and fp:IsA("BasePart") and Refuge.InBox(fp, pos, 3) then
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
		{ Dir = Vector3.new(-1, 0, 0), Text = "→ CLASS HALL" },
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
	-- Lanterns along the paths (warm pools of light for the evening). Inner lanterns carry
	-- the lights; outer ones only glow. Poles that would stand in the ready ring or in a
	-- station's footprint move inward or drop out. String lights hang between the poles
	-- (Neon bulbs with no lights of their own, so phones stay smooth).
	local lights = Instance.new("Folder")
	lights.Name = "EveningLights"
	lights.Parent = folder
	local function poleClear(pos: Vector3): boolean
		if (pos - readyCenter).Magnitude < 13 then
			return false
		end
		for _, m in stations do
			local fp = m:FindFirstChild("Footprint")
			if fp and fp:IsA("BasePart") and Refuge.InBox(fp, pos, 1) then
				return false
			end
		end
		return true
	end
	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local tops: { [number]: { Attachment } } = { [-1] = {}, [1] = {} }
		for ri, r in { 26, 44 } do
			for _, side in { -1, 1 } do
				local pos = O + dir * r + dir:Cross(Vector3.yAxis) * 6 * side
				if ri == 2 and not poleClear(pos) then
					pos = O + dir * 33 + dir:Cross(Vector3.yAxis) * 6 * side
				end
				if not poleClear(pos) then
					continue
				end
				-- tall poles so the string lights hang well above head height (~7 studs at the dip)
				local pole = Build.Cyl("LanternPole", 9, 0.35, CFrame.new(pos + Vector3.new(0, 4.5, 0)), Color3.fromRGB(70, 56, 44), Enum.Material.Wood, deco)
				local glow = Build.Part({ Name = "Lantern", Size = Vector3.new(0.8, 1, 0.8), CFrame = CFrame.new(pos + Vector3.new(0, 9.3, 0)), Color = Color3.fromRGB(255, 190, 110), Material = Enum.Material.Neon, Parent = deco, CanCollide = false })
				if ri == 1 then
					local light = Instance.new("PointLight")
					light.Color = Color3.fromRGB(255, 180, 110)
					light.Range = 14
					light.Brightness = 1.2
					light.Shadows = false
					light.Parent = glow
				end
				pole.CanQuery = false
				-- string anchor just under the lantern, its axis pointing down (for the sag)
				local att = Instance.new("Attachment")
				att.Name = "StringAnchor"
				att.CFrame = CFrame.new(0, -0.6, 0) * CFrame.Angles(0, 0, -math.pi / 2)
				att.Parent = glow
				table.insert(tops[side], att)
			end
		end
		for _, side in { -1, 1 } do
			local t = tops[side]
			if #t == 2 then
				Refuge.StringLights(t[1], t[2], 9, 1.4, lights)
			end
		end
		-- a festoon across the path between the two inner lanterns
		if tops[-1][1] and tops[1][1] then
			Refuge.StringLights(tops[-1][1], tops[1][1], 6, 1, lights)
		end
	end
	return board
end

-- True when `pos` lies inside `part`'s ground plan (X/Z only), grown by `margin` studs.
function Refuge.InBox(part: BasePart, pos: Vector3, margin: number): boolean
	local rel = part.CFrame:PointToObjectSpace(pos)
	return math.abs(rel.X) <= part.Size.X / 2 + margin and math.abs(rel.Z) <= part.Size.Z / 2 + margin
end

-- String lights between two attachments whose axis points down: a dark wire (a curved
-- Beam) with coloured Neon bulbs along the same curve. The middle dips by `sag` studs.
local BULBS = {
	Color3.fromRGB(255, 232, 180),
	Color3.fromRGB(255, 170, 70),
	Color3.fromRGB(90, 220, 200),
	Color3.fromRGB(255, 120, 150),
	Color3.fromRGB(160, 230, 110),
}
function Refuge.StringLights(a0: Attachment, a1: Attachment, bulbs: number, sag: number, parent: Instance)
	local h0, h1 = a0.Parent, a1.Parent
	if not (h0 and h0:IsA("BasePart") and h1 and h1:IsA("BasePart")) then
		return
	end
	-- cubic Bezier with both control points `c` below the ends: the midpoint sits 0.75c lower
	local c = sag / 0.75
	local beam = Instance.new("Beam")
	beam.Name = "StringWire"
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.CurveSize0 = c
	beam.CurveSize1 = -c
	beam.Width0 = 0.08
	beam.Width1 = 0.08
	beam.Segments = 12
	beam.FaceCamera = true
	beam.Color = ColorSequence.new(Color3.fromRGB(40, 34, 28))
	beam.Parent = parent
	local p0 = (h0 :: BasePart).CFrame * a0.CFrame.Position
	local p3 = (h1 :: BasePart).CFrame * a1.CFrame.Position
	local p1, p2 = p0 - Vector3.new(0, c, 0), p3 - Vector3.new(0, c, 0)
	for i = 1, bulbs do
		local t = i / (bulbs + 1)
		local u = 1 - t
		local pos = p0 * (u * u * u) + p1 * (3 * u * u * t) + p2 * (3 * u * t * t) + p3 * (t * t * t)
		local b = Build.Ball("Bulb", 0.45, CFrame.new(pos - Vector3.new(0, 0.25, 0)), BULBS[(i - 1) % #BULBS + 1], Enum.Material.Neon, parent, false)
		b.CastShadow = false
	end
end

-- Class Hall -------------------------------------------------------------------------------
-- A log cabin west of the lobby fire (it faces the fire). Each class stands as a mannequin
-- in its own warmly lit window, tinted in the class colour and holding a fitting tool, with a
-- name + ◆ price tag above; the free class greets you behind the counter in the doorway.
-- A neon "CLASSES" sign sits over the door. Returns the "Classes" station model: its
-- PrimaryPart is the Counter (the caller adds the station prompt) and a Footprint box marks
-- the ground it covers so decorations and lanterns keep clear.
-- `makeRig(color)` may return an R15 rig (server only); otherwise a part-built figure is used.

export type ClassDef = { Id: string, Name: string, Price: number, Order: number, Glyph: string, Color: { number } }

local HALL_TOOLS = {
	Survivor = "StoneAxe",
	Lumberjack = "SteelAxe",
	Miner = "IronPickaxe",
	Hunter = "HuntingBow",
	Scavenger = "Crowbar",
	Raider = "Sledgehammer",
	Tracker = "CrudeSpear",
}
local HALL_BAYS = { 15.5, 10.5, 5.5, -5.5, -10.5, -15.5 } -- window centres (left to right from the fire)

local function classColor(def: ClassDef): Color3
	local c = def.Color or {}
	return Color3.fromRGB(c[1] or 200, c[2] or 200, c[3] or 200)
end

-- Anchors and tints an R15 rig and stands it with its feet on `stand`.
local function fitRig(rig: Model, color: Color3, stand: CFrame)
	for _, d in rig:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			local n = d.Name
			if n == "Head" then
				d.Color = Build.Tint(color, 1.15)
			elseif string.find(n, "Leg") or string.find(n, "Foot") then
				d.Color = Build.Tint(color, 0.72)
			elseif n ~= "HumanoidRootPart" then
				d.Color = color
			end
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	local bc = rig:FindFirstChildOfClass("BodyColors")
	if bc then
		bc.HeadColor3 = Build.Tint(color, 1.15)
		bc.TorsoColor3 = color
		bc.LeftArmColor3 = color
		bc.RightArmColor3 = color
		bc.LeftLegColor3 = Build.Tint(color, 0.72)
		bc.RightLegColor3 = Build.Tint(color, 0.72)
	end
	local hum = rig:FindFirstChildOfClass("Humanoid")
	if hum then
		pcall(function()
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
			hum.EvaluateStateMachine = false
		end)
	end
	local root = rig:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		rig.PrimaryPart = root
	end
	-- stand it up, then drop it so its lowest point rests on the stand
	rig:PivotTo(stand * CFrame.new(0, 3, 0))
	local box, size = rig:GetBoundingBox()
	local bottom = box.Position.Y - size.Y / 2
	rig:PivotTo(rig:GetPivot() + Vector3.new(0, stand.Position.Y - bottom, 0))
end

-- A simple mannequin from parts (no assets needed), feet on `stand`.
local function partFigure(color: Color3, stand: CFrame): Model
	local m = Build.Model("Mannequin")
	local legs = Build.Tint(color, 0.72)
	local function limb(name: string, size: Vector3, x: number, y: number, c: Color3): BasePart
		return Build.Part({ Name = name, Size = size, CFrame = stand * CFrame.new(x, y, 0), Color = c, Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false, Parent = m })
	end
	limb("LeftLeg", Vector3.new(0.95, 2, 1), -0.5, 1, legs)
	limb("RightLeg", Vector3.new(0.95, 2, 1), 0.5, 1, legs)
	local torso = limb("Torso", Vector3.new(2, 2, 1), 0, 3, color)
	limb("LeftArm", Vector3.new(0.9, 2, 1), -1.5, 3, color)
	limb("RightArm", Vector3.new(0.9, 2, 1), 1.5, 3, color)
	local hand = limb("RightHand", Vector3.new(0.6, 0.5, 0.6), 1.5, 1.75, color)
	hand.Transparency = 1
	local head = Build.Ball("Head", 1.3, stand * CFrame.new(0, 4.65, 0), Build.Tint(color, 1.15), Enum.Material.SmoothPlastic, m, false)
	head.CanQuery = false
	m.PrimaryPart = torso
	return m
end

-- Puts the class tool in the figure's right hand (anchored, no collision).
local function holdTool(fig: Model, toolId: string?)
	local hand = fig:FindFirstChild("RightHand", true)
	if not (toolId and hand and hand:IsA("BasePart") and ItemModels.HasModel(toolId)) then
		return
	end
	local ok, held = pcall(ItemModels.Held, toolId)
	if not ok or not held then
		return
	end
	for _, d in held:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
		end
	end
	local target
	if string.find(toolId, "Bow") then
		-- bows stand upright in the fist, lifted so the lower limb clears the floor
		target = hand.CFrame * CFrame.new(0, 0.9, -0.2)
	else
		-- hafted tools rest upright from the fist, head forward
		target = hand.CFrame * CFrame.new(0, -0.2, 0) * CFrame.Angles(math.rad(90), 0, 0) * CFrame.Angles(0, 0, math.pi)
	end
	held:PivotTo(target)
	held.Name = "Tool"
	held.Parent = fig
end

function Refuge.ClassHall(parent: Instance, O: Vector3, classes: { ClassDef }, makeRig: ((Color3) -> Model?)?): Model
	local m = Build.Model("Classes", parent)
	local hallCF = CFrame.lookAt(O + Vector3.new(-42, 0, 1.5), O + Vector3.new(0, 0, 1.5)) -- clear of the SW pond bank
	local function at(x: number, y: number, z: number): CFrame
		return hallCF * CFrame.new(x, y, z)
	end
	local LOG = Color3.fromRGB(112, 78, 52)
	local DARK = Color3.fromRGB(78, 54, 38)
	local ROOF = Color3.fromRGB(70, 58, 52)
	local TEAL = Color3.fromRGB(90, 230, 200)
	local WARM = Color3.fromRGB(255, 190, 120)
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, collide: boolean?): BasePart
		return Build.Part({ Name = name, Size = size, CFrame = cf, Color = color, Material = mat, CanCollide = collide ~= false, Parent = m })
	end
	-- Shell: floor, back and side walls, the front wall with six windows and a doorway.
	part("Floor", Vector3.new(37, 1, 11), at(0, 0.5, 5), DARK, Enum.Material.WoodPlanks)
	part("BackWall", Vector3.new(37, 10, 1), at(0, 6, 10.5), LOG, Enum.Material.WoodPlanks)
	for _, x in { -18.5, 18.5 } do
		part("SideWall", Vector3.new(1, 10, 11), at(x, 6, 5), LOG, Enum.Material.WoodPlanks)
	end
	for _, x in { -10.5, 10.5 } do
		part("Sill", Vector3.new(16, 1.6, 1), at(x, 1.8, 0), LOG, Enum.Material.WoodPlanks)
	end
	part("Lintel", Vector3.new(38, 2.4, 1), at(0, 9.8, 0), LOG, Enum.Material.WoodPlanks)
	for _, x in { -18, -13, -8, 8, 13, 18 } do
		part("Post", Vector3.new(1, 6, 1.1), at(x, 5.6, 0), DARK, Enum.Material.Wood)
	end
	for _, x in { -3, 3 } do
		part("DoorPost", Vector3.new(1, 7.6, 1.2), at(x, 4.8, 0), DARK, Enum.Material.Wood)
	end
	local blocker = part("DoorBlock", Vector3.new(5, 7.6, 0.3), at(0, 4.8, 0), DARK, Enum.Material.SmoothPlastic)
	blocker.Transparency = 1
	blocker.CanQuery = false
	-- Gable roof (ridge along the front) with filled gable ends.
	local slope = math.atan2(4.2, 6.5)
	local run = math.sqrt(4.2 * 4.2 + 6.5 * 6.5) + 1
	part("Roof", Vector3.new(39.5, 0.8, run), at(0, 12.9, 1.6) * CFrame.Angles(-slope, 0, 0), ROOF, Enum.Material.Slate)
	part("Roof", Vector3.new(39.5, 0.8, run), at(0, 12.9, 8.4) * CFrame.Angles(slope, 0, 0), ROOF, Enum.Material.Slate)
	for _, x in { -18.5, 18.5 } do
		Build.Part({ Class = "WedgePart", Name = "Gable", Size = Vector3.new(1, 4.2, 5), CFrame = at(x, 13.1, 2.5) * CFrame.Angles(0, math.pi, 0), Color = LOG, Material = Enum.Material.WoodPlanks, Parent = m })
		Build.Part({ Class = "WedgePart", Name = "Gable", Size = Vector3.new(1, 4.2, 5.5), CFrame = at(x, 13.1, 7.75), Color = LOG, Material = Enum.Material.WoodPlanks, Parent = m })
	end
	part("Chimney", Vector3.new(2.4, 8, 2.4), at(12, 14.5, 8), Color3.fromRGB(110, 104, 98), Enum.Material.Cobblestone)
	-- Display: a raised stage behind the glass, each bay backed by a warm glowing panel.
	part("Stage", Vector3.new(36, 0.6, 4), at(0, 1.3, 3.5), Color3.fromRGB(96, 66, 46), Enum.Material.WoodPlanks)
	for i, x in HALL_BAYS do
		local glass = part("Window", Vector3.new(4, 6, 0.2), at(x, 5.6, 0), Color3.fromRGB(255, 226, 180), Enum.Material.Glass)
		glass.Transparency = 0.6
		glass.CastShadow = false
		local glow = part("WindowGlow", Vector3.new(4.4, 6, 0.2), at(x, 5.2, 9.9), Color3.fromRGB(196, 116, 58), Enum.Material.Neon, false)
		glow.CastShadow = false
		-- flower box under each window
		part("FlowerBox", Vector3.new(3.6, 0.6, 0.8), at(x, 2.3, -0.9), DARK, Enum.Material.Wood, false)
		part("Flowers", Vector3.new(3.3, 0.4, 0.6), at(x, 2.75, -0.9), if i % 2 == 0 then Color3.fromRGB(240, 200, 80) else Color3.fromRGB(230, 120, 150), Enum.Material.Grass, false)
	end
	part("DoorGlow", Vector3.new(4.4, 7, 0.2), at(0, 4.6, 9.9), Color3.fromRGB(196, 116, 58), Enum.Material.Neon, false).CastShadow = false
	for _, x in { -9, 9 } do
		local lamp = part("Lamp", Vector3.new(0.6, 0.6, 0.6), at(x, 8.4, 2.5), WARM, Enum.Material.Neon, false)
		local light = Instance.new("PointLight")
		light.Color = WARM
		light.Range = 14
		light.Brightness = 1.4
		light.Shadows = false
		light.Parent = lamp
	end
	-- Porch and counter (the station prompt goes on the counter).
	part("Porch", Vector3.new(16, 0.6, 5), at(0, 0.3, -2.5), LOG, Enum.Material.WoodPlanks)
	local counter = part("Counter", Vector3.new(7, 3, 1.6), at(0, 2.1, -3.2), LOG, Enum.Material.WoodPlanks)
	part("CounterTop", Vector3.new(7.6, 0.3, 2), at(0, 3.75, -3.2), DARK, Enum.Material.Wood)
	part("CounterTrim", Vector3.new(7, 0.2, 0.2), at(0, 3.45, -4.1), TEAL, Enum.Material.Neon, false).CastShadow = false
	m.PrimaryPart = counter
	-- Neon sign over the door
	local sign = part("Sign", Vector3.new(15, 3.4, 0.5), at(0, 12.3, -2.1), Color3.fromRGB(40, 30, 24), Enum.Material.WoodPlanks, false)
	for _, s in { { 0, 1.8, 15.4, 0.25 }, { 0, -1.8, 15.4, 0.25 }, { -7.6, 0, 0.25, 3.6 }, { 7.6, 0, 0.25, 3.6 } } do
		part("SignNeon", Vector3.new(s[3], s[4], 0.3), at(s[1], 12.3 + s[2], -2.3), TEAL, Enum.Material.Neon, false).CastShadow = false
	end
	for _, x in { -6, 6 } do
		part("SignBracket", Vector3.new(0.4, 0.4, 2.2), at(x, 11, -1.1), DARK, Enum.Material.Wood, false)
	end
	local sg = Instance.new("SurfaceGui")
	sg.Name = "SignText"
	sg.Face = Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(600, 136)
	sg.LightInfluence = 0
	sg.Parent = sign
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Font = Enum.Font.GothamBlack
	tl.Text = "CLASSES"
	tl.TextScaled = true
	tl.TextColor3 = Color3.fromRGB(255, 226, 150)
	tl.Parent = sg
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 140, 60)
	stroke.Thickness = 3
	stroke.Parent = tl
	local signLight = Instance.new("PointLight")
	signLight.Color = TEAL
	signLight.Range = 16
	signLight.Brightness = 1.6
	signLight.Shadows = false
	signLight.Parent = sign
	-- Ground plan for keep-clear checks (porch included)
	local fp = part("Footprint", Vector3.new(40, 16, 19), at(0, 8, 4), DARK, Enum.Material.SmoothPlastic, false)
	fp.Transparency = 1
	fp.CanQuery = false

	-- Mannequins: the free/first class in the doorway, the rest in the windows.
	local list = table.clone(classes)
	table.sort(list, function(a, b)
		return (a.Order or 0) < (b.Order or 0)
	end)
	local spots: { { x: number, z: number } } = { { x = 0, z = 1.5 } }
	for _, x in HALL_BAYS do
		table.insert(spots, { x = x, z = 3.5 })
	end
	local function tag(def: ClassDef, x: number, color: Color3)
		local anchor = part("Tag_" .. def.Id, Vector3.new(0.2, 0.2, 0.2), at(x, 9.6, -1.2), color, Enum.Material.SmoothPlastic, false)
		anchor.Transparency = 1
		anchor.CanQuery = false
		local bb = Instance.new("BillboardGui")
		bb.Name = "ClassTag"
		bb.Size = UDim2.new(4.6, 0, 1.9, 0)
		bb.MaxDistance = 70
		bb.LightInfluence = 0
		bb.AlwaysOnTop = false
		bb.Adornee = anchor
		bb.Parent = anchor
		local stack = Instance.new("UIListLayout")
		stack.SortOrder = Enum.SortOrder.LayoutOrder
		stack.Parent = bb
		local name = Instance.new("TextLabel")
		name.LayoutOrder = 1
		name.Size = UDim2.fromScale(1, 0.56)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.GothamBlack
		name.TextScaled = true
		name.Text = (def.Glyph or "") .. " " .. def.Name
		name.TextColor3 = Build.Tint(color, 1.25)
		name.TextStrokeTransparency = 0.3
		name.Parent = bb
		local price = Instance.new("TextLabel")
		price.LayoutOrder = 2
		price.Size = UDim2.fromScale(1, 0.44)
		price.BackgroundTransparency = 1
		price.Font = Enum.Font.GothamBold
		price.TextScaled = true
		price.Text = if (def.Price or 0) > 0 then "◆ " .. def.Price else "FREE"
		price.TextColor3 = if (def.Price or 0) > 0 then Color3.fromRGB(140, 205, 255) else Color3.fromRGB(150, 240, 150)
		price.TextStrokeTransparency = 0.3
		price.Parent = bb
	end
	for i, def in list do
		local spot = spots[i]
		if not spot then
			break
		end
		local color = classColor(def)
		tag(def, spot.x, color)
		local stand = at(spot.x, 1.6, spot.z) * CFrame.Angles(0, math.rad(((i * 37) % 21) - 10), 0)
		-- rigs load from the platform (they can yield), so each figure builds on its own thread
		task.spawn(function()
			local fig: Model? = nil
			if makeRig then
				local ok, rig = pcall(makeRig, color)
				if ok and rig then
					local okFit = pcall(fitRig, rig, color, stand)
					if okFit then
						fig = rig
					else
						rig:Destroy()
					end
				end
			end
			local figure = fig or partFigure(color, stand)
			figure.Name = "Mannequin_" .. def.Id
			pcall(holdTool, figure, HALL_TOOLS[def.Id])
			figure.Parent = m
		end)
	end
	return m
end

-- Daily Challenges board near the spawn (faces along cf.LookVector). The client draws this
-- player's challenges on the "ChallengeBoardFace" part; a static title shows until then.
function Refuge.ChallengeBoard(parent: Instance, cf: CFrame): Model
	local m = Build.Model("ChallengeBoard", parent)
	local WOOD = Color3.fromRGB(140, 100, 64)
	for _, x in { -6.4, 6.4 } do
		Build.Part({ Name = "Post", Size = Vector3.new(0.7, 10.4, 0.7), CFrame = cf * CFrame.new(x, 5.2, 0.3), Color = Color3.fromRGB(96, 66, 42), Material = Enum.Material.Wood, Parent = m })
	end
	local face = Build.Part({ Name = "ChallengeBoardFace", Size = Vector3.new(12, 7, 0.4), CFrame = cf * CFrame.new(0, 6, 0), Color = Color3.fromRGB(38, 32, 28), Material = Enum.Material.WoodPlanks, Parent = m })
	for _, s in { { 0, 3.65, 12.8, 0.4 }, { 0, -3.65, 12.8, 0.4 }, { -6.2, 0, 0.4, 7.7 }, { 6.2, 0, 0.4, 7.7 } } do
		Build.Part({ Name = "Frame", Size = Vector3.new(s[3], s[4], 0.6), CFrame = cf * CFrame.new(s[1], 6 + s[2], 0), Color = WOOD, Material = Enum.Material.Wood, CanCollide = false, Parent = m })
	end
	Build.Part({ Name = "Cap", Size = Vector3.new(14, 0.6, 2.2), CFrame = cf * CFrame.new(0, 10.6, 0.1) * CFrame.Angles(math.rad(-8), 0, 0), Color = Color3.fromRGB(70, 58, 52), Material = Enum.Material.Slate, Parent = m })
	local strip = Build.Part({ Name = "BoardNeon", Size = Vector3.new(12.4, 0.2, 0.2), CFrame = cf * CFrame.new(0, 10.1, -0.6), Color = Color3.fromRGB(255, 184, 80), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CastShadow = false, Parent = m })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 140)
	light.Range = 12
	light.Brightness = 1
	light.Shadows = false
	light.Parent = strip
	local sg = Instance.new("SurfaceGui")
	sg.Name = "BoardStatic"
	sg.Face = Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(600, 350)
	sg.LightInfluence = 0.2
	sg.Parent = face
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Font = Enum.Font.GothamBlack
	tl.TextScaled = true
	tl.TextColor3 = Color3.fromRGB(255, 225, 160)
	tl.Text = "DAILY CHALLENGES"
	tl.Parent = sg
	m.PrimaryPart = face
	return m
end

-- Queue-zone dressing for the ready ring: a hazard-stripe band round the pad edge, READY UP
-- painted on the floor, and the "QueueBoard" anchor the client hangs the live counter on.
function Refuge.QueueZone(parent: Instance, center: Vector3, radius: number): BasePart
	local zone = Instance.new("Folder")
	zone.Name = "QueueZone"
	zone.Parent = parent
	local n = 24
	local r = radius - 0.9
	for i = 0, n - 1 do
		local a = (i + 0.5) * math.pi * 2 / n
		local pos = center + Vector3.new(math.cos(a) * r, 0.44, math.sin(a) * r)
		local amber = i % 2 == 0
		Build.Part({
			Name = "Stripe",
			Size = Vector3.new(2.7, 0.08, 1.4),
			CFrame = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z)) * CFrame.Angles(0, math.rad(18), 0),
			Color = if amber then Color3.fromRGB(255, 184, 40) else Color3.fromRGB(36, 32, 28),
			Material = if amber then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			Parent = zone,
		})
	end
	-- floor lettering on the fire side of the ring, reading from the approach path
	local text = Build.Part({ Name = "ReadyFloorText", Size = Vector3.new(12, 0.05, 4), CFrame = CFrame.lookAt(center + Vector3.new(0, 0.43, 4), center + Vector3.new(0, 0.43, -10)), Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false, Parent = zone })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Top
	sg.CanvasSize = Vector2.new(600, 200)
	sg.LightInfluence = 0
	sg.Parent = text
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Font = Enum.Font.GothamBlack
	tl.TextScaled = true
	tl.TextColor3 = Color3.fromRGB(190, 255, 200)
	tl.TextTransparency = 0.15
	tl.Text = "READY UP"
	tl.Parent = sg
	local board = Build.Part({ Name = "QueueBoard", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(center + Vector3.new(0, 13, 0)), Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false, Parent = zone })
	return board
end

return Refuge
