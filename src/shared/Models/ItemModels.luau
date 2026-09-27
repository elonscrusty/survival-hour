--!nonstrict
-- Hand-held item models and world-pickup visuals.
-- Held models: PrimaryPart "Handle", built so that the Handle's CFrame is the
-- grip. The server welds Handle to the character's RightHand with `Grip`.

local Build = require("./Build")
local Skins = require("./Skins")

local ItemModels = {}

-- Mesh-pack look for held items. The pack's tools point their barrel/blade
-- along -Z with up +Y; this game's grips differ per item, so each entry maps
-- the pack frame onto this game's Handle frame.
local UP_TO_FORWARD = CFrame.Angles(0, 0, math.pi) * CFrame.Angles(-math.pi / 2, 0, 0) -- haft up -> haft along -Z, head up
local HELD_SKINS: { [string]: { string | CFrame } } = {
	Spear = { "Spear", CFrame.new() },
	Bow = { "Bow", CFrame.new() },
	Sword = { "Sword", UP_TO_FORWARD },
	Shield = { "Shield", CFrame.Angles(0, math.pi / 2, 0) },
	Pistol = { "Pistol", CFrame.new() },
	Rifle = { "Rifle", CFrame.new() },
	StoneAxe = { "StoneAxe", UP_TO_FORWARD },
	RepairHammer = { "RepairHammer", UP_TO_FORWARD },
	Canteen = { "Canteen", CFrame.new() },
	Bandage = { "Bandage_Held", CFrame.new() },
	Arrow = { "SM_Arrow", CFrame.new() },
	Bullet = { "SM_Pickup_Ammo", CFrame.new(0, -0.3, 0) },
}
-- World pickups for raw resources.
local PICKUP_SKINS = {
	Stick = "SM_Pickup_Stick",
	Stone = "SM_Pickup_Stone",
	Wood = "SM_Pickup_Wood",
	Plant = "SM_Pickup_Fiber",
	Leather = "SM_Pickup_Leather",
	Rope = "SM_Pickup_Rope",
}

local WOOD = Color3.fromRGB(140, 100, 64)
local WOOD_DARK = Color3.fromRGB(96, 66, 42)
local STONE = Color3.fromRGB(128, 128, 132)
local STEEL = Color3.fromRGB(196, 202, 212)
local LEATHER = Color3.fromRGB(150, 92, 60)
local ROPE = Color3.fromRGB(205, 180, 120)

-- Grip transform (applied as RightHand.CFrame * Grip) per item.
ItemModels.Grip = {
	Default = CFrame.new(0, -0.15, 0) * CFrame.Angles(math.rad(-90), 0, 0),
	Bow = CFrame.new(0, -0.15, 0) * CFrame.Angles(0, math.rad(90), 0),
	Shield = CFrame.new(0, -0.1, -0.3) * CFrame.Angles(0, math.rad(90), 0),
	Canteen = CFrame.new(0, -0.3, 0),
}

local function handle(m: Model, size: Vector3, color: Color3, material: Enum.Material): BasePart
	local h = Build.Part({ Name = "Handle", Size = size, CFrame = CFrame.new(), Color = color, Material = material, Parent = m, Anchored = false, CanCollide = false, CanQuery = false, Massless = true })
	m.PrimaryPart = h
	return h
end

local function piece(m: Model, p: Build.PartProps): BasePart
	p.Parent = m
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	return Build.Part(p)
end

-- Builds with Handle at origin; all parts welded to it.
local builders: { [string]: (Model) -> () } = {}

builders.Spear = function(m)
	handle(m, Vector3.new(0.35, 0.35, 1.2), WOOD_DARK, Enum.Material.Wood)
	piece(m, { Name = "Shaft", Size = Vector3.new(0.3, 0.3, 9), CFrame = CFrame.new(0, 0, -2.8), Color = WOOD, Material = Enum.Material.Wood })
	piece(m, { Name = "Tip", Class = "WedgePart", Size = Vector3.new(0.25, 0.7, 1.6), CFrame = CFrame.new(0, 0.2, -8) * CFrame.Angles(0, math.rad(180), 0), Color = STONE, Material = Enum.Material.Slate })
	piece(m, { Name = "Tip", Class = "WedgePart", Size = Vector3.new(0.25, 0.7, 1.6), CFrame = CFrame.new(0, -0.2, -8) * CFrame.Angles(0, math.rad(180), math.rad(180)), Color = STONE, Material = Enum.Material.Slate })
	piece(m, { Name = "Wrap", Size = Vector3.new(0.4, 0.4, 0.6), CFrame = CFrame.new(0, 0, -6.9), Color = ROPE, Material = Enum.Material.Fabric })
