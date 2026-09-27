--!nonstrict
-- Player-built structures. Each model's PrimaryPart is "Root": an invisible,
-- non-colliding box matching the footprint (Items[id].Size) with its bottom on
-- the ground. Visible parts carry collision. Pivot = ground centre.

local Build = require("./Build")
local Skins = require("./Skins")

local Structures = {}

-- The mesh pack builds walls on an 8-stud grid; this game snaps every 10 studs,
-- so wall-like meshes are stretched along X to span the same footprint.
local GRID_STRETCH = 10 / 8

local WOOD = Color3.fromRGB(138, 98, 62)
local WOOD_DARK = Color3.fromRGB(98, 68, 42)
local ROPE = Color3.fromRGB(205, 180, 120)
local STONE = Color3.fromRGB(132, 130, 126)

local function root(m: Model, size: Vector3): BasePart
	local r = Build.Part({ Name = "Root", Size = size, CFrame = CFrame.new(0, size.Y / 2, 0), Transparency = 1, CanCollide = false, CanQuery = true, Parent = m })
	m.PrimaryPart = r
	return r
end

local function place(m: Model, cf: CFrame, parent: Instance?): Model
	Build.SetPivot(m, m.PrimaryPart :: BasePart, CFrame.new())
	m:PivotTo(cf)
	if parent then
		m.Parent = parent
	end
	return m
end

local function palisade(m: Model, width: number, height: number, thick: number)
	local count = math.floor(width / 1.25)
	for i = 0, count - 1 do
		local x = -width / 2 + 0.625 + i * 1.25
		local h = height - (i % 3) * 0.5
		Build.Cyl("Stake", h, 1.2, CFrame.new(x, h / 2, 0), if i % 2 == 0 then WOOD else WOOD_DARK, Enum.Material.Wood, m)
		Build.Decor({ Name = "Point", Class = "WedgePart", Size = Vector3.new(1.1, 1, 0.6), CFrame = CFrame.new(x, h + 0.5, 0.3), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = m })
		Build.Decor({ Name = "Point", Class = "WedgePart", Size = Vector3.new(1.1, 1, 0.6), CFrame = CFrame.new(x, h + 0.5, -0.3) * CFrame.Angles(0, math.rad(180), 0), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = m })
	end
	for _, y in { height * 0.3, height * 0.72 } do
		Build.Part({ Name = "Brace", Size = Vector3.new(width, 0.6, 0.4), CFrame = CFrame.new(0, y, -thick / 2 - 0.1), Color = WOOD_DARK, Material = Enum.Material.WoodPlanks, Parent = m, CanCollide = false })
		Build.Decor({ Name = "Lash", Size = Vector3.new(width * 0.98, 0.25, thick + 0.3), CFrame = CFrame.new(0, y + 0.45, 0), Color = ROPE, Material = Enum.Material.Fabric, Parent = m, CastShadow = false })
	end
	-- One solid collider so gaps between stakes can't be squeezed through.
	Build.Part({ Name = "Collider", Size = Vector3.new(width, height, thick), CFrame = CFrame.new(0, height / 2, 0), Transparency = 1, Parent = m })
end

function Structures.WoodWall(cf: CFrame, parent: Instance?): Model
	local m = Build.Model("WoodWall")
	root(m, Vector3.new(10, 9, 1.6))
	palisade(m, 10, 9, 1.6)
	place(m, cf, parent)
	if Skins.Enabled() then
		Skins.Dress(m, "SM_WoodenWall", { stretch = Vector3.new(GRID_STRETCH, 0.95, 1.05) })
	end
	return m
end

function Structures.ReinforcedWall(cf: CFrame, parent: Instance?): Model
	local m = Build.Model("ReinforcedWall")
	root(m, Vector3.new(10, 10, 2.4))
	-- stone base course
	for row = 0, 2 do
		for i = 0, 3 do
			local off = if row % 2 == 0 then 0 else 1.25
			local x = -3.75 + i * 2.5 + off
			if x < 5 then
				Build.Part({ Name = "Block", Size = Vector3.new(2.4, 1.8, 2.4), CFrame = CFrame.new(x - 0.0, 0.9 + row * 1.85, 0), Color = if (row + i) % 2 == 0 then STONE else Build.Tint(STONE, 0.85), Material = Enum.Material.Cobblestone, Parent = m, CanCollide = false })
			end
		end
	end
	-- timber upper
	for i = 0, 7 do
		local x = -4.4 + i * 1.25
		Build.Cyl("Stake", 5, 1.2, CFrame.new(x, 7.5, 0), WOOD, Enum.Material.Wood, m, false)
	end
	Build.Part({ Name = "Band", Size = Vector3.new(10.2, 0.5, 2.6), CFrame = CFrame.new(0, 5.6, 0), Color = Color3.fromRGB(70, 72, 78), Material = Enum.Material.Metal, Parent = m, CanCollide = false })
	Build.Part({ Name = "Collider", Size = Vector3.new(10, 10, 2.4), CFrame = CFrame.new(0, 5, 0), Transparency = 1, Parent = m })
	place(m, cf, parent)
	if Skins.Enabled() then
		Skins.Dress(m, "SM_ReinforcedWall", { stretch = Vector3.new(GRID_STRETCH, 1.0, 1.4) })
	end
	return m
