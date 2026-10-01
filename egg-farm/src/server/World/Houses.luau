--!strict
-- Housing tier models 1..10 (Data/Housing): Little Coop, Twin Coop, Hen House, Red Barn, Big Barn,
-- Poultry Hall, Egg Factory, Hen Tower, Sky Roost, Mega Dome. Tier 0 = the "For Sale" pad.
-- Built at the origin in the "house frame": door faces -Z, ground at y = 0, footprint at most
-- 34 (x) by 28 (z) studs (PlotLayout.Houses[i].buildingMax). World pivots the model into place.
-- Each tier visibly grows and gets more elaborate; colours come from the theme palette (roles)
-- so Kit.Recolor repaints them when the farm's egg changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Kit = require(Shared:WaitForChild("Models"):WaitForChild("Kit"))

local Houses = {}

local F = Kit.Fixed
local NEON = Enum.Material.Neon

type B = {
	m: Model,
	box: (self: B, name: string, size: Vector3, pos: Vector3, look: any, opts: { [string]: any }?) -> BasePart,
	at: (self: B, name: string, size: Vector3, cf: CFrame, look: any, opts: { [string]: any }?) -> BasePart,
}

-- `look` is a theme role (string) or a fixed Color3.
local function make(m: Model): B
	local b = { m = m } :: any
	function b.at(self: B, name: string, size: Vector3, cf: CFrame, look: any, opts: { [string]: any }?): BasePart
		local o: any = table.clone(opts or {})
		o.name, o.size, o.cf = name, size, cf
		if type(look) == "string" then
			o.role = look
		else
			o.color = look
		end
		return Kit.Part(self.m, o)
	end
	function b.box(self: B, name: string, size: Vector3, pos: Vector3, look: any, opts: { [string]: any }?): BasePart
		return self:at(name, size, CFrame.new(pos), look, opts)
	end
	return b :: B
end

local function gable(b: B, cf: CFrame, w: number, d: number, h: number, look: any, opts: { [string]: any }?)
	local o: any = table.clone(opts or {})
	o.shape = "Wedge"
	b:at("Roof", Vector3.new(w, h, d / 2), cf * CFrame.new(0, h / 2, -d / 4), look, o)
	b:at("Roof", Vector3.new(w, h, d / 2), cf * CFrame.new(0, h / 2, d / 4) * CFrame.Angles(0, math.pi, 0), look, o)
end

-- Cross-gable "spire" roof over a w x d base at `cf`: two gables at right angles. Plain wedges
-- only (no CornerWedge orientation guesswork), reads as a pointed roof from every side.
local function pyramid(b: B, cf: CFrame, w: number, d: number, h: number, look: any)
	gable(b, cf, w, d, h, look)
	gable(b, cf * CFrame.Angles(0, math.pi / 2, 0), d, w, h, look)
end

local function door(b: B, pos: Vector3, w: number, h: number, look: any?)
	b:box("Door", Vector3.new(w, h, 0.3), pos + Vector3.new(0, h / 2, 0), look or F.black, { shade = 0.35 })
end

local function window(b: B, pos: Vector3, w: number, h: number, glow: boolean?)
	b:box("Window", Vector3.new(w, h, 0.25), pos, if glow then Color3.fromRGB(255, 236, 170) else F.glass, {
		material = if glow then NEON else Enum.Material.Glass,
		transparency = if glow then 0 else 0.1,
	})
end

-- Small coop used by tiers 1 and 2. Origin at its ground centre, door to -Z.
local function coop(b: B, at: CFrame)
	for _, x in { -3, 3 } do
		for _, z in { -2.2, 2.2 } do
			b:at("Leg", Vector3.new(0.6, 1.2, 0.6), at * CFrame.new(x, 0.6, z), "wood", { shade = 0.25 })
		end
	end
	b:at("Floor", Vector3.new(8, 0.4, 6), at * CFrame.new(0, 1.4, 0), "wood", { shade = 0.15 })
	b:at("Walls", Vector3.new(7.6, 4, 5.6), at * CFrame.new(0, 3.6, 0), "wood")
	b:at("Trim", Vector3.new(8, 0.35, 6), at * CFrame.new(0, 5.55, 0), "accent")
	b:at("Roof", Vector3.new(8.8, 2.4, 3.4), at * CFrame.new(0, 6.9, -1.7), "roof", { shape = "Wedge" })
	b:at("Roof", Vector3.new(8.8, 2.4, 3.4), at * CFrame.new(0, 6.9, 1.7) * CFrame.Angles(0, math.pi, 0), "roof", { shape = "Wedge" })
	b:at("Door", Vector3.new(1.6, 2, 0.3), at * CFrame.new(0, 2.6, -2.85), F.black, { shade = 0.3 })
	b:at("Ramp", Vector3.new(1.6, 1.6, 2.6), at * CFrame.new(0, 0.8, -4.1), "wood", { shape = "Wedge", shade = 0.1 })