end

builders.Bow = function(m)
	handle(m, Vector3.new(0.35, 0.8, 0.35), LEATHER, Enum.Material.Fabric)
	for i, seg in { { 1.6, 20 }, { -1.6, -20 } } do
		piece(m, { Name = "Limb" .. i, Size = Vector3.new(0.25, 2.8, 0.3), CFrame = CFrame.new(0, seg[1], -0.35) * CFrame.Angles(math.rad(seg[2]), 0, 0), Color = WOOD, Material = Enum.Material.Wood })
		piece(m, { Name = "LimbTip" .. i, Size = Vector3.new(0.22, 1.2, 0.26), CFrame = CFrame.new(0, seg[1] * 1.85, -0.2) * CFrame.Angles(math.rad(-seg[2] * 1.2), 0, 0), Color = WOOD_DARK, Material = Enum.Material.Wood })
	end
	piece(m, { Name = "String", Size = Vector3.new(0.06, 6.2, 0.06), CFrame = CFrame.new(0, 0, 0.45), Color = Color3.fromRGB(230, 226, 210), Material = Enum.Material.SmoothPlastic })
end

builders.Sword = function(m)
	handle(m, Vector3.new(0.35, 0.35, 1.2), LEATHER, Enum.Material.Fabric)
	piece(m, { Name = "Guard", Size = Vector3.new(1.8, 0.3, 0.35), CFrame = CFrame.new(0, 0, -0.75), Color = Color3.fromRGB(120, 100, 70), Material = Enum.Material.Metal })
	piece(m, { Name = "Blade", Size = Vector3.new(0.5, 0.12, 4.2), CFrame = CFrame.new(0, 0, -3), Color = STEEL, Material = Enum.Material.Metal, Reflectance = 0.15 })
	piece(m, { Name = "Point", Class = "WedgePart", Size = Vector3.new(0.12, 0.25, 0.8), CFrame = CFrame.new(0.12, 0, -5.5) * CFrame.Angles(0, math.rad(180), math.rad(90)), Color = STEEL, Material = Enum.Material.Metal })
	piece(m, { Name = "Pommel", Size = Vector3.new(0.45, 0.45, 0.45), CFrame = CFrame.new(0, 0, 0.7), Color = Color3.fromRGB(120, 100, 70), Material = Enum.Material.Metal })
end

builders.Shield = function(m)
	handle(m, Vector3.new(0.3, 0.8, 0.3), LEATHER, Enum.Material.Fabric)
	local face = piece(m, { Name = "Face", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 4.2, 4.2), CFrame = CFrame.new(-0.35, 0, 0), Color = WOOD, Material = Enum.Material.WoodPlanks })
	face:SetAttribute("TeamTint", false)
	piece(m, { Name = "Rim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 4.5, 4.5), CFrame = CFrame.new(-0.3, 0, 0), Color = Color3.fromRGB(80, 80, 86), Material = Enum.Material.Metal })
	piece(m, { Name = "Boss", Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(-0.6, 0, 0), Color = STEEL, Material = Enum.Material.Metal })
end

builders.Pistol = function(m)
	handle(m, Vector3.new(0.4, 1, 0.45), WOOD_DARK, Enum.Material.Wood)
	piece(m, { Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 0.35, 0.35), CFrame = CFrame.new(0, 0.5, -0.8) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(70, 70, 74), Material = Enum.Material.Metal })
	piece(m, { Name = "Lock", Size = Vector3.new(0.3, 0.4, 0.6), CFrame = CFrame.new(0.15, 0.55, 0), Color = Color3.fromRGB(160, 140, 90), Material = Enum.Material.Metal })
end

builders.Rifle = function(m)
	handle(m, Vector3.new(0.4, 0.8, 0.5), WOOD_DARK, Enum.Material.Wood)
	piece(m, { Name = "Stock", Size = Vector3.new(0.45, 0.8, 2), CFrame = CFrame.new(0, 0, 1.3), Color = WOOD, Material = Enum.Material.Wood })
	piece(m, { Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4.5, 0.32, 0.32), CFrame = CFrame.new(0, 0.35, -2.2) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(60, 60, 64), Material = Enum.Material.Metal })
	piece(m, { Name = "Fore", Size = Vector3.new(0.42, 0.4, 2.4), CFrame = CFrame.new(0, 0.05, -1.4), Color = WOOD, Material = Enum.Material.Wood })
end