end

-- Gate: a door panel ("Door") that the server moves between Closed/Open.
function Structures.Gate(cf: CFrame, teamColor: Color3, parent: Instance?): Model
	local m = Build.Model("Gate")
	root(m, Vector3.new(10, 9, 1.6))
	for _, x in { -4.6, 4.6 } do
		Build.Cyl("Post", 10, 1.6, CFrame.new(x, 5, 0), WOOD_DARK, Enum.Material.Wood, m)
	end
	Build.Part({ Name = "Header", Size = Vector3.new(10.4, 1, 1.8), CFrame = CFrame.new(0, 9.6, 0), Color = WOOD_DARK, Material = Enum.Material.WoodPlanks, Parent = m })
	local door = Build.Model("Door", m)
	local doorPanel = Build.Part({ Name = "Panel", Size = Vector3.new(7.6, 8.2, 1), CFrame = CFrame.new(0, 4.3, 0), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = door })
	Build.Part({ Name = "Cross", Size = Vector3.new(9.5, 0.6, 0.3), CFrame = CFrame.new(0, 4.3, -0.6) * CFrame.Angles(0, 0, math.rad(45)), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = door, CanCollide = false })
	local sigil = Build.Decor({ Name = "Sigil", Size = Vector3.new(2, 2, 0.1), CFrame = CFrame.new(0, 6.2, -0.56), Color = teamColor, Material = Enum.Material.Fabric, Parent = door })
	sigil:SetAttribute("TeamTint", true)
	door.PrimaryPart = doorPanel
	place(m, cf, parent)
	if Skins.Enabled() then
		-- frame + door mesh; the door mesh rides inside the Door model so SetGateOpen moves it
		Skins.Dress(m, "SM_Gate", { stretch = Vector3.new(GRID_STRETCH, 0.9, 1.1), keep = { Sigil = true } })
		for _, d in m:GetChildren() do
			if d:IsA("BasePart") and d:GetAttribute("Skin") and d.Name == "SM_Gate_Door" then
				d.Parent = door
			end
		end
		-- the pack's gate owns one post; add the other side's post
		Skins.Dress(m, "SM_WallPost", { offset = CFrame.new(-5, 0, 0), noHide = true, extra = true })
	end
	return m
end

-- Opens/closes a gate's door on the server (replicates).
function Structures.SetGateOpen(m: Model, open: boolean)
	local door = m:FindFirstChild("Door") :: Model?
	local rootPart = m.PrimaryPart
	if not door or not rootPart then
		return
	end
	local closed = rootPart.CFrame * CFrame.new(0, -rootPart.Size.Y / 2 + 4.3, 0)
	local target = if open then closed * CFrame.new(0, 7.4, 0) else closed
	door:PivotTo(target)
	for _, d in door:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = (not open) and d.Name == "Panel"
		end
	end
	m:SetAttribute("Open", open)
end

function Structures.Spikes(cf: CFrame, parent: Instance?): Model
	local m = Build.Model("Spikes")
	root(m, Vector3.new(8, 3, 3))
	Build.Part({ Name = "Base", Size = Vector3.new(8, 0.6, 2.4), CFrame = CFrame.new(0, 0.3, 0), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = m })
	for i = 0, 5 do
		for _, dir in { -1, 1 } do
			local x = -3.4 + i * 1.36
			Build.Part({ Name = "Spike", Size = Vector3.new(0.4, 3.2, 0.4), CFrame = CFrame.new(x, 1.6, dir * 0.5) * CFrame.Angles(math.rad(25 * dir), 0, 0), Color = Color3.fromRGB(176, 140, 96), Material = Enum.Material.Wood, Parent = m, CanCollide = false })
		end
	end
	local hurt = Build.Part({ Name = "Hurt", Size = Vector3.new(8.4, 3.2, 3.4), CFrame = CFrame.new(0, 1.6, 0), Transparency = 1, CanCollide = false, Parent = m })
	hurt.CanTouch = true
	hurt.CanQuery = false
	place(m, cf, parent)
	if Skins.Enabled() then
		Skins.Dress(m, "SM_Spikes")
	end
	return m