end

local builders: { (B) -> () } = {}

builders[1] = function(b) -- Little Coop
	coop(b, CFrame.new(0, 0, 2))
	b:box("Feeder", Vector3.new(2.4, 0.6, 1), Vector3.new(3.5, 0.3, -4), "accent")
end

builders[2] = function(b) -- Twin Coop
	coop(b, CFrame.new(-5.5, 0, 3))
	coop(b, CFrame.new(5.5, 0, 3))
	b:box("Walkway", Vector3.new(3, 0.4, 5), Vector3.new(0, 3.4, 3), "wood", { shade = 0.15 })
	-- small fenced run in front
	b:box("RunRail", Vector3.new(20, 0.3, 0.3), Vector3.new(0, 1.4, -6.5), F.white)
	b:box("RunRailL", Vector3.new(0.3, 0.3, 5), Vector3.new(-10, 1.4, -4), F.white)
	b:box("RunRailR", Vector3.new(0.3, 0.3, 5), Vector3.new(10, 1.4, -4), F.white)
	for _, x in { -10, -5, 5, 10 } do
		b:box("Post", Vector3.new(0.5, 1.8, 0.5), Vector3.new(x, 0.9, -6.5), F.white)
	end
	b:box("Feeder", Vector3.new(3, 0.6, 1), Vector3.new(0, 0.3, -2), "accent")
end

builders[3] = function(b) -- Hen House
	b:box("Base", Vector3.new(15, 0.8, 11), Vector3.new(0, 0.4, 0), F.stone)
	b:box("Walls", Vector3.new(14, 6, 10), Vector3.new(0, 3.8, 0), "wood")
	for _, x in { -7, 7 } do
		for _, z in { -5, 5 } do
			b:box("Corner", Vector3.new(0.6, 6, 0.6), Vector3.new(x, 3.8, z), F.white)
		end
	end
	gable(b, CFrame.new(0, 6.8, 0), 15.4, 11.6, 4.2, "roof")
	b:box("Gable", Vector3.new(14, 0.4, 10.2), Vector3.new(0, 6.9, 0), "accent")
	door(b, Vector3.new(0, 0.8, -5.1), 3, 4)
	b:box("DoorFrame", Vector3.new(3.8, 0.5, 0.35), Vector3.new(0, 5.05, -5.1), F.white)
	window(b, Vector3.new(-4.4, 4.2, -5.1), 2.2, 1.8)
	window(b, Vector3.new(4.4, 4.2, -5.1), 2.2, 1.8)
	b:box("Chimney", Vector3.new(1.4, 3.4, 1.4), Vector3.new(4.5, 9.5, 2.5), F.stone)
	b:box("Step", Vector3.new(4, 0.5, 1.4), Vector3.new(0, 0.25, -6), F.stone)
end

