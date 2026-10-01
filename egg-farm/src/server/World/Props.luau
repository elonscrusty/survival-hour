--!strict
-- Farm props built from native parts: warehouse, dock, road, silos, worker shed, menu boards,
-- gate sign, fences, theme decorations, the hill with the road tunnel. Every builder takes a
-- world CFrame (already placed by World) and parents into `parent`. Colours use theme roles so
-- Kit.Recolor can repaint a farm; decorations are rebuilt when the theme's decor kind changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Kit = require(Shared:WaitForChild("Models"):WaitForChild("Kit"))

local Props = {}

local F = Kit.Fixed
local NEON = Enum.Material.Neon

local function P(parent: Instance, name: string, size: Vector3, cf: CFrame, look: any, opts: { [string]: any }?): BasePart
	local o: any = table.clone(opts or {})
	o.name, o.size, o.cf = name, size, cf
	if type(look) == "string" then
		o.role = look
	else
		o.color = look
	end
	return Kit.Part(parent, o)
end
Props.P = P

local function gable(parent: Instance, cf: CFrame, w: number, d: number, h: number, look: any, opts: { [string]: any }?)
	local o: any = table.clone(opts or {})
	o.shape = "Wedge"
	P(parent, "Roof", Vector3.new(w, h, d / 2), cf * CFrame.new(0, h / 2, -d / 4), look, o)
	P(parent, "Roof", Vector3.new(w, h, d / 2), cf * CFrame.new(0, h / 2, d / 4) * CFrame.Angles(0, math.pi, 0), look, o)
end
Props.Gable = gable

-- A flat glowing ring zone. The returned zone part is an UNROTATED invisible block whose Size.X/Z
-- is the diameter (ZoneService reads it in object space); the visible disc is two child parts.
function Props.Ring(parent: Instance, name: string, cf: CFrame, radius: number): BasePart
	local zone = P(parent, name, Vector3.new(radius * 2, 0.2, radius * 2), cf * CFrame.new(0, 0.25, 0), F.white, {
		transparency = 1,
		collide = false,
		shadow = false,
	})
	zone:SetAttribute("Radius", radius)
	local flat = cf * CFrame.Angles(0, 0, math.pi / 2)
	P(zone, "Glow", Vector3.new(0.12, radius * 2, radius * 2), flat * CFrame.new(0.2, 0, 0), "accent", {
		shape = "Cylinder",
		material = NEON,
		transparency = 0.25,
		collide = false,
		shadow = false,
	})
	P(zone, "Inner", Vector3.new(0.12, radius * 2 - 1.6, radius * 2 - 1.6), flat * CFrame.new(0.24, 0, 0), "path", {
		shape = "Cylinder",
		collide = false,
		shadow = false,
	})
	return zone
end

