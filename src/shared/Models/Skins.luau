--!nonstrict
-- Mesh skins: dresses the procedural models with the Survival Hour mesh pack
-- (ReplicatedStorage.SurvivalHourAssets, from SurvivalHourAssets.rbxm).
--
-- The procedural parts keep doing their job (collision, queries, prompts,
-- effects, names the services look up); they are only made invisible. The
-- mesh is added on top as a non-colliding, non-queryable visual. If the asset
-- library is missing, or ReplicatedStorage:GetAttribute("MeshSkins") == false,
-- every call is a no-op and the game looks exactly as before.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Skins = {}

local index: { [string]: Instance } = {}
local looked = false

local function library(): boolean
	if not looked then
		looked = true
		local lib = ReplicatedStorage:FindFirstChild("SurvivalHourAssets") or ReplicatedStorage:FindFirstChild("SurvivalHour")
		if lib then
			for _, cat in lib:GetChildren() do
				for _, item in cat:GetChildren() do
					index[item.Name] = item
				end
			end
		end
	end
	return next(index) ~= nil
end

function Skins.Enabled(): boolean
	return ReplicatedStorage:GetAttribute("MeshSkins") ~= false and library()
end

function Skins.Has(name: string): boolean
	return Skins.Enabled() and index[name] ~= nil
end