builders.StoneAxe = function(m)
	handle(m, Vector3.new(0.35, 0.35, 1), WOOD_DARK, Enum.Material.Wood)
	piece(m, { Name = "Haft", Size = Vector3.new(0.32, 0.32, 3.4), CFrame = CFrame.new(0, 0, -1.4), Color = WOOD, Material = Enum.Material.Wood })
	piece(m, { Name = "Head", Class = "WedgePart", Size = Vector3.new(0.5, 1.6, 1.3), CFrame = CFrame.new(0, 0.7, -2.9) * CFrame.Angles(0, 0, 0), Color = STONE, Material = Enum.Material.Slate })
	piece(m, { Name = "Lash", Size = Vector3.new(0.45, 0.5, 0.6), CFrame = CFrame.new(0, 0.15, -2.9), Color = ROPE, Material = Enum.Material.Fabric })
end

builders.RepairHammer = function(m)
	handle(m, Vector3.new(0.35, 0.35, 1), WOOD_DARK, Enum.Material.Wood)
	piece(m, { Name = "Haft", Size = Vector3.new(0.3, 0.3, 2.6), CFrame = CFrame.new(0, 0, -1.1), Color = WOOD, Material = Enum.Material.Wood })
	piece(m, { Name = "Head", Size = Vector3.new(0.7, 0.7, 1.6), CFrame = CFrame.new(0, 0, -2.5) * CFrame.Angles(math.rad(90), 0, 0), Color = STONE, Material = Enum.Material.Slate })
end

builders.Canteen = function(m)
	handle(m, Vector3.new(0.3, 0.6, 0.3), LEATHER, Enum.Material.Fabric)
	piece(m, { Name = "Body", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7, 1.6, 1.6), CFrame = CFrame.new(0, -0.9, 0) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(70, 110, 150), Material = Enum.Material.Metal })
	piece(m, { Name = "Cap", Size = Vector3.new(0.35, 0.35, 0.35), CFrame = CFrame.new(0, -0.05, 0), Color = Color3.fromRGB(60, 60, 60), Material = Enum.Material.Metal })
end

builders.Bandage = function(m)
	handle(m, Vector3.new(0.5, 0.5, 0.8), Color3.fromRGB(240, 236, 226), Enum.Material.Fabric)
	piece(m, { Name = "Cross", Size = Vector3.new(0.52, 0.2, 0.52), CFrame = CFrame.new(0, 0.2, 0), Color = Color3.fromRGB(210, 60, 60), Material = Enum.Material.SmoothPlastic })
end

builders.Armor = function(m)
	handle(m, Vector3.new(2, 2, 1), LEATHER, Enum.Material.Fabric)
	piece(m, { Name = "Strap", Size = Vector3.new(0.4, 2.1, 1.05), CFrame = CFrame.new(0.5, 0, 0), Color = Color3.fromRGB(100, 60, 40), Material = Enum.Material.Fabric })
end

builders.Arrow = function(m)
	handle(m, Vector3.new(0.12, 0.12, 2.6), WOOD, Enum.Material.Wood)
	piece(m, { Name = "Tip", Class = "WedgePart", Size = Vector3.new(0.08, 0.3, 0.5), CFrame = CFrame.new(0, 0, -1.5) * CFrame.Angles(0, math.rad(180), 0), Color = STONE, Material = Enum.Material.Slate })
	piece(m, { Name = "Fletch", Size = Vector3.new(0.04, 0.35, 0.5), CFrame = CFrame.new(0, 0, 1.1), Color = Color3.fromRGB(220, 220, 220), Material = Enum.Material.SmoothPlastic })
end

builders.Bullet = function(m)
	handle(m, Vector3.new(0.9, 0.6, 0.6), Color3.fromRGB(120, 90, 60), Enum.Material.Fabric)
	piece(m, { Name = "Shot", Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.3, 0.3), CFrame = CFrame.new(0, 0.35, 0), Color = Color3.fromRGB(90, 90, 96), Material = Enum.Material.Metal })
end