end

function Structures.StorageBox(cf: CFrame, teamColor: Color3, parent: Instance?): Model
	local m = Build.Model("StorageBox")
	root(m, Vector3.new(6, 4, 4))
	Build.Part({ Name = "Chest", Size = Vector3.new(6, 2.8, 4), CFrame = CFrame.new(0, 1.4, 0), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = m })
	Build.Part({ Name = "Lid", Size = Vector3.new(6.2, 0.9, 4.2), CFrame = CFrame.new(0, 3.2, 0), Color = WOOD_DARK, Material = Enum.Material.WoodPlanks, Parent = m })
	for _, x in { -2.4, 2.4 } do
		Build.Decor({ Name = "Band", Size = Vector3.new(0.4, 3.8, 4.3), CFrame = CFrame.new(x, 1.9, 0), Color = Color3.fromRGB(70, 72, 78), Material = Enum.Material.Metal, Parent = m })
	end
	local plate = Build.Decor({ Name = "Crest", Size = Vector3.new(1.4, 1.4, 0.1), CFrame = CFrame.new(0, 1.8, -2.06), Color = teamColor, Material = Enum.Material.SmoothPlastic, Parent = m })
	plate:SetAttribute("TeamTint", true)
	Build.Decor({ Name = "Lock", Size = Vector3.new(0.6, 0.7, 0.2), CFrame = CFrame.new(0, 3.0, -2.2), Color = Color3.fromRGB(200, 180, 90), Material = Enum.Material.Metal, Parent = m })
	place(m, cf, parent)
	if Skins.Enabled() then
		Skins.Dress(m, "SM_StorageBox", { scale = 1.9, keep = { Lock = true } })
	end
	return m
end

function Structures.Watchtower(cf: CFrame, teamColor: Color3, parent: Instance?): Model
	local m = Build.Model("Watchtower")
	root(m, Vector3.new(8, 16, 8))
	for _, x in { -3.4, 3.4 } do
		for _, z in { -3.4, 3.4 } do
			Build.Cyl("Leg", 16, 1.1, CFrame.new(x, 8, z), WOOD_DARK, Enum.Material.Wood, m)
		end
	end
	-- cross bracing
	for _, side in { -3.4, 3.4 } do
		Build.Part({ Name = "Brace", Size = Vector3.new(0.4, 9, 0.4), CFrame = CFrame.new(0, 6, side) * CFrame.Angles(0, 0, math.rad(40)), Color = WOOD, Material = Enum.Material.Wood, Parent = m, CanCollide = false })
		Build.Part({ Name = "Brace", Size = Vector3.new(0.4, 9, 0.4), CFrame = CFrame.new(side, 6, 0) * CFrame.Angles(math.rad(40), 0, 0), Color = WOOD, Material = Enum.Material.Wood, Parent = m, CanCollide = false })
	end
	-- platform with a hatch gap on the ladder side
	Build.Part({ Name = "Floor", Size = Vector3.new(8.4, 0.6, 6), CFrame = CFrame.new(0, 12, 1.2), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = m })
	Build.Part({ Name = "Floor", Size = Vector3.new(4, 0.6, 2.4), CFrame = CFrame.new(-2.2, 12, -3), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = m })
	-- railings
	for _, r in { { 0, 4.1, 8.4, 0.4 }, { -4.1, 0, 0.4, 8.4 }, { 4.1, 0, 0.4, 8.4 } } do
		Build.Part({ Name = "Rail", Size = Vector3.new(r[3], 3, r[4]), CFrame = CFrame.new(r[1], 13.8, r[2]), Color = WOOD_DARK, Material = Enum.Material.WoodPlanks, Parent = m })
	end
	-- ladder
	local ladder = Instance.new("TrussPart")
	ladder.Name = "Ladder"
	ladder.Size = Vector3.new(2, 14, 2)
	ladder.CFrame = CFrame.new(2.4, 7, -5.2)
	ladder.Color = WOOD_DARK
	ladder.Material = Enum.Material.Wood
	ladder.Anchored = true
	ladder.Style = Enum.Style.NoSupports
	ladder.Parent = m
	-- roof + flag
	Build.Part({ Class = "WedgePart", Name = "Roof", Size = Vector3.new(9, 2.4, 4.6), CFrame = CFrame.new(0, 17.4, 2.3), Color = Build.Tint(teamColor, 0.75), Material = Enum.Material.Fabric, Parent = m, CanCollide = false })
	Build.Part({ Class = "WedgePart", Name = "Roof", Size = Vector3.new(9, 2.4, 4.6), CFrame = CFrame.new(0, 17.4, -2.3) * CFrame.Angles(0, math.rad(180), 0), Color = Build.Tint(teamColor, 0.75), Material = Enum.Material.Fabric, Parent = m, CanCollide = false })
	for _, x in { -3.4, 3.4 } do
		for _, z in { -3.4, 3.4 } do
			Build.Part({ Name = "RoofPost", Size = Vector3.new(0.5, 4.4, 0.5), CFrame = CFrame.new(x, 14.2, z), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = m, CanCollide = false })
		end
	end
	place(m, cf, parent)
	if Skins.Enabled() then
		-- The pack's tower has its platform at 10 studs with the hatch on the other
		-- side: raise it to this tower's 12-stud floor and turn it so the hatch lines
		-- up, then move the climbable truss under the mesh ladder.
		Skins.Dress(m, "SM_Watchtower", { stretch = Vector3.new(1, 1.2, 1), offset = CFrame.Angles(0, math.rad(-90), 0) })
		ladder.CFrame = m:GetPivot() * CFrame.new(2.4, 7, -3.0)
		ladder.Transparency = 1
	end
	return m
