--!strict
--[[
	SurvivalHourSetup: helpers that finish imported Survival Hour meshes in Studio.

	STATUS: written without access to Roblox Studio and NOT yet run there.
	Review it and test on one asset before relying on it.

	Put this ModuleScript and SurvivalHourAssetData (generated) side by side,
	for example in ReplicatedStorage.SurvivalHour.

	Roblox places an imported MeshPart's CFrame at the centre of its bounding
	box. The data stores each asset's origin (its pivot / building anchor) as
	OriginOffset in that MeshPart space, and every attachment, collision box
	and part placement below is relative to that origin.
]]

local AssetData = require(script.Parent:WaitForChild("SurvivalHourAssetData"))

local Setup = {}

type Data = { [string]: any }

local function cf(t: { number }): CFrame
	return CFrame.new(table.unpack(t))
end

local function originCFrame(entry: Data): CFrame
	local o = entry.OriginOffset or { 0, 0, 0 }
	return CFrame.new(o[1], o[2], o[3])
end

function Setup.GetData(assetName: string): Data?
	return AssetData[assetName]
end

-- Moves the MeshPart's pivot to the asset's authored origin (building anchor,
-- grip point, hinge, ...). Pivot-based placement (PivotTo) then lines up with
-- the catalog's footprints and snapping rules.
function Setup.SetPivot(meshPart: MeshPart, assetName: string?)
	local entry = AssetData[assetName or meshPart.Name]
	if entry then
		meshPart.PivotOffset = originCFrame(entry)
	end
end

-- Renames imported "<Name>_Att" attachments to "<Name>" and creates any that
-- are missing from the data (e.g. if an importer version skipped them).
function Setup.EnsureAttachments(meshPart: MeshPart, assetName: string?)
	local entry = AssetData[assetName or meshPart.Name]
	if not entry then
		return
	end
	local origin = originCFrame(entry)
	for name, t in entry.Attachments do
		local att = meshPart:FindFirstChild(name .. "_Att") or meshPart:FindFirstChild(name)
		if att and att:IsA("Attachment") then
			att.Name = name
		else
			local a = Instance.new("Attachment")
			a.Name = name
			a.CFrame = origin * cf(t)
			a.Parent = meshPart
		end
	end
end

-- Builds invisible collision boxes from the data, welds them to the mesh and
-- turns off collision on the render mesh (so decorative bits never catch players).
function Setup.BuildCollision(meshPart: MeshPart, assetName: string?): { BasePart }
	local entry = AssetData[assetName or meshPart.Name]
	local made = {}
	if not entry or #entry.CollisionBoxes == 0 then
		return made
	end
	local origin = meshPart.CFrame * originCFrame(entry)
	for i, box in entry.CollisionBoxes do
		local p = Instance.new("Part")
		p.Name = "Collision" .. i
		p.Transparency = 1
		p.CanCollide = true
		p.CanQuery = true
		p.CanTouch = true
		p.CastShadow = false
		p.Anchored = meshPart.Anchored
		p.Size = Vector3.new(box.Size[1], box.Size[2], box.Size[3])
		p.CFrame = origin * cf(box.CFrame)
		if not p.Anchored then
			local w = Instance.new("WeldConstraint")
			w.Part0 = meshPart
			w.Part1 = p
			w.Parent = p
		end
		p.Parent = meshPart
		table.insert(made, p)
	end
	meshPart.CanCollide = false
	return made
end

-- Positions separately imported moving parts (door, lid, slide, ...) at rest
-- relative to the main mesh. `parts` maps part name -> MeshPart.
function Setup.PlaceParts(mainMesh: MeshPart, parts: { [string]: MeshPart }, assetName: string?)
	local entry = AssetData[assetName or mainMesh.Name]
	if not entry then
		return
	end
	local origin = mainMesh.CFrame * originCFrame(entry)
	for name, info in entry.Parts do
		local part = parts[name]
		if part then
			local partOrigin = originCFrame(info)
			part.CFrame = origin * cf(info.Placement) * partOrigin:Inverse()
			part.PivotOffset = partOrigin -- pivot = hinge / slide axis
		end
	end
