--!nonstrict
-- Player-built structures. Each model's PrimaryPart is "Root": an invisible,
-- non-colliding box matching the footprint (Items[id].Size) with its bottom on
-- the ground. Visible parts carry collision. Pivot = ground centre.

local Build = require("./Build")

local Structures = {}

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
	return place(m, cf, parent)
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
	return place(m, cf, parent)
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
	return place(m, cf, parent)
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
	return place(m, cf, parent)
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
	return place(m, cf, parent)
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
	return place(m, cf, parent)
end

function Structures.Build(id: string, cf: CFrame, teamColor: Color3, parent: Instance?): Model
	if id == "WoodWall" then
		return Structures.WoodWall(cf, parent)
	elseif id == "ReinforcedWall" then
		return Structures.ReinforcedWall(cf, parent)
	elseif id == "Gate" then
		return Structures.Gate(cf, teamColor, parent)
	elseif id == "Spikes" then
		return Structures.Spikes(cf, parent)
	elseif id == "StorageBox" then
		return Structures.StorageBox(cf, teamColor, parent)
	elseif id == "Watchtower" then
		return Structures.Watchtower(cf, teamColor, parent)
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
