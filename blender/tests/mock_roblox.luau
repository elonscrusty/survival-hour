-- Minimal Roblox API mock to smoke-test SurvivalHour_CommandBarSetup.lua outside Studio.
-- Run: luau blender/tests/mock_roblox.luau  (the harness loads the script with loadstring-like require)
-- It checks control flow and property/method usage, not real geometry math.

local CFrameMT = {}
CFrameMT.__index = CFrameMT
local function mkcf(x, y, z)
	return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, CFrameMT)
end
CFrameMT.__mul = function(a, b)
	return mkcf(a.x + b.x, a.y + b.y, a.z + b.z)
end
function CFrameMT:Inverse()
	return mkcf(-self.x, -self.y, -self.z)
end
function CFrameMT:ToObjectSpace(o)
	return mkcf(o.x - self.x, o.y - self.y, o.z - self.z)
end
CFrame = {
	new = function(x, y, z, ...)
		assert(type(x or 0) == "number", "CFrame.new expects numbers")
		local extra = select("#", ...)
		assert(extra == 0 or extra == 9, "CFrame.new expects 3 or 12 numbers, got " .. (3 + extra))
		return mkcf(x, y, z)
	end,
}
Vector3 = {
	new = function(x, y, z)
		return { X = x, Y = y, Z = z }
	end,
}
Color3 = { fromRGB = function(r, g, b) return { r, g, b } end }
local function enumtab(name)
	return setmetatable({}, {
		__index = function(_, k)
			return name .. "." .. k
		end,
	})
end
Enum = { CollisionFidelity = enumtab("CollisionFidelity"), Material = enumtab("Material") }

local CLASSES = {
	MeshPart = { "BasePart", "Instance" },
	Part = { "BasePart", "Instance" },
	Model = { "PVInstance", "Instance" },
	Folder = { "Instance" },
	Attachment = { "Instance" },
	Bone = { "Attachment", "Instance" },
	Tool = { "Instance" },
	Accessory = { "Instance" },
	SurfaceAppearance = { "Instance" },
	AnimationController = { "Instance" },
	Animator = { "Instance" },
	WeldConstraint = { "Instance" },
	RigidConstraint = { "Instance" },
	Workspace = { "Model", "Instance" },
	Service = { "Instance" },
}
local PROPS = { -- allowed writable properties per class (catches typos)
	BasePart = { Anchored = 1, CanCollide = 1, CanQuery = 1, CanTouch = 1, CastShadow = 1, Transparency = 1,
		Size = 1, CFrame = 1, PivotOffset = 1, Material = 1, Color = 1, Massless = 1, CollisionFidelity = 1 },
	Model = { PrimaryPart = 1, WorldPivot = 1 },
	Attachment = { CFrame = 1 },
	Tool = { Grip = 1 },
	SurfaceAppearance = { ColorMap = 1, NormalMap = 1, RoughnessMap = 1, MetalnessMap = 1 },
	WeldConstraint = { Part0 = 1, Part1 = 1 },
	RigidConstraint = { Attachment0 = 1, Attachment1 = 1 },
}

local Inst = {}
local function isA(class, want)
	if class == want then
		return true
	end
	for _, c in CLASSES[class] or {} do
		if c == want then
			return true
		end
	end
	return false
end

local function new(class, name)
	assert(CLASSES[class], "Instance.new: unknown class " .. tostring(class))
	local raw = { ClassName = class, Name = name or class, _children = {}, _attrs = {}, _parent = nil,
		CFrame = mkcf(), Size = { X = 2, Y = 2, Z = 2 } }
	if class == "Bone" then
		raw.WorldCFrame = mkcf(0, 0, 0)
	end
	return setmetatable(raw, Inst)
end

Inst.__index = function(self, k)
	if k == "Parent" then
		return rawget(self, "_parent")
	end
	local m = Inst[k]
	if m then
		return m
	end
	for _, c in rawget(self, "_children") do -- Roblox: child access by name
		if c.Name == k then
			return c
		end
	end
	return nil
end
Inst.__newindex = function(self, k, v)
	if k == "Parent" then
		local old = rawget(self, "_parent")
		if old then
			local ch = rawget(old, "_children")
			for i, c in ch do
				if c == self then
					table.remove(ch, i)
					break
				end
			end
		end
		rawset(self, "_parent", v)
		if v then
			table.insert(rawget(v, "_children"), self)
		end
		return
	end
	if k == "Name" then
		rawset(self, k, v)
		return
	end
	local ok = false
	for cls, props in PROPS do
		if isA(rawget(self, "ClassName"), cls) and props[k] then
			ok = true
		end
	end
	assert(ok, string.format("cannot set %s.%s (unknown / not allowed in mock)", rawget(self, "ClassName"), k))
	rawset(self, k, v)
end
function Inst:IsA(c)
	return isA(rawget(self, "ClassName"), c)
end
function Inst:GetChildren()
	return table.clone(rawget(self, "_children"))
end
function Inst:GetDescendants()
	local out = {}
	local function walk(n)
		for _, c in rawget(n, "_children") do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function Inst:FindFirstChild(n, rec)
	for _, c in (rec and self:GetDescendants() or rawget(self, "_children")) do
		if c.Name == n then
			return c
		end
	end
	return nil
end
function Inst:FindFirstChildOfClass(cl)
	for _, c in rawget(self, "_children") do
		if rawget(c, "ClassName") == cl then
			return c
		end
	end
	return nil
end
function Inst:FindFirstChildWhichIsA(cl, rec)
	for _, c in (rec and self:GetDescendants() or rawget(self, "_children")) do
		if c:IsA(cl) then
			return c
		end
	end
	return nil
end
function Inst:FindFirstAncestorOfClass(cl)
	local p = self.Parent
	while p do
		if rawget(p, "ClassName") == cl then
			return p
		end
		p = p.Parent
	end
	return nil
end
function Inst:Destroy()
	self.Parent = nil
end
function Inst:SetAttribute(k, v)
	rawget(self, "_attrs")[k] = v
end
function Inst:Clone()
	local c = new(rawget(self, "ClassName"), self.Name)
	for _, ch in rawget(self, "_children") do
		ch:Clone().Parent = c
	end
	return c
end
function Inst:GetExtentsSize()
	return { X = 4, Y = 4, Z = 4 }
end
function Inst:PivotTo(cf)
	assert(getmetatable(cf) == CFrameMT, "PivotTo expects a CFrame")
end
function Inst:SetWaypoint(name)
	assert(type(name) == "string")
end
function Inst:GetService(n)
	return self._services[n]
end

Instance = { new = function(c) return new(c) end }
workspace = new("Workspace", "Workspace")
local services = {
	ServerStorage = new("Service", "ServerStorage"),
	ReplicatedStorage = new("Service", "ReplicatedStorage"),
	ChangeHistoryService = new("Service", "ChangeHistoryService"),
}
game = setmetatable({ _services = services }, { __index = Inst })

return { new = new, workspace = workspace, services = services }