-- Deterministic variant pick from a position, so server and client agree.
function Skins.Pick(list: { string }, cf: CFrame): string
	local p = cf.Position
	local h = math.floor(math.abs(p.X * 7.31 + p.Z * 3.17 + p.Y * 1.3))
	return list[(h % #list) + 1]
end

-- Height (studs) of an asset's main mesh at scale 1.
function Skins.Height(name: string): number
	local src = index[name]
	if not src then
		return 1
	end
	local main = if src:IsA("Model") then src.PrimaryPart else src:FindFirstChild("Handle")
	return if main and main:IsA("BasePart") then main.Size.Y else 1
end

function Skins.Width(name: string): number
	local src = index[name]
	local main = src and (if src:IsA("Model") then src.PrimaryPart else src:FindFirstChild("Handle"))
	return if main and main:IsA("BasePart") then math.max(main.Size.X, main.Size.Z) else 1
end

-- Visual-only clone of an asset: a Model whose pivot is the asset's authored
-- origin (ground anchor, grip point or R15 attachment). No collision parts.
function Skins.Visual(name: string): Model?
	if not Skins.Enabled() then
		return nil
	end
	local src = index[name]
	if not src then
		return nil
	end
	local c = src:Clone()
	local pivot: CFrame
	if c:IsA("Tool") then
		local h = c:FindFirstChild("Handle") :: BasePart
		pivot = h.CFrame * c.Grip
	elseif c:IsA("Accessory") then
		local h = c:FindFirstChild("Handle") :: BasePart
		local att = h and h:FindFirstChildWhichIsA("Attachment")
		pivot = if att then h.CFrame * att.CFrame else h.CFrame
	elseif c:IsA("Model") then
		pivot = c:GetPivot()
	else
		return nil
	end
	local m = Instance.new("Model")
	m.Name = "Skin"
	for _, d in c:GetDescendants() do
		if d:IsA("BasePart") then
			if string.sub(d.Name, 1, 9) == "Collision" or string.sub(d.Name, 1, 6) == "Hitbox" then
				continue
			end
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			d:SetAttribute("Skin", true)
			d:SetAttribute("SkinOf", name)
			for _, w in d:GetChildren() do
				if w:IsA("WeldConstraint") or w:IsA("RigidConstraint") or w:IsA("Weld") then
					w:Destroy()
				end
			end
			d.Parent = m
		end
	end
	c:Destroy()
	m.WorldPivot = pivot
	return m
end

export type Opts = {
	scale: number?, -- uniform scale about the asset origin
	stretch: Vector3?, -- extra per-axis stretch (asset space), e.g. to fit a 10-stud wall grid
	offset: CFrame?, -- extra transform after the target pivot (rotation / shift)
	cf: CFrame?, -- world placement (defaults to the target model's pivot)
	parent: Instance?, -- where the mesh parts go (defaults to the target model)
	attrs: { [string]: any }?, -- attributes set on every mesh part (e.g. Yield = true)
	transparency: number?, -- start hidden (1) for state-driven meshes
	keep: { [string]: boolean }?, -- procedural part names to leave visible
	noHide: boolean?, -- don't hide the procedural parts
	extra: boolean?, -- an add-on mesh (not the model's main skin): skip damage-swap bookkeeping
}

-- Hides the procedural look of `model` (parts stay collidable/queryable).
-- Parts marked TeamTint, parts named in `keep`, and mesh skins stay visible.
function Skins.Hide(model: Instance, keep: { [string]: boolean }?)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not d:GetAttribute("Skin") then
			if d.Transparency < 1 and not d:GetAttribute("TeamTint") and not (keep and keep[d.Name]) then
				d.Transparency = 1
				d.CastShadow = false
				d:SetAttribute("SkinHidden", true)
				for _, g in d:GetChildren() do
					if g:IsA("SurfaceGui") or g:IsA("Decal") or g:IsA("Texture") then
						if g:IsA("SurfaceGui") then
							g.Enabled = false
						else
							(g :: any).Transparency = 1
						end
					end
				end
			end
		end
	end
end

-- Puts a mesh asset on `target`. Returns the mesh parts (empty if unavailable).
function Skins.Dress(target: Model, name: string, opts: Opts?): { BasePart }
	local o = opts or {}
	local skin = Skins.Visual(name)
	if not skin then
		return {}
	end
	if not o.noHide then
		Skins.Hide(target, o.keep)
	end
	local pivot = skin.WorldPivot
	if o.stretch then
		local k = o.stretch
		for _, p in skin:GetChildren() do
			if p:IsA("BasePart") then
				local rel = pivot:ToObjectSpace(p.CFrame)
				p.Size = p.Size * k
				p.CFrame = pivot * CFrame.new(rel.Position * k) * rel.Rotation
			end
		end
	end
	if o.scale and math.abs(o.scale - 1) > 1e-3 then
		skin:ScaleTo(o.scale)
	end
	skin:PivotTo((o.cf or target:GetPivot()) * (o.offset or CFrame.new()))
	local parts = {}
	local parent = o.parent or target
	for _, p in skin:GetChildren() do
		if p:IsA("BasePart") then
			if o.attrs then
				for k, v in o.attrs do
					p:SetAttribute(k, v)
				end
			end
			if o.transparency then
				p.Transparency = o.transparency
			end
			p.Parent = parent
			table.insert(parts, p)
		end
	end
	skin:Destroy()
	-- remember how this skin was placed so damage states can swap variants
	if not o.extra and (not o.parent or o.parent == target) then
		target:SetAttribute("SkinBase", target:GetAttribute("SkinBase") or name)
		target:SetAttribute("SkinName", name)
		target:SetAttribute("SkinScale", o.scale or 1)
		if o.stretch then
			target:SetAttribute("SkinStretch", o.stretch)
		end
		if o.offset then
			target:SetAttribute("SkinOffset", o.offset)
		end
	end
	return parts
end

-- Removes mesh parts of asset `name` (or all skins) directly under `target`.
function Skins.Strip(target: Instance, name: string?)
	for _, d in target:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Skin") and (name == nil or d:GetAttribute("SkinOf") == name) then
			d:Destroy()
		end
	end
end

-- Swaps the model's main skin for another asset with the same placement.
function Skins.Swap(target: Model, toName: string, offset: CFrame?)
	if not Skins.Has(toName) then
		return
	end
	local from = target:GetAttribute("SkinName")
	if from == toName or from == nil then
		return
	end
	-- keep only skins that belong to the main asset (e.g. its lid); strip them
	for _, d in target:GetChildren() do
		if d:IsA("BasePart") and d:GetAttribute("Skin") and (d:GetAttribute("SkinOf") == from) then
			d:Destroy()
		end
	end
	Skins.Dress(target, toName, {
		scale = target:GetAttribute("SkinScale"),
		stretch = target:GetAttribute("SkinStretch"),
		offset = offset or target:GetAttribute("SkinOffset"),
		noHide = true,
	})
end

-- Shows/hides skin parts tagged with `attr` (e.g. stumps after a tree falls).
function Skins.SetTagged(model: Instance, attr: string, visible: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute(attr) then
			d.Transparency = if visible then 0 else 1
		end
	end
end

-- Held items: weld a mesh onto the procedural held model (Handle = grip).
-- `correction` maps the pack's tool frame onto this game's grip frame.
function Skins.DressHeld(model: Model, name: string, correction: CFrame?): boolean
	local handle = model.PrimaryPart
	if not handle then
		return false
	end
	local skin = Skins.Visual(name)
	if not skin then
		return false
	end
	Skins.Hide(model)
	skin:PivotTo(handle.CFrame * (correction or CFrame.new()))
	for _, p in skin:GetChildren() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.Massless = true
			p.Parent = model
			local w = Instance.new("WeldConstraint")
			w.Part0 = handle
			w.Part1 = p
			w.Parent = p
		end
	end
	skin:Destroy()
	return true
end

return Skins
