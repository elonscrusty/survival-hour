--!nonstrict
-- The lobby as a forest refuge (over a voxel forest floor with a stream and
-- ponds, built by WorldService): layered forest ring, lobby props (gathering deck, stalls, party area, ready arch, class stands),
-- signposts and lanterns; the lodge, leaderboards and lantern fence of the campfire plaza.
-- Mesh-first over the
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

function Refuge.Dress(folder: Instance, O: Vector3, readyCenter: Vector3, stations: { [string]: Model }, water: Water?)
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
		local pos = ringSpot(63, 70) -- outside the lantern fence (radius 60)
		if not clearOfStations(pos) then
			continue
		end
		local kind = ({ "Spruce", "Spruce", "Aspen", "GiantTree" })[rng:NextInteger(1, 4)]
		Decor.Place(kind, flatCF(pos), rng, rng:NextNumber(0.8, 1.15), deco)
	end
	for _ = 1, 40 do
		local pos = ringSpot(44, 57)
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
	-- Stations get their Blender props (procedural counters stay as colliders)
	local DRESS = { Party = "SM_Lobby_PartyArea", Locker = "SM_Lobby_ShopDisplay" }
	for name, mesh in DRESS do
		local m = stations[name]
		if m and m.PrimaryPart then
			local pos = m.PrimaryPart.Position
			Skins.Dress(m, mesh, { cf = flatCF(Vector3.new(pos.X, O.Y, pos.Z), O), keep = { Awning = name == "Locker" } })
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
	-- Signposts toward each station
	local SIGNS = {
		{ Dir = Vector3.new(1, 0, 0), Text = "→ LEADERBOARDS" },
		{ Dir = Vector3.new(-1, 0, 0), Text = "→ CAMP STORE & CLASSES" },
		{ Dir = Vector3.new(0, 0, 1), Text = "→ PARTY" },
		{ Dir = Vector3.new(0, 0, -1), Text = "→ READY UP" },
		{ Dir = Vector3.new(1, 0, 1).Unit, Text = "→ OUTFITTER" },
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

-- Class Hall ------------------------------------------------------------------------------
-- The class mannequins live in the lodge (Refuge.ClassHall below): tinted in the class colour,
-- holding a fitting tool, with a name + ◆ price tag above.

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

-- Surface text on an invisible part (stays readable when a mesh hides the procedural look).
local function signText(parent: Instance, name: string, size: Vector2, cf: CFrame, text: string, color: Color3, glow: Color3?): TextLabel
	local p = Build.Part({ Name = name, Size = Vector3.new(size.X, size.Y, 0.05), CFrame = cf, Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false, Parent = parent })
	local sg = Instance.new("SurfaceGui")
	sg.Name = "SignText"
	sg.Face = Enum.NormalId.Front
	sg.PixelsPerStud = 40
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.LightInfluence = 0
	sg.Parent = p
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Font = Enum.Font.FredokaOne
	tl.TextScaled = true
	tl.Text = text
	tl.TextColor3 = color
	tl.Parent = sg
	local stroke = Instance.new("UIStroke")
	stroke.Color = glow or Color3.fromRGB(70, 40, 20)
	stroke.Thickness = 3
	stroke.Parent = tl
	return tl
end
Refuge.SignText = signText

local function warmLight(part: BasePart, range: number)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 180, 110)
	light.Range = range
	light.Brightness = 1.3
	light.Shadows = false
	light.Parent = part
end