-- Menu board: two posts and a panel facing -Z of `cf` (use CFrame.lookAt towards the viewer).
function Props.Board(parent: Instance, name: string, cf: CFrame, title: string, menu: string, slot: number?): BasePart
	local model = Instance.new("Model")
	model.Name = "Stand"
	for _, x in { -2.6, 2.6 } do
		P(model, "Post", Vector3.new(0.5, 6, 0.5), cf * CFrame.new(x, 3, 0.3), "wood")
	end
	P(model, "Frame", Vector3.new(6.6, 3.8, 0.35), cf * CFrame.new(0, 4.6, 0.1), "accent", { shadow = true })
	P(model, "Roof", Vector3.new(7.2, 0.4, 1.2), cf * CFrame.new(0, 6.7, 0.2), "roof")
	local panel = P(parent, name, Vector3.new(6, 3.2, 0.3), cf * CFrame.new(0, 4.6, -0.1), F.white, { query = false })
	Kit.Label(panel, title, Enum.NormalId.Front, Color3.fromRGB(60, 50, 40), 40).TextStrokeTransparency = 1
	local hint = Kit.Label(panel, "", Enum.NormalId.Back, Color3.fromRGB(60, 50, 40), 40)
	hint.Text = title
	hint.TextStrokeTransparency = 1
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = title
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt:SetAttribute("Menu", menu)
	panel:SetAttribute("Menu", menu)
	if slot then
		prompt:SetAttribute("Slot", slot)
		panel:SetAttribute("Slot", slot)
	end
	prompt.Parent = panel
	model.Parent = panel -- decoration lives under the panel, so Boards/* holds only prompt parts
	return panel
end

-- Warehouse: centre `cf` on the ground, door facing -Z of `cf`.
function Props.Warehouse(parent: Instance, cf: CFrame, w: number, d: number): Model
	local m = Instance.new("Model")
	m.Name = "Warehouse"
	local h = 11
	P(m, "Floor", Vector3.new(w + 2, 0.8, d + 2), cf * CFrame.new(0, 0.4, 0), F.stone)
	P(m, "Walls", Vector3.new(w, h, d), cf * CFrame.new(0, 0.8 + h / 2, 0), "wood")
	for _, x in { -w / 2, w / 2 } do
		for _, z in { -d / 2, d / 2 } do
			P(m, "Corner", Vector3.new(1, h, 1), cf * CFrame.new(x, 0.8 + h / 2, z), F.white)
		end
	end
	P(m, "Trim", Vector3.new(w + 0.4, 0.8, d + 0.4), cf * CFrame.new(0, 0.8 + h - 0.4, 0), "accent")
	gable(m, cf * CFrame.new(0, 0.8 + h, 0), w + 2, d + 2, 6, "roof")
	P(m, "Door", Vector3.new(14, 9, 0.4), cf * CFrame.new(0, 0.8 + 4.5, -d / 2 - 0.1), F.black, { shade = 0.2 })
	P(m, "DoorFrame", Vector3.new(15.6, 1, 0.6), cf * CFrame.new(0, 0.8 + 9.5, -d / 2 - 0.2), F.white)
	-- egg crates stacked just inside the door so the deposit point reads at a glance
	for i, x in { -4.5, -1.5, 1.5, 4.5 } do
		P(m, "Crate", Vector3.new(2.6, 1.6, 2), cf * CFrame.new(x, 0.8 + 0.8, -d / 2 + 2), Color3.fromRGB(176, 120, 70), { material = Enum.Material.Wood })
		if i % 2 == 0 then
			P(m, "Crate", Vector3.new(2.6, 1.6, 2), cf * CFrame.new(x - 1.5, 0.8 + 2.4, -d / 2 + 2), Color3.fromRGB(176, 120, 70), { material = Enum.Material.Wood })
		end
	end
	local sign = P(m, "Sign", Vector3.new(16, 3, 0.5), cf * CFrame.new(0, 0.8 + h + 1.2, -d / 2 - 1.1), "accent", { shadow = true })
	Kit.Label(sign, "WAREHOUSE", Enum.NormalId.Front, Color3.new(1, 1, 1), 30)
	Kit.Egg(m, cf * CFrame.new(0, 0.8 + h + 5.2, -d / 2 - 1.1), Vector3.new(3, 4, 1), { name = "EggIcon", color = F.cream })
	m.Parent = parent
	return m
end

-- Loading dock: platform along x at `cf`, bay markers at given world CFrames.
function Props.Dock(parent: Instance, cf: CFrame, w: number, d: number, bays: { CFrame }): Model
	local m = Instance.new("Model")
	m.Name = "Dock"
	P(m, "Platform", Vector3.new(w, 2, d), cf * CFrame.new(0, 1, 0), F.stone)
	P(m, "Edge", Vector3.new(w, 0.4, 0.6), cf * CFrame.new(0, 2.2, -d / 2 + 0.3), F.yellow)
	for i, bcf in bays do
		local bay = P(m, "Bay" .. i, Vector3.new(10, 0.2, 18), bcf * CFrame.new(0, 0.12, 0), F.asphalt, { collide = false, shadow = false })
		bay:SetAttribute("Bay", i)
		for _, x in { -5, 5 } do
			P(bay, "Line", Vector3.new(0.4, 0.06, 18), bcf * CFrame.new(x, 0.25, 0), F.white, { collide = false, shadow = false })
		end
		local lamp = P(bay, "Lamp", Vector3.new(1.2, 1.2, 0.3), bcf * CFrame.new(0, 3.5, -10.6), F.darkStone, {
			material = NEON,
			collide = false,
			shadow = false,
		})
		lamp:SetAttribute("Bay", i)
		local num = P(bay, "Number", Vector3.new(3, 2, 0.2), bcf * CFrame.new(0, 3.6, 9.4), F.darkStone, { collide = false, shadow = false })
		Kit.Label(num, tostring(i), Enum.NormalId.Back, Color3.new(1, 1, 1), 30)
	end
	m.Parent = parent
	return m
end

function Props.Silo(parent: Instance, name: string, cf: CFrame, radius: number, built: boolean, permanent: boolean): Model
	local m = Instance.new("Model")
	m.Name = name
	Kit.Column(m, cf, 0.6, radius * 2 + 1.2, { name = "Pad", color = F.stone })
	if built then
		Kit.Column(m, cf * CFrame.new(0, 0.6, 0), 14, radius * 2, { name = "Body", color = F.metal, shadow = true, collide = true })
		Kit.Column(m, cf * CFrame.new(0, 4, 0), 0.7, radius * 2 + 0.3, { name = "Band", role = "accent" })
		Kit.Column(m, cf * CFrame.new(0, 10, 0), 0.7, radius * 2 + 0.3, { name = "Band", role = "accent" })
		P(m, "Cap", Vector3.new(radius * 2, radius * 2, radius * 2), cf * CFrame.new(0, 14.6, 0), "roof", { shape = "Ball" })
		if permanent then
			Kit.Column(m, cf * CFrame.new(0, 7, 0), 0.9, radius * 2 + 0.4, { name = "Gold", color = Color3.fromRGB(255, 200, 60), material = NEON })
		end
	else
		P(m, "Marker", Vector3.new(0.4, 1.4, 0.4), cf * CFrame.new(0, 1.3, 0), "wood")
	end
	m:SetAttribute("Built", built)
	m.Parent = parent
	return m
end

function Props.Shed(parent: Instance, cf: CFrame, w: number, d: number): Model
	local m = Instance.new("Model")
	m.Name = "WorkerShed"
	P(m, "Walls", Vector3.new(w, 7, d), cf * CFrame.new(0, 3.5, 0), "wood", { shade = 0.08 })
	gable(m, cf * CFrame.new(0, 7, 0), w + 1, d + 1.4, 3.5, "roof")
	P(m, "Door", Vector3.new(3.4, 5, 0.3), cf * CFrame.new(0, 2.5, -d / 2 - 0.1), F.black, { shade = 0.3 })
	P(m, "Window", Vector3.new(2.4, 1.8, 0.25), cf * CFrame.new(-5, 4, -d / 2 - 0.1), Color3.fromRGB(255, 236, 170), { material = NEON })
	P(m, "Bench", Vector3.new(5, 0.5, 1.4), cf * CFrame.new(4.6, 1.2, -d / 2 - 1.2), "wood", { shade = 0.2 })
	P(m, "Barrel", Vector3.new(1.6, 2, 1.6), cf * CFrame.new(-w / 2 - 1.2, 1, -d / 2 + 1.5), "wood", { shade = 0.3 })
	m.Parent = parent
	return m
end

-- Entrance gate with the owner's name. `cf` at the gate centre, facing out (-Z = outside).
function Props.Gate(parent: Instance, cf: CFrame, width: number): (Model, TextLabel, TextLabel)
	local m = Instance.new("Model")
	m.Name = "Gate"
	for _, x in { -width / 2, width / 2 } do
		P(m, "Pillar", Vector3.new(2, 12, 2), cf * CFrame.new(x, 6, 0), "wood", { collide = true })
		P(m, "PillarCap", Vector3.new(2.6, 0.8, 2.6), cf * CFrame.new(x, 12.4, 0), "accent")
	end
	local sign = P(m, "Nameplate", Vector3.new(width + 2, 4, 0.8), cf * CFrame.new(0, 10, 0), "roof", { shadow = true })
	local front = Kit.Label(sign, "Free plot", Enum.NormalId.Front, Color3.new(1, 1, 1), 24)
	local back = Kit.Label(sign, "Free plot", Enum.NormalId.Back, Color3.new(1, 1, 1), 24)
	Kit.Egg(m, cf * CFrame.new(0, 13.6, 0), Vector3.new(2.4, 3.2, 1), { name = "EggTop", role = "accent" })
	m.Parent = parent
	return m, front, back
end

-- Fence along a segment a -> b (world CFrames on the ground), posts every ~14 studs, 2 rails.
function Props.Fence(parent: Instance, a: Vector3, b: Vector3)
	local d = b - a
	local len = d.Magnitude
	if len < 0.5 then
		return
	end
	local n = math.max(1, math.floor(len / 14 + 0.5))
	for i = 0, n do
		local p = a + d * (i / n)
		P(parent, "Post", Vector3.new(0.8, 3.6, 0.8), CFrame.new(p + Vector3.new(0, 1.8, 0)), "wood", { shadow = false })
	end
	local mid = a + d / 2
	local cf = CFrame.lookAt(mid, mid + d)
	P(parent, "Rail", Vector3.new(0.3, 0.4, len), cf + Vector3.new(0, 2.8, 0), "wood", { collide = true, shadow = false, shade = 0.1 })
	P(parent, "Rail", Vector3.new(0.3, 0.4, len), cf + Vector3.new(0, 1.5, 0), "wood", { collide = true, shadow = false, shade = 0.1 })
end

-- One decoration of the theme's decor kind at `cf` (on the ground). `seed` varies size/rotation.
function Props.Decor(parent: Instance, kind: string, cf: CFrame, seed: number)
	local rng = Random.new(seed)
	local s = 0.85 + rng:NextNumber() * 0.4
	local rot = cf * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0)
	local m = Instance.new("Model")
	m.Name = "Decor"
	if kind == "trees" or kind == "hives" then
		Kit.Column(m, rot, 5 * s, 1.4 * s, { name = "Trunk", color = F.trunk })
		P(m, "Leaves", Vector3.one * 7 * s, rot * CFrame.new(0, 7 * s, 0), F.leaf, { shape = "Ball", shadow = true })
		P(m, "Leaves", Vector3.one * 5 * s, rot * CFrame.new(1.6 * s, 9.6 * s, 0.6 * s), F.leaf:Lerp(Color3.new(1, 1, 0.4), 0.15), { shape = "Ball" })
		if kind == "hives" then
			local hive = rot * CFrame.new(3.5 * s, 0, 2 * s)
			Kit.Column(m, hive, 0.8, 2.2, { name = "HiveBase", color = F.trunk })
			for i = 0, 2 do
				Kit.Column(m, hive * CFrame.new(0, 0.8 + i * 0.9, 0), 0.9, 2.4 - i * 0.5, { name = "Hive", color = Color3.fromRGB(250, 196, 50) })
			end
		end
	elseif kind == "clover" then
		for i = 0, 2 do
			local a = i * math.pi * 2 / 3
			P(m, "Leaf", Vector3.new(2.2, 0.6, 2.2) * s, rot * CFrame.new(math.cos(a) * 1.2 * s, 2.6 * s, math.sin(a) * 1.2 * s), Color3.fromRGB(60, 170, 80), { shape = "Ball" })
		end
		Kit.Column(m, rot, 2.4 * s, 0.4, { name = "Stem", color = Color3.fromRGB(50, 130, 60) })
		P(m, "Flower", Vector3.one * 1.2, rot * CFrame.new(2.5, 0.6, 1), F.white, { shape = "Ball" })
		P(m, "Flower", Vector3.one * 1.0, rot * CFrame.new(-2, 0.5, -1.5), Color3.fromRGB(255, 160, 200), { shape = "Ball" })
	elseif kind == "palms" then
		local top = rot * CFrame.new(0, -1 * s, 0)
		for _ = 0, 3 do
			top = top * CFrame.new(0, 2.2 * s, 0) * CFrame.Angles(0, 0, math.rad(6))
			P(m, "Trunk", Vector3.new(1.2, 2.4, 1.2) * s, top, Color3.fromRGB(170, 130, 80))
		end
		for i = 0, 4 do
			local a = i * math.pi * 2 / 5
			P(m, "Frond", Vector3.new(1.4, 0.3, 6) * s, top * CFrame.Angles(0, a, 0) * CFrame.new(0, 1, -3 * s) * CFrame.Angles(math.rad(-20), 0, 0), Color3.fromRGB(60, 170, 70), { shadow = true })
		end
	elseif kind == "pines" then
		Kit.Column(m, rot, 3 * s, 1.2 * s, { name = "Trunk", color = F.trunk })
		for i = 0, 2 do
			local w = (7 - i * 2) * s
			P(m, "Needles", Vector3.new(w, 2.6 * s, w), rot * CFrame.new(0, (3.6 + i * 2.4) * s, 0) * CFrame.Angles(0, math.rad(45 * i), 0), Color3.fromRGB(40, 110, 70), { shadow = i == 0 })
		end
		P(m, "Snow", Vector3.new(1.6, 1.4, 1.6) * s, rot * CFrame.new(0, 10.5 * s, 0), F.white)
	elseif kind == "cacti" then
		local g = Color3.fromRGB(70, 150, 80)
		Kit.Column(m, rot, 8 * s, 1.8 * s, { name = "Cactus", color = g, shadow = true })
		P(m, "ArmL", Vector3.new(2.4, 1.2, 1.2) * s, rot * CFrame.new(-1.6 * s, 4 * s, 0), g)
		P(m, "ArmLUp", Vector3.new(1.2, 2.6, 1.2) * s, rot * CFrame.new(-2.6 * s, 5.5 * s, 0), g)
		P(m, "ArmR", Vector3.new(2.4, 1.2, 1.2) * s, rot * CFrame.new(1.6 * s, 5.4 * s, 0), g)
		P(m, "ArmRUp", Vector3.new(1.2, 2, 1.2) * s, rot * CFrame.new(2.6 * s, 6.6 * s, 0), g)
		P(m, "Bloom", Vector3.one * 0.9, rot * CFrame.new(0, 8.2 * s, 0), Color3.fromRGB(255, 110, 150), { shape = "Ball" })
	elseif kind == "rocks" then
		local dark = Color3.fromRGB(58, 50, 52)
		P(m, "Rock", Vector3.new(5, 3.6, 4) * s, rot * CFrame.new(0, 1.4 * s, 0) * CFrame.Angles(0.2, 0.4, 0.1), dark, { shadow = true, collide = true })
		P(m, "Rock", Vector3.new(3, 2.4, 3) * s, rot * CFrame.new(3 * s, 0.9 * s, 1.5 * s) * CFrame.Angles(-0.3, 1, 0.2), dark)
		P(m, "Lava", Vector3.new(0.5, 0.3, 3.6) * s, rot * CFrame.new(0, 3.2 * s, 0) * CFrame.Angles(0.2, 0.4, 0.1), Color3.fromRGB(255, 110, 30), { material = NEON })
	elseif kind == "crystals" then
		local c = Color3.fromRGB(190, 120, 255)
		for i = 0, 2 do
			local tilt = CFrame.Angles(math.rad(-15 + i * 15), 0, math.rad(12 - i * 12))
			P(m, "Crystal", Vector3.new(1.4, 5 - i, 1.4) * s, rot * CFrame.new((i - 1) * 1.4 * s, (2.5 - i * 0.5) * s, 0) * tilt * CFrame.Angles(0, math.rad(45), 0), if i == 1 then Color3.fromRGB(120, 220, 255) else c, {
				material = NEON,
				transparency = 0.15,
			})
		end
		P(m, "Base", Vector3.new(3.6, 0.8, 2.4) * s, rot * CFrame.new(0, 0.4, 0), F.darkStone)
	elseif kind == "orbs" then
		Kit.Column(m, rot, 3 * s, 1.6 * s, { name = "Pedestal", color = F.darkMetal })
		P(m, "Orb", Vector3.one * 2.6 * s, rot * CFrame.new(0, 5.4 * s, 0), Color3.fromRGB(120, 240, 255), { shape = "Ball", material = NEON })
		P(m, "Ring", Vector3.new(0.3, 4 * s, 4 * s), rot * CFrame.new(0, 5.4 * s, 0) * CFrame.Angles(0, 0, math.rad(70)), Color3.fromRGB(230, 90, 200), { shape = "Cylinder", transparency = 0.4 })
	else -- spires
		local gold = Color3.fromRGB(255, 200, 60)
		Kit.Column(m, rot, 1, 3 * s, { name = "Base", color = F.white })
		Kit.Column(m, rot * CFrame.new(0, 1, 0), 6 * s, 1.4 * s, { name = "Spire", color = F.white, shadow = true })
		Kit.Column(m, rot * CFrame.new(0, 1 + 6 * s, 0), 2 * s, 0.8 * s, { name = "Tip", color = gold })
		P(m, "Orb", Vector3.one * 1.4 * s, rot * CFrame.new(0, (3.6 + 8 * s) - 2.4 * s, 0), gold, { shape = "Ball", material = NEON })
	end
	m.Parent = parent
end

-- Hill ridge (with tunnel mouths at the given world positions) along a row of plots.
function Props.Ridge(parent: Instance, cf: CFrame, length: number, depth: number, tunnels: { CFrame })
	local m = Instance.new("Model")
	m.Name = "Ridge"
	local green = Color3.fromRGB(96, 160, 84)
	P(m, "Hill", Vector3.new(length, 26, depth), cf * CFrame.new(0, 13, -depth / 2), green, { material = Enum.Material.Grass, collide = true })
	P(m, "Slope", Vector3.new(length, 26, 30), cf * CFrame.new(0, 13, -depth - 15), green, {
		shape = "Wedge",
		material = Enum.Material.Grass,
		collide = true,
	})
	P(m, "Crest", Vector3.new(length, 8, depth * 0.6), cf * CFrame.new(0, 30, -depth * 0.55), green:Lerp(Color3.new(0, 0, 0), 0.08), {
		material = Enum.Material.Grass,
		collide = true,
	})
	for i, tcf in tunnels do
		local mouth = P(m, "Tunnel" .. i, Vector3.new(14, 11, 1), tcf * CFrame.new(0, 5.5, -0.4), F.black, { collide = false, shadow = false })
		mouth.Material = Enum.Material.SmoothPlastic
		P(m, "Arch", Vector3.new(16, 2, 2), tcf * CFrame.new(0, 12, 0.6), F.stone)
		P(m, "ArchL", Vector3.new(2, 11, 2), tcf * CFrame.new(-8, 5.5, 0.6), F.stone)
		P(m, "ArchR", Vector3.new(2, 11, 2), tcf * CFrame.new(8, 5.5, 0.6), F.stone)
		local sign = P(m, "MarketSign", Vector3.new(12, 2.4, 0.4), tcf * CFrame.new(0, 14.6, 0.6), F.yellow)
		Kit.Label(sign, "TO MARKET", Enum.NormalId.Back, Color3.fromRGB(40, 40, 40), 30).TextStrokeTransparency = 1
	end
	m.Parent = parent
end

return Props