end

-- Survival Wars building tiers -------------------------------------------------------------

local SCRAP = Color3.fromRGB(128, 112, 96)
local IRON = Color3.fromRGB(92, 96, 104)

-- Wooden floor / platform (Tier I). Walkable; 10x10 so it tiles with walls.
function Structures.WoodFloor(cf: CFrame, parent: Instance?): Model
	local m = Build.Model("WoodFloor")
	root(m, Vector3.new(10, 1, 10))
	for i = 0, 7 do
		Build.Part({ Name = "Plank", Size = Vector3.new(10, 0.5, 1.2), CFrame = CFrame.new(0, 0.75, -4.4 + i * 1.26), Color = if i % 2 == 0 then WOOD else Build.Tint(WOOD, 0.9), Material = Enum.Material.WoodPlanks, Parent = m, CanCollide = false })
	end
	for _, x in { -4.4, 4.4 } do
		Build.Part({ Name = "Joist", Size = Vector3.new(0.6, 0.6, 10), CFrame = CFrame.new(x, 0.3, 0), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = m, CanCollide = false })
	end
	Build.Part({ Name = "Collider", Size = Vector3.new(10, 1, 10), CFrame = CFrame.new(0, 0.5, 0), Transparency = 1, Parent = m })
	place(m, cf, parent)
	if Skins.Has("SM_WoodFloor") then
		Skins.Dress(m, "SM_WoodFloor")
	end
	return m
end

-- Stone-and-timber wall with a shooting window (Tier II).
function Structures.WindowWall(cf: CFrame, parent: Instance?): Model
	local m = Structures.ReinforcedWall(CFrame.new(), nil)
	Skins.Unskin(m) -- the pack wall is solid; show the procedural wall with its window
	m.Name = "WindowWall"
	-- carve the window: replace the single collider with four around a 3x1.6 gap
	local col = m:FindFirstChild("Collider")
	if col then
		col:Destroy()
	end
	local gy, gh, gw = 6.6, 1.6, 3
	for _, c in {
		{ Vector3.new(10, gy - gh / 2, 2.4), Vector3.new(0, (gy - gh / 2) / 2, 0) },
		{ Vector3.new(10, 10 - (gy + gh / 2), 2.4), Vector3.new(0, (10 + gy + gh / 2) / 2, 0) },
		{ Vector3.new((10 - gw) / 2, gh, 2.4), Vector3.new(-(gw / 2 + (10 - gw) / 4), gy, 0) },
		{ Vector3.new((10 - gw) / 2, gh, 2.4), Vector3.new(gw / 2 + (10 - gw) / 4, gy, 0) },
	} do
		Build.Part({ Name = "Collider", Size = c[1], CFrame = CFrame.new(c[2]), Transparency = 1, Parent = m })
	end
	for _, d in m:GetChildren() do
		if d:IsA("BasePart") and d.Name == "Stake" and math.abs(d.Position.X) < gw / 2 + 0.6 then
			d:Destroy()
		end
	end
	Build.Part({ Name = "Sill", Size = Vector3.new(gw + 0.6, 0.4, 2.8), CFrame = CFrame.new(0, gy - gh / 2 - 0.2, 0), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = m, CanCollide = false })
	Build.Part({ Name = "Lintel", Size = Vector3.new(gw + 0.6, 0.4, 2.8), CFrame = CFrame.new(0, gy + gh / 2 + 0.2, 0), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = m, CanCollide = false })
	return place(m, cf, parent)