builders[4] = function(b) -- Red Barn (gambrel roof)
	local w, d, h = 18, 14, 8
	b:box("Base", Vector3.new(w + 0.8, 0.8, d + 0.8), Vector3.new(0, 0.4, 0), F.stone)
	b:box("Walls", Vector3.new(w, h, d), Vector3.new(0, 0.8 + h / 2, 0), "roof")
	local top = 0.8 + h
	for _, x in { -w / 2, w / 2 } do
		for _, z in { -d / 2, d / 2 } do
			b:box("Corner", Vector3.new(0.7, h, 0.7), Vector3.new(x, 0.8 + h / 2, z), F.white)
		end
	end
	local rw = w + 0.8
	b:box("RoofCore", Vector3.new(rw, 4, 8), Vector3.new(0, top + 2, 0), "wood", { shade = 0.35 })
	b:at("RoofLow", Vector3.new(rw, 4, 3.4), CFrame.new(0, top + 2, -5.6), "wood", { shape = "Wedge", shade = 0.35 })
	b:at("RoofLow", Vector3.new(rw, 4, 3.4), CFrame.new(0, top + 2, 5.6) * CFrame.Angles(0, math.pi, 0), "wood", { shape = "Wedge", shade = 0.35 })
	b:at("RoofHigh", Vector3.new(rw, 2.2, 4), CFrame.new(0, top + 5.1, -2), "wood", { shape = "Wedge", shade = 0.35 })
	b:at("RoofHigh", Vector3.new(rw, 2.2, 4), CFrame.new(0, top + 5.1, 2) * CFrame.Angles(0, math.pi, 0), "wood", { shape = "Wedge", shade = 0.35 })
	-- big barn door with white X
	local dz = -d / 2 - 0.1
	b:box("Door", Vector3.new(6, 6.5, 0.3), Vector3.new(0, 0.8 + 3.25, dz), "roof", { shade = 0.25 })
	b:box("DoorFrame", Vector3.new(6.8, 0.6, 0.4), Vector3.new(0, 7.35, dz - 0.05), F.white)
	b:at("Brace", Vector3.new(0.5, 8.6, 0.4), CFrame.new(0, 4.05, dz - 0.1) * CFrame.Angles(0, 0, math.atan2(6, 6.5)), F.white)
	b:at("Brace", Vector3.new(0.5, 8.6, 0.4), CFrame.new(0, 4.05, dz - 0.1) * CFrame.Angles(0, 0, -math.atan2(6, 6.5)), F.white)
	b:box("Loft", Vector3.new(3.4, 2.6, 0.3), Vector3.new(0, top + 2, -d / 2 - 1.6), F.black, { shade = 0.2 })
	b:box("Hay", Vector3.new(2.6, 1.2, 0.6), Vector3.new(0, top + 1.2, -d / 2 - 1.9), F.hay)
	window(b, Vector3.new(-6, 5, dz), 2, 2)
	window(b, Vector3.new(6, 5, dz), 2, 2)
	b:box("Vane", Vector3.new(0.2, 2.2, 0.2), Vector3.new(0, top + 7.3, 0), F.darkMetal)
	b:box("VaneArrow", Vector3.new(2, 0.2, 0.2), Vector3.new(0, top + 8.1, 0), "accent")
end