end

-- Wraps a held item in a Tool. The mesh's authored origin is the grip point, so
-- Tool.Grip is just that offset (barrel/blade forward along -Z, up +Y).
function Setup.MakeTool(meshPart: MeshPart, assetName: string?): Tool
	local name = assetName or meshPart.Name
	local entry = AssetData[name]
	local tool = Instance.new("Tool")
	tool.Name = (string.gsub(name, "^SM_", ""))
	meshPart.Name = "Handle"
	meshPart.Anchored = false
	meshPart.CanCollide = false
	if entry then
		tool.Grip = originCFrame(entry)
	end
	meshPart.Parent = tool
	return tool
end

-- Wraps an armour piece as a rigid Accessory attached to its R15 attachment.
function Setup.MakeAccessory(meshPart: MeshPart, assetName: string?): Accessory
	local name = assetName or meshPart.Name
	local entry = AssetData[name]
	local acc = Instance.new("Accessory")
	acc.Name = (string.gsub(name, "^ACC_", ""))
	meshPart.Name = "Handle"
	meshPart.Anchored = false
	meshPart.CanCollide = false
	meshPart.Massless = true
	if entry and entry.R15Attachment then
		local attName = entry.R15Attachment
		local att = meshPart:FindFirstChild(attName .. "_Att") or meshPart:FindFirstChild(attName)
		if not att then
			att = Instance.new("Attachment")
			att.Parent = meshPart
		end
		att.Name = attName
		;(att :: Attachment).CFrame = originCFrame(entry)
	end
	meshPart.Parent = acc
	return acc
end

-- Team colours: SurfaceAppearance texture ids can't be changed by game scripts
-- at runtime, so make one SurfaceAppearance per team in Studio (see
-- Docs/IMPORT.md) under ReplicatedStorage.SurvivalHourAtlas with the names
-- Neutral, Red, Blue, Yellow and Purple. This clones the right one onto every
-- MeshPart under `root`.
function Setup.ApplyAtlas(root: Instance, team: string?)
	local folder = game:GetService("ReplicatedStorage"):FindFirstChild("SurvivalHourAtlas")
	if not folder then
		warn("SurvivalHourSetup: ReplicatedStorage.SurvivalHourAtlas not found")
		return
	end
	local template = folder:FindFirstChild(team or "Neutral") or folder:FindFirstChild("Neutral")
	if not template then
		return
	end
	local targets = root:GetDescendants()
	table.insert(targets, root)
	for _, d in targets do
		if d:IsA("MeshPart") then
			local old = d:FindFirstChildOfClass("SurfaceAppearance")
			if old then
				old:Destroy()
			end
			template:Clone().Parent = d
		end
	end
end

-- Rigged wildlife: make sure the imported rig can play animations.
function Setup.PrepareRig(model: Model): Animator
	local controller = model:FindFirstChildOfClass("AnimationController")
		or model:FindFirstChildOfClass("Humanoid")
	if not controller then
		local c = Instance.new("AnimationController")
		c.Parent = model
		controller = c
	end
	local animator = (controller :: Instance):FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = controller
	end
	return animator :: Animator
end

-- One-call convenience for a static asset: pivot, attachments, collision.
function Setup.PrepareStatic(meshPart: MeshPart, assetName: string?)
	local name = assetName or meshPart.Name
	Setup.SetPivot(meshPart, name)
	Setup.EnsureAttachments(meshPart, name)
	local entry = AssetData[name]
	if entry then
		local kind = entry.Kind
		if kind == "Effect" then
			meshPart.CanCollide = false
			meshPart.CanQuery = false
			meshPart.CanTouch = false
			meshPart.CastShadow = false
		elseif #entry.CollisionBoxes > 0 then
			Setup.BuildCollision(meshPart, name)
		else
			-- CollisionFidelity can only be changed in Studio (plugins / command bar),
			-- not by game scripts; set it at edit time if this call is refused.
			pcall(function()
				meshPart.CollisionFidelity = (Enum.CollisionFidelity :: any)[entry.CollisionFidelity]
					or Enum.CollisionFidelity.Box
			end)
		end
	end
end

return Setup