end

-- Scrap wall (Tier III): corrugated sheets on a timber frame.
function Structures.ScrapWall(cf: CFrame, parent: Instance?): Model
	local m = Build.Model("ScrapWall")
	root(m, Vector3.new(10, 10, 2))
	for _, x in { -4.6, 0, 4.6 } do
		Build.Part({ Name = "Post", Size = Vector3.new(0.8, 10.4, 0.8), CFrame = CFrame.new(x, 5.2, 0.6), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = m, CanCollide = false })
	end
	for i = 0, 4 do
		local col = if i % 2 == 0 then SCRAP else Build.Tint(SCRAP, 0.8)
		Build.Part({ Name = "Sheet", Size = Vector3.new(2.3, 9.4, 0.3), CFrame = CFrame.new(-4 + i * 2, 5, -0.2) * CFrame.Angles(0, 0, math.rad((i % 3 - 1) * 2)), Color = col, Material = Enum.Material.CorrodedMetal, Parent = m, CanCollide = false })
	end
	Build.Part({ Name = "Rail", Size = Vector3.new(10.2, 0.5, 0.5), CFrame = CFrame.new(0, 8.6, 0.6), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = m, CanCollide = false })
	Build.Part({ Name = "Collider", Size = Vector3.new(10, 10, 2), CFrame = CFrame.new(0, 5, 0), Transparency = 1, Parent = m })
	place(m, cf, parent)
	if Skins.Has("SM_ScrapWall") then
		Skins.Dress(m, "SM_ScrapWall")
	end
	return m
end

-- Metal wall (Tier IV): riveted plates.
function Structures.MetalWall(cf: CFrame, parent: Instance?): Model
	local m = Build.Model("MetalWall")
	root(m, Vector3.new(10, 11, 2.6))
	for row = 0, 2 do
		for i = 0, 1 do
			Build.Part({ Name = "Plate", Size = Vector3.new(4.9, 3.5, 1.6), CFrame = CFrame.new(-2.5 + i * 5, 1.9 + row * 3.6, 0), Color = if (row + i) % 2 == 0 then IRON else Build.Tint(IRON, 0.85), Material = Enum.Material.DiamondPlate, Parent = m, CanCollide = false })
		end
	end
	for _, x in { -5, 5 } do
		Build.Part({ Name = "Beam", Size = Vector3.new(0.8, 11, 2.6), CFrame = CFrame.new(x, 5.5, 0), Color = Color3.fromRGB(60, 62, 68), Material = Enum.Material.Metal, Parent = m, CanCollide = false })
	end
	Build.Part({ Name = "Collider", Size = Vector3.new(10, 11, 2.6), CFrame = CFrame.new(0, 5.5, 0), Transparency = 1, Parent = m })
	place(m, cf, parent)
	if Skins.Has("SM_MetalWall") then
		Skins.Dress(m, "SM_MetalWall")
	end
	return m
end

-- Door/gate variants reuse the Gate model (a "Door" sub-model the server moves).
local function recolorDoor(m: Model, color: Color3, material: Enum.Material)
	Skins.Unskin(m) -- tiered doors use the procedural look in their own materials
	local door = m:FindFirstChild("Door")
	if door then
		for _, d in door:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "Panel" then
				d.Color = color
				d.Material = material
			end
		end
	end
end

function Structures.ReinforcedDoor(cf: CFrame, teamColor: Color3, parent: Instance?): Model
	local m = Structures.Gate(CFrame.new(), teamColor, nil)
	m.Name = "ReinforcedDoor"
	recolorDoor(m, Color3.fromRGB(110, 84, 58), Enum.Material.WoodPlanks)
	local door = m:FindFirstChild("Door")
	if door then
		for _, y in { 2, 6.6 } do
			Build.Part({ Name = "Strap", Size = Vector3.new(7.8, 0.5, 1.1), CFrame = CFrame.new(0, y, 0), Color = IRON, Material = Enum.Material.Metal, Parent = door, CanCollide = false })
		end
	end
	return place(m, cf, parent)
end

function Structures.HeavyGate(cf: CFrame, teamColor: Color3, parent: Instance?): Model
	local m = Structures.Gate(CFrame.new(), teamColor, nil)
	m.Name = "HeavyGate"
	recolorDoor(m, IRON, Enum.Material.DiamondPlate)
	return place(m, cf, parent)
end

-- Storage tiers (Wooden Crate = StorageBox) ----------------------------------------------