builders[5] = function(b) -- Big Barn: wider barn, silo tower, lean-to and a cupola
	local w, d, h = 22, 16, 9
	b:box("Base", Vector3.new(w + 1, 0.8, d + 1), Vector3.new(-2, 0.4, 0), F.stone)
	b:box("Walls", Vector3.new(w, h, d), Vector3.new(-2, 0.8 + h / 2, 0), "roof")
	local top = 0.8 + h
	for _, x in { -w / 2 - 2, w / 2 - 2 } do
		for _, z in { -d / 2, d / 2 } do
			b:box("Corner", Vector3.new(0.8, h, 0.8), Vector3.new(x, 0.8 + h / 2, z), F.white)
		end
	end
	b:box("Band", Vector3.new(w + 0.2, 0.6, d + 0.2), Vector3.new(-2, 0.8 + h * 0.55, 0), F.white)
	gable(b, CFrame.new(-2, top, 0), w + 1, d + 1.4, 6, "wood", { shade = 0.35 })
	b:box("Cupola", Vector3.new(3, 2.6, 3), Vector3.new(-2, top + 6.6, 0), F.white)
	gable(b, CFrame.new(-2, top + 7.9, 0), 3.6, 3.6, 1.6, "roof")
	local dz = -d / 2 - 0.1
	b:box("Door", Vector3.new(7, 7, 0.3), Vector3.new(-2, 0.8 + 3.5, dz), "roof", { shade = 0.25 })
	b:box("DoorFrame", Vector3.new(7.8, 0.6, 0.4), Vector3.new(-2, 8.1, dz - 0.05), F.white)
	b:at("Brace", Vector3.new(0.5, 9.4, 0.4), CFrame.new(-2, 4.3, dz - 0.1) * CFrame.Angles(0, 0, math.atan2(7, 7)), F.white)
	b:at("Brace", Vector3.new(0.5, 9.4, 0.4), CFrame.new(-2, 4.3, dz - 0.1) * CFrame.Angles(0, 0, -math.atan2(7, 7)), F.white)
	b:box("Loft", Vector3.new(4, 3, 0.3), Vector3.new(-2, top + 2, -d / 2 - 0.9), F.black, { shade = 0.2 })
	window(b, Vector3.new(-9, 5.5, dz), 2.4, 2.2)
	window(b, Vector3.new(5, 5.5, dz), 2.4, 2.2)
	-- silo tower on the right
	Kit.Column(b.m, CFrame.new(13, 0, 2), 18, 7, { role = "wood", shade = 0.05, name = "Tower" })
	Kit.Column(b.m, CFrame.new(13, 6, 2), 0.6, 7.3, { role = "accent", name = "TowerBand" })
	Kit.Column(b.m, CFrame.new(13, 12, 2), 0.6, 7.3, { role = "accent", name = "TowerBand" })
	b:box("TowerCap", Vector3.new(7.2, 7.2, 7.2), Vector3.new(13, 18, 2), "roof", { shape = "Ball" })
	-- lean-to on the left
	b:box("LeanTo", Vector3.new(4, 5, 12), Vector3.new(-15, 3.3, 1), "wood", { shade = 0.1 })
	b:at("LeanRoof", Vector3.new(12.6, 2, 5), CFrame.new(-15, 6.8, 1) * CFrame.Angles(0, math.pi / 2, 0), "roof", { shape = "Wedge", shade = 0.1 })
	b:box("HayStack", Vector3.new(3, 2, 3), Vector3.new(-15.5, 1, -7.5), F.hay)
end

builders[6] = function(b) -- Poultry Hall: a long hall with a ridge vent, window rows and fans
	local w, d, h = 32, 18, 7.5
	b:box("Base", Vector3.new(w + 1, 1, d + 1), Vector3.new(0, 0.5, 0), F.stone)
	b:box("Walls", Vector3.new(w, h, d), Vector3.new(0, 1 + h / 2, 0), "wood")
	local top = 1 + h
	b:box("Skirt", Vector3.new(w + 0.3, 1.4, d + 0.3), Vector3.new(0, 1.7, 0), "roof", { shade = 0.2 })
	gable(b, CFrame.new(0, top, 0), w + 1.6, d + 2, 5.5, "roof")
	b:box("Vent", Vector3.new(w - 6, 1.6, 3), Vector3.new(0, top + 6.1, 0), "accent")
	gable(b, CFrame.new(0, top + 6.9, 0), w - 5, 4, 1.4, "roof", { shade = 0.15 })
	for i = -3, 3 do
		if i ~= 0 then
			window(b, Vector3.new(i * 4.4, 5.6, -d / 2 - 0.1), 2.6, 2, true)
		end
	end
	door(b, Vector3.new(0, 1, -d / 2 - 0.1), 4.6, 5.2)
	b:box("Sign", Vector3.new(10, 2.2, 0.4), Vector3.new(0, top + 0.3, -d / 2 - 1.2), "accent")
	for _, x in { -w / 2 - 0.2, w / 2 + 0.2 } do
		for _, z in { -4, 4 } do
			b:at("Fan", Vector3.new(0.5, 3.2, 3.2), CFrame.new(x, 5, z), F.darkMetal, { shape = "Cylinder" })
		end
	end
	b:box("Ramp", Vector3.new(6, 1, 3), Vector3.new(0, 0.5, -d / 2 - 2), F.stone)
	b:box("Silo", Vector3.new(4, 9, 4), Vector3.new(-w / 2 + 1, 4.5, d / 2 + 2.4), F.metal)
	b:box("SiloCap", Vector3.new(4.4, 1.2, 4.4), Vector3.new(-w / 2 + 1, 9.6, d / 2 + 2.4), "roof")
end