local RESOURCE_LOOK = {
	Stick = { Color3.fromRGB(140, 100, 64), Enum.Material.Wood, Vector3.new(0.3, 0.3, 2.4) },
	Stone = { Color3.fromRGB(128, 128, 132), Enum.Material.Slate, Vector3.new(1, 0.8, 1) },
	Wood = { Color3.fromRGB(150, 108, 70), Enum.Material.Wood, Vector3.new(0.9, 0.9, 2.2) },
	Plant = { Color3.fromRGB(110, 170, 80), Enum.Material.Grass, Vector3.new(1, 0.6, 1) },
	Leather = { Color3.fromRGB(150, 92, 60), Enum.Material.Fabric, Vector3.new(1.4, 0.2, 1.2) },
	Rope = { Color3.fromRGB(205, 180, 120), Enum.Material.Fabric, Vector3.new(1.2, 0.5, 1.2) },
	Scrap = { Color3.fromRGB(150, 130, 110), Enum.Material.CorrodedMetal, Vector3.new(1.1, 0.4, 0.9) },
	Iron = { Color3.fromRGB(170, 120, 100), Enum.Material.Metal, Vector3.new(0.9, 0.6, 0.9) },
	Coal = { Color3.fromRGB(45, 45, 50), Enum.Material.Basalt, Vector3.new(0.8, 0.7, 0.8) },
	RareComponent = { Color3.fromRGB(230, 190, 80), Enum.Material.Metal, Vector3.new(0.6, 0.6, 0.6) },
}

function ItemModels.HasModel(id: string): boolean
	return builders[id] ~= nil or RESOURCE_LOOK[id] ~= nil
end

-- Builds an unanchored held model (Handle is the grip point).
function ItemModels.Held(id: string): Model?
	local b = builders[id]
	if not b then
		return nil
	end
	local m = Build.Model(id)
	b(m)
	local h = m.PrimaryPart :: BasePart
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d ~= h then
			local w = Instance.new("WeldConstraint")
			w.Part0 = h
			w.Part1 = d
			w.Parent = d
		end
	end
	local skin = HELD_SKINS[id]
	if skin then
		Skins.DressHeld(m, skin[1] :: string, skin[2] :: CFrame)
	end
	return m
end

function ItemModels.GripFor(id: string): CFrame
	return ItemModels.Grip[id] or ItemModels.Grip.Default
end

-- Anchored world pickup: the item model resting on a small glowing base.
function ItemModels.Pickup(id: string, count: number, cf: CFrame, parent: Instance?): Model
	local m = Build.Model("Pickup")
	local base = Build.Part({ Name = "Base", Size = Vector3.new(2.4, 0.3, 2.4), CFrame = CFrame.new(0, 0.15, 0), Transparency = 1, CanCollide = false, CanQuery = true, Parent = m })
	m.PrimaryPart = base
	local look = RESOURCE_LOOK[id]
	if look then
		for i = 1, math.min(count, 3) do
			Build.Part({ Name = "Res", Size = look[3], CFrame = CFrame.new((i - 2) * 0.6, 0.4 + i * 0.25, 0) * CFrame.Angles(0, i * 1.3, 0), Color = look[1], Material = look[2], Parent = m, CanCollide = false, CanQuery = false })
		end
	else
		local held = ItemModels.Held(id)
		if held then
			for _, d in held:GetDescendants() do
				if d:IsA("WeldConstraint") then
					d:Destroy()
				end
			end
			held:PivotTo(CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90)))
			for _, d in held:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanQuery = false
				end
			end
			held.Parent = m
		end
	end
	if look and PICKUP_SKINS[id] and Skins.Enabled() then
		Skins.Dress(m, PICKUP_SKINS[id], { scale = 1.4, offset = CFrame.new(0, 0.1, 0) })
	end
	local glow = Build.Decor({ Name = "Glow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 3, 3), CFrame = CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 230, 150), Material = Enum.Material.Neon, Transparency = 0.6, Parent = m, CastShadow = false })
	glow.Name = "Glow"
	Build.SetPivot(m, m.PrimaryPart :: BasePart, CFrame.new())
	m:PivotTo(cf)
	if parent then
		m.Parent = parent
	end
	return m
end

-- Supply bag dropped on death (all carried resources).
function ItemModels.SupplyBag(cf: CFrame, teamColor: Color3, parent: Instance?): Model
	local m = Build.Model("SupplyBag")
	local base = Build.Part({ Name = "Bag", Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 2.6, 2.6), CFrame = CFrame.new(0, 1.2, 0), Color = Color3.fromRGB(150, 120, 80), Material = Enum.Material.Fabric, Parent = m, CanCollide = false })
	Build.Decor({ Name = "Tie", Size = Vector3.new(1.2, 0.5, 1.2), CFrame = CFrame.new(0, 2.5, 0), Color = teamColor, Material = Enum.Material.Fabric, Parent = m })
	Build.SetPivot(m, base, CFrame.new())
	m:PivotTo(cf)
	if parent then
		m.Parent = parent
	end
	return m
end

return ItemModels