local function chest(name: string, size: Vector3, body: Color3, lid: Color3, mat: Enum.Material, teamColor: Color3, bands: number): Model
	local m = Build.Model(name)
	root(m, size)
	Build.Part({ Name = "Chest", Size = Vector3.new(size.X, size.Y * 0.72, size.Z), CFrame = CFrame.new(0, size.Y * 0.36, 0), Color = body, Material = mat, Parent = m })
	Build.Part({ Name = "Lid", Size = Vector3.new(size.X + 0.2, size.Y * 0.24, size.Z + 0.2), CFrame = CFrame.new(0, size.Y * 0.84, 0), Color = lid, Material = mat, Parent = m })
	for i = 1, bands do
		local x = -size.X / 2 + i * size.X / (bands + 1)
		Build.Decor({ Name = "Band", Size = Vector3.new(0.4, size.Y * 0.98, size.Z + 0.3), CFrame = CFrame.new(x, size.Y * 0.49, 0), Color = Color3.fromRGB(70, 72, 78), Material = Enum.Material.Metal, Parent = m })
	end
	local plate = Build.Decor({ Name = "Crest", Size = Vector3.new(1.2, 1.2, 0.1), CFrame = CFrame.new(0, size.Y * 0.45, -size.Z / 2 - 0.06), Color = teamColor, Material = Enum.Material.SmoothPlastic, Parent = m })
	plate:SetAttribute("TeamTint", true)
	Build.Decor({ Name = "Lock", Size = Vector3.new(0.6, 0.7, 0.2), CFrame = CFrame.new(0, size.Y * 0.72, -size.Z / 2 - 0.12), Color = Color3.fromRGB(200, 180, 90), Material = Enum.Material.Metal, Parent = m })
	return m
end

-- Dress a storage/trap with its pack mesh, keeping the lock/crest/lamp indicators.
local function dressKeep(m: Model, name: string)
	if Skins.Has(name) then
		Skins.Dress(m, name, { keep = { Lock = true, Lamp = true } })
	end
end

function Structures.ReinforcedChest(cf: CFrame, teamColor: Color3, parent: Instance?): Model
	local m = chest("ReinforcedChest", Vector3.new(6, 4.4, 4), Color3.fromRGB(120, 90, 62), Color3.fromRGB(90, 66, 44), Enum.Material.WoodPlanks, teamColor, 3)
	place(m, cf, parent)
	dressKeep(m, "SM_ReinforcedChest")
	return m
end

function Structures.MetalLocker(cf: CFrame, teamColor: Color3, parent: Instance?): Model
	local m = Build.Model("MetalLocker")
	root(m, Vector3.new(4, 7, 3))
	Build.Part({ Name = "Chest", Size = Vector3.new(4, 7, 3), CFrame = CFrame.new(0, 3.5, 0), Color = Color3.fromRGB(96, 110, 104), Material = Enum.Material.Metal, Parent = m })
	for i = 0, 2 do
		Build.Decor({ Name = "Vent", Size = Vector3.new(2.4, 0.15, 0.1), CFrame = CFrame.new(0, 5.8 + i * 0.3, -1.55), Color = Color3.fromRGB(50, 56, 54), Material = Enum.Material.Metal, Parent = m })
	end
	local plate = Build.Decor({ Name = "Crest", Size = Vector3.new(1.2, 1.2, 0.1), CFrame = CFrame.new(0, 4, -1.56), Color = teamColor, Material = Enum.Material.SmoothPlastic, Parent = m })
	plate:SetAttribute("TeamTint", true)
	Build.Decor({ Name = "Lock", Size = Vector3.new(0.5, 0.9, 0.2), CFrame = CFrame.new(1.4, 3.5, -1.6), Color = Color3.fromRGB(200, 180, 90), Material = Enum.Material.Metal, Parent = m })
	place(m, cf, parent)
	dressKeep(m, "SM_MetalLocker")
	return m
end

function Structures.SurvivalSafe(cf: CFrame, teamColor: Color3, parent: Instance?): Model
	local m = Build.Model("SurvivalSafe")
	root(m, Vector3.new(4.5, 5, 4.5))
	Build.Part({ Name = "Chest", Size = Vector3.new(4.5, 5, 4.5), CFrame = CFrame.new(0, 2.5, 0), Color = Color3.fromRGB(58, 62, 68), Material = Enum.Material.DiamondPlate, Parent = m })
	Build.Cyl("Dial", 0.3, 1.4, CFrame.new(0.8, 2.8, -2.35) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(200, 180, 90), Enum.Material.Metal, m, false)
	Build.Decor({ Name = "Lock", Size = Vector3.new(0.4, 1.4, 0.3), CFrame = CFrame.new(-1.1, 2.6, -2.35), Color = Color3.fromRGB(170, 170, 176), Material = Enum.Material.Metal, Parent = m })
	local plate = Build.Decor({ Name = "Crest", Size = Vector3.new(1, 1, 0.1), CFrame = CFrame.new(0, 4.1, -2.3), Color = teamColor, Material = Enum.Material.SmoothPlastic, Parent = m })
	plate:SetAttribute("TeamTint", true)
	place(m, cf, parent)
	dressKeep(m, "SM_SurvivalSafe")
	return m