builders[7] = function(b) -- Egg Factory: industrial block, sawtooth roof, chimneys, conveyor
	local w, d, h = 30, 20, 10
	b:box("Base", Vector3.new(w + 1, 1, d + 1), Vector3.new(0, 0.5, 0), F.darkStone)
	b:box("Walls", Vector3.new(w, h, d), Vector3.new(0, 1 + h / 2, 0), F.stone)
	local top = 1 + h
	b:box("Stripe", Vector3.new(w + 0.2, 1.2, d + 0.2), Vector3.new(0, top - 1.2, 0), "accent")
	b:box("Stripe2", Vector3.new(w + 0.2, 0.6, d + 0.2), Vector3.new(0, 2.2, 0), "roof")
	-- sawtooth roof: 4 wedges across the width, glass faces to the front
	for i = 0, 3 do
		local x = -w / 2 + 3.75 + i * 7.5
		b:at("Saw", Vector3.new(d, 3.2, 7.5), CFrame.new(x, top + 1.6, 0) * CFrame.Angles(0, math.pi / 2, 0), "roof", { shape = "Wedge" })
		b:box("SawGlass", Vector3.new(0.3, 3, d - 1), Vector3.new(x + 3.6, top + 1.5, 0), Color3.fromRGB(255, 236, 170), { material = NEON })
	end
	for _, x in { -10, -4 } do
		Kit.Column(b.m, CFrame.new(x, top, 6), 10, 2.6, { color = F.metal, name = "Chimney" })
		Kit.Column(b.m, CFrame.new(x, top + 8, 6), 1, 2.9, { role = "roof", name = "ChimneyBand" })
	end
	-- roll-up door and lit windows
	b:box("RollDoor", Vector3.new(7, 6.5, 0.3), Vector3.new(-6, 1 + 3.25, -d / 2 - 0.1), F.metal)
	for i = 0, 4 do
		b:box("DoorRib", Vector3.new(7, 0.15, 0.4), Vector3.new(-6, 2 + i * 1.3, -d / 2 - 0.15), F.darkMetal)
	end
	for _, x in { 3, 7.5, 12 } do
		window(b, Vector3.new(x, 7, -d / 2 - 0.1), 3, 2.4, true)
	end
	-- conveyor coming out of the front with eggs on it
	b:box("Conveyor", Vector3.new(3, 0.6, 4), Vector3.new(6, 2.4, -d / 2 - 2), F.darkMetal)
	b:box("ConveyorLegs", Vector3.new(2.6, 2.1, 0.5), Vector3.new(6, 1.05, -d / 2 - 3.5), F.metal)
	for i = 0, 2 do
		Kit.Egg(b.m, CFrame.new(6, 3.15, -d / 2 - 0.9 - i * 1.35), Vector3.new(0.9, 1.2, 0.9), { color = F.cream, name = "Egg" })
	end
	-- big egg sign on the roof
	b:box("SignPost", Vector3.new(0.6, 4, 0.6), Vector3.new(9, top + 4, -4), F.darkMetal)
	Kit.Egg(b.m, CFrame.new(9, top + 8, -4), Vector3.new(4.5, 6, 1.5), { role = "accent", name = "EggSign" })
	b:box("Pipe", Vector3.new(1, 1, d), Vector3.new(w / 2 + 0.6, top - 3, 0), F.metal)
end

builders[8] = function(b) -- Hen Tower: base hall + three stacked floors with balconies, pyramid roof
	b:box("Base", Vector3.new(30, 1, 24), Vector3.new(0, 0.5, 0), F.stone)
	b:box("Hall", Vector3.new(28, 6, 22), Vector3.new(0, 4, 0), "wood")
	b:box("HallTrim", Vector3.new(28.4, 0.8, 22.4), Vector3.new(0, 7.4, 0), "accent")
	door(b, Vector3.new(0, 1, -11.1), 5, 5)
	for _, x in { -9, 9 } do
		window(b, Vector3.new(x, 4.5, -11.1), 3, 2, true)
	end
	local y = 7.8
	local sizes = { 16, 14, 12 }
	for i, s in sizes do
		b:box("Floor" .. i, Vector3.new(s, 7, s), Vector3.new(0, y + 3.5, 1), "wood", { shade = if i % 2 == 0 then 0.08 else 0 })
		b:box("Balcony" .. i, Vector3.new(s + 3, 0.6, s + 3), Vector3.new(0, y + 0.3, 1), "roof", { shade = 0.15 })
		b:box("Rail" .. i, Vector3.new(s + 3, 1, 0.3), Vector3.new(0, y + 1.1, 1 - (s + 3) / 2), "accent")
		window(b, Vector3.new(-s / 4, y + 4, 1 - s / 2 - 0.1), 2.4, 2.4, true)
		window(b, Vector3.new(s / 4, y + 4, 1 - s / 2 - 0.1), 2.4, 2.4, true)
		y += 7
	end
	pyramid(b, CFrame.new(0, y, 1), 13.4, 13.4, 7, "roof")
	b:box("FlagPole", Vector3.new(0.3, 5, 0.3), Vector3.new(0, y + 9.5, 1), F.metal)
	b:box("Flag", Vector3.new(0.15, 1.6, 2.6), Vector3.new(0, y + 11.1, 2.4), "accent")