-- Lodge layout (model space of SM_Lobby_Lodge: front wall at z 0, porch toward -z, +x is the
-- viewer's left). Mannequin spots on the class stage behind the right-hand opening.
local LODGE_SPOTS = {
	{ x = -9.6, z = 1.9 }, -- free class, front and centre
	{ x = -5.4, z = 1.9 },
	{ x = -13.8, z = 1.9 },
	{ x = -7.5, z = 3.8 },
	{ x = -11.7, z = 3.8 },
	{ x = -3.8, z = 3.8 },
	{ x = -14.4, z = 3.8 },
}

-- Class Hall + Camp Store: a two-storey log lodge west of the lobby fire (it faces the fire).
-- CAMP STORE (left) has the shop counter; CLASSES (right) has the class mannequins on a stage,
-- each tinted in its class colour, holding a fitting tool, with a name + ◆ price tag above.
-- Returns the "Classes" station model (PrimaryPart = its Counter, the caller adds the prompt)
-- and creates a "Shop" station model beside it in `parent` (PrimaryPart = the store Counter).
-- A Footprint box on the Classes model marks the ground the lodge covers.
-- `makeRig(color)` may return an R15 rig (server only); otherwise a part-built figure is used.
function Refuge.ClassHall(parent: Instance, O: Vector3, classes: { ClassDef }, makeRig: ((Color3) -> Model?)?): Model
	local m = Build.Model("Classes", parent)
	local shop = Build.Model("Shop", parent)
	local hallCF = CFrame.lookAt(O + Vector3.new(-38, 0, 3), O + Vector3.new(0, 0, 3))
	local function at(x: number, y: number, z: number): CFrame
		return hallCF * CFrame.new(x, y, z)
	end
	local LOG = Color3.fromRGB(150, 98, 58)
	local DARK = Color3.fromRGB(104, 68, 42)
	local ROOF = Color3.fromRGB(96, 150, 78)
	local WARM = Color3.fromRGB(255, 196, 120)
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, collide: boolean?, into: Instance?): BasePart
		return Build.Part({ Name = name, Size = size, CFrame = cf, Color = color, Material = mat, CanCollide = collide ~= false, Parent = into or m })
	end
	local F = 1.2
	-- Floor, porch and steps (walkable: a ramp-like pair of steps across the whole front)
	part("Floor", Vector3.new(36, F, 14), at(0, F / 2, 7), DARK, Enum.Material.WoodPlanks)
	part("Porch", Vector3.new(37, F, 6.2), at(0, F / 2, -3.1), LOG, Enum.Material.WoodPlanks)
	part("Step", Vector3.new(37, 0.8, 0.8), at(0, 0.4, -6.6), DARK, Enum.Material.WoodPlanks)
	part("Step", Vector3.new(37, 0.4, 0.8), at(0, 0.2, -7.3), DARK, Enum.Material.WoodPlanks)
	-- Walls: back, sides, the three front piers and the lintel; a wall between the shops
	part("BackWall", Vector3.new(37, 10, 1), at(0, F + 5, 14), LOG, Enum.Material.WoodPlanks)
	for _, x in { -18, 18 } do
		part("SideWall", Vector3.new(1, 10, 15), at(x, F + 5, 7), LOG, Enum.Material.WoodPlanks)
	end
	for _, s in { { -16.75, 2.5 }, { 0, 5 }, { 16.75, 2.5 } } do
		part("Pier", Vector3.new(s[2], 10, 1), at(s[1], F + 5, 0), LOG, Enum.Material.WoodPlanks)
	end
	part("Lintel", Vector3.new(37, 1.6, 1), at(0, F + 8.9, 0), DARK, Enum.Material.WoodPlanks)
	part("Divider", Vector3.new(0.6, 9.8, 14), at(0, F + 4.9, 7), DARK, Enum.Material.WoodPlanks)
	for _, x in { -9, 9 } do
		local glow = part("BackGlow", Vector3.new(12.4, 5.8, 0.2), at(x, F + 3.6, 13.4), Color3.fromRGB(230, 170, 100), Enum.Material.Neon, false)
		glow.CastShadow = false
	end
	-- Porch roof on four posts, and the roof over the ground floor
	for _, x in { -18, -2.5, 2.5, 18 } do
		part("PorchPost", Vector3.new(0.8, 9, 0.8), at(x, F + 4.5, -5.8), DARK, Enum.Material.Wood)
	end
	part("PorchBeam", Vector3.new(38, 0.9, 0.9), at(0, F + 9.1, -5.8), DARK, Enum.Material.Wood, false)
	part("PorchRoof", Vector3.new(39, 0.5, 8.2), at(0, F + 11, -2.8) * CFrame.Angles(math.rad(-19), 0, 0), ROOF, Enum.Material.WoodPlanks, false)
	part("Ceiling", Vector3.new(38, 0.6, 15), at(0, F + 10.2, 7), DARK, Enum.Material.WoodPlanks, false)
	-- Upper storey with glowing windows and a gable roof
	local UZ = F + 10.5
	part("Upper", Vector3.new(22, 7.2, 12), at(0, UZ + 3.6, 7.5), LOG, Enum.Material.WoodPlanks, false)
	for _, x in { -7, 7 } do
		part("UpperWindow", Vector3.new(2.6, 3.2, 0.2), at(x, UZ + 3.8, 1.4), WARM, Enum.Material.Neon, false).CastShadow = false
	end
	local rise, half = 7.6, 12.6
	local slope = math.atan2(rise, half)
	local run = math.sqrt(rise * rise + half * half)
	for _, s in { -1, 1 } do
		part("UpperRoof", Vector3.new(run + 0.6, 0.6, 15), at(s * half / 2, UZ + 7 + rise / 2, 7) * CFrame.Angles(0, 0, -s * slope), ROOF, Enum.Material.WoodPlanks, false)
	end
	part("GableSign", Vector3.new(15.6, 5.2, 0.5), at(0, UZ + 9.6, -1.1), LOG, Enum.Material.WoodPlanks, false)
	part("Chimney", Vector3.new(2.6, 17, 2.6), at(-12.5, F + 15.5, 11), Color3.fromRGB(140, 134, 126), Enum.Material.Cobblestone, false)
	-- CAMP STORE counter (viewer's left) and the CLASSES lectern + mannequin stage (right)
	local storeCounter = part("Counter", Vector3.new(11, 3.4, 1.4), at(9, F + 1.7, -0.8), LOG, Enum.Material.WoodPlanks, true, shop)
	part("CounterTop", Vector3.new(11.6, 0.3, 1.8), at(9, F + 3.55, -0.8), DARK, Enum.Material.Wood, true, shop)
	for i, x in { 13, 11, 9, 7, 5 } do
		part("Goods", Vector3.new(0.8, 0.7, 0.6), at(x, F + 4.05, -0.8), if i % 2 == 0 then Color3.fromRGB(220, 170, 60) else Color3.fromRGB(110, 150, 80), Enum.Material.SmoothPlastic, false, shop)
	end
	for _, y in { F + 2.2, F + 4.2, F + 6.2 } do
		part("Shelf", Vector3.new(12.4, 0.25, 1.4), at(9, y, 12.6), DARK, Enum.Material.Wood, false, shop)
	end
	shop.PrimaryPart = storeCounter
	local lectern = part("Counter", Vector3.new(2.6, 3.2, 1.2), at(-9, F + 1.6, -0.9), LOG, Enum.Material.WoodPlanks)
	part("Stage", Vector3.new(12.8, 0.6, 3.4), at(-9, F + 0.3, 2.8), DARK, Enum.Material.WoodPlanks)
	-- keep players out of the class room (the mannequins don't collide); the lectern stays in front
	local block = part("ClassBlock", Vector3.new(13, 9, 0.3), at(-9, F + 4.5, 0.3), DARK, Enum.Material.SmoothPlastic)
	block.Transparency = 1
	block.CanQuery = false
	m.PrimaryPart = lectern
	-- Lanterns (two carry lights) and barrels on the porch
	for i, x in { -17.1, -3.6, 3.6, 17.1 } do
		local lamp = part("Lantern", Vector3.new(0.6, 0.8, 0.6), at(x, F + 7.5, -5.8), WARM, Enum.Material.Neon, false)
		lamp.CastShadow = false
		if i == 2 or i == 3 then
			warmLight(lamp, 16)
		end
	end
	for _, s in { -1, 1 } do
		Build.Cyl("Barrel", 1.9, 1.8, at(s * 16.6, F + 0.95, -4.6), LOG, Enum.Material.Wood, m)
	end
	-- Words: the game's name on the gable, a sign over each shop
	signText(m, "TitleSign", Vector2.new(14.6, 4.4), at(0, UZ + 9.6, -1.6), "SURVIVAL HOUR", Color3.fromRGB(255, 214, 120), Color3.fromRGB(120, 60, 20))
	signText(shop, "StoreSign", Vector2.new(12, 1.8), at(10.25, F + 7.4, -6.5), "CAMP STORE", Color3.fromRGB(255, 232, 180))
	signText(m, "ClassSign", Vector2.new(12, 1.8), at(-10.25, F + 7.4, -6.5), "CLASSES", Color3.fromRGB(255, 232, 180))
	for _, x in { 10.25, -10.25 } do
		part("ShopSign", Vector3.new(12.6, 2.3, 0.4), at(x, F + 7.4, -6.1), LOG, Enum.Material.WoodPlanks, false)
	end
	-- Ground plan for keep-clear checks (porch and steps included)
	local fp = part("Footprint", Vector3.new(40, 16, 24), at(0, 8, 3.4), DARK, Enum.Material.SmoothPlastic, false)
	fp.Transparency = 1
	fp.CanQuery = false
	-- The Blender lodge replaces the look; the parts above stay as colliders
	if Skins.Has("SM_Lobby_Lodge") then
		Skins.Dress(m, "SM_Lobby_Lodge", { cf = hallCF })
		Skins.Hide(shop)
	end

	-- Mannequins: the free/first class front and centre, the rest around it
	local list = table.clone(classes)
	table.sort(list, function(a, b)
		return (a.Order or 0) < (b.Order or 0)
	end)
	local function tag(def: ClassDef, spot: { x: number, z: number }, color: Color3)
		local anchor = part("Tag_" .. def.Id, Vector3.new(0.2, 0.2, 0.2), at(spot.x, if spot.z > 3 then 9.1 else 8.1, spot.z - 1.2), color, Enum.Material.SmoothPlastic, false)
		anchor.Transparency = 1
		anchor.CanQuery = false
		local bb = Instance.new("BillboardGui")
		bb.Name = "ClassTag"
		bb.Size = UDim2.new(3.4, 0, 1.4, 0)
		bb.MaxDistance = 60
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
		name.Font = Enum.Font.FredokaOne
		name.TextScaled = true
		name.Text = def.Name
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
		local spot = LODGE_SPOTS[i]
		if not spot then
			break
		end
		local color = classColor(def)
		tag(def, spot, color)
		local stand = at(spot.x, F + 0.6, spot.z) * CFrame.Angles(0, math.rad(((i * 37) % 21) - 10), 0)
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

-- Roofed leaderboard (Most Kills / Wins / Playtime) standing at `cf` (panel faces cf.LookVector).
-- Refuge.FillLeaderboard writes its rows.
local ROWS = 10
function Refuge.Leaderboard(parent: Instance, cf: CFrame, name: string, title: string): Model
	local m = Build.Model(name, parent)
	local DARK = Color3.fromRGB(92, 62, 40)
	for _, x in { -5.6, 5.6 } do
		Build.Part({ Name = "Post", Size = Vector3.new(0.76, 12.6, 0.76), CFrame = cf * CFrame.new(x, 6.2, 0.2), Color = DARK, Material = Enum.Material.Wood, Parent = m })
	end
	local back = Build.Part({ Name = "Backboard", Size = Vector3.new(11, 10.6, 0.5), CFrame = cf * CFrame.new(0, 6.9, 0.2), Color = Color3.fromRGB(60, 42, 30), Material = Enum.Material.WoodPlanks, Parent = m })
	Build.Part({ Name = "TitlePlank", Size = Vector3.new(9.6, 1.5, 0.35), CFrame = cf * CFrame.new(0, 11.1, -0.3), Color = Color3.fromRGB(226, 190, 140), Material = Enum.Material.WoodPlanks, CanCollide = false, Parent = m })
	for _, s in { -1, 1 } do
		Build.Part({ Name = "Roof", Size = Vector3.new(13, 0.4, 2.4), CFrame = cf * CFrame.new(0, 12.85, 0.2 + s * 0.95) * CFrame.Angles(math.rad(s * 30), 0, 0), Color = Color3.fromRGB(96, 150, 78), Material = Enum.Material.WoodPlanks, CanCollide = false, Parent = m })
	end
	for _, x in { -5.6, 5.6 } do
		local lamp = Build.Part({ Name = "Lantern", Size = Vector3.new(0.55, 0.75, 0.55), CFrame = cf * CFrame.new(x, 10.75, -0.9), Color = Color3.fromRGB(255, 196, 120), Material = Enum.Material.Neon, CanCollide = false, CastShadow = false, Parent = m })
		if x > 0 then
			warmLight(lamp, 12)
		end
	end
	m.PrimaryPart = back
	if Skins.Has("SM_Lobby_Leaderboard") then
		Skins.Dress(m, "SM_Lobby_Leaderboard", { cf = cf })
	end
	signText(m, "Title", Vector2.new(9.2, 1.4), cf * CFrame.new(0, 11.1, -0.5), title, Color3.fromRGB(120, 60, 24), Color3.fromRGB(255, 236, 200))
	-- rows: a SurfaceGui on an invisible face just in front of the panel
	local face = Build.Part({ Name = "Rows", Size = Vector3.new(10, 7.6, 0.05), CFrame = cf * CFrame.new(0, 6.4, -0.34), Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false, Parent = m })
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Rows"
	sg.Face = Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(500, 380)
	sg.LightInfluence = 0
	sg.Parent = face
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = sg
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 18)
	pad.PaddingRight = UDim.new(0, 18)
	pad.PaddingTop = UDim.new(0, 8)
	pad.Parent = sg
	for i = 1, ROWS do
		local row = Instance.new("Frame")
		row.Name = "Row" .. i
		row.LayoutOrder = i
		row.Size = UDim2.new(1, 0, 0, 36)
		row.BackgroundTransparency = 1
		row.Parent = sg
		local function cell(nm: string, x: number, w: number, align: Enum.TextXAlignment, color: Color3)
			local t = Instance.new("TextLabel")
			t.Name = nm
			t.AutoLocalize = false
			t.Position = UDim2.fromScale(x, 0)
			t.Size = UDim2.fromScale(w, 1)
			t.BackgroundTransparency = 1
			t.Font = Enum.Font.FredokaOne
			t.TextScaled = true
			t.TextXAlignment = align
			t.TextColor3 = color
			t.Text = ""
			t.Parent = row
		end
		local gold = i == 1
		cell("Rank", 0, 0.16, Enum.TextXAlignment.Left, if gold then Color3.fromRGB(255, 210, 70) else Color3.fromRGB(240, 200, 140))
		cell("Player", 0.17, 0.6, Enum.TextXAlignment.Left, Color3.fromRGB(255, 244, 225))
		cell("Value", 0.77, 0.23, Enum.TextXAlignment.Right, Color3.fromRGB(240, 200, 140))
	end
	return m
end

-- Writes up to ten { Name, Value } rows onto a Refuge.Leaderboard (empty list: a waiting line).
function Refuge.FillLeaderboard(board: Model, rows: { { Name: string, Value: string } })
	local face = board:FindFirstChild("Rows")
	local sg = face and face:FindFirstChild("Rows")
	if not sg then
		return
	end
	for i = 1, ROWS do
		local row = sg:FindFirstChild("Row" .. i)
		if row then
			local r = rows[i]
			local rank, player, value = row:FindFirstChild("Rank"), row:FindFirstChild("Player"), row:FindFirstChild("Value")
			rank.Text = if r then (if i == 1 then "👑" else "#" .. i) else ""
			player.Text = if r then r.Name elseif i == 1 and #rows == 0 then "Play a match to get on the board!" else ""
			value.Text = if r then r.Value else ""
		end
	end
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
	-- header plank with the title (stays when the Blender board replaces the look)
	Build.Part({ Name = "Header", Size = Vector3.new(9, 2.2, 0.4), CFrame = cf * CFrame.new(0, 12, -0.2), Color = Color3.fromRGB(226, 190, 140), Material = Enum.Material.WoodPlanks, CanCollide = false, Parent = m })
	for _, x in { -6.4, 6.4 } do
		Build.Part({ Name = "HeaderPost", Size = Vector3.new(0.7, 4, 0.7), CFrame = cf * CFrame.new(x, 12, 0.3), Color = Color3.fromRGB(96, 66, 42), Material = Enum.Material.Wood, Parent = m })
	end
	if Skins.Has("SM_Lobby_QuestBoard") then
		Skins.Dress(m, "SM_Lobby_QuestBoard", { cf = cf })
		-- the client draws on the face: keep it as an invisible surface just in front of the mesh panel
		face.Size = Vector3.new(11.2, 6.6, 0.05)
		face.CFrame = cf * CFrame.new(0, 6, -0.34)
		local static = face:FindFirstChild("BoardStatic")
		if static and static:IsA("SurfaceGui") then
			static.Enabled = true
		end
	end
	signText(m, "Title", Vector2.new(8.6, 1.9), cf * CFrame.new(0, 12, -0.45), "DAILY CHALLENGES", Color3.fromRGB(120, 60, 24), Color3.fromRGB(255, 236, 200))
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

-- Log fence ring round the plaza at `radius` from O, in 8-stud segments with a lantern post
-- every fourth joint. `clear(pos)` drops segments over paths, water or buildings.
function Refuge.Fence(parent: Instance, O: Vector3, radius: number, clear: (Vector3) -> boolean): Folder
	local f = Instance.new("Folder")
	f.Name = "Fence"
	f.Parent = parent
	local n = math.floor(2 * math.pi * radius / 8)
	local WOOD = Color3.fromRGB(150, 104, 62)
	local DARK = Color3.fromRGB(100, 68, 44)
	local lit = 0
	for i = 0, n - 1 do
		local a0, a1 = i * 2 * math.pi / n, (i + 1) * 2 * math.pi / n
		local p0 = O + Vector3.new(math.cos(a0) * radius, 0, math.sin(a0) * radius)
		local p1 = O + Vector3.new(math.cos(a1) * radius, 0, math.sin(a1) * radius)
		if not (clear(p0) and clear(p1) and clear((p0 + p1) / 2)) then
			continue
		end
		local cf = CFrame.lookAt(p0, p1) * CFrame.Angles(0, math.pi / 2, 0) -- local +X runs from p0 to p1
		local len = (p1 - p0).Magnitude
		local seg = Build.Model("FenceSegment", f)
		Build.Cyl("Post", 3.6, 0.8, cf * CFrame.new(0, 1.8, 0), DARK, Enum.Material.Wood, seg)
		for _, y in { 1.1, 2.5 } do
			Build.Part({ Name = "Rail", Shape = Enum.PartType.Cylinder, Size = Vector3.new(len, 0.48, 0.48), CFrame = cf * CFrame.new(len / 2, y, 0), Color = WOOD, Material = Enum.Material.Wood, Parent = seg })
		end
		seg.PrimaryPart = seg:FindFirstChild("Post") :: BasePart
		if Skins.Has("SM_Lobby_Fence") then
			Skins.Dress(seg, "SM_Lobby_Fence", { cf = cf })
		end
		if i % 4 == 0 then
			local post = Build.Model("FenceLantern", f)
			Build.Part({ Name = "Post", Size = Vector3.new(1.1, 3.8, 1.1), CFrame = cf * CFrame.new(0, 1.9, 0), Color = DARK, Material = Enum.Material.Wood, Parent = post })
			local lamp = Build.Part({ Name = "Lantern", Size = Vector3.new(0.7, 0.95, 0.7), CFrame = cf * CFrame.new(0, 4.35, 0), Color = Color3.fromRGB(255, 196, 120), Material = Enum.Material.Neon, CanCollide = false, CastShadow = false, Parent = post })
			post.PrimaryPart = post:FindFirstChild("Post") :: BasePart
			if Skins.Has("SM_Lobby_FenceLantern") then
				Skins.Dress(post, "SM_Lobby_FenceLantern", { cf = cf }) -- the hidden lantern keeps its light
			end
			lit += 1
			if lit % 2 == 1 and lit <= 7 then -- a few real lights; the rest only glow (phones stay smooth)
				warmLight(lamp, 14)
			end
		end
	end
	return f
end

return Refuge