end

-- Breached storage look: the lock hangs open and a red tag shows.
function Structures.SetBreached(m: Model, breached: boolean)
	m:SetAttribute("Breached", breached)
	local lock = m:FindFirstChild("Lock", true) :: BasePart?
	if lock then
		lock.Color = if breached then Color3.fromRGB(200, 60, 50) else Color3.fromRGB(200, 180, 90)
		lock.Transparency = 0
	end
	local tag = m:FindFirstChild("BreachTag")
	if breached and not tag and m.PrimaryPart then
		local r = m.PrimaryPart
		Build.Decor({ Name = "BreachTag", Size = Vector3.new(r.Size.X * 0.6, 0.3, 0.1), CFrame = r.CFrame * CFrame.new(0, r.Size.Y * 0.2, -r.Size.Z / 2 - 0.15), Color = Color3.fromRGB(220, 60, 40), Material = Enum.Material.Neon, Parent = m, CastShadow = false })
	elseif not breached and tag then
		tag:Destroy()
	end
end

-- Traps ------------------------------------------------------------------------------------

local function trigger(m: Model, size: Vector3, y: number): BasePart
	local t = Build.Part({ Name = "Trigger", Size = size, CFrame = CFrame.new(0, y, 0), Transparency = 1, CanCollide = false, Parent = m })
	t.CanTouch = true
	t.CanQuery = false
	return t
end

-- Tripwire alarm: two stakes, a wire and a can rattle (Tier II).
function Structures.TripwireAlarm(cf: CFrame, parent: Instance?): Model
	local m = Build.Model("TripwireAlarm")
	root(m, Vector3.new(8, 1.5, 1))
	for _, x in { -3.8, 3.8 } do
		Build.Part({ Name = "Stake", Size = Vector3.new(0.3, 1.4, 0.3), CFrame = CFrame.new(x, 0.7, 0), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = m, CanCollide = false })
	end
	Build.Decor({ Name = "Wire", Size = Vector3.new(7.6, 0.05, 0.05), CFrame = CFrame.new(0, 0.6, 0), Color = Color3.fromRGB(200, 200, 190), Material = Enum.Material.SmoothPlastic, Parent = m, CastShadow = false })
	Build.Cyl("Can", 0.5, 0.35, CFrame.new(3.8, 1.2, 0), Color3.fromRGB(160, 160, 150), Enum.Material.Metal, m, false)
	trigger(m, Vector3.new(7.6, 1.2, 1.2), 0.6)
	place(m, cf, parent)
	dressKeep(m, "SM_TripwireAlarm")
	return m
end

-- Snare: a rope loop on a bent sapling; holds the victim briefly, then it's spent (Tier II).
function Structures.Snare(cf: CFrame, parent: Instance?): Model
	local m = Build.Model("Snare")
	root(m, Vector3.new(3, 1, 3))
	Build.Decor({ Name = "Loop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 2.4, 2.4), CFrame = CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = ROPE, Material = Enum.Material.Fabric, Parent = m, CastShadow = false })
	Build.Part({ Name = "Sapling", Size = Vector3.new(0.25, 3.6, 0.25), CFrame = CFrame.new(1.4, 1.5, 0) * CFrame.Angles(0, 0, math.rad(-35)), Color = WOOD, Material = Enum.Material.Wood, Parent = m, CanCollide = false })
	trigger(m, Vector3.new(2.6, 1.4, 2.6), 0.7)
	place(m, cf, parent)
	dressKeep(m, "SM_Snare")
	return m
end

-- Bear trap: steel jaws (Tier III). Heavy damage + hold; spent after one bite.
function Structures.BearTrap(cf: CFrame, parent: Instance?): Model
	local m = Build.Model("BearTrap")
	root(m, Vector3.new(3, 1, 3))
	Build.Decor({ Name = "Plate", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 1.6, 1.6), CFrame = CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = IRON, Material = Enum.Material.Metal, Parent = m })
	for _, dir in { -1, 1 } do
		Build.Decor({ Name = "Jaw", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 2.6, 2.6), CFrame = CFrame.new(0, 0.2, dir * 0.4) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(120, 124, 130), Material = Enum.Material.Metal, Parent = m, Transparency = 0.2 })
	end
	trigger(m, Vector3.new(2.4, 1.2, 2.4), 0.6)
	place(m, cf, parent)
	dressKeep(m, "SM_BearTrap")
	return m