end

builders[9] = function(b) -- Sky Roost: glass tower with floating roost platforms and a balloon
	b:box("Base", Vector3.new(30, 1, 26), Vector3.new(0, 0.5, 0), F.stone)
	b:box("Hall", Vector3.new(24, 6, 18), Vector3.new(0, 4, 2), "wood")
	b:box("HallTrim", Vector3.new(24.4, 0.8, 18.4), Vector3.new(0, 7.4, 2), "accent")
	door(b, Vector3.new(0, 1, -7.1), 5, 5)
	local y = 7.8
	for i = 1, 4 do
		b:box("Storey" .. i, Vector3.new(12, 6, 12), Vector3.new(0, y + 3, 2), "wood", { shade = if i % 2 == 0 then 0.1 else 0 })
		b:box("Glass" .. i, Vector3.new(12.3, 2, 12.3), Vector3.new(0, y + 3.4, 2), Color3.fromRGB(150, 230, 255), { material = NEON, transparency = 0.25 })
		y += 6
	end
	b:box("TopDeck", Vector3.new(14, 0.8, 14), Vector3.new(0, y + 0.4, 2), "roof")
	pyramid(b, CFrame.new(0, y + 0.8, 2), 10, 10, 5, "roof")
	b:box("Antenna", Vector3.new(0.4, 6, 0.4), Vector3.new(0, y + 8.8, 2), F.metal)
	b:box("Beacon", Vector3.new(1, 1, 1), Vector3.new(0, y + 12, 2), "accent", { material = NEON, shape = "Ball" })
	-- floating roost platforms on both sides with little coops and bridges
	for _, side in { -1, 1 } do
		local px, py = side * 12, 16 + (if side > 0 then 6 else 0)
		Kit.Column(b.m, CFrame.new(px, py - 1, 2), 1, 9, { role = "groundEdge", name = "Platform" })
		Kit.Column(b.m, CFrame.new(px, py - 2.2, 2), 1.2, 4, { color = Color3.fromRGB(150, 230, 255), material = NEON, transparency = 0.3, name = "Hover" })
		b:box("MiniCoop", Vector3.new(4.5, 3, 4), Vector3.new(px, py + 1.5, 2), "wood")
		gable(b, CFrame.new(px, py + 3, 2), 5.2, 4.8, 1.8, "roof")
		b:box("Bridge", Vector3.new(4, 0.4, 2.2), Vector3.new(side * 7.5, py - 0.3, 2), "accent")
	end
	Kit.Egg(b.m, CFrame.new(-11, y + 4, 9), Vector3.new(6, 7, 6), { role = "accent", name = "Balloon", shadow = true })
	b:box("BalloonRope", Vector3.new(0.2, 8, 0.2), Vector3.new(-9, y - 3, 7), F.white)
end

