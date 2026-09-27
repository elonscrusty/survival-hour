--!nonstrict
-- Small Roblox environment for running model builders under the Luau CLI.
-- Real CFrame/Vector3 math; permissive Instances (any property) with the
-- hierarchy, attribute, pivot and scale behaviour the builders rely on.

local M = {}

-- Vector3 ------------------------------------------------------------------
local V3 = {}
V3.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return if m > 0 then Vector3.new(v.X / m, v.Y / m, v.Z / m) else Vector3.new(0, 0, 0)
	end
	return V3[k]
end
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
end
V3.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return v3(b.X * a, b.Y * a, b.Z * a)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3.__tostring = function(a) return string.format("%.3f, %.3f, %.3f", a.X, a.Y, a.Z) end
function V3.Cross(a, b) return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
function V3.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function V3.Lerp(a, b, t) return a + (b - a) * t end
Vector3 = { new = v3, zero = v3(0, 0, 0), one = v3(1, 1, 1), xAxis = v3(1, 0, 0), yAxis = v3(0, 1, 0), zAxis = v3(0, 0, 1) }

-- CFrame --------------------------------------------------------------------
local CF = {}
local function cf(px, py, pz, r)
	return setmetatable({ p = v3(px, py, pz), r = r or { 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, CF)
end
local function mulR(a, b)
	local o = {}
	for i = 0, 2 do
		for j = 0, 2 do
			o[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
		end
	end
	return o
end
local function rotV(r, v)
	return v3(r[1] * v.X + r[2] * v.Y + r[3] * v.Z, r[4] * v.X + r[5] * v.Y + r[6] * v.Z, r[7] * v.X + r[8] * v.Y + r[9] * v.Z)
end
CF.__index = function(c, k)
	if k == "Position" then
		return c.p
	elseif k == "X" then
		return c.p.X
	elseif k == "Y" then
		return c.p.Y
	elseif k == "Z" then
		return c.p.Z
	elseif k == "Rotation" then
		return cf(0, 0, 0, c.r)
	elseif k == "LookVector" then
		return rotV(c.r, v3(0, 0, -1))
	elseif k == "UpVector" then
		return rotV(c.r, v3(0, 1, 0))
	elseif k == "RightVector" then
		return rotV(c.r, v3(1, 0, 0))
	end
	return CF[k]
end
CF.__mul = function(a, b)
	if getmetatable(b) == CF then
		local p = a.p + rotV(a.r, b.p)
		return cf(p.X, p.Y, p.Z, mulR(a.r, b.r))
	end
	return a.p + rotV(a.r, b) -- CFrame * Vector3
end
CF.__add = function(a, v) return cf(a.p.X + v.X, a.p.Y + v.Y, a.p.Z + v.Z, a.r) end
CF.__sub = function(a, v) return cf(a.p.X - v.X, a.p.Y - v.Y, a.p.Z - v.Z, a.r) end
function CF.Inverse(c)
	local r = c.r
	local t = { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] }
	local p = rotV(t, -c.p)
	return cf(p.X, p.Y, p.Z, t)
end
function CF.ToObjectSpace(a, b) return a:Inverse() * b end
function CF.ToWorldSpace(a, b) return a * b end
function CF.PointToObjectSpace(a, v) return a:Inverse() * v end
function CF.Lerp(a, b, t)
	local p = a.p:Lerp(b.p, t)
	return cf(p.X, p.Y, p.Z, if t < 0.5 then a.r else b.r)
end
function CF.GetComponents(c)
	return c.p.X, c.p.Y, c.p.Z, table.unpack(c.r)
end
local function axisAngle(axis, a)
	local u = axis.Unit
	local x, y, z = u.X, u.Y, u.Z
	local c, s, t = math.cos(a), math.sin(a), 1 - math.cos(a)
	return { t * x * x + c, t * x * y - s * z, t * x * z + s * y, t * x * y + s * z, t * y * y + c, t * y * z - s * x, t * x * z - s * y, t * y * z + s * x, t * z * z + c }
end
CFrame = {
	new = function(x, y, z, ...)
		if x == nil then
			return cf(0, 0, 0)
		end
		if type(x) == "table" then
			if y then -- new(pos, lookAt)
				return CFrame.lookAt(x, y)
			end
			return cf(x.X, x.Y, x.Z)
		end
		local n = select("#", ...)
		if n == 9 then
			return cf(x, y, z, { ... })
		end
		assert(n == 0, "CFrame.new: expected 3 or 12 numbers")
		return cf(x, y, z)
	end,
	Angles = function(rx, ry, rz)
		local X = axisAngle(v3(1, 0, 0), rx)
		local Y = axisAngle(v3(0, 1, 0), ry)
		local Z = axisAngle(v3(0, 0, 1), rz)
		return cf(0, 0, 0, mulR(mulR(X, Y), Z))
	end,
	fromAxisAngle = function(axis, a) return cf(0, 0, 0, axisAngle(axis, a)) end,
	lookAt = function(at, target)
		local f = (target - at).Unit
		local up = v3(0, 1, 0)
		if math.abs(f:Dot(up)) > 0.999 then
			up = v3(0, 0, 1)
		end
		local right = f:Cross(up).Unit
		local u = right:Cross(f)
		return cf(at.X, at.Y, at.Z, { right.X, u.X, -f.X, right.Y, u.Y, -f.Y, right.Z, u.Z, -f.Z })
	end,
	identity = cf(0, 0, 0),
}
CFrame.fromEulerAnglesXYZ = CFrame.Angles

-- misc datatypes -------------------------------------------------------------
Color3 = {
	new = function(r, g, b) return { R = r or 0, G = g or 0, B = b or 0, Lerp = function(a, b2, t) return { R = a.R + (b2.R - a.R) * t, G = a.G + (b2.G - a.G) * t, B = a.B + (b2.B - a.B) * t } end } end,
}
Color3.fromRGB = function(r, g, b) return Color3.new(r / 255, g / 255, b / 255) end
NumberRange = { new = function(a, b) return { Min = a, Max = b or a } end }
NumberSequence = { new = function(...) return { ... } end }
ColorSequence = { new = function(...) return { ... } end }
UDim2 = { new = function(...) return { ... } end, fromScale = function(...) return { ... } end, fromOffset = function(...) return { ... } end }
Vector2 = { new = function(x, y) return { X = x, Y = y } end }
local function enum(name)
	return setmetatable({}, { __index = function(t, k)
		local v = { Name = k, EnumType = name }
		rawset(t, k, v)
		return v
	end })
end
Enum = setmetatable({}, { __index = function(t, k)
	local e = enum(k)
	rawset(t, k, e)
	return e
end })

-- Instances ------------------------------------------------------------------
local ISA = {
	Part = { "BasePart", "PVInstance" }, WedgePart = { "BasePart", "PVInstance" }, CornerWedgePart = { "BasePart", "PVInstance" },
	TrussPart = { "BasePart", "PVInstance" }, MeshPart = { "BasePart", "PVInstance" },
	Model = { "PVInstance" }, Tool = { "Model", "PVInstance" }, Accessory = {},
	Attachment = {}, Bone = { "Attachment" },
}
local Inst = {}
local function isA(class, want)
	if class == want or want == "Instance" then
		return true
	end
	for _, c in ISA[class] or {} do
		if c == want then
			return true
		end
	end
	return false
end

local function new(class)
	local raw = { _class = class, _children = {}, _attrs = {}, _props = { Name = class } }
	if isA(class, "BasePart") then
		local pr = raw._props
		pr.CFrame, pr.Size, pr.PivotOffset = cf(0, 0, 0), v3(4, 1, 2), cf(0, 0, 0)
		pr.Transparency, pr.Anchored, pr.CanCollide, pr.CanQuery, pr.CanTouch = 0, true, true, true, true
		pr.CastShadow, pr.Massless = true, false
		pr.Color = Color3.new(0.6, 0.6, 0.6)
	elseif class == "Tool" then
		raw._props.Grip = cf(0, 0, 0)
	elseif class == "Attachment" or class == "Bone" then
		raw._props.CFrame = cf(0, 0, 0)
	elseif class == "Model" then
		raw._props.WorldPivot = cf(0, 0, 0)
	end
	if class == "SurfaceGui" or class == "Fire" or class == "PointLight" or class == "ParticleEmitter" or class == "Smoke" then
		raw._props.Enabled = true
	end
	return setmetatable(raw, Inst)
end

Inst.__index = function(self, k)
	if k == "Parent" then
		return rawget(self, "_parent")
	elseif k == "ClassName" then
		return rawget(self, "_class")
	elseif k == "Position" and isA(rawget(self, "_class"), "BasePart") then
		return rawget(self, "_props").CFrame.p
	end
	local m = Inst[k]
	if m ~= nil then
		return m
	end
	local v = rawget(self, "_props")[k]
	if v ~= nil then
		return v
	end
	for _, c in rawget(self, "_children") do
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
	if k == "Position" then
		local c = rawget(self, "_props").CFrame
		rawget(self, "_props").CFrame = cf(v.X, v.Y, v.Z, c.r)
		return
	end
	if k == "WorldPivot" and rawget(self, "_props").PrimaryPart then
		return -- Roblox ignores WorldPivot while a PrimaryPart is set
	end
	rawget(self, "_props")[k] = v
end
function Inst:IsA(c) return isA(rawget(self, "_class"), c) end
function Inst:GetChildren() return table.clone(rawget(self, "_children")) end
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
	for _, c in (if rec then self:GetDescendants() else rawget(self, "_children")) do
		if c.Name == n then
			return c
		end
	end
	return nil
end
function Inst:FindFirstChildOfClass(cl)
	for _, c in rawget(self, "_children") do
		if rawget(c, "_class") == cl then
			return c
		end
	end
	return nil
end
function Inst:FindFirstChildWhichIsA(cl, rec)
	for _, c in (if rec then self:GetDescendants() else rawget(self, "_children")) do
		if c:IsA(cl) then
			return c
		end
	end
	return nil
end
function Inst:FindFirstAncestorOfClass(cl)
	local p = self.Parent
	while p do
		if rawget(p, "_class") == cl then
			return p
		end
		p = p.Parent
	end
	return nil
end
function Inst:IsDescendantOf(a)
	local p = self.Parent
	while p do
		if p == a then
			return true
		end
		p = p.Parent
	end
	return false
end
function Inst:Destroy() self.Parent = nil end
function Inst:SetAttribute(k, v) rawget(self, "_attrs")[k] = v end
function Inst:GetAttribute(k) return rawget(self, "_attrs")[k] end
function Inst:Clone()
	local map = {}
	local function copy(n)
		local c = new(rawget(n, "_class"))
		map[n] = c
		for k, v in rawget(n, "_props") do
			rawget(c, "_props")[k] = v
		end
		for k, v in rawget(n, "_attrs") do
			rawget(c, "_attrs")[k] = v
		end
		for _, ch in rawget(n, "_children") do
			copy(ch).Parent = c
		end
		return c
	end
	local root = copy(self)
	-- remap instance references (PrimaryPart, Part0/1) to the copies
	for orig, c in map do
		for k, v in rawget(c, "_props") do
			if type(v) == "table" and map[v] then
				rawget(c, "_props")[k] = map[v]
			end
		end
	end
	return root
end
local function parts(model)
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end
function Inst:GetPivot()
	if self:IsA("BasePart") then
		return self.CFrame * self.PivotOffset
	end
	local pp = rawget(self, "_props").PrimaryPart
	if pp then
		return pp.CFrame * pp.PivotOffset
	end
	return rawget(self, "_props").WorldPivot
end
function Inst:PivotTo(target)
	assert(getmetatable(target) == CF, "PivotTo expects a CFrame")
	local delta = target * self:GetPivot():Inverse()
	if self:IsA("BasePart") then
		self.CFrame = delta * self.CFrame
		return
	end
	for _, p in parts(self) do
		p.CFrame = delta * p.CFrame
	end
	if not rawget(self, "_props").PrimaryPart then
		rawget(self, "_props").WorldPivot = target
	end
end
function Inst:ScaleTo(s)
	local pivot = self:GetPivot()
	local cur = self:GetAttribute("_scale") or 1
	local k = s / cur
	for _, p in parts(self) do
		local rel = pivot:ToObjectSpace(p.CFrame)
		p.Size = p.Size * k
		p.CFrame = pivot * cf(rel.p.X * k, rel.p.Y * k, rel.p.Z * k, rel.r)
	end
	self:SetAttribute("_scale", s)
end
function Inst:GetScale() return self:GetAttribute("_scale") or 1 end
function Inst:GetExtentsSize() return v3(4, 4, 4) end
-- Axis-aligned bounds of the model's parts (enough for colliders in tests).
function Inst:GetBoundingBox()
	local lo, hi
	for _, p in parts(self) do
		local c, h = p.CFrame.p, p.Size * 0.5
		local a = v3(c.X - h.X, c.Y - h.Y, c.Z - h.Z)
		local b = v3(c.X + h.X, c.Y + h.Y, c.Z + h.Z)
		lo = if lo then v3(math.min(lo.X, a.X), math.min(lo.Y, a.Y), math.min(lo.Z, a.Z)) else a
		hi = if hi then v3(math.max(hi.X, b.X), math.max(hi.Y, b.Y), math.max(hi.Z, b.Z)) else b
	end
	if not lo then
		return self:GetPivot(), v3(0, 0, 0)
	end
	return cf((lo.X + hi.X) / 2, (lo.Y + hi.Y) / 2, (lo.Z + hi.Z) / 2), v3(hi.X - lo.X, hi.Y - lo.Y, hi.Z - lo.Z)
end
function Inst:GetService(n)
	return rawget(self, "_props")[n]
end

Instance = { new = function(c, parent)
	local i = new(c)
	if parent then
		i.Parent = parent
	end
	return i
end }

game = new("DataModel")
rawget(game, "_props").ReplicatedStorage = new("ReplicatedStorage")
rawget(game, "_props").ReplicatedStorage.Name = "ReplicatedStorage"
workspace = new("Workspace")
task = { wait = function() end, spawn = function(f, ...) f(...) end, delay = function() end }

M.new = new
M.cf = cf
return M