end

-- Advanced alarm (Tier V): a motion-sensor post with a lamp; watches a radius.
function Structures.AdvancedAlarm(cf: CFrame, teamColor: Color3, parent: Instance?): Model
	local m = Build.Model("AdvancedAlarm")
	root(m, Vector3.new(1.5, 5, 1.5))
	Build.Part({ Name = "Post", Size = Vector3.new(0.6, 4.4, 0.6), CFrame = CFrame.new(0, 2.2, 0), Color = IRON, Material = Enum.Material.Metal, Parent = m })
	local lamp = Build.Decor({ Name = "Lamp", Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(0, 4.8, 0), Color = Color3.fromRGB(120, 220, 120), Material = Enum.Material.Neon, Parent = m })
	lamp:SetAttribute("TeamTint", false)
	local plate = Build.Decor({ Name = "Crest", Size = Vector3.new(0.7, 0.7, 0.1), CFrame = CFrame.new(0, 3.4, -0.36), Color = teamColor, Material = Enum.Material.SmoothPlastic, Parent = m })
	plate:SetAttribute("TeamTint", true)
	return place(m, cf, parent)
end

function Structures.Build(id: string, cf: CFrame, teamColor: Color3, parent: Instance?): Model
	local plain = {
		WoodWall = Structures.WoodWall,
		ReinforcedWall = Structures.ReinforcedWall,
		Spikes = Structures.Spikes,
		WoodFloor = Structures.WoodFloor,
		WindowWall = Structures.WindowWall,
		ScrapWall = Structures.ScrapWall,
		MetalWall = Structures.MetalWall,
		TripwireAlarm = Structures.TripwireAlarm,
		Snare = Structures.Snare,
		BearTrap = Structures.BearTrap,
	}
	local tinted = {
		Gate = Structures.Gate,
		ReinforcedDoor = Structures.ReinforcedDoor,
		HeavyGate = Structures.HeavyGate,
		StorageBox = Structures.StorageBox,
		ReinforcedChest = Structures.ReinforcedChest,
		MetalLocker = Structures.MetalLocker,
		SurvivalSafe = Structures.SurvivalSafe,
		Watchtower = Structures.Watchtower,
		AdvancedAlarm = Structures.AdvancedAlarm,
	}
	if plain[id] then
		return plain[id](cf, parent)
	elseif tinted[id] then
		return tinted[id](cf, teamColor, parent)
	end
	error("Unknown structure " .. id)
end

-- Damage states: darken + show crack splinters below 66% and 33% health.
function Structures.ApplyDamageState(m: Model, frac: number)
	local stage = if frac > 0.66 then 0 elseif frac > 0.33 then 1 else 2
	if m:GetAttribute("DamageStage") == stage then
		return
	end
	m:SetAttribute("DamageStage", stage)
	-- mesh pack: swap to the damaged mesh below 66% health (and back when repaired)
	local skinBase = m:GetAttribute("SkinBase")
	if skinBase then
		if stage >= 1 and Skins.Has(skinBase .. "_Damaged") then
			Skins.Swap(m, skinBase .. "_Damaged")
		elseif stage == 0 then
			Skins.Swap(m, skinBase)
		end
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Root" and d.Transparency < 1 and not d:GetAttribute("TeamTint") then
			local base = d:GetAttribute("BaseColor")
			if base == nil then
				d:SetAttribute("BaseColor", d.Color)
				base = d.Color
			end
			d.Color = Build.Tint(base :: Color3, 1 - stage * 0.18)
		end
	end
	local cracks = m:FindFirstChild("Cracks")
	if cracks then
		cracks:Destroy()
	end
	if stage > 0 and m.PrimaryPart then
		local f = Instance.new("Folder")
		f.Name = "Cracks"
		f.Parent = m
		local r = m.PrimaryPart
		for i = 1, stage * 3 do
			local off = Vector3.new((i * 1.7 % r.Size.X) - r.Size.X / 2, (i * 2.3 % r.Size.Y) - r.Size.Y / 2, -r.Size.Z / 2 - 0.08)
			Build.Decor({ Name = "Crack", Size = Vector3.new(0.25, 1.6, 0.1), CFrame = r.CFrame * CFrame.new(off) * CFrame.Angles(0, 0, math.rad(i * 47)), Color = Color3.fromRGB(30, 24, 20), Material = Enum.Material.SmoothPlastic, Parent = f, CastShadow = false })
		end
	end
end

return Structures