builders[10] = function(b) -- Mega Dome: domed hall, ring of glowing pillars, giant egg on top
	Kit.Column(b.m, CFrame.new(0, 0, 0), 2.2, 28, { color = F.stone, name = "Base" })
	Kit.Column(b.m, CFrame.new(0, 2.2, 0), 0.8, 26.6, { role = "accent", name = "BaseRing" })
	b:box("Dome", Vector3.new(26, 26, 26), Vector3.new(0, 2.2, 0), "roof", { shape = "Ball" })
	Kit.Column(b.m, CFrame.new(0, 7.2, 0), 1.2, 24.6, { role = "accent", name = "Band" })
	Kit.Column(b.m, CFrame.new(0, 11.4, 0), 1, 20.5, { color = Color3.fromRGB(255, 240, 190), material = NEON, name = "LightBand" })
	-- entrance
	b:box("Entrance", Vector3.new(8, 7, 7), Vector3.new(0, 5.7, -10.3), "wood")
	b:at("Arch", Vector3.new(7, 8.2, 8.2), CFrame.new(0, 9.2, -10.3) * CFrame.Angles(0, math.pi / 2, 0), "roof", { shape = "Cylinder" })
	door(b, Vector3.new(0, 2.2, -13.9), 4.4, 5)
	-- pillars with glowing tips around the dome
	for i = 0, 7 do
		local a = (i + 0.5) * math.pi / 4
		local x, z = math.sin(a) * 13.4, math.cos(a) * 13.4
		if z > -9 or math.abs(x) > 6 then
			Kit.Column(b.m, CFrame.new(x, 2.2, z), 9, 1.4, { role = "wood", shade = 0.1, name = "Pillar" })
			b:box("PillarTip", Vector3.new(1.8, 1.8, 1.8), Vector3.new(x, 12.2, z), "accent", { shape = "Ball", material = NEON })
		end
	end
	-- the giant egg
	Kit.Column(b.m, CFrame.new(0, 14.6, 0), 1.6, 6, { color = F.metal, name = "EggStand" })
	Kit.Egg(b.m, CFrame.new(0, 20.4, 0), Vector3.new(7, 9.5, 7), { role = "accent", name = "GiantEgg", shadow = true, reflect = 0.15 })
	b:box("Spire", Vector3.new(0.5, 4, 0.5), Vector3.new(0, 27, 0), F.metal)
end

-- "For Sale" pad: a dashed outline and a sign. Lives in the same frame as the tier models.
local function forSale(b: B)
	for _, s in { { Vector3.new(26, 0.25, 1), Vector3.new(0, 0.12, -11) }, { Vector3.new(26, 0.25, 1), Vector3.new(0, 0.12, 11) }, { Vector3.new(1, 0.25, 22), Vector3.new(-13, 0.12, 0) }, { Vector3.new(1, 0.25, 22), Vector3.new(13, 0.12, 0) } } do
		b:box("Outline", s[1], s[2], F.white, { transparency = 0.25 })
	end
	b:box("SignPost", Vector3.new(0.5, 5, 0.5), Vector3.new(-3, 2.5, -9), "wood")
	b:box("SignPost", Vector3.new(0.5, 5, 0.5), Vector3.new(3, 2.5, -9), "wood")
	local board = b:box("SignBoard", Vector3.new(8, 3, 0.4), Vector3.new(0, 4.6, -9), F.white, { shadow = true })
	Kit.Label(board, "FOR SALE", Enum.NormalId.Front, Color3.fromRGB(210, 50, 50), 40)
	Kit.Label(board, "FOR SALE", Enum.NormalId.Back, Color3.fromRGB(210, 50, 50), 40)
	for _, p in { Vector3.new(-13, 1, -11), Vector3.new(13, 1, -11), Vector3.new(-13, 1, 11), Vector3.new(13, 1, 11) } do
		b:box("Stake", Vector3.new(0.3, 2, 0.3), p, "wood")
		b:box("Flag", Vector3.new(0.1, 0.6, 0.9), p + Vector3.new(0, 0.7, 0.5), "accent")
	end
end

-- Build the model for `tier` (0 = for sale) with the given palette. Returns a Model whose pivot is
-- the house-frame origin.
function Houses.Build(tier: number, palette: Kit.Palette): Model
	Kit.SetPalette(palette)
	local m = Instance.new("Model")
	m.Name = if tier > 0 then "Tier" .. tier else "ForSale"
	local b = make(m)
	if tier <= 0 then
		forSale(b)
	else
		local fn = builders[math.clamp(tier, 1, #builders)]
		fn(b)
	end
	m:SetAttribute("Tier", tier)
	m.WorldPivot = CFrame.identity
	return m
end

Houses.MaxTier = #builders

return Houses
