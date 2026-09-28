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
NumberSequenceKeypoint = { new = function(t, v, e) return { Time = t, Value = v, Envelope = e or 0 } end }
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

-- Generated by tests/skins/make_library_data.py from Roblox/catalog.json
local __LibraryData = {{name="SM_Reference_Dummy_R15",kind="Reference",cat="Reference",size={3.95,5.25,1.23},oo={0,-2.625,0.0125},parts={},r15=""},{name="SM_Tree_Pine_Medium01",kind="WorldProp",cat="Forest",size={11.55,20.49,11.38},oo={0.4555,-9.753,-0.423},parts={},r15=""},{name="SM_Tree_Pine_Medium02",kind="WorldProp",cat="Forest",size={8.14,17.47,10.01},oo={-0.4075,-8.2665,0.3285},parts={},r15=""},{name="SM_Tree_Pine_Large01",kind="WorldProp",cat="Forest",size={17.54,32.42,15.37},oo={0.0465,-15.7905,-0.5415},parts={},r15=""},{name="SM_Tree_Pine_Small01",kind="Harvestable",cat="Forest",size={6.66,10.48,7.15},oo={0.3275,-4.7575,0.1015},parts={},r15=""},{name="SM_Tree_Oak_Medium01",kind="WorldProp",cat="Forest",size={15.01,15.95,15.3},oo={-0.5045,-7.4035,0.0745},parts={},r15=""},{name="SM_Tree_Oak_Medium02",kind="WorldProp",cat="Forest",size={13.96,14.65,12.88},oo={0.433,-6.7615,0.2665},parts={},r15=""},{name="SM_Tree_Oak_Large01",kind="WorldProp",cat="Forest",size={21.55,24.74,20.01},oo={-0.4205,-11.8155,-0.075},parts={},r15=""},{name="SM_Tree_Oak_Small01",kind="Harvestable",cat="Forest",size={5.65,8.86,6.34},oo={0.6535,-3.9035,0.888},parts={},r15=""},{name="SM_Tree_Birch_Medium01",kind="WorldProp",cat="Forest",size={5.28,18.12,6.6},oo={-0.104,-8.657,-0.2415},parts={},r15=""},{name="SM_Tree_Birch_Small01",kind="Harvestable",cat="Forest",size={4.37,10.71,4.04},oo={-0.2585,-4.9135,0.4705},parts={},r15=""},{name="SM_Tree_Dead_Large01",kind="WorldProp",cat="Forest",size={16.3,20.06,15.57},oo={0.5595,-9.4535,0.188},parts={},r15=""},{name="SM_Tree_Pine_Small01_Stump",kind="Harvestable",cat="Forest",size={3.04,1.2,3.12},oo={0.066,-0.3,-0.107},parts={},r15=""},{name="SM_Tree_Oak_Small01_Stump",kind="Harvestable",cat="Forest",size={3.17,1.15,2.86},oo={0.142,-0.275,0},parts={},r15=""},{name="SM_Tree_Birch_Small01_Stump",kind="Harvestable",cat="Forest",size={2.94,1.1,2.67},oo={0.132,-0.25,0},parts={},r15=""},{name="SM_Stump_Old01",kind="WorldProp",cat="Forest",size={4.11,2.18,4.11},oo={0,-0.7895,0},parts={},r15=""},{name="SM_Stump_Old02",kind="WorldProp",cat="Forest",size={3.74,3.88,3.74},oo={0,-1.6385,0},parts={},r15=""},{name="SM_FallenLog01",kind="WorldProp",cat="Forest",size={8.06,2.29,1.78},oo={-0.002,-1.0685,-0.054},parts={},r15=""},{name="SM_FallenLog02_Hollow",kind="WorldProp",cat="Forest",size={10.88,3.11,2.74},oo={-0.292,-1.432,-0.042},parts={},r15=""},{name="SM_Branch01",kind="WorldProp",cat="Forest",size={4.55,0.48,3.01},oo={-0.0125,-0.24,-0.15},parts={},r15=""},{name="SM_Branch02",kind="WorldProp",cat="Forest",size={3.65,0.53,2.9},oo={-0.0145,-0.2665,-0.1125},parts={},r15=""},{name="SM_Sticks_Loose01",kind="WorldProp",cat="Forest",size={1.85,0.28,3.06},oo={0.323,-0.1615,0.0175},parts={},r15=""},{name="SM_Rock_Small01",kind="WorldProp",cat="Forest",size={1.81,0.61,1.29},oo={0.027,-0.3045,0.0005},parts={},r15=""},{name="SM_Rock_Small02",kind="WorldProp",cat="Forest",size={2.53,0.72,1.69},oo={0.232,-0.359,-0.102},parts={},r15=""},{name="SM_Rock_Small03",kind="WorldProp",cat="Forest",size={2.8,0.29,2.35},oo={-0.036,-0.145,0.047},parts={},r15=""},{name="SM_Boulder01",kind="WorldProp",cat="Forest",size={9.54,3.49,6.65},oo={0.4185,-1.7455,-0.0085},parts={},r15=""},{name="SM_Boulder02",kind="WorldProp",cat="Forest",size={6.82,4.77,5.87},oo={-0.1055,-2.386,0.1895},parts={},r15=""},{name="SM_Boulder03",kind="WorldProp",cat="Forest",size={6.86,2.25,5.46},oo={-0.151,-1.125,-0.2615},parts={},r15=""},{name="SM_StoneDeposit01",kind="Harvestable",cat="Forest",size={5.99,2.48,4.24},oo={-0.0195,-1.239,0.0255},parts={},r15=""},{name="SM_StoneDeposit01_Depleted",kind="Harvestable",cat="Forest",size={4.38,0.75,4.48},oo={-0.413,-0.374,-0.169},parts={},r15=""},{name="SM_FiberPlant01",kind="Harvestable",cat="Forest",size={1.93,3.79,1.95},oo={-0.0025,-1.8255,-0.109},parts={},r15=""},{name="SM_FiberPlant01_Harvested",kind="Harvestable",cat="Forest",size={0.52,0.65,0.81},oo={-0.0865,-0.258,-0.0475},parts={},r15=""},{name="SM_Grass_Clump01",kind="WorldProp",cat="Forest",size={1.23,1.47,1.35},oo={-0.1845,-0.663,-0.074},parts={},r15=""},{name="SM_Grass_Clump02",kind="WorldProp",cat="Forest",size={2.6,1.17,1.28},oo={0.0785,-0.5135,-0.2845},parts={},r15=""},{name="SM_Grass_Clump03",kind="WorldProp",cat="Forest",size={1.34,2.03,1.14},oo={-0.098,-0.944,0.031},parts={},r15=""},{name="SM_Bush01",kind="WorldProp",cat="Forest",size={2.85,2.02,3.44},oo={-0.1695,-1.011,0.1825},parts={},r15=""},{name="SM_Bush02",kind="WorldProp",cat="Forest",size={4.54,2.75,4.53},oo={-0.291,-1.3755,-0.0635},parts={},r15=""},{name="SM_Bush03_Berry",kind="WorldProp",cat="Forest",size={3.26,1.84,3.14},oo={-0.124,-0.9205,-0.044},parts={},r15=""},{name="SM_Fern01",kind="WorldProp",cat="Forest",size={3.98,0.74,3.94},oo={0.034,-0.3715,-0.126},parts={},r15=""},{name="SM_Fern02",kind="WorldProp",cat="Forest",size={2.75,0.74,2.85},oo={-0.111,-0.3715,0.023},parts={},r15=""},{name="SM_Mushrooms01",kind="WorldProp",cat="Forest",size={1.47,0.93,1.02},oo={-0.0425,-0.464,0.002},parts={},r15=""},{name="SM_Mushrooms02_Glow",kind="WorldProp",cat="Forest",size={1.03,0.65,0.49},oo={0.1195,-0.327,0.2565},parts={},r15=""},{name="SM_LeafLitter01",kind="WorldProp",cat="Forest",size={6.08,0.19,4.96},oo={0.018,-0.094,-0.0535},parts={},r15=""},{name="SM_Pinecones01",kind="WorldProp",cat="Forest",size={1.67,0.3,2.24},oo={0.2195,-0.1185,0.0315},parts={},r15=""},{name="SM_MossPatch01",kind="WorldProp",cat="Forest",size={4.67,0.16,3.62},oo={-0.032,-0.0775,0.0285},parts={},r15=""},{name="SM_Landmark_StandingStones",kind="WorldProp",cat="Forest",size={17.26,7.9,17.79},oo={0.366,-3.9485,0.012},parts={},r15=""},{name="SM_Landmark_AntlerTotem",kind="WorldProp",cat="Forest",size={3.32,8.86,1.19},oo={-0.001,-4.1215,0.0325},parts={},r15=""},{name="SM_Landmark_GiantLog",kind="WorldProp",cat="Forest",size={22.8,8.6,7.43},oo={0,-3.491,-0.1555},parts={},r15=""},{name="SM_Clearing_GroundPatch",kind="WorldProp",cat="Forest",size={40,0.65,40},oo={0,0.275,0},parts={},r15=""},{name="SM_Camp_LogBench",kind="WorldProp",cat="Forest",size={5,1.89,1.26},oo={0,-0.945,-0.0195},parts={},r15=""},{name="SM_Camp_FirewoodStack",kind="WorldProp",cat="Forest",size={2.65,1.76,1.5},oo={0,-0.88,0},parts={},r15=""},{name="SM_Camp_DryingRack",kind="WorldProp",cat="Forest",size={4.6,4.23,1.41},oo={0,-1.9,0},parts={},r15=""},{name="SM_Camp_Lantern",kind="WorldProp",cat="Forest",size={1.36,5.3,0.64},oo={0.54,-2.35,0},parts={},r15=""},{name="SM_Camp_Bedroll",kind="WorldProp",cat="Forest",size={1.8,0.71,4.6},oo={0,-0.3,0},parts={},r15=""},{name="SM_Camp_Barrel",kind="WorldProp",cat="Forest",size={2,2.53,2},oo={0,-1.265,0},parts={},r15=""},{name="SM_Camp_ChoppingBlock",kind="WorldProp",cat="Forest",size={3.8,1.7,3.84},oo={0.002,-0.55,0.004},parts={},r15=""},{name="SM_Camp_TeamBanner",kind="WorldProp",cat="Forest",size={2.29,9.4,0.39},oo={0.9525,-4.3,0},parts={},r15=""},{name="SM_Stream_Straight",kind="WorldProp",cat="Stream",size={24,4.05,16},oo={0,0.575,0},parts={},r15=""},{name="SM_Stream_Bend90",kind="WorldProp",cat="Stream",size={28,3.8,28},oo={-2,0.7,-6},parts={},r15=""},{name="SM_Stream_PoolEnd",kind="WorldProp",cat="Stream",size={24,3.8,24},oo={0,0.7,-4},parts={},r15=""},{name="SM_Stream_Water_Straight",kind="Effect",cat="Stream",size={10.5,0.1,16},oo={0,0.65,0},parts={},r15=""},{name="SM_Stream_Water_Bend90",kind="Effect",cat="Stream",size={21.25,0.1,21.25},oo={-5.375,0.65,-2.625},parts={},r15=""},{name="SM_Stream_Water_PoolEnd",kind="Effect",cat="Stream",size={12.4,0.1,21.2},oo={0,0.65,-2.6},parts={},r15=""},{name="SM_StreamRocks01",kind="WorldProp",cat="Stream",size={3.24,0.64,3.38},oo={0.4485,-0.3185,0.289},parts={},r15=""},{name="SM_StreamRocks02",kind="WorldProp",cat="Stream",size={7.58,1.59,2.25},oo={0.0105,-0.793,0.168},parts={},r15=""},{name="SM_StreamRocks03",kind="WorldProp",cat="Stream",size={3.01,0.2,4.23},oo={0.543,-0.1,-0.1685},parts={},r15=""},{name="SM_Campfire_Burning",kind="Structure",cat="Camp",size={6.81,6.5,6.44},oo={0.247,-2.95,0.004},parts={},r15=""},{name="SM_Campfire_Extinguished",kind="Structure",cat="Camp",size={6.96,6.5,6.62},oo={0.169,-2.95,0.042},parts={},r15=""},{name="SM_Campfire_ColdWet",kind="Structure",cat="Camp",size={6.96,6.5,6.76},oo={0.1725,-2.95,0.0305},parts={},r15=""},{name="SM_Campfire_Flames",kind="Effect",cat="Camp",size={2.47,4.9,2.42},oo={0.2055,-2.7,-0.053},parts={},r15=""},{name="SM_Campfire_WaterTarget",kind="Effect",cat="Camp",size={6.4,0.44,6.4},oo={0,-0.35,0},parts={},r15=""},{name="SM_Workbench_Level01",kind="Structure",cat="Camp",size={6,3.46,2.44},oo={0,-1.73,0},parts={},r15=""},{name="SM_Workbench_Level02",kind="Structure",cat="Camp",size={7,6.4,3.62},oo={0,-3.2,0.2875},parts={},r15=""},{name="SM_Workbench_Level03",kind="Structure",cat="Camp",size={10.09,7.8,3.5},oo={-1.044,-3.9,0},parts={},r15=""},{name="SM_WoodenWall",kind="Structure",cat="Crafting_L1",size={8.59,10.13,1.56},oo={-0.3955,-4.7625,-0.0895},parts={},r15=""},{name="SM_WoodenWall_Damaged",kind="Structure",cat="Crafting_L1",size={8.59,10.14,1.56},oo={-0.3955,-4.7625,-0.0895},parts={},r15=""},{name="SM_WallPost",kind="Structure",cat="Crafting_L1",size={1.42,10.13,1.42},oo={0,-4.765,0},parts={},r15=""},{name="SM_StoneAxe",kind="Equippable",cat="Crafting_L1",size={0.48,3.46,1.58},oo={0,-1.0285,0.2775},parts={},r15=""},{name="SM_StorageBox",kind="Structure",cat="Crafting_L1",size={3.13,1.8,2.02},oo={0.015,-0.9,0},parts={{name="SM_StorageBox_Lid",size={3.1,0.45,2.27},oo={0,-0.0525,1.035},place={0,1.8,1.05,1,0,0,0,1,0,0,0,1}}},r15=""},{name="SM_StorageBox_Damaged",kind="Structure",cat="Crafting_L1",size={3.13,1.8,2.02},oo={0.015,-0.9,0},parts={{name="SM_StorageBox_Lid_Damaged",size={3.1,0.53,2.27},oo={0,-0.0895,1.035},place={0,1.8,1.05,0.9986,0.0073,0.0518,0,0.9903,-0.1392,-0.0523,0.139,0.9889}}},r15=""},{name="SM_Spear",kind="Equippable",cat="Crafting_L1",size={0.53,1.01,7.21},oo={0.0155,0.3425,1.203},parts={},r15=""},{name="SM_RepairHammer",kind="Equippable",cat="Crafting_L1",size={0.81,3.19,1.5},oo={0,-0.8935,0.2495},parts={},r15=""},{name="SM_Debris_Splinters",kind="Debris",cat="Crafting_L1",size={1.6,0.18,1.6},oo={-0.001,-0.17,0.0005},parts={},r15=""},{name="SM_Debris_LogChunk",kind="Debris",cat="Crafting_L1",size={2.1,0.97,0.95},oo={0.25,-0.5,-0.025},parts={},r15=""},{name="SM_Debris_MetalBand",kind="Debris",cat="Crafting_L1",size={2,0.3,0.16},oo={0,-0.2,-0.21},parts={},r15=""},{name="SM_Canteen",kind="Equippable",cat="Crafting_L2",size={1.1,1.71,1.37},oo={0,-0.6215,0.198},parts={},r15=""},{name="SM_Bow",kind="Equippable",cat="Crafting_L2",size={0.28,4.63,0.53},oo={0,0,0.0625},parts={},r15=""},{name="SM_Arrow",kind="Projectile",cat="Crafting_L2",size={0.2,0.95,3.05},oo={0,0,0.025},parts={},r15=""},{name="SM_ArrowBundle",kind="Pickup",cat="Crafting_L2",size={0.47,1.11,3.05},oo={0.0425,-0.2,0.025},parts={},r15=""},{name="SM_Gate",kind="Structure",cat="Crafting_L2",size={8.95,11.04,1.4},oo={-0.225,-5.22,0},parts={{name="SM_Gate_Door",size={6.7,7.45,0.74},oo={3.227,-3.725,-0.08},place={3.35,0.05,0,1,0,0,0,1,0,0,0,1}}},r15=""},{name="SM_Gate_Door_Damaged",kind="MovingPart",cat="Crafting_L2",size={6.7,7.45,0.88},oo={3.227,-3.725,-0.15},parts={},r15=""},{name="SM_Spikes",kind="Structure",cat="Crafting_L2",size={8,2.6,3.55},oo={0,-1.3,0.3255},parts={},r15=""},{name="SM_Spikes_Damaged",kind="Structure",cat="Crafting_L2",size={8,2.6,3.55},oo={0,-1.3,0.3255},parts={},r15=""},{name="SM_ReinforcedWall",kind="Structure",cat="Crafting_L3",size={9.08,10.14,1.73},oo={-0.1325,-4.9295,-0.0575},parts={},r15=""},{name="SM_ReinforcedWall_Damaged",kind="Structure",cat="Crafting_L3",size={9.13,10.14,1.73},oo={-0.1095,-4.929,-0.054},parts={},r15=""},{name="SM_Watchtower",kind="Structure",cat="Crafting_L3",size={9.05,22.61,9.05},oo={0,-10.897,0},parts={},r15=""},{name="SM_Sword",kind="Equippable",cat="Crafting_L3",size={0.32,4.37,0.95},oo={0,-1.565,-0.03},parts={},r15=""},{name="SM_Shield",kind="Equippable",cat="Crafting_L3",size={2.9,2.9,0.68},oo={0,0,0.29},parts={},r15=""},{name="ACC_Armor_Helmet",kind="Accessory",cat="Armor",size={1.62,1.3,1.67},oo={0,0.45,-0.0165},parts={},r15="HatAttachment"},{name="ACC_Armor_Chest",kind="Accessory",cat="Armor",size={2.2,1.92,1.32},oo={0,0.02,-0.3385},parts={},r15="BodyFrontAttachment"},{name="ACC_Armor_Back",kind="Accessory",cat="Armor",size={2.1,2.05,0.49},oo={0,0.175,-0.226},parts={},r15="BodyBackAttachment"},{name="ACC_Armor_ShoulderL",kind="Accessory",cat="Armor",size={1.58,0.98,1.17},oo={-0.01,0.088,0.025},parts={},r15="LeftShoulderAttachment"},{name="ACC_Armor_ShoulderR",kind="Accessory",cat="Armor",size={1.58,0.98,1.17},oo={0.01,0.088,0.025},parts={},r15="RightShoulderAttachment"},{name="ACC_Armor_Belt",kind="Accessory",cat="Armor",size={2.22,1.03,1.34},oo={0,0.3375,0.06},parts={},r15="WaistCenterAttachment"},{name="SM_Pickup_Stick",kind="Pickup",cat="Pickups",size={1.7,0.47,0.52},oo={-0.0005,-0.2,0.007},parts={},r15=""},{name="SM_Pickup_Stone",kind="Pickup",cat="Pickups",size={1.41,0.69,0.92},oo={0.0385,-0.3465,-0.0135},parts={},r15=""},{name="SM_Pickup_Wood",kind="Pickup",cat="Pickups",size={1.07,0.93,1.3},oo={0,-0.447,0},parts={},r15=""},{name="SM_Pickup_Fiber",kind="Pickup",cat="Pickups",size={0.54,0.31,1.66},oo={0,-0.18,-0.024},parts={},r15=""},{name="SM_Pickup_Rope",kind="Pickup",cat="Pickups",size={1.56,0.36,1.23},oo={0.1625,-0.166,0.0015},parts={},r15=""},{name="SM_Pickup_Leather",kind="Pickup",cat="Pickups",size={1.3,0.49,1.29},oo={0,-0.18,0},parts={},r15=""},{name="SM_Pickup_Ammo",kind="Pickup",cat="Pickups",size={1.25,0.81,0.85},oo={0,-0.4125,0.025},parts={},r15=""},{name="SM_Pickup_Bandage",kind="Pickup",cat="Pickups",size={0.55,0.77,1.47},oo={0,-0.36,0.3665},parts={},r15=""},{name="SM_Pickup_Diamond",kind="Pickup",cat="Pickups",size={1.32,1.04,1.32},oo={0,-0.57,0},parts={},r15=""},{name="SM_CarePackage_Crate",kind="Structure",cat="Loot",size={4.45,3.41,4.45},oo={0,-1.6975,0},parts={{name="SM_CarePackage_Lid",size={4.25,0.45,4.39},oo={0,-0.226,2.045},place={0,3.4,2,1,0,0,0,1,0,0,0,1}}},r15=""},{name="SM_Parachute_Canopy",kind="Effect",cat="Loot",size={14,4.4,14},oo={0,-14.2,0},parts={},r15=""},{name="SM_Parachute_Lines",kind="Effect",cat="Loot",size={13.89,12.44,13.89},oo={0,-5.8195,0},parts={},r15=""},{name="SM_Beacon",kind="WorldProp",cat="Loot",size={1.78,5.12,2.02},oo={0.274,-2.4405,0},parts={},r15=""},{name="SM_LandingMarker",kind="WorldProp",cat="Loot",size={7.99,0.33,7.99},oo={0,-0.165,0},parts={},r15=""},{name="SM_SupplyCrate_Small01",kind="Structure",cat="Loot",size={1.86,1.52,1.9},oo={0,-0.75,0.0275},parts={{name="SM_SupplyCrate_Small01_Lid",size={1.9,0.25,1.9},oo={0,-0.125,0.9},place={0,1.5,0.9,1,0,0,0,1,0,0,0,1}}},r15=""},{name="SM_SupplyCrate_Small02",kind="Structure",cat="Loot",size={3.26,1.12,1.51},oo={0,-0.55,0.0275},parts={{name="SM_SupplyCrate_Small02_Lid",size={3.3,0.25,1.5},oo={0,-0.125,0.7},place={0,1.1,0.7,1,0,0,0,1,0,0,0,1}}},r15=""},{name="SM_SupplyCrate_Small03",kind="Structure",cat="Loot",size={3.73,1.31,3.36},oo={0.4,-0.655,-0.3},parts={{name="SM_SupplyCrate_Small03_Lid",size={2.3,0.25,1.7},oo={0,-0.125,0.8},place={0,1.3,0.8,1,0,0,0,1,0,0,0,1}}},r15=""},{name="SM_Bandage_Held",kind="Equippable",cat="Loot",size={0.45,1.46,0.73},oo={0,0.319,0.0685},parts={},r15=""},{name="SM_Ammo_Pistol",kind="Pickup",cat="Loot",size={0.9,0.75,0.62},oo={0,-0.3675,0},parts={},r15=""},{name="SM_Ammo_Shotgun",kind="Pickup",cat="Loot",size={1.1,0.95,0.7},oo={0,-0.475,0},parts={},r15=""},{name="SM_Ammo_Rifle",kind="Pickup",cat="Loot",size={1.3,0.96,0.6},oo={0,-0.4825,0},parts={},r15=""},{name="SM_Pistol",kind="Equippable",cat="Firearms",size={0.28,1.05,1.41},oo={0,0.096,0.3035},parts={{name="SM_Pistol_Slide",size={0.28,0.29,1.47},oo={-0.0025,-0.0275,0.335},place={0,0.47,0,1,0,0,0,1,0,0,0,1}}},r15=""},{name="SM_Shotgun",kind="Equippable",cat="Firearms",size={0.33,1.08,5.67},oo={0,-0.049,0.763},parts={{name="SM_Shotgun_Pump",size={0.34,0.33,1.16},oo={0,0,-0.131},place={0,0.22,-1.9,1,0,0,0,1,0,0,0,1}}},r15=""},{name="SM_Rifle",kind="Equippable",cat="Firearms",size={0.34,1.24,5.69},oo={0,-0.059,0.556},parts={{name="SM_Rifle_Bolt",size={0.49,0.37,0.8},oo={-0.173,0.115,0},place={0,0.52,0.35,1,0,0,0,1,0,0,0,1}}},r15=""},{name="SK_Wolf",kind="Rig",cat="Wildlife",size={1.64,4.05,6.51},oo={0,0,0},parts={},r15=""},{name="SK_Bear",kind="Rig",cat="Wildlife",size={3.06,4.72,7.87},oo={0,0,0},parts={},r15=""},{name="SK_Bat",kind="Rig",cat="Wildlife",size={5.2,0.72,1.91},oo={0,0,0},parts={},r15=""},{name="SM_Lobby_GatheringArea",kind="Lobby",cat="Lobby",size={26,7.3,26},oo={0,-3.65,0},parts={},r15=""},{name="SM_Lobby_ReadyStation",kind="Lobby",cat="Lobby",size={8.87,8.66,5.4},oo={0,-4.019,0},parts={},r15=""},{name="SM_Lobby_PartyArea",kind="Lobby",cat="Lobby",size={14.05,8,14},oo={0,-4,0},parts={},r15=""},{name="SM_Lobby_PowerupStand",kind="Lobby",cat="Lobby",size={2.85,3.95,3},oo={0,-1.975,0},parts={},r15=""},{name="SM_Lobby_ShopDisplay",kind="Lobby",cat="Lobby",size={10,7.37,6.9},oo={0,-3.6845,0.2525},parts={},r15=""},{name="SM_Sign_Post",kind="Lobby",cat="Lobby",size={4,5.1,0.54},oo={0,-2.25,-0.0015},parts={{name="SM_Sign_Post_Panel",size={3.5,1.8,0.2},oo={0,0,0},place={0,3.6,-0.1,1,0,0,0,1,0,0,0,1}}},r15=""},{name="SM_Sign_Hanging",kind="Lobby",cat="Lobby",size={4.5,3.44,0.34},oo={0,1.7225,0},parts={{name="SM_Sign_Hanging_Panel",size={4,2,0.2},oo={0,0,0},place={0,-2.2,0,1,0,0,0,1,0,0,0,1}}},r15=""},{name="SM_Sign_Board",kind="Lobby",cat="Lobby",size={12,9.3,1.6},oo={0,-4.25,-0.1},parts={{name="SM_Sign_Board_Panel",size={9,4.5,0.2},oo={0,0,0},place={0,5,0,1,0,0,0,1,0,0,0,1}}},r15=""},{name="SM_Sign_Plaque",kind="Lobby",cat="Lobby",size={1.8,0.94,0.34},oo={0,0,0},parts={{name="SM_Sign_Plaque_Panel",size={1.3,0.45,0.2},oo={0,0,0},place={0,0,0,1,0,0,0,1,0,0,0,1}}},r15=""},{name="SM_Emblem_Trailblazer",kind="Lobby",cat="Lobby",size={2.64,2.64,0.47},oo={0,0,-0.045},parts={},r15=""},{name="SM_Emblem_Scavenger",kind="Lobby",cat="Lobby",size={2.64,2.64,0.49},oo={0,0,-0.035},parts={},r15=""},{name="SM_Emblem_Hunter",kind="Lobby",cat="Lobby",size={2.64,2.64,0.46},oo={0,0,-0.05},parts={},r15=""},{name="SM_Emblem_Climber",kind="Lobby",cat="Lobby",size={2.64,2.64,0.49},oo={0,0,-0.0345},parts={},r15=""},{name="SM_Emblem_Craftsman",kind="Lobby",cat="Lobby",size={2.64,2.64,0.48},oo={0,0,-0.04},parts={},r15=""},{name="SM_Emblem_Sharpshooter",kind="Lobby",cat="Lobby",size={2.64,2.64,0.58},oo={0,0,0.01},parts={},r15=""},{name="SM_Cliff_Face01",kind="WorldProp",cat="SW_Landscape",size={24.8,26.38,9.71},oo={0.0405,-12.212,0.2555},parts={},r15=""},{name="SM_Cliff_Face02",kind="WorldProp",cat="SW_Landscape",size={24.62,23.56,9.66},oo={0.188,-11.0735,0.02},parts={},r15=""},{name="SM_CaveEntrance",kind="WorldProp",cat="SW_Landscape",size={20.87,15.4,9.75},oo={-0.16,-4.2015,0.568},parts={},r15=""},{name="SM_CaveTunnel_Segment",kind="WorldProp",cat="SW_Landscape",size={14.75,12.95,12.4},oo={-0.1465,-5.6865,0.368},parts={},r15=""},{name="SM_CaveChamber_End",kind="WorldProp",cat="SW_Landscape",size={19.37,15.88,20.19},oo={0.542,-6.7265,-3.894},parts={},r15=""},{name="SM_Riverbank_Straight",kind="WorldProp",cat="SW_Landscape",size={16,2.08,10.06},oo={0,0.36,0.0285},parts={},r15=""},{name="SM_Riverbank_Bend",kind="WorldProp",cat="SW_Landscape",size={13.77,2.08,12.64},oo={2.5485,0.36,-1.318},parts={},r15=""},{name="SM_Ground_Forest01",kind="WorldProp",cat="SW_Landscape",size={32,2.54,32},oo={0,0.7305,0},parts={},r15=""},{name="SM_Ground_Clearing01",kind="WorldProp",cat="SW_Landscape",size={32,2.74,32},oo={0,0.6305,0},parts={},r15=""},{name="SM_Trail_Segment01",kind="WorldProp",cat="SW_Landscape",size={4.96,0.66,12.02},oo={0.08,-0.2715,-0.002},parts={},r15=""},{name="SM_Roots01",kind="WorldProp",cat="SW_Landscape",size={4.97,0.57,4.82},oo={0.028,-0.264,-0.2065},parts={},r15=""},{name="SM_Roots02",kind="WorldProp",cat="SW_Landscape",size={4.86,0.93,2.72},oo={-0.0055,-0.4095,-0.0065},parts={},r15=""},{name="SM_Flowers01",kind="WorldProp",cat="SW_Landscape",size={2.53,1.04,2.31},oo={-0.021,-0.396,-0.021},parts={},r15=""},{name="SM_Flowers02",kind="WorldProp",cat="SW_Landscape",size={2.44,1.03,2.37},oo={0.0905,-0.388,0.115},parts={},r15=""},{name="SM_Sapling01",kind="WorldProp",cat="SW_Landscape",size={2.46,5.07,2.41},oo={0.114,-2.3315,-0.068},parts={},r15=""},{name="SM_Tree_Spruce01",kind="WorldProp",cat="SW_Landscape",size={12.21,20.41,12.03},oo={0,-9.797,-0.187},parts={},r15=""},{name="SM_Tree_Spruce02",kind="WorldProp",cat="SW_Landscape",size={14.42,24.45,14.2},oo={0,-11.8205,-0.2205},parts={},r15=""},{name="SM_Tree_Aspen01",kind="WorldProp",cat="SW_Landscape",size={7.67,19.22,7.54},oo={-0.1635,-9.304,0.1745},parts={},r15=""},{name="SM_ScrapPile01",kind="Harvestable",cat="SW_Landscape",size={4.33,2.09,3.75},oo={0,-0.706,0.0055},parts={},r15=""},{name="SM_OreDeposit_Coal",kind="Harvestable",cat="SW_Landscape",size={5.23,3.59,4.49},oo={0.1045,-1.19,0.2055},parts={},r15=""},{name="SM_OreDeposit_Iron",kind="Harvestable",cat="SW_Landscape",size={5.37,3.26,4.56},oo={-0.021,-1.1585,0.0205},parts={},r15=""},{name="SM_POI_Campsite",kind="Structure",cat="SW_POI",size={18.46,3.71,15.03},oo={0.07,-1.746,1.5705},parts={},r15=""},{name="SM_POI_Shed",kind="Structure",cat="SW_POI",size={9,7.83,6.96},oo={0,-3.8145,0},parts={},r15=""},{name="SM_POI_HuntingBlind",kind="Structure",cat="SW_POI",size={6.4,8.6,6.9},oo={0,-4.3,-0.25},parts={},r15=""},{name="SM_POI_BrokenVehicle",kind="Structure",cat="SW_POI",size={15.11,5.35,9.42},oo={-1.066,-2.6765,2.0705},parts={},r15=""},{name="SM_POI_SmallCabin",kind="Structure",cat="SW_POI",size={10.87,11.6,10.9},oo={0,-5.7,-0.95},parts={},r15=""},{name="SM_POI_Cabin",kind="Structure",cat="SW_POI",size={14.87,12.84,13.4},oo={0,-6.319,-1.2},parts={},r15=""},{name="SM_POI_RangerStation",kind="Structure",cat="SW_POI",size={15.56,12.84,22.1},oo={-0.3485,-6.319,2.35},parts={},r15=""},{name="SM_POI_LoggingCamp",kind="Structure",cat="SW_POI",size={19.11,9.42,24},oo={0.8795,-4.6095,5.5},parts={},r15=""},{name="SM_POI_AbandonedHouse",kind="Structure",cat="SW_POI",size={16.48,13.98,17.62},oo={-0.191,-6.889,2.31},parts={},r15=""},{name="SM_POI_MineEntrance",kind="Structure",cat="SW_POI",size={15.71,8.47,20.56},oo={0.138,-3.4155,-1.2195},parts={},r15=""},{name="SM_POI_Bunker",kind="Structure",cat="SW_POI",size={14.6,8.7,14.92},oo={0,-4.25,-1.1605},parts={},r15=""},{name="SM_POI_Outpost",kind="Structure",cat="SW_POI",size={26.56,9.36,20.6},oo={0,-4.518,3.25},parts={},r15=""},{name="SM_POI_IndustrialSite",kind="Structure",cat="SW_POI",size={34.93,10.6,22.5},oo={-0.4655,-5.3,-2.25},parts={},r15=""},{name="SM_POI_LargeMine",kind="Structure",cat="SW_POI",size={19.35,14.81,20.95},oo={-1.325,-6.174,-1.027},parts={},r15=""},{name="SM_Chest_Common",kind="Structure",cat="SW_Loot",size={3.4,2.4,2.47},oo={0,-1.2,0.0625},parts={},r15=""},{name="SM_Chest_Uncommon",kind="Structure",cat="SW_Loot",size={3.4,2.4,2.47},oo={0,-1.2,0.0625},parts={},r15=""},{name="SM_Chest_Rare",kind="Structure",cat="SW_Loot",size={3.4,2.4,2.53},oo={0,-1.2,0.09},parts={},r15=""},{name="SM_Chest_VeryRare",kind="Structure",cat="SW_Loot",size={3.4,2.4,2.53},oo={0,-1.2,0.09},parts={},r15=""},{name="SM_Pickaxe_Stone",kind="Equippable",cat="SW_Tools",size={0.47,3.61,2.2},oo={0,-1.103,0},parts={},r15=""},{name="SM_Pickaxe_Iron",kind="Equippable",cat="SW_Tools",size={0.31,3.61,2.62},oo={0,-1.103,0},parts={},r15=""},{name="SM_Axe_Iron",kind="Equippable",cat="SW_Tools",size={0.31,3.61,1.58},oo={0,-1.103,0.31},parts={},r15=""},{name="SM_Crowbar",kind="Equippable",cat="SW_Tools",size={0.14,3.5,0.88},oo={0,-0.634,0.166},parts={},r15=""},{name="SM_Sledgehammer",kind="Equippable",cat="SW_Tools",size={0.6,4.2,1.5},oo={0,-1.399,0},parts={},r15=""},{name="SM_HuntingBow",kind="Equippable",cat="SW_Tools",size={0.3,4.84,0.77},oo={0,0,-0.0855},parts={},r15=""},{name="SM_Crossbow",kind="Equippable",cat="SW_Tools",size={3.21,0.95,3.05},oo={0,-0.075,0.9235},parts={},r15=""},{name="SM_ReinforcedChest",kind="Structure",cat="SW_Base",size={6.2,4.3,4.3},oo={0,-2.15,0},parts={},r15=""},{name="SM_MetalLocker",kind="Structure",cat="SW_Base",size={4,7,3.2},oo={0,-3.5,0.1},parts={},r15=""},{name="SM_SurvivalSafe",kind="Structure",cat="SW_Base",size={4.5,5,4.8},oo={0,-2.5,0.15},parts={},r15=""},{name="SM_ScrapWall",kind="Structure",cat="SW_Base",size={10.46,10.4,1.35},oo={-0.0815,-5.2,0.325},parts={},r15=""},{name="SM_MetalWall",kind="Structure",cat="SW_Base",size={10.8,11,2.6},oo={0,-5.5,0},parts={},r15=""},{name="SM_WoodFloor",kind="Structure",cat="SW_Base",size={10,1,10.02},oo={0,-0.5,-0.01},parts={},r15=""},{name="SM_BearTrap",kind="Structure",cat="SW_Base",size={2.56,0.55,1.76},oo={0,-0.275,0},parts={},r15=""},{name="SM_Snare",kind="Structure",cat="SW_Base",size={3.14,3.25,2.46},oo={0.3095,-1.6035,0},parts={},r15=""},{name="SM_TripwireAlarm",kind="Structure",cat="SW_Base",size={7.91,1.4,0.53},oo={0.003,-0.7,-0.115},parts={},r15=""},{name="SM_Workbench_Level04",kind="Structure",cat="SW_Base",size={12.1,7.7,4},oo={2.05,-3.85,0},parts={},r15=""},{name="SM_Workbench_Level05",kind="Structure",cat="SW_Base",size={12.15,7.7,4.1},oo={2.025,-3.85,0},parts={},r15=""}}

-- Runs every skinned model builder against a mocked Roblox environment and a
-- fake mesh library generated from the pack catalog. Usage (project root):
--   luau tests/skins/run_skins.luau
-- Checks: meshes are added, procedural parts are hidden but keep collision,
-- state hooks (stump, yield, extinguish, damage, gate, parachute) work, held
-- items weld, and with the library disabled nothing changes.

local Mock = M
local Data = __LibraryData

Random = {
	new = function(seed)
		local s = seed or 1
		local function nxt()
			s = (s * 1103515245 + 12345) % 2147483648
			return s / 2147483648
		end
		return {
			NextNumber = function(_, a, b)
				a, b = a or 0, b or 1
				return a + (b - a) * nxt()
			end,
			NextInteger = function(_, a, b)
				return a + math.floor(nxt() * (b - a + 1))
			end,
		}
	end,
}

local RS = game:GetService("ReplicatedStorage")

-- fake library ----------------------------------------------------------------
local lib = Instance.new("Folder")
lib.Name = "SurvivalHourAssets"
lib.Parent = RS
local cats = {}
local function mesh(name, size, oo, at)
	local mp = Instance.new("MeshPart")
	mp.Name = name
	mp.Size = Vector3.new(size[1], size[2], size[3])
	mp.CFrame = at * CFrame.new(-oo[1], -oo[2], -oo[3])
	mp.PivotOffset = CFrame.new(oo[1], oo[2], oo[3])
	return mp
end
for _, e in Data do
	local cat = cats[e.cat]
	if not cat then
		cat = Instance.new("Folder")
		cat.Name = e.cat
		cat.Parent = lib
		cats[e.cat] = cat
	end
	if e.kind == "Equippable" then
		local t = Instance.new("Tool")
		t.Name = (string.gsub(e.name, "^SM_", ""))
		mesh("Handle", e.size, e.oo, CFrame.new()).Parent = t
		t.Grip = CFrame.new(e.oo[1], e.oo[2], e.oo[3])
		for _, p in e.parts do
			mesh(p.name, p.size, p.oo, CFrame.new(table.unpack(p.place))).Parent = t
		end
		t.Parent = cat
	elseif e.kind == "Accessory" then
		local a = Instance.new("Accessory")
		a.Name = (string.gsub(e.name, "^ACC_", ""))
		local h = mesh("Handle", e.size, e.oo, CFrame.new())
		h.Parent = a
		local att = Instance.new("Attachment")
		att.Name = e.r15
		att.CFrame = CFrame.new(e.oo[1], e.oo[2], e.oo[3])
		att.Parent = h
		a.Parent = cat
	else
		local m = Instance.new("Model")
		m.Name = e.name
		local mp = mesh(e.name, e.size, e.oo, CFrame.new())
		mp.Parent = m
		m.PrimaryPart = mp
		local col = Instance.new("Part")
		col.Name = "Collision1"
		col.Parent = m
		for _, p in e.parts do
			mesh(p.name, p.size, p.oo, CFrame.new(table.unpack(p.place))).Parent = m
		end
		m.Parent = cat
	end
end


local __m_Build = (function()
-- Small helpers for building models from Roblox primitives.

local Build = {}

export type PartProps = {
	Name: string?,
	Shape: Enum.PartType?,
	Class: string?, -- "Part" | "WedgePart" | "CornerWedgePart" | "TrussPart"
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3?,
	Material: Enum.Material?,
	Anchored: boolean?,
	CanCollide: boolean?,
	CanQuery: boolean?,
	CanTouch: boolean?,
	Transparency: number?,
	Reflectance: number?,
	CastShadow: boolean?,
	Parent: Instance?,
	Massless: boolean?,
}

function Build.Part(p: PartProps): BasePart
	local part = Instance.new((p.Class or "Part") :: any) :: BasePart
	if p.Shape and part:IsA("Part") then
		(part :: Part).Shape = p.Shape
	end
	part.Name = p.Name or "Part"
	part.Size = p.Size
	part.CFrame = p.CFrame
	part.Color = p.Color or Color3.fromRGB(160, 160, 160)
	part.Material = p.Material or Enum.Material.SmoothPlastic
	part.Anchored = if p.Anchored == nil then true else p.Anchored
	part.CanCollide = if p.CanCollide == nil then true else p.CanCollide
	part.CanQuery = if p.CanQuery == nil then true else p.CanQuery
	part.CanTouch = if p.CanTouch == nil then false else p.CanTouch
	part.Transparency = p.Transparency or 0
	part.Reflectance = p.Reflectance or 0
	part.CastShadow = if p.CastShadow == nil then true else p.CastShadow
	part.Massless = p.Massless == true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if p.Parent then
		part.Parent = p.Parent
	end
	return part
end

-- Decorative part: no collision/query/touch, no shadow cost for tiny bits.
function Build.Decor(p: PartProps): BasePart
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return Build.Part(p)
end

-- Cylinder whose axis points along +Y (Roblox cylinders run along X).
function Build.Cyl(name: string, height: number, diameter: number, cf: CFrame, color: Color3, material: Enum.Material, parent: Instance?, collide: boolean?): BasePart
	return Build.Part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = cf * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material,
		Parent = parent,
		CanCollide = if collide == nil then true else collide,
		CanQuery = if collide == false then false else true,
	})
end

function Build.Ball(name: string, diameter: number, cf: CFrame, color: Color3, material: Enum.Material, parent: Instance?, collide: boolean?): BasePart
	return Build.Part({
		Name = name,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(diameter, diameter, diameter),
		CFrame = cf,
		Color = color,
		Material = material,
		Parent = parent,
		CanCollide = collide == true,
		CanQuery = collide == true,
	})
end

function Build.Model(name: string, parent: Instance?): Model
	local m = Instance.new("Model")
	m.Name = name
	if parent then
		m.Parent = parent
	end
	return m
end

-- Sets a model's PrimaryPart and makes `pivot` (in the model's current frame)
-- its pivot. Assigning Model.WorldPivot has no effect once a PrimaryPart is
-- set (the pivot is PrimaryPart.CFrame * PivotOffset), which previously left
-- every model pivoting on its primary part's centre and half-buried.
function Build.SetPivot(model: Model, primary: BasePart, pivot: CFrame)
	model.PrimaryPart = primary
	primary.PivotOffset = primary.CFrame:ToObjectSpace(pivot)
end

-- Welds every BasePart in `model` to `root` (for unanchored assemblies).
function Build.WeldAll(model: Instance, root: BasePart)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = d
			w.Parent = d
		end
	end
end

function Build.SetAll(model: Instance, props: { [string]: any })
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			for k, v in props do
				(d :: any)[k] = v
			end
		end
	end
end

function Build.Tint(c: Color3, f: number): Color3
	return Color3.new(math.clamp(c.R * f, 0, 1), math.clamp(c.G * f, 0, 1), math.clamp(c.B * f, 0, 1))
end

-- A billboard label (used for names, prompts' context and landmarks).
function Build.Label(adornee: BasePart, text: string, offset: Vector3, color: Color3?, maxDistance: number?): BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Name = "Label"
	bb.Size = UDim2.fromOffset(200, 40)
	bb.StudsOffsetWorldSpace = offset
	bb.AlwaysOnTop = false
	bb.MaxDistance = maxDistance or 80
	bb.LightInfluence = 0
	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.fromScale(1, 1)
	tl.Font = Enum.Font.GothamBold
	tl.TextScaled = true
	tl.Text = text
	tl.TextColor3 = color or Color3.new(1, 1, 1)
	tl.TextStrokeTransparency = 0.4
	tl.Parent = bb
	bb.Adornee = adornee
	bb.Parent = adornee
	return bb
end

return Build

end)()
local __m_Skins = (function()
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
local version: any = nil

local function library(): boolean
	-- AssetLoaderService bumps AssetsVersion as uploaded meshes arrive: re-index then.
	local v = ReplicatedStorage:GetAttribute("AssetsVersion")
	if v ~= version then
		version = v
		looked = false
	end
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
				d:SetAttribute("SkinT", d.Transparency)
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

-- Removes every mesh skin and shows the procedural parts again (for variants whose
-- shape no longer matches the pack mesh, e.g. a wall with a window cut in it).
function Skins.Unskin(target: Instance)
	Skins.Strip(target)
	for _, d in target:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("SkinHidden") then
			d.Transparency = d:GetAttribute("SkinT") or 0
			d.CastShadow = true
			d:SetAttribute("SkinHidden", nil)
			for _, g in d:GetChildren() do
				if g:IsA("SurfaceGui") then
					g.Enabled = true
				elseif g:IsA("Decal") or g:IsA("Texture") then
					(g :: any).Transparency = 0
				end
			end
		end
	end
	if target:IsA("Model") then
		target:SetAttribute("SkinName", nil)
		target:SetAttribute("SkinBase", nil)
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

end)()
local __m_Nature = (function()
-- Forest models built from primitives. Every model is built around the origin
-- with its pivot at ground level, then moved with PivotTo.

local Build = __m_Build
local Skins = __m_Skins

local Nature = {}

-- Mesh-pack look (see Skins.luau): pick a variant by position and size it to
-- roughly match the procedural silhouette it replaces.
local function skinHeight(m: Model, names: { string }, height: number, opts: Skins.Opts?)
	if not Skins.Enabled() then
		return
	end
	local name = Skins.Pick(names, m:GetPivot())
	local o = opts or {}
	o.scale = height / Skins.Height(name)
	Skins.Dress(m, name, o)
end

local function skinWidth(m: Model, names: { string }, width: number, opts: Skins.Opts?)
	if not Skins.Enabled() then
		return
	end
	local name = Skins.Pick(names, m:GetPivot())
	local o = opts or {}
	o.scale = width / Skins.Width(name)
	Skins.Dress(m, name, o)
end

local BARK = Color3.fromRGB(94, 66, 44)
local BARK_LIGHT = Color3.fromRGB(122, 90, 62)
local BIRCH = Color3.fromRGB(226, 222, 206)
local PINE = Color3.fromRGB(46, 96, 58)
local PINE_DARK = Color3.fromRGB(34, 74, 46)
local LEAF = Color3.fromRGB(78, 132, 62)
local LEAF_LIGHT = Color3.fromRGB(112, 160, 72)
local ROCK = Color3.fromRGB(118, 120, 124)
local ROCK_DARK = Color3.fromRGB(92, 94, 100)
local MOSS = Color3.fromRGB(84, 118, 64)

local function finish(m: Model, primary: BasePart, cf: CFrame, parent: Instance?): Model
	Build.SetPivot(m, primary, CFrame.new(primary.Position.X, 0, primary.Position.Z))
	m:PivotTo(cf)
	if parent then
		m.Parent = parent
	end
	return m
end

-- Tall pine built from tiered discs so it reads as a conifer silhouette.
function Nature.Pine(cf: CFrame, scale: number, parent: Instance?): Model
	local m = Build.Model("Pine")
	local s = scale
	local trunk = Build.Cyl("Trunk", 30 * s, 2.4 * s, CFrame.new(0, 15 * s, 0), BARK, Enum.Material.Wood, m)
	local tiers = 4
	for i = 1, tiers do
		local t = (i - 1) / (tiers - 1)
		local d = (15 - 10 * t) * s
		local y = (10 + 4.6 * (i - 1)) * s
		local disc = Build.Cyl("Needles", 3.4 * s, d, CFrame.new(0, y, 0) * CFrame.Angles(0, math.rad(i * 37), 0),
			if i % 2 == 0 then PINE else PINE_DARK, Enum.Material.Grass, m, false)
		disc.CastShadow = true

	end
	Build.Ball("Tip", 3 * s, CFrame.new(0, (10 + 4.6 * tiers) * s, 0), PINE, Enum.Material.Grass, m)
	finish(m, trunk, cf, parent)
	skinHeight(m, { "SM_Tree_Pine_Medium01", "SM_Tree_Pine_Medium02", "SM_Tree_Pine_Large01" }, 30 * s)
	return m
end

function Nature.Oak(cf: CFrame, scale: number, parent: Instance?): Model
	local m = Build.Model("Oak")
	local s = scale
	local trunk = Build.Cyl("Trunk", 16 * s, 3.2 * s, CFrame.new(0, 8 * s, 0), BARK_LIGHT, Enum.Material.Wood, m)
	-- two limbs
	Build.Cyl("Limb", 8 * s, 1.4 * s, CFrame.new(2.2 * s, 15 * s, 0) * CFrame.Angles(0, 0, math.rad(-35)), BARK_LIGHT, Enum.Material.Wood, m, false)
	Build.Cyl("Limb", 7 * s, 1.2 * s, CFrame.new(-2 * s, 14 * s, 1 * s) * CFrame.Angles(math.rad(20), 0, math.rad(30)), BARK_LIGHT, Enum.Material.Wood, m, false)
	local blobs = {
		{ 0, 22, 0, 14 }, { 5, 19, 2, 10 }, { -5, 19, -2, 10 }, { 2, 18, -5, 9 }, { -2, 20, 5, 9 },
	}
	for i, b in blobs do
		Build.Ball("Canopy", b[4] * s, CFrame.new(b[1] * s, b[2] * s, b[3] * s), if i % 2 == 0 then LEAF else LEAF_LIGHT, Enum.Material.LeafyGrass, m)
	end
	finish(m, trunk, cf, parent)
	skinHeight(m, { "SM_Tree_Oak_Medium01", "SM_Tree_Oak_Medium02", "SM_Tree_Oak_Large01" }, 28 * s)
	return m
end

function Nature.Birch(cf: CFrame, scale: number, parent: Instance?): Model
	local m = Build.Model("Birch")
	local s = scale
	local trunk = Build.Cyl("Trunk", 24 * s, 1.6 * s, CFrame.new(0, 12 * s, 0), BIRCH, Enum.Material.SmoothPlastic, m)
	-- bark marks
	for i = 1, 3 do
		Build.Decor({ Name = "Mark", Size = Vector3.new(0.3, 0.4 * s, 1.0 * s), CFrame = CFrame.new(0, (3 + i * 3.8) * s, 0) * CFrame.Angles(0, math.rad(i * 70), 0) * CFrame.new(0.72 * s, 0, 0), Color = Color3.fromRGB(50, 46, 42), Material = Enum.Material.SmoothPlastic, Parent = m, CastShadow = false })
	end
	for i, b in { { 0, 23, 0, 9 }, { 2.5, 20, 1, 7 }, { -2.5, 19, -1, 7 } } do
		Build.Ball("Canopy", b[4] * s, CFrame.new(b[1] * s, b[2] * s, b[3] * s), if i == 1 then Color3.fromRGB(150, 180, 80) else Color3.fromRGB(128, 168, 74), Enum.Material.LeafyGrass, m)
	end
	finish(m, trunk, cf, parent)
	skinHeight(m, { "SM_Tree_Birch_Medium01" }, 27 * s)
	return m
end

-- Choppable small tree (wood node). `Stage` attribute switches between full and stump.
function Nature.SmallTree(cf: CFrame, parent: Instance?): Model
	local m = Build.Model("SmallTree")
	local trunk = Build.Cyl("Trunk", 10, 1.5, CFrame.new(0, 5, 0), BARK, Enum.Material.Wood, m)
	local stump = Build.Cyl("Stump", 1.4, 1.7, CFrame.new(0, 0.7, 0), BARK_LIGHT, Enum.Material.Wood, m)
	stump.Transparency = 1
	stump.CanCollide = false
	local c1 = Build.Ball("Leaves", 7, CFrame.new(0, 10.5, 0), LEAF, Enum.Material.LeafyGrass, m)
	local c2 = Build.Ball("Leaves", 5, CFrame.new(1.4, 8.6, 0.8), LEAF_LIGHT, Enum.Material.LeafyGrass, m)
	c1:SetAttribute("Canopy", true)
	c2:SetAttribute("Canopy", true)
	trunk:SetAttribute("Canopy", true)
	-- Notch marks that show chopping progress
	local notch = Build.Decor({ Name = "Notch", Size = Vector3.new(0.4, 0.8, 1.2), CFrame = CFrame.new(0.7, 2.5, 0), Color = Color3.fromRGB(214, 180, 130), Material = Enum.Material.Wood, Parent = m, CastShadow = false })
	notch.Transparency = 1
	return finish(m, trunk, cf, parent)
end

function Nature.SetSmallTreeStage(m: Model, stage: string)
	local full = stage == "Full"
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			if d:GetAttribute("Canopy") then
				d.Transparency = if full then 0 else 1
				d.CanCollide = full and d.Name == "Trunk"
				d.CanQuery = full
			elseif d.Name == "Stump" then
				d.Transparency = if full then 1 else 0
				d.CanCollide = not full
			end
		end
	end
end

function Nature.Bush(cf: CFrame, scale: number, parent: Instance?): Model
	local m = Build.Model("Bush")
	local s = scale
	local main = Build.Ball("Bush", 4.5 * s, CFrame.new(0, 1.6 * s, 0), LEAF, Enum.Material.LeafyGrass, m)
	Build.Ball("Bush", 3.4 * s, CFrame.new(1.8 * s, 1.2 * s, 0.6 * s), LEAF_LIGHT, Enum.Material.LeafyGrass, m)
	Build.Ball("Bush", 3 * s, CFrame.new(-1.6 * s, 1.1 * s, -0.8 * s), PINE, Enum.Material.LeafyGrass, m)
	for _, d in m:GetChildren() do
		(d :: BasePart).CastShadow = false
	end
	finish(m, main, cf, parent)
	skinWidth(m, { "SM_Bush01", "SM_Bush02", "SM_Bush03_Berry" }, 7 * s)
	return m
end

-- Plant fibre node: a fern cluster with pale fronds.
function Nature.Fern(cf: CFrame, parent: Instance?): Model
	local m = Build.Model("Fern")
	local base = Build.Decor({ Name = "Base", Size = Vector3.new(2, 0.6, 2), CFrame = CFrame.new(0, 0.3, 0), Color = Color3.fromRGB(70, 110, 50), Material = Enum.Material.Grass, Parent = m })
	base.CanQuery = true
	for i = 0, 6 do
		local a = math.rad(i * (360 / 7))
		Build.Decor({
			Name = "Frond",
			Class = "WedgePart",
			Size = Vector3.new(0.3, 3.2, 1.3),
			CFrame = CFrame.Angles(0, a, 0) * CFrame.new(0, 1.5, 1.2) * CFrame.Angles(math.rad(35), 0, 0),
			Color = if i % 2 == 0 then Color3.fromRGB(120, 176, 84) else Color3.fromRGB(96, 150, 70),
			Material = Enum.Material.Grass,
			Parent = m,
			CastShadow = false,
		})
	end
	-- flower buds that disappear when picked
	for i = 0, 2 do
		local a = math.rad(i * 120 + 20)
		local b = Build.Ball("Bud", 0.6, CFrame.Angles(0, a, 0) * CFrame.new(0, 2.4, 0.9), Color3.fromRGB(236, 214, 120), Enum.Material.SmoothPlastic, m)
		b.CastShadow = false
	end
	return finish(m, base, cf, parent)
end

function Nature.TwigPile(cf: CFrame, parent: Instance?): Model
	local m = Build.Model("TwigPile")
	local base = Build.Decor({ Name = "Base", Size = Vector3.new(3, 0.3, 3), CFrame = CFrame.new(0, 0.15, 0), Color = Color3.fromRGB(96, 76, 52), Material = Enum.Material.Ground, Parent = m })
	base.CanQuery = true
	for i = 0, 6 do
		local a = math.rad(i * 53)
		Build.Decor({
			Name = "Twig",
			Size = Vector3.new(3.2, 0.3, 0.3),
			CFrame = CFrame.new(0, 0.4 + (i % 3) * 0.22, 0) * CFrame.Angles(0, a, math.rad((i % 2) * 8)),
			Color = if i % 2 == 0 then BARK_LIGHT else BARK,
			Material = Enum.Material.Wood,
			Parent = m,
			CastShadow = false,
		})
	end
	return finish(m, base, cf, parent)
end

function Nature.RockPile(cf: CFrame, parent: Instance?): Model
	local m = Build.Model("RockPile")
	local base = Build.Part({ Name = "Base", Size = Vector3.new(2.6, 1.4, 2.2), CFrame = CFrame.new(0, 0.6, 0) * CFrame.Angles(0.2, 0.5, 0.1), Color = ROCK, Material = Enum.Material.Slate, Parent = m })
	Build.Part({ Name = "Chunk", Size = Vector3.new(1.4, 1, 1.4), CFrame = CFrame.new(1.4, 0.5, 0.6) * CFrame.Angles(0.3, 1.1, 0.2), Color = ROCK_DARK, Material = Enum.Material.Slate, Parent = m, CanCollide = false })
	Build.Part({ Name = "Chunk", Size = Vector3.new(1.1, 0.8, 1.2), CFrame = CFrame.new(-1.2, 0.4, -0.7) * CFrame.Angles(0.1, 0.4, 0.4), Color = ROCK, Material = Enum.Material.Slate, Parent = m, CanCollide = false })
	return finish(m, base, cf, parent)
end

function Nature.BigRock(cf: CFrame, scale: number, parent: Instance?): Model
	local m = Build.Model("BigRock")
	local s = scale
	local main = Build.Part({ Name = "Rock", Size = Vector3.new(8, 5.5, 7) * s, CFrame = CFrame.new(0, 2.2 * s, 0) * CFrame.Angles(0.15, 0.3, 0.08), Color = ROCK, Material = Enum.Material.Rock, Parent = m })
	Build.Part({ Name = "Rock", Size = Vector3.new(5, 4, 5) * s, CFrame = CFrame.new(3 * s, 1.6 * s, 2 * s) * CFrame.Angles(0.3, 0.9, 0.2), Color = ROCK_DARK, Material = Enum.Material.Rock, Parent = m })
	Build.Part({ Class = "WedgePart", Name = "Rock", Size = Vector3.new(4, 3, 5) * s, CFrame = CFrame.new(-3.5 * s, 1.2 * s, -1 * s) * CFrame.Angles(0, math.rad(80), 0), Color = ROCK, Material = Enum.Material.Rock, Parent = m })
	Build.Decor({ Name = "Moss", Size = Vector3.new(6, 0.5, 5) * s, CFrame = CFrame.new(0, 5 * s, 0) * CFrame.Angles(0.15, 0.3, 0.08), Color = MOSS, Material = Enum.Material.Grass, Parent = m, CastShadow = false })
	finish(m, main, cf, parent)
	skinWidth(m, { "SM_Boulder01", "SM_Boulder02", "SM_Boulder03" }, 10 * s)
	return m
end

function Nature.StandingStone(cf: CFrame, parent: Instance?): Model
	local m = Build.Model("StandingStone")
	local main = Build.Part({ Name = "Stone", Size = Vector3.new(3.5, 12, 2.2), CFrame = CFrame.new(0, 5.5, 0) * CFrame.Angles(0.05, 0, 0.04), Color = Color3.fromRGB(128, 126, 120), Material = Enum.Material.Slate, Parent = m })
	Build.Decor({ Name = "Rune", Size = Vector3.new(1.4, 1.4, 0.15), CFrame = CFrame.new(0, 7, -1.12) * CFrame.Angles(0, 0, math.rad(45)), Color = Color3.fromRGB(120, 200, 190), Material = Enum.Material.Neon, Parent = m, CastShadow = false })
	Build.Decor({ Name = "Moss", Size = Vector3.new(3.7, 0.4, 2.4), CFrame = CFrame.new(0, 11.4, 0), Color = MOSS, Material = Enum.Material.Grass, Parent = m })
	return finish(m, main, cf, parent)
end

function Nature.FallenGiant(cf: CFrame, parent: Instance?): Model
	local m = Build.Model("FallenGiant")
	local log = Build.Cyl("Log", 24, 4.5, CFrame.new(0, 2, 0) * CFrame.Angles(math.rad(90), 0, 0), BARK, Enum.Material.Wood, m)
	Build.Cyl("Ring", 0.4, 4.2, CFrame.new(0, 2, 12.1) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(200, 164, 118), Enum.Material.Wood, m, false)
	Build.Cyl("Stump", 5, 5.5, CFrame.new(0, 2.5, -15), BARK, Enum.Material.Wood, m)
	for i = 1, 4 do
		Build.Decor({ Name = "Moss", Size = Vector3.new(3, 0.6, 3), CFrame = CFrame.new(0, 4.2, -9 + i * 4.5), Color = MOSS, Material = Enum.Material.Grass, Parent = m })
	end
	for i = 1, 3 do
		Build.Ball("Mushroom", 1.2, CFrame.new(2.3, 1 + i * 0.6, -6 + i * 5), Color3.fromRGB(220, 90, 70), Enum.Material.SmoothPlastic, m)
	end
	finish(m, log, cf, parent)
	-- the pack's giant log runs along X; this one runs along Z
	if Skins.Enabled() then
		Skins.Dress(m, "SM_Landmark_GiantLog", { scale = 1.1, offset = CFrame.Angles(0, math.rad(90), 0) })
	end
	return m
end

function Nature.Ruins(cf: CFrame, parent: Instance?): Model
	local m = Build.Model("Ruins")
	local STONE = Color3.fromRGB(150, 146, 136)
	local floor = Build.Part({ Name = "Floor", Size = Vector3.new(22, 0.8, 16), CFrame = CFrame.new(0, 0.2, 0), Color = Color3.fromRGB(120, 116, 108), Material = Enum.Material.Cobblestone, Parent = m })
	-- two broken wall stubs + columns
	Build.Part({ Name = "Wall", Size = Vector3.new(1.6, 7, 9), CFrame = CFrame.new(7, 3.5, -2), Color = STONE, Material = Enum.Material.Brick, Parent = m })
	Build.Part({ Class = "WedgePart", Name = "Wall", Size = Vector3.new(1.6, 4, 5), CFrame = CFrame.new(7, 9, -4.5), Color = STONE, Material = Enum.Material.Brick, Parent = m })
	Build.Part({ Name = "Wall", Size = Vector3.new(1.6, 5, 7), CFrame = CFrame.new(-7, 2.5, 3), Color = STONE, Material = Enum.Material.Brick, Parent = m })
	for i, x in { -9, -3, 3, 9 } do
		local h = if i % 2 == 0 then 10 else 6
		Build.Cyl("Column", h, 2, CFrame.new(x, h / 2, 7), STONE, Enum.Material.Marble, m)
	end
	Build.Part({ Name = "Lintel", Size = Vector3.new(8, 1.2, 2.2), CFrame = CFrame.new(-3, 10.6, 7) * CFrame.Angles(0, 0, math.rad(-6)), Color = STONE, Material = Enum.Material.Marble, Parent = m })
	for i = 1, 5 do
		Build.Part({ Name = "Rubble", Size = Vector3.new(1.5, 1, 1.2), CFrame = CFrame.new(-4 + i * 2, 0.9, -5 + (i % 2) * 2) * CFrame.Angles(0.3 * i, i, 0.2), Color = STONE, Material = Enum.Material.Slate, Parent = m, CanCollide = false })
	end
	return finish(m, floor, cf, parent)
end

-- Tall grass clumps for thickets (non-colliding; slows movement via server zone).
function Nature.GrassClump(cf: CFrame, parent: Instance?): Model
	local m = Build.Model("Grass")
	local base = Build.Decor({ Name = "Base", Size = Vector3.new(1, 0.2, 1), CFrame = CFrame.new(0, 0.1, 0), Color = LEAF, Material = Enum.Material.Grass, Parent = m, CastShadow = false })
	for i = 0, 4 do
		Build.Decor({ Name = "Blade", Class = "WedgePart", Size = Vector3.new(0.2, 4.5, 1), CFrame = CFrame.Angles(0, math.rad(i * 72), 0) * CFrame.new(0, 2.2, 0.4) * CFrame.Angles(math.rad(10), 0, 0), Color = if i % 2 == 0 then Color3.fromRGB(130, 170, 80) else Color3.fromRGB(104, 146, 66), Material = Enum.Material.Grass, Parent = m, CastShadow = false })
	end
	finish(m, base, cf, parent)
	skinHeight(m, { "SM_Grass_Clump03", "SM_Grass_Clump01", "SM_Fern01" }, 4)
	return m
end

function Nature.Flower(cf: CFrame, color: Color3, parent: Instance?): Model
	local m = Build.Model("Flower")
	local stem = Build.Decor({ Name = "Stem", Size = Vector3.new(0.2, 1.4, 0.2), CFrame = CFrame.new(0, 0.7, 0), Color = LEAF, Material = Enum.Material.Grass, Parent = m, CastShadow = false })
	local head = Build.Ball("Head", 0.8, CFrame.new(0, 1.5, 0), color, Enum.Material.SmoothPlastic, m)
	head.CastShadow = false
	return finish(m, stem, cf, parent)
end

return Nature

end)()
local __m_Flora = (function()
-- Flora: procedural vegetation and rock models for SURVIVAL WARS, built only
-- from Roblox primitives (no asset ids, no MeshParts).
--
-- Contract (see docs/OVERHAUL.md):
--  * Every builder is `(cf, rng, [extra args], parent?) -> Model`.
--  * Models are built around the origin with the pivot at ground centre (y = 0),
--    finished with Build.SetPivot(m, primary, CFrame.new()) then m:PivotTo(cf).
--  * All variation (variant, scale jitter, colour jitter) comes from `rng`.
--  * Resource models expose the part roles Root / Top / Stump / Notch / Yield.
--  * Only trunks, stumps, logs and rocks collide; everything else is Decor.
--  * Parts smaller than 1.5 studs never cast shadows.

local Build = __m_Build
local Skins = __m_Skins

local Flora = {}

local M = Enum.Material
local TAU = math.pi * 2

--------------------------------------------------------------------------------
-- Palettes
--------------------------------------------------------------------------------

local BARK = Color3.fromRGB(92, 66, 46)
local BARK_DARK = Color3.fromRGB(70, 50, 36)
local BARK_PINE = Color3.fromRGB(108, 70, 48)
local BARK_OAK = Color3.fromRGB(104, 84, 64)
local BARK_GREY = Color3.fromRGB(124, 120, 112)
local BIRCH_BARK = Color3.fromRGB(226, 222, 208)
local ASPEN_BARK = Color3.fromRGB(204, 208, 190)
local BARK_MARK = Color3.fromRGB(46, 42, 38)
local CUT_WOOD = Color3.fromRGB(214, 180, 130)

local NEEDLE = { Color3.fromRGB(30, 66, 42), Color3.fromRGB(40, 84, 50), Color3.fromRGB(54, 102, 58) }
local SPRUCE = { Color3.fromRGB(26, 58, 44), Color3.fromRGB(34, 70, 52), Color3.fromRGB(44, 82, 60) }
local SPRUCE_BLUE = { Color3.fromRGB(56, 88, 86), Color3.fromRGB(70, 104, 102), Color3.fromRGB(84, 116, 112) }
local LEAF = { Color3.fromRGB(56, 104, 46), Color3.fromRGB(78, 132, 56), Color3.fromRGB(106, 154, 64) }
local LEAF_DEEP = { Color3.fromRGB(44, 86, 42), Color3.fromRGB(60, 108, 48), Color3.fromRGB(82, 128, 54) }
local BIRCH_LEAF = { Color3.fromRGB(112, 156, 62), Color3.fromRGB(138, 176, 74), Color3.fromRGB(162, 190, 86) }
local ASPEN_LEAF = { Color3.fromRGB(128, 168, 66), Color3.fromRGB(156, 182, 72), Color3.fromRGB(178, 190, 80) }
local ASPEN_GOLD = { Color3.fromRGB(214, 186, 70), Color3.fromRGB(226, 168, 58), Color3.fromRGB(196, 194, 84) }
local BUSH = { Color3.fromRGB(50, 96, 46), Color3.fromRGB(70, 120, 52), Color3.fromRGB(94, 140, 60) }
local GRASS = { Color3.fromRGB(84, 138, 58), Color3.fromRGB(106, 158, 66), Color3.fromRGB(128, 168, 74) }
local GRASS_DRY = { Color3.fromRGB(150, 156, 82), Color3.fromRGB(172, 162, 92), Color3.fromRGB(128, 146, 72) }
local FERN = { Color3.fromRGB(88, 146, 62), Color3.fromRGB(106, 162, 70), Color3.fromRGB(72, 128, 54) }
local MOSS = { Color3.fromRGB(74, 112, 54), Color3.fromRGB(92, 128, 60), Color3.fromRGB(62, 98, 50) }
local LITTER = { Color3.fromRGB(150, 92, 44), Color3.fromRGB(176, 124, 52), Color3.fromRGB(124, 76, 42), Color3.fromRGB(162, 146, 70) }
local ROCK = { Color3.fromRGB(112, 114, 118), Color3.fromRGB(126, 124, 120), Color3.fromRGB(96, 98, 104) }
local ROCK_WARM = { Color3.fromRGB(122, 114, 104), Color3.fromRGB(106, 100, 94), Color3.fromRGB(136, 130, 120) }
local DIRT = Color3.fromRGB(92, 72, 52)
local FLOWER = {
	Color3.fromRGB(236, 90, 110),
	Color3.fromRGB(246, 214, 90),
	Color3.fromRGB(172, 120, 232),
	Color3.fromRGB(244, 244, 240),
	Color3.fromRGB(120, 170, 245),
	Color3.fromRGB(246, 150, 70),
}
local BERRY = { Color3.fromRGB(200, 34, 48), Color3.fromRGB(110, 40, 124), Color3.fromRGB(56, 72, 170) }
local CAP_RED = Color3.fromRGB(196, 44, 38)
local CAP_BROWN = Color3.fromRGB(146, 100, 62)
local CAP_TAN = Color3.fromRGB(196, 164, 116)
local STEM = Color3.fromRGB(234, 226, 206)
local WATER = Color3.fromRGB(150, 204, 236)

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function pick(rng: Random, list)
	return list[rng:NextInteger(1, #list)]
end

-- Colour with +-amt brightness jitter.
local function vary(rng: Random, c: Color3, amt: number?): Color3
	local a = amt or 0.08
	return Build.Tint(c, 1 + rng:NextNumber(-a, a))
end

-- Random palette entry with brightness jitter.
local function shade(rng: Random, list, amt: number?): Color3
	return vary(rng, pick(rng, list), amt)
end

local function spin(rng: Random): CFrame
	return CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
end

-- Rotation-only frame (for cylinders) whose Y axis runs from `a` to `b`.
local function segment(a: Vector3, b: Vector3): (CFrame, number)
	local dir = b - a
	local len = dir.Magnitude
	local mid = (a + b) / 2
	local up = if math.abs(dir.Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	return CFrame.lookAt(mid, b, up) * CFrame.Angles(-math.pi / 2, 0, 0), len
end

-- Cylinder from point a to point b.
local function limb(name: string, a: Vector3, b: Vector3, d: number, color: Color3, mat: Enum.Material, parent: Instance, collide: boolean?): BasePart
	local cf, len = segment(a, b)
	return Build.Cyl(name, len, d, cf, color, mat, parent, collide == true)
end

-- Decorative block/wedge.
local function block(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, parent: Instance, class: string?): BasePart
	return Build.Decor({ Name = name, Class = class, Size = size, CFrame = cf, Color = color, Material = mat, Parent = parent })
end

-- Colliding block/wedge (rocks, logs).
local function solid(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, parent: Instance, class: string?): BasePart
	return Build.Part({ Name = name, Class = class, Size = size, CFrame = cf, Color = color, Material = mat, Parent = parent })
end

local function markYield(p: BasePart): BasePart
	p:SetAttribute("Yield", true)
	return p
end

-- Invisible, queryable, non-colliding footprint part (resource PrimaryPart).
local function makeRoot(m: Model, w: number, h: number, depth: number?): BasePart
	return Build.Part({
		Name = "Root",
		Size = Vector3.new(w, h, depth or w),
		CFrame = CFrame.new(0, h / 2, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = true,
		CanTouch = false,
		CastShadow = false,
		Parent = m,
	})
end

-- Shadow pass, pivot at ground centre, move and parent.
local function finish(m: Model, primary: BasePart, cf: CFrame, parent: Instance?, noShadow: boolean?): Model
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local s = d.Size
			if noShadow or math.max(s.X, s.Y, s.Z) < 1.5 then
				d.CastShadow = false
			end
		end
	end
	Build.SetPivot(m, primary, CFrame.new())
	m:PivotTo(cf)
	if parent then
		m.Parent = parent
	end
	return m
end

-- Stack of needle tiers (cylinders of decreasing diameter) along `axis`
-- (a rotation-only CFrame). `drift` pushes upper tiers sideways (wind).
local function tierStack(parent: Instance, rng: Random, axis: CFrame, y0: number, y1: number, n: number, d0: number, d1: number, thick: number, palette, drift: Vector3?, jitter: number)
	for i = 1, n do
		local t = if n <= 1 then 0 else (i - 1) / (n - 1)
		local y = y0 + (y1 - y0) * t
		local d = (d0 + (d1 - d0) * t) * rng:NextNumber(0.9, 1.08)
		local pos = axis * Vector3.new(0, y, 0)
		if drift then
			pos += drift * t
		end
		pos += Vector3.new(rng:NextNumber(-jitter, jitter), 0, rng:NextNumber(-jitter, jitter))
		local tilt = CFrame.Angles(rng:NextNumber(-0.07, 0.07), rng:NextNumber(0, TAU), rng:NextNumber(-0.07, 0.07))
		Build.Cyl("Needles", thick * rng:NextNumber(0.88, 1.1), d, CFrame.new(pos) * tilt, shade(rng, palette, 0.06), M.Grass, parent, false)
	end
end

-- Lush broadleaf crown: one core ball plus `n - 1` overlapping blobs around it.
local function crown(parent: Instance, rng: Random, center: Vector3, r: number, n: number, palette, squash: number?)
	local sq = squash or 0.45
	Build.Ball("Canopy", r * 2 * rng:NextNumber(0.9, 1.05), CFrame.new(center + Vector3.new(0, r * 0.1, 0)), shade(rng, palette, 0.05), M.LeafyGrass, parent)
	local a0 = rng:NextNumber(0, TAU)
	for i = 2, n do
		local a = a0 + (i - 2) * TAU / math.max(1, n - 1) + rng:NextNumber(-0.4, 0.4)
		local dist = r * rng:NextNumber(0.55, 0.85)
		local off = Vector3.new(math.cos(a) * dist, r * rng:NextNumber(-sq, sq * 0.6), math.sin(a) * dist)
		Build.Ball("Canopy", r * rng:NextNumber(1.0, 1.4), CFrame.new(center + off), shade(rng, palette, 0.06), M.LeafyGrass, parent)
	end
end

-- Dark bark marks on a birch/aspen trunk (thin decor slivers).
local function barkMarks(parent: Instance, rng: Random, base: CFrame, radius: number, y0: number, y1: number, n: number)
	for i = 1, n do
		local y = y0 + (y1 - y0) * (i - 0.5) / n + rng:NextNumber(-0.5, 0.5)
		block("Mark", Vector3.new(0.2, rng:NextNumber(0.25, 0.45), radius * rng:NextNumber(0.7, 1.1)),
			base * CFrame.new(0, y, 0) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0) * CFrame.new(radius * 0.94, 0, 0),
			BARK_MARK, M.SmoothPlastic, parent)
	end
end

-- Chop notches just above the hinge (hidden until the tree is Damaged).
local function addNotches(m: Model, rng: Random, hingeY: number, d: number)
	local a = rng:NextNumber(0, TAU)
	for i = 0, 1 do
		local n = block("Notch", Vector3.new(0.4, 0.75, d * 0.6),
			CFrame.new(0, hingeY + 0.4 + i * 0.2, 0) * CFrame.Angles(0, a + i * (math.pi * 0.85), 0) * CFrame.new(d * 0.4, 0, 0),
			CUT_WOOD, M.Wood, m)
		n.Transparency = 1
	end
end

local function newScale(rng: Random, scale: number?): number
	return (scale or 1) * rng:NextNumber(0.88, 1.12)
end


--------------------------------------------------------------------------------
-- Mesh-pack skins for resource nodes (see Skins.luau). The procedural parts stay
-- as invisible colliders/yield markers; meshes follow the same state rules:
--   * trees: mesh inside Top (falls with it), stump mesh tagged SkinStump
--   * harvest nodes: full mesh tagged Yield, depleted mesh always visible
--------------------------------------------------------------------------------

local TREE_SKINS = {
	Pine = { Small = "SM_Tree_Pine_Small01", Medium = "SM_Tree_Pine_Medium01", Large = "SM_Tree_Pine_Large01" },
	Oak = { Small = "SM_Tree_Oak_Small01", Medium = "SM_Tree_Oak_Medium01", Large = "SM_Tree_Oak_Large01" },
	Birch = { Small = "SM_Tree_Birch_Small01", Medium = "SM_Tree_Birch_Medium01", Large = "SM_Tree_Birch_Medium01" },
}
local STUMP_SKINS = { Pine = "SM_Tree_Pine_Small01_Stump", Oak = "SM_Tree_Oak_Small01_Stump", Birch = "SM_Tree_Birch_Small01_Stump", Dead = "SM_Stump_Old02" }

local function skinTree(m: Model, top: Model, treeName: string, stumpName: string, height: number)
	if not Skins.Enabled() then
		return
	end
	local k = height / Skins.Height(treeName)
	Skins.Hide(m)
	Skins.Dress(m, treeName, { scale = k, parent = top, noHide = true })
	-- stump mesh: hidden while the tree stands, shown once it is felled
	Skins.Dress(m, stumpName, { scale = math.max(0.8, k), noHide = true, transparency = 1, attrs = { SkinStump = true } })
end

local function skinHarvest(m: Model, full: string, depleted: string?, scale: number, keep: { [string]: boolean }?)
	if not Skins.Enabled() then
		return
	end
	Skins.Hide(m, keep)
	Skins.Dress(m, full, { scale = scale, noHide = true, attrs = { Yield = true } })
	if depleted then
		Skins.Dress(m, depleted, { scale = scale, noHide = true })
	end
end

--------------------------------------------------------------------------------
-- Resource models
--------------------------------------------------------------------------------

local TREE_SIZES = {
	Small = { h0 = 10, h1 = 14, d = 1.4, g0 = 0.9, g1 = 1.1 },
	Medium = { h0 = 18, h1 = 24, d = 2.2, g0 = 1.1, g1 = 1.3 },
	Large = { h0 = 28, h1 = 36, d = 3.2, g0 = 1.3, g1 = 1.5 },
}

--- Choppable tree. `size` "Small"|"Medium"|"Large", `species` "Pine"|"Oak"|"Birch".
--- Roles: Root (PrimaryPart), Stump, 2x Notch, Top (Model, pivot at hinge) with
--- a colliding Trunk plus decor canopy. Attributes: HingeY, TreeSize, Species.
--- Parts: Pine <= 12, Oak <= 13, Birch <= 12.
function Flora.ResourceTree(cf: CFrame, rng: Random, size: string, species: string, parent: Instance?): Model
	local spec = TREE_SIZES[size] or TREE_SIZES.Medium
	local sp = if species == "Oak" or species == "Birch" then species else "Pine"
	local tier = if size == "Small" then 1 elseif size == "Large" then 3 else 2
	local H = rng:NextNumber(spec.h0, spec.h1)
	local d = spec.d * rng:NextNumber(0.94, 1.06)
	local hingeY = rng:NextNumber(spec.g0, spec.g1)

	local m = Build.Model(sp .. "Tree")
	m:SetAttribute("HingeY", hingeY)
	m:SetAttribute("TreeSize", size)
	m:SetAttribute("Species", sp)

	local root = makeRoot(m, d + 1, hingeY + 3) -- 1
	local barkBase = if sp == "Birch" then BIRCH_BARK elseif sp == "Oak" then BARK_OAK else BARK_PINE
	local bark = vary(rng, barkBase, 0.06)
	Build.Cyl("Stump", hingeY, d * 1.1, CFrame.new(0, hingeY / 2, 0), Build.Tint(bark, 0.9), M.Wood, m, true) -- 2
	addNotches(m, rng, hingeY, d) -- 4

	local top = Build.Model("Top", m)
	local trunk: BasePart

	if sp == "Pine" then
		local trunkTop = H * 0.9
		trunk = Build.Cyl("Trunk", trunkTop - hingeY, d * 0.94, CFrame.new(0, (trunkTop + hingeY) / 2, 0), bark, M.Wood, top, true) -- 5
		local n = 3 + tier -- 4 / 5 / 6 tiers
		local baseD = H * rng:NextNumber(0.38, 0.46)
		local y0 = math.max(H * 0.28, hingeY + 2.5)
		local y1 = H * 0.82
		local thick = (y1 - y0) / (n - 1) * 1.45
		tierStack(top, rng, CFrame.new(), y0, y1, n, baseD, baseD * 0.3, thick, NEEDLE, nil, d * 0.12) -- <= 11
		Build.Cyl("Tip", H - y1, math.max(0.8, baseD * 0.14), CFrame.new(0, (y1 + H) / 2, 0), shade(rng, NEEDLE, 0.05), M.Grass, top, false) -- <= 12
	elseif sp == "Oak" then
		local trunkTop = H * 0.58
		trunk = Build.Cyl("Trunk", trunkTop - hingeY, d, CFrame.new(0, (trunkTop + hingeY) / 2, 0), bark, M.Wood, top, true) -- 5
		local r = H * 0.26
		local cy = H - r * 1.1
		local a = rng:NextNumber(0, TAU)
		for i = 0, 1 do -- 7
			local aa = a + i * math.pi + rng:NextNumber(-0.5, 0.5)
			local from = Vector3.new(0, trunkTop * rng:NextNumber(0.7, 0.9), 0)
			local to = Vector3.new(math.cos(aa) * r * 0.8, cy - r * 0.2, math.sin(aa) * r * 0.8)
			limb("Branch", from, to, d * 0.45, bark, M.Wood, top, false)
		end
		local nBalls = if tier == 1 then 3 elseif tier == 2 then 5 else 6
		crown(top, rng, Vector3.new(0, cy, 0), r, nBalls, LEAF) -- <= 13
	else -- Birch
		local trunkTop = H * 0.9
		local td = d * 0.8
		trunk = Build.Cyl("Trunk", trunkTop - hingeY, td, CFrame.new(0, (trunkTop + hingeY) / 2, 0), bark, M.Wood, top, true) -- 5
		barkMarks(top, rng, CFrame.new(), td / 2, hingeY + 1, H * 0.5, 2) -- 7
		local a = rng:NextNumber(0, TAU)
		limb("Branch", Vector3.new(0, H * 0.55, 0), Vector3.new(math.cos(a) * H * 0.14, H * 0.7, math.sin(a) * H * 0.14), td * 0.4, bark, M.Wood, top, false) -- 8
		local n = if tier == 1 then 3 else 4
		local r = H * 0.13
		for i = 1, n do -- <= 12
			local t = (i - 1) / (n - 1)
			local y = H * 0.56 + (H - r * 1.4 - H * 0.56) * t
			local w = r * (1.25 - 0.35 * t) * rng:NextNumber(0.9, 1.1)
			local off = Vector3.new(rng:NextNumber(-r, r) * 0.45, 0, rng:NextNumber(-r, r) * 0.45)
			Build.Ball("Canopy", w * 2, CFrame.new(Vector3.new(0, y, 0) + off), shade(rng, BIRCH_LEAF, 0.05), M.LeafyGrass, top)
		end
	end

	Build.SetPivot(top, trunk, CFrame.new(0, hingeY, 0))
	finish(m, root, cf, parent)
	skinTree(m, top, TREE_SKINS[sp][size] or TREE_SKINS[sp].Medium, STUMP_SKINS[sp], H)
	return m
end

--- Dead tree (dry wood resource): grey leafless snag with Root/Stump/Notch/Top roles.
--- Parts: 9-10.
function Flora.DeadTree(cf: CFrame, rng: Random, parent: Instance?): Model
	local H = rng:NextNumber(14, 22)
	local d = rng:NextNumber(1.7, 2.2)
	local hingeY = rng:NextNumber(1.0, 1.3)
	local m = Build.Model("DeadTree")
	m:SetAttribute("HingeY", hingeY)
	m:SetAttribute("Species", "Dead")

	local root = makeRoot(m, d + 1, hingeY + 3) -- 1
	local bark = vary(rng, BARK_GREY, 0.08)
	Build.Cyl("Stump", hingeY, d * 1.1, CFrame.new(0, hingeY / 2, 0), Build.Tint(bark, 0.88), M.Wood, m, true) -- 2
	addNotches(m, rng, hingeY, d) -- 4

	local top = Build.Model("Top", m)
	local lean = rng:NextNumber(0, 0.08)
	local axis = CFrame.Angles(0, rng:NextNumber(0, TAU), lean)
	local trunk = Build.Cyl("Trunk", H - hingeY, d, axis * CFrame.new(0, (H + hingeY) / 2, 0), bark, M.Wood, top, true) -- 5
	-- snapped top: a pale jagged wedge
	block("Snap", Vector3.new(d * 0.7, d * 1.2, d * 0.8), axis * CFrame.new(0, H + d * 0.5, 0) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
		Build.Tint(CUT_WOOD, 0.8), M.Wood, top, "WedgePart") -- 6
	local nb = rng:NextInteger(3, 4)
	local a0 = rng:NextNumber(0, TAU)
	for i = 1, nb do -- <= 10
		local y = H * (0.35 + 0.5 * (i - 1) / (nb - 1)) * rng:NextNumber(0.95, 1.05)
		local from = axis * Vector3.new(0, y, 0)
		local a = a0 + i * 2.3
		local len = H * rng:NextNumber(0.14, 0.24) * (1.1 - 0.4 * (i - 1) / (nb - 1))
		local to = from + Vector3.new(math.cos(a) * len, len * rng:NextNumber(0.3, 0.9), math.sin(a) * len)
		limb("Branch", from, to, d * rng:NextNumber(0.22, 0.32), vary(rng, BARK_GREY, 0.06), M.Wood, top, false)
	end

	Build.SetPivot(top, trunk, CFrame.new(0, hingeY, 0))
	finish(m, root, cf, parent)
	skinTree(m, top, "SM_Tree_Dead_Large01", STUMP_SKINS.Dead, H)
	return m
end

--- Berry bush: 2-3 leafy balls with 6-8 berries (Yield) of one colour.
--- Parts: <= 12.
function Flora.BerryBush(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("BerryBush")
	local root = makeRoot(m, 4.5, 3) -- 1
	local berryCol = pick(rng, BERRY)
	local balls = {}
	local nb = rng:NextInteger(2, 3)
	for i = 1, nb do -- <= 4
		local r = if i == 1 then rng:NextNumber(1.7, 2.1) else rng:NextNumber(1.2, 1.6)
		local a = rng:NextNumber(0, TAU)
		local off = if i == 1 then Vector3.zero else Vector3.new(math.cos(a) * 1.5, 0, math.sin(a) * 1.5)
		local c = off + Vector3.new(0, r * 0.8, 0)
		Build.Ball("Leaves", r * 2, CFrame.new(c), shade(rng, BUSH, 0.06), M.LeafyGrass, m)
		table.insert(balls, { c = c, r = r })
	end
	local n = rng:NextInteger(6, 8)
	for _ = 1, n do -- <= 12
		local b = balls[rng:NextInteger(1, #balls)]
		local a = rng:NextNumber(0, TAU)
		local el = rng:NextNumber(0.05, 1.1)
		local dir = Vector3.new(math.cos(el) * math.cos(a), math.sin(el), math.cos(el) * math.sin(a))
		markYield(Build.Ball("Berry", rng:NextNumber(0.42, 0.55), CFrame.new(b.c + dir * b.r * 0.94), vary(rng, berryCol, 0.1), M.SmoothPlastic, m))
	end
	finish(m, root, cf, parent)
	if Skins.Enabled() then
		-- sized to the procedural leaf balls so the berries sit on the bush, not in the air
		Skins.Dress(m, "SM_Bush01", { scale = 1.6, keep = { Berry = true } }) -- berries stay procedural (they are the yield)
	end
	return m
end

--- Mushroom patch: a mossy base with 4-5 mushrooms; stems and caps are Yield.
--- Parts: <= 12.
function Flora.MushroomPatch(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("MushroomPatch")
	local root = makeRoot(m, 3.5, 1.5) -- 1
	Build.Cyl("Moss", 0.2, rng:NextNumber(2.8, 3.4), CFrame.new(0, 0.08, 0), shade(rng, MOSS, 0.06), M.Grass, m, false) -- 2
	local capCol = if rng:NextNumber() < 0.5 then CAP_BROWN else CAP_TAN
	local n = rng:NextInteger(4, 5)
	for i = 1, n do -- <= 12
		local a = rng:NextNumber(0, TAU)
		local dist = if i == 1 then 0.2 else rng:NextNumber(0.5, 1.3)
		local h = rng:NextNumber(0.5, 1.0)
		local pos = Vector3.new(math.cos(a) * dist, 0, math.sin(a) * dist)
		local stem = Build.Cyl("Stem", h, rng:NextNumber(0.22, 0.32), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15)), STEM, M.SmoothPlastic, m, false)
		markYield(stem)
		local cd = rng:NextNumber(0.6, 1.0)
		markYield(Build.Cyl("Cap", 0.28, cd, CFrame.new(pos + Vector3.new(0, h, 0)) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), 0, rng:NextNumber(-0.12, 0.12)), vary(rng, capCol, 0.1), M.SmoothPlastic, m, false))
	end
	finish(m, root, cf, parent)
	skinHarvest(m, "SM_Mushrooms01", nil, 2.2)
	return m
end

--- Loose stones on a dirt patch; the stones are Yield. Parts: <= 8.
function Flora.LooseStones(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("LooseStones")
	local root = makeRoot(m, 3.5, 1.2) -- 1
	Build.Cyl("Dirt", 0.16, rng:NextNumber(2.8, 3.4), CFrame.new(0, 0.06, 0), vary(rng, DIRT, 0.08), M.Ground, m, false) -- 2
	local n = rng:NextInteger(4, 6)
	for _ = 1, n do -- <= 8
		local a = rng:NextNumber(0, TAU)
		local dist = rng:NextNumber(0, 1.2)
		local s = Vector3.new(rng:NextNumber(0.5, 0.9), rng:NextNumber(0.3, 0.55), rng:NextNumber(0.45, 0.8))
		markYield(block("Stone", s, CFrame.new(math.cos(a) * dist, s.Y * 0.4, math.sin(a) * dist) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, TAU), rng:NextNumber(-0.3, 0.3)),
			shade(rng, ROCK, 0.1), if rng:NextNumber() < 0.5 then M.Slate else M.Rock, m))
	end
	finish(m, root, cf, parent)
	skinHarvest(m, "SM_StreamRocks01", "SM_StreamRocks03", 1.0)
	return m
end

--- Rock pile: a colliding main boulder (+ optional side rock) that stays, with
--- 4-6 small loose chunks marked Yield. Parts: <= 9.
local function rockPile(cf: CFrame, rng: Random, parent: Instance?, k: number, name: string): Model
	local m = Build.Model(name)
	local root = makeRoot(m, 6 * k, 3.5 * k) -- 1
	local mat = if rng:NextNumber() < 0.5 then M.Rock else M.Slate
	local main = Vector3.new(rng:NextNumber(3.6, 4.6), rng:NextNumber(2.4, 3.2), rng:NextNumber(3.2, 4.2)) * k
	solid("Boulder", main, CFrame.new(0, main.Y * 0.42, 0) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, TAU), rng:NextNumber(-0.15, 0.15)), shade(rng, ROCK, 0.08), mat, m) -- 2
	if rng:NextNumber() < 0.6 or k > 1 then -- 3
		local s = Vector3.new(rng:NextNumber(1.8, 2.4), rng:NextNumber(1.2, 1.8), rng:NextNumber(1.6, 2.2)) * k
		local a = rng:NextNumber(0, TAU)
		solid("Rock", s, CFrame.new(math.cos(a) * 2.2 * k, s.Y * 0.4, math.sin(a) * 2.2 * k) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, TAU), rng:NextNumber(-0.3, 0.3)), shade(rng, ROCK, 0.08), mat, m)
	end
	local n = rng:NextInteger(4, 6)
	local a0 = rng:NextNumber(0, TAU)
	for i = 1, n do -- <= 9
		local a = a0 + i * TAU / n + rng:NextNumber(-0.3, 0.3)
		local dist = rng:NextNumber(2.2, 2.9) * k
		local s = Vector3.new(rng:NextNumber(0.7, 1.2), rng:NextNumber(0.5, 0.9), rng:NextNumber(0.7, 1.1)) * math.sqrt(k)
		markYield(block("Chunk", s, CFrame.new(math.cos(a) * dist, s.Y * 0.4, math.sin(a) * dist) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, TAU), rng:NextNumber(-0.4, 0.4)),
			shade(rng, ROCK, 0.1), mat, m))
	end
	finish(m, root, cf, parent)
	skinHarvest(m, "SM_StoneDeposit01", "SM_StoneDeposit01_Depleted", 1.05 * k)
	return m
end

--- Small stone deposit (Crude Pickaxe+): boulder + chunks (Yield). Parts: <= 9.
function Flora.RockPile(cf: CFrame, rng: Random, parent: Instance?): Model
	return rockPile(cf, rng, parent, 1, "RockPile")
end

--- Large stone deposit (Stone Pickaxe+): the same pile at double size.
function Flora.LargeRockPile(cf: CFrame, rng: Random, parent: Instance?): Model
	return rockPile(cf, rng, parent, 2, "LargeRockPile")
end

--- Scrap pile (POI node, pickaxe): rusted sheets, a wheel rim and cans (Yield). Parts: <= 10.
function Flora.ScrapPile(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("ScrapPile")
	local root = makeRoot(m, 5, 2.5) -- 1
	local rust = { Color3.fromRGB(128, 84, 58), Color3.fromRGB(110, 96, 84), Color3.fromRGB(90, 96, 104) }
	block("Base", Vector3.new(4.4, 0.4, 3.8), CFrame.new(0, 0.2, 0) * spin(rng), Color3.fromRGB(70, 60, 52), M.Ground, m) -- 2
	for i = 1, 6 do -- 8
		local s = Vector3.new(rng:NextNumber(1.2, 2.4), rng:NextNumber(0.15, 0.5), rng:NextNumber(0.8, 1.8))
		local a = rng:NextNumber(0, TAU)
		markYield(block("Scrap", s, CFrame.new(math.cos(a) * rng:NextNumber(0, 1.4), 0.4 + i * 0.18, math.sin(a) * rng:NextNumber(0, 1.2)) * CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, TAU), rng:NextNumber(-0.6, 0.6)),
			rust[(i % #rust) + 1], M.CorrodedMetal, m))
	end
	markYield(Build.Cyl("Rim", 0.4, 1.6, CFrame.new(1.2, 0.9, -0.6) * CFrame.Angles(0.4, 0, 1.2), Color3.fromRGB(60, 60, 64), M.Metal, m, false)) -- 9
	finish(m, root, cf, parent)
	skinHarvest(m, "SM_ScrapPile01", "SM_StoneDeposit01_Depleted", 1)
	return m
end

-- Ore deposits (POI / cave nodes, Stone Pickaxe+): a rock hump with coloured seams (Yield).
local function oreDeposit(cf: CFrame, rng: Random, parent: Instance?, name: string, seam: Color3, seamMat: Enum.Material, k: number): Model
	local m = Build.Model(name)
	local root = makeRoot(m, 5 * k, 3.5 * k) -- 1
	local main = Vector3.new(rng:NextNumber(3.8, 4.6), rng:NextNumber(2.6, 3.2), rng:NextNumber(3.2, 4)) * k
	solid("Rock", main, CFrame.new(0, main.Y * 0.42, 0) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, TAU), 0), shade(rng, ROCK, 0.08), M.Slate, m) -- 2
	for i = 1, 5 do -- 7
		local a = i * TAU / 5 + rng:NextNumber(-0.3, 0.3)
		local s = Vector3.new(rng:NextNumber(0.6, 1.1), rng:NextNumber(0.4, 0.8), rng:NextNumber(0.6, 1)) * k
		markYield(block("Seam", s, CFrame.new(math.cos(a) * main.X * 0.42, main.Y * rng:NextNumber(0.35, 0.7), math.sin(a) * main.Z * 0.42) * CFrame.Angles(rng:NextNumber(0, 1), a, 0), seam, seamMat, m))
	end
	finish(m, root, cf, parent)
	skinHarvest(m, if name == "CoalDeposit" then "SM_OreDeposit_Coal" else "SM_OreDeposit_Iron", "SM_StoneDeposit01_Depleted", k)
	return m
end

function Flora.CoalDeposit(cf: CFrame, rng: Random, parent: Instance?): Model
	return oreDeposit(cf, rng, parent, "CoalDeposit", Color3.fromRGB(34, 34, 38), M.Basalt, 1)
end

function Flora.IronDeposit(cf: CFrame, rng: Random, parent: Instance?): Model
	return oreDeposit(cf, rng, parent, "IronDeposit", Color3.fromRGB(170, 104, 76), M.CorrodedMetal, 1)
end

function Flora.RichIronDeposit(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = oreDeposit(cf, rng, parent, "RichIronDeposit", Color3.fromRGB(200, 120, 80), M.CorrodedMetal, 1.3)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Seam" then
			local glow = Instance.new("PointLight")
			glow.Color = Color3.fromRGB(255, 170, 110)
			glow.Range = 6
			glow.Brightness = 0.6
			glow.Parent = d
			break
		end
	end
	return m
end

--- Twig pile: a leaf-litter patch with 5-7 crossed twigs (Yield). Parts: <= 9.
function Flora.TwigPile(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("TwigPile")
	local root = makeRoot(m, 3.5, 1.2) -- 1
	block("Litter", Vector3.new(rng:NextNumber(2.6, 3.2), 0.1, rng:NextNumber(2.4, 3.0)), CFrame.new(0, 0.05, 0) * spin(rng), shade(rng, LITTER, 0.08), M.Ground, m) -- 2
	local n = rng:NextInteger(5, 7)
	for i = 1, n do -- <= 9
		local len = rng:NextNumber(1.6, 2.6)
		local a = rng:NextNumber(0, TAU)
		local y = 0.12 + i * 0.07
		local c = Vector3.new(rng:NextNumber(-0.5, 0.5), y, rng:NextNumber(-0.5, 0.5))
		local dir = Vector3.new(math.cos(a), rng:NextNumber(-0.08, 0.12), math.sin(a)) * (len / 2)
		markYield(limb("Twig", c - dir, c + dir, rng:NextNumber(0.14, 0.22), vary(rng, if i % 2 == 0 then BARK else BARK_GREY, 0.1), M.Wood, m, false))
	end
	finish(m, root, cf, parent)
	skinHarvest(m, "SM_Sticks_Loose01", nil, 1.3, { Litter = true })
	return m
end

--- Fibre plant: dark basal fronds that stay, plus tall pale fibre fronds and
--- seed buds that are Yield. Parts: <= 12.
function Flora.FibrePlant(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("FibrePlant")
	local root = makeRoot(m, 3, 2) -- 1
	Build.Ball("Tuft", 1.4, CFrame.new(0, 0.3, 0), shade(rng, FERN, 0.05), M.Grass, m) -- 2
	local a0 = rng:NextNumber(0, TAU)
	for i = 0, 2 do -- 5: low fronds (stay)
		local a = a0 + i * TAU / 3
		block("Frond", Vector3.new(0.2, 2.0, 1.0), CFrame.Angles(0, a, 0) * CFrame.new(0, 0.7, 0.9) * CFrame.Angles(math.rad(62), 0, 0),
			vary(rng, FERN[3], 0.08), M.Grass, m, "WedgePart")
	end
	local nTall = 4
	for i = 0, nTall - 1 do -- 9: tall fibre fronds (Yield)
		local a = a0 + math.pi / 3 + i * TAU / nTall + rng:NextNumber(-0.2, 0.2)
		local h = rng:NextNumber(2.6, 3.4)
		markYield(block("Fibre", Vector3.new(0.18, h, 0.8), CFrame.Angles(0, a, 0) * CFrame.new(0, h * 0.45, 0.45) * CFrame.Angles(math.rad(rng:NextNumber(14, 26)), 0, 0),
			vary(rng, Color3.fromRGB(160, 178, 104), 0.08), M.Grass, m, "WedgePart"))
	end
	local budCol = vary(rng, Color3.fromRGB(236, 214, 120), 0.06)
	for i = 0, 2 do -- 12: buds (Yield)
		local a = a0 + i * TAU / 3 + 0.5
		markYield(Build.Ball("Bud", rng:NextNumber(0.45, 0.6), CFrame.Angles(0, a, 0) * CFrame.new(0, rng:NextNumber(2.3, 2.9), 0.9), budCol, M.SmoothPlastic, m))
	end
	finish(m, root, cf, parent)
	skinHarvest(m, "SM_FiberPlant01", "SM_FiberPlant01_Harvested", 1.0)
	return m
end

--------------------------------------------------------------------------------
-- Decorative trees  (cf, rng, scale?, parent)
--------------------------------------------------------------------------------

--- Pine. Variants: tall-slim tiered, broad layered (with dead lower stubs),
--- lopsided windswept. Parts: 8 / 10 / 8.
function Flora.Pine(cf: CFrame, rng: Random, scale: number?, parent: Instance?): Model
	local s = newScale(rng, scale)
	local m = Build.Model("Pine")
	local bark = vary(rng, BARK_PINE, 0.07)
	local v = rng:NextInteger(1, 3)
	local trunk: BasePart
	if v == 1 then -- tall & slim
		local H = 34 * s
		trunk = Build.Cyl("Trunk", H * 0.9, 1.8 * s, CFrame.new(0, H * 0.45, 0), bark, M.Wood, m, true)
		tierStack(m, rng, CFrame.new(), H * 0.3, H * 0.84, 6, 11 * s, 3 * s, H * 0.14, NEEDLE, nil, 0.3 * s)
		Build.Cyl("Tip", H * 0.14, 1.4 * s, CFrame.new(0, H * 0.92, 0), shade(rng, NEEDLE, 0.05), M.Grass, m, false)
	elseif v == 2 then -- broad, layered, tiers with gaps
		local H = 28 * s
		trunk = Build.Cyl("Trunk", H * 0.88, 2.3 * s, CFrame.new(0, H * 0.44, 0), bark, M.Wood, m, true)
		tierStack(m, rng, CFrame.new(), H * 0.3, H * 0.86, 5, 17 * s, 5 * s, H * 0.08, NEEDLE, nil, 0.6 * s)
		Build.Cyl("Tip", H * 0.12, 2 * s, CFrame.new(0, H * 0.93, 0), shade(rng, NEEDLE, 0.05), M.Grass, m, false)
		local a = rng:NextNumber(0, TAU)
		for i = 0, 1 do
			local aa = a + i * 2.4
			local y = H * rng:NextNumber(0.14, 0.24)
			limb("DeadBranch", Vector3.new(0, y, 0), Vector3.new(math.cos(aa) * 3 * s, y - 0.8 * s, math.sin(aa) * 3 * s), 0.35 * s, BARK_GREY, M.Wood, m, false)
		end
	else -- lopsided windswept
		local H = 30 * s
		local a = rng:NextNumber(0, TAU)
		local lean = rng:NextNumber(0.06, 0.12)
		local axis = CFrame.Angles(0, a, 0) * CFrame.Angles(0, 0, lean)
		local leanDir = CFrame.Angles(0, a, 0):VectorToWorldSpace(Vector3.new(-1, 0, 0))
		trunk = Build.Cyl("Trunk", H * 0.88, 2 * s, axis * CFrame.new(0, H * 0.44, 0), bark, M.Wood, m, true)
		tierStack(m, rng, axis, H * 0.34, H * 0.86, 6, 13 * s, 3.5 * s, H * 0.1, NEEDLE, leanDir * 3.5 * s, 0.4 * s)
		Build.Cyl("Tip", H * 0.1, 1.4 * s, CFrame.new(axis * Vector3.new(0, H * 0.92, 0) + leanDir * 3.5 * s),shade(rng, NEEDLE, 0.05), M.Grass, m, false)
	end
	return finish(m, trunk, cf, parent)
end

--- Spruce: dense tiers starting near the ground. Variants: dense cone, blue
--- spruce, narrow subalpine spire. Parts: 10 / 10 / 11.
function Flora.Spruce(cf: CFrame, rng: Random, scale: number?, parent: Instance?): Model
	local s = newScale(rng, scale)
	local m = Build.Model("Spruce")
	local bark = vary(rng, BARK_DARK, 0.07)
	local v = rng:NextInteger(1, 3)
	local trunk: BasePart
	if v == 1 then
		local H = 30 * s
		trunk = Build.Cyl("Trunk", H * 0.9, 1.9 * s, CFrame.new(0, H * 0.45, 0), bark, M.Wood, m, true)
		tierStack(m, rng, CFrame.new(), H * 0.1, H * 0.85, 8, 14 * s, 2.5 * s, H * 0.13, SPRUCE, nil, 0.25 * s)
		Build.Cyl("Tip", H * 0.12, 1.2 * s, CFrame.new(0, H * 0.93, 0), shade(rng, SPRUCE, 0.05), M.Grass, m, false)
	elseif v == 2 then
		local H = 26 * s
		trunk = Build.Cyl("Trunk", H * 0.9, 2 * s, CFrame.new(0, H * 0.45, 0), bark, M.Wood, m, true)
		Build.Cyl("Flare", 1.2 * s, 3 * s, CFrame.new(0, 0.6 * s, 0), Build.Tint(bark, 0.9), M.Wood, m, true)
		tierStack(m, rng, CFrame.new(), H * 0.12, H * 0.84, 7, 15 * s, 3 * s, H * 0.14, SPRUCE_BLUE, nil, 0.3 * s)
		Build.Cyl("Tip", H * 0.12, 1.4 * s, CFrame.new(0, H * 0.93, 0), shade(rng, SPRUCE_BLUE, 0.05), M.Grass, m, false)
	else
		local H = 38 * s
		trunk = Build.Cyl("Trunk", H * 0.9, 1.6 * s, CFrame.new(0, H * 0.45, 0), bark, M.Wood, m, true)
		tierStack(m, rng, CFrame.new(), H * 0.08, H * 0.86, 9, 8 * s, 2 * s, H * 0.11, SPRUCE, nil, 0.2 * s)
		Build.Cyl("Tip", H * 0.12, 0.9 * s, CFrame.new(0, H * 0.93, 0), shade(rng, SPRUCE, 0.05), M.Grass, m, false)
	end
	return finish(m, trunk, cf, parent)
end

--- Oak. Variants: round crown, wide spreading, two-trunk. Parts: <= 11 / 11 / 10.
function Flora.Oak(cf: CFrame, rng: Random, scale: number?, parent: Instance?): Model
	local s = newScale(rng, scale)
	local m = Build.Model("Oak")
	local bark = vary(rng, BARK_OAK, 0.07)
	local pal = if rng:NextNumber() < 0.5 then LEAF else LEAF_DEEP
	local v = rng:NextInteger(1, 3)
	local trunk: BasePart
	if v == 1 then -- round crown
		local H = 24 * s
		local tTop = H * 0.55
		trunk = Build.Cyl("Trunk", tTop, 2.8 * s, CFrame.new(0, tTop / 2, 0), bark, M.Wood, m, true)
		Build.Cyl("Flare", 1.4 * s, 3.8 * s, CFrame.new(0, 0.7 * s, 0), Build.Tint(bark, 0.9), M.Wood, m, true)
		local r = 6.5 * s
		local cy = H - r * 1.1
		local a0 = rng:NextNumber(0, TAU)
		for i = 0, 2 do
			local a = a0 + i * TAU / 3 + rng:NextNumber(-0.3, 0.3)
			limb("Limb", Vector3.new(0, tTop * 0.85, 0), Vector3.new(math.cos(a) * r * 0.6, cy - r * 0.1, math.sin(a) * r * 0.6), 1.1 * s, bark, M.Wood, m, false)
		end
		crown(m, rng, Vector3.new(0, cy, 0), r, 6, pal)
	elseif v == 2 then -- wide spreading
		local H = 20 * s
		local tTop = H * 0.45
		trunk = Build.Cyl("Trunk", tTop, 3.2 * s, CFrame.new(0, tTop / 2, 0), bark, M.Wood, m, true)
		local a0 = rng:NextNumber(0, TAU)
		local ends = {}
		for i = 0, 3 do
			local a = a0 + i * TAU / 4 + rng:NextNumber(-0.35, 0.35)
			local reach = rng:NextNumber(7, 9.5) * s
			local e = Vector3.new(math.cos(a) * reach, tTop + rng:NextNumber(2.5, 4) * s, math.sin(a) * reach)
			limb("Limb", Vector3.new(0, tTop * 0.9, 0), e, 1.2 * s, bark, M.Wood, m, false)
			table.insert(ends, e)
		end
		for i, e in ends do
			Build.Ball("Canopy", rng:NextNumber(7, 9) * s, CFrame.new(e + Vector3.new(0, 1.5 * s, 0)), shade(rng, pal, 0.06), M.LeafyGrass, m)
			if i <= 2 then
				local mid = e * Vector3.new(0.45, 1, 0.45) + Vector3.new(0, 3 * s, 0)
				Build.Ball("Canopy", rng:NextNumber(8, 10) * s, CFrame.new(mid), shade(rng, pal, 0.06), M.LeafyGrass, m)
			end
		end
		-- 1 + 4 + 6 = 11
	else -- two-trunk fork
		local H = 24 * s
		trunk = Build.Cyl("Flare", 2.4 * s, 4.2 * s, CFrame.new(0, 1.2 * s, 0), bark, M.Wood, m, true)
		local a = rng:NextNumber(0, TAU)
		for i = 0, 1 do
			local aa = a + i * math.pi
			local topP = Vector3.new(math.cos(aa) * 4.5 * s, H * rng:NextNumber(0.5, 0.6), math.sin(aa) * 4.5 * s)
			limb("Trunk", Vector3.new(0, 1.8 * s, 0), topP, 2 * s, bark, M.Wood, m, true)
			crown(m, rng, topP + Vector3.new(math.cos(aa) * 1.5 * s, 4 * s, math.sin(aa) * 1.5 * s), 4.8 * s, if i == 0 then 4 else 3, pal)
		end
		-- 1 + 2 + 7 = 10
	end
	return finish(m, trunk, cf, parent)
end

--- Birch. Variants: single slender, clump of 3 stems, leaning. Parts: 9 / 11 / 8.
function Flora.Birch(cf: CFrame, rng: Random, scale: number?, parent: Instance?): Model
	local s = newScale(rng, scale)
	local m = Build.Model("Birch")
	local bark = vary(rng, BIRCH_BARK, 0.04)
	local v = rng:NextInteger(1, 3)
	local trunk: BasePart
	local function column(axis: CFrame, H: number, td: number, n: number, marks: number, r: number)
		local t = Build.Cyl("Trunk", H * 0.9, td, axis * CFrame.new(0, H * 0.45, 0), bark, M.Wood, m, true)
		barkMarks(m, rng, axis, td / 2, 1.5 * s, H * 0.55, marks)
		for i = 1, n do
			local k = (i - 1) / math.max(1, n - 1)
			local y = H * 0.55 + (H - r * 1.3 - H * 0.55) * k
			local w = r * (1.25 - 0.35 * k) * rng:NextNumber(0.9, 1.1)
			local p = axis * Vector3.new(0, y, 0) + Vector3.new(rng:NextNumber(-0.5, 0.5) * r, 0, rng:NextNumber(-0.5, 0.5) * r)
			Build.Ball("Canopy", w * 2, CFrame.new(p), shade(rng, BIRCH_LEAF, 0.05), M.LeafyGrass, m)
		end
		return t
	end
	if v == 1 then
		local H = 26 * s
		trunk = column(CFrame.new(), H, 1.3 * s, 4, 3, 3.4 * s)
		local a = rng:NextNumber(0, TAU)
		limb("Branch", Vector3.new(0, H * 0.5, 0), Vector3.new(math.cos(a) * 3 * s, H * 0.64, math.sin(a) * 3 * s), 0.5 * s, bark, M.Wood, m, false)
	elseif v == 2 then
		local a0 = rng:NextNumber(0, TAU)
		for i = 0, 2 do
			local H = 22 * s * rng:NextNumber(0.85, 1.1)
			local axis = CFrame.Angles(0, a0 + i * TAU / 3, 0) * CFrame.Angles(0, 0, rng:NextNumber(0.1, 0.18))
			local t = column(axis, H, 1.0 * s, 2, if i == 0 then 2 else 0, 2.8 * s)
			if i == 0 then
				trunk = t
			end
		end
	else
		local H = 24 * s
		local axis = CFrame.Angles(0, rng:NextNumber(0, TAU), 0) * CFrame.Angles(0, 0, rng:NextNumber(0.14, 0.22))
		trunk = column(axis, H, 1.3 * s, 4, 3, 3.2 * s)
	end
	return finish(m, trunk, cf, parent)
end

--- Aspen: tall pale trunk with a narrow columnar crown. Variants: green
--- column, golden column, twin grove pair. Parts: 8 / 8 / 11.
function Flora.Aspen(cf: CFrame, rng: Random, scale: number?, parent: Instance?): Model
	local s = newScale(rng, scale)
	local m = Build.Model("Aspen")
	local bark = vary(rng, ASPEN_BARK, 0.04)
	local v = rng:NextInteger(1, 3)
	local pal = if v == 2 then ASPEN_GOLD else ASPEN_LEAF
	local function stem(base: Vector3, H: number, n: number, marks: number)
		local t = Build.Cyl("Trunk", H * 0.92, 1.1 * s, CFrame.new(base + Vector3.new(0, H * 0.46, 0)), bark, M.Wood, m, true)
		barkMarks(m, rng, CFrame.new(base), 0.55 * s, 1.5 * s, H * 0.5, marks)
		local r = 2.3 * s
		for i = 1, n do
			local k = (i - 1) / math.max(1, n - 1)
			local y = H * 0.5 + (H - r - H * 0.5) * k
			local p = base + Vector3.new(rng:NextNumber(-0.6, 0.6) * s, y, rng:NextNumber(-0.6, 0.6) * s)
			Build.Ball("Canopy", r * 2 * (1.15 - 0.3 * k) * rng:NextNumber(0.9, 1.1), CFrame.new(p), shade(rng, pal, 0.06), M.LeafyGrass, m)
		end
		return t
	end
	local trunk: BasePart
	if v <= 2 then
		trunk = stem(Vector3.zero, 28 * s, 5, 2)
	else
		local a = rng:NextNumber(0, TAU)
		local off = Vector3.new(math.cos(a), 0, math.sin(a)) * 2.2 * s
		trunk = stem(off, 28 * s * rng:NextNumber(0.95, 1.05), 4, 1)
		stem(-off, 22 * s * rng:NextNumber(0.9, 1.05), 3, 1)
	end
	return finish(m, trunk, cf, parent)
end

--- Giant landmark tree: massive trunk, buttress roots, 4 limbs and a layered
--- two-tier canopy. Parts: 20 (budget 22).
function Flora.GiantTree(cf: CFrame, rng: Random, scale: number?, parent: Instance?): Model
	local s = newScale(rng, scale)
	local m = Build.Model("GiantTree")
	local bark = vary(rng, BARK, 0.06)
	local pal = if rng:NextNumber() < 0.5 then LEAF else LEAF_DEEP
	local tTop = 34 * s
	local trunk = Build.Cyl("Trunk", tTop, 7 * s, CFrame.new(0, tTop / 2, 0), bark, M.Wood, m, true) -- 1
	Build.Cyl("Flare", 3 * s, 10 * s, CFrame.new(0, 1.5 * s, 0), Build.Tint(bark, 0.9), M.Wood, m, true) -- 2
	local a0 = rng:NextNumber(0, TAU)
	for i = 0, 3 do -- 6: buttress roots
		local a = a0 + i * TAU / 4 + rng:NextNumber(-0.3, 0.3)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		limb("Root", dir * 2.5 * s + Vector3.new(0, 5 * s, 0), dir * 8.5 * s + Vector3.new(0, -0.5 * s, 0), 2.2 * s, Build.Tint(bark, 0.95), M.Wood, m, true)
	end
	local ends = {}
	for i = 0, 3 do -- 10: limbs
		local a = a0 + math.pi / 4 + i * TAU / 4 + rng:NextNumber(-0.3, 0.3)
		local reach = rng:NextNumber(11, 15) * s
		local e = Vector3.new(math.cos(a) * reach, tTop + rng:NextNumber(3, 7) * s, math.sin(a) * reach)
		limb("Limb", Vector3.new(0, tTop * rng:NextNumber(0.78, 0.9), 0), e, 2.4 * s, bark, M.Wood, m, false)
		table.insert(ends, e)
	end
	for _, e in ends do -- 14: lower canopy blobs at limb ends
		Build.Ball("Canopy", rng:NextNumber(12, 15) * s, CFrame.new(e + Vector3.new(0, 1.5 * s, 0)), shade(rng, pal, 0.06), M.LeafyGrass, m)
	end
	-- 20: upper crown
	crown(m, rng, Vector3.new(0, tTop + 11 * s, 0), 9 * s, 6, pal, 0.3)
	return finish(m, trunk, cf, parent)
end

--- Dead snag. Variants: tall broken snag, short jagged stub with fungus,
--- leaning snag with one big branch. Parts: <= 6.
function Flora.DeadSnag(cf: CFrame, rng: Random, scale: number?, parent: Instance?): Model
	local s = newScale(rng, scale)
	local m = Build.Model("DeadSnag")
	local bark = vary(rng, BARK_GREY, 0.08)
	local v = rng:NextInteger(1, 3)
	local trunk: BasePart
	if v == 1 then
		local H = 18 * s
		trunk = Build.Cyl("Trunk", H, 2 * s, CFrame.new(0, H / 2, 0), bark, M.Wood, m, true)
		block("Snap", Vector3.new(1.4 * s, 2.4 * s, 1.6 * s), CFrame.new(0, H + 1.1 * s, 0) * spin(rng), Build.Tint(CUT_WOOD, 0.75), M.Wood, m, "WedgePart")
		local a0 = rng:NextNumber(0, TAU)
		for i = 1, 3 do
			local y = H * (0.3 + i * 0.18)
			local a = a0 + i * 2.2
			local len = rng:NextNumber(2.5, 4) * s
			limb("Branch", Vector3.new(0, y, 0), Vector3.new(math.cos(a) * len, y + len * 0.6, math.sin(a) * len), 0.45 * s, bark, M.Wood, m, false)
		end
	elseif v == 2 then
		local H = 6 * s
		trunk = Build.Cyl("Trunk", H, 2.8 * s, CFrame.new(0, H / 2, 0), bark, M.Wood, m, true)
		local a = rng:NextNumber(0, TAU)
		block("Jag", Vector3.new(1.4 * s, 2.2 * s, 1.2 * s), CFrame.new(0, H + 1 * s, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0.5 * s, 0, 0), Build.Tint(CUT_WOOD, 0.7), M.Wood, m, "WedgePart")
		block("Jag", Vector3.new(1.2 * s, 1.4 * s, 1.2 * s), CFrame.new(0, H + 0.6 * s, 0) * CFrame.Angles(0, a + 2.5, 0) * CFrame.new(0.6 * s, 0, 0), Build.Tint(CUT_WOOD, 0.65), M.Wood, m, "WedgePart")
		for i = 0, 1 do
			Build.Cyl("Fungus", 0.3 * s, rng:NextNumber(1.4, 2) * s, CFrame.new(0, H * (0.35 + i * 0.3), 0) * CFrame.Angles(0, a + 1 + i, 0) * CFrame.new(1.3 * s, 0, 0), vary(rng, CAP_TAN, 0.1), M.SmoothPlastic, m, false)
		end
	else
		local H = 16 * s
		local axis = CFrame.Angles(0, rng:NextNumber(0, TAU), 0) * CFrame.Angles(0, 0, rng:NextNumber(0.2, 0.3))
		trunk = Build.Cyl("Trunk", H, 2.2 * s, axis * CFrame.new(0, H / 2, 0), bark, M.Wood, m, true)
		local from = axis * Vector3.new(0, H * 0.6, 0)
		local a = rng:NextNumber(0, TAU)
		limb("Branch", from, from + Vector3.new(math.cos(a) * 5 * s, 4 * s, math.sin(a) * 5 * s), 0.8 * s, bark, M.Wood, m, false)
		block("Snap", Vector3.new(1.6 * s, 2 * s, 1.6 * s), axis * CFrame.new(0, H + 0.9 * s, 0), Build.Tint(CUT_WOOD, 0.75), M.Wood, m, "WedgePart")
	end
	return finish(m, trunk, cf, parent)
end

--------------------------------------------------------------------------------
-- Logs, stumps, saplings, bushes
--------------------------------------------------------------------------------

--- Fallen log. Variants: mossy, with branch stubs, with shelf fungus. Parts: <= 5.
function Flora.FallenLog(cf: CFrame, rng: Random, scale: number?, parent: Instance?): Model
	local s = newScale(rng, scale)
	local m = Build.Model("FallenLog")
	local len = rng:NextNumber(10, 18) * s
	local d = rng:NextNumber(2.2, 3.2) * s
	local bark = vary(rng, pick(rng, { BARK, BARK_OAK, BARK_GREY }), 0.08)
	local lay = CFrame.new(0, d * 0.42, 0) * CFrame.Angles(0, 0, math.pi / 2) -- axis along -X
	local log = Build.Cyl("Log", len, d, lay, bark, M.Wood, m, true)
	Build.Cyl("Cut", 0.12, d * 0.86, lay * CFrame.new(0, len / 2 + 0.02, 0), vary(rng, CUT_WOOD, 0.08), M.Wood, m, false)
	local v = rng:NextInteger(1, 3)
	if v == 1 then
		block("Moss", Vector3.new(len * 0.6, 0.3, d * 0.6), CFrame.new(rng:NextNumber(-1, 1) * s, d * 0.42 + d * 0.45, 0), shade(rng, MOSS, 0.06), M.Grass, m)
		block("Moss", Vector3.new(len * 0.25, 0.3, d * 0.5), CFrame.new(-len * 0.3, d * 0.42 + d * 0.4, 0.2 * d) * CFrame.Angles(0.3, 0, 0), shade(rng, MOSS, 0.06), M.Grass, m)
	elseif v == 2 then
		for i = 0, 1 do
			local x = (i - 0.5) * len * 0.5 + rng:NextNumber(-1, 1) * s
			local side = if rng:NextNumber() < 0.5 then 1 else -1
			local p = Vector3.new(x, d * 0.6, side * d * 0.35)
			limb("Stub", p, p + Vector3.new(rng:NextNumber(-0.8, 0.8), 1.4 * s, side * 1.8 * s), 0.45 * s, bark, M.Wood, m, false)
		end
	else
		for i = 0, 2 do
			local x = (i - 1) * len * 0.22 + rng:NextNumber(-0.5, 0.5)
			Build.Cyl("Fungus", 0.25, rng:NextNumber(1.0, 1.6) * s, CFrame.new(x, d * 0.42 + rng:NextNumber(-0.1, 0.25) * d, d * 0.5), vary(rng, if i == 1 then CAP_BROWN else CAP_TAN, 0.1), M.SmoothPlastic, m, false)
		end
	end
	return finish(m, log, cf, parent)
end

--- Tree stump. Variants: clean cut (pale top ring + roots), broken jagged,
--- mossy. Parts: <= 5.
function Flora.Stump(cf: CFrame, rng: Random, scale: number?, parent: Instance?): Model
	local s = newScale(rng, scale)
	local m = Build.Model("Stump")
	local d = rng:NextNumber(2.2, 3.4) * s
	local h = rng:NextNumber(1.2, 2.2) * s
	local bark = vary(rng, pick(rng, { BARK, BARK_OAK, BARK_PINE }), 0.08)
	local st = Build.Cyl("Stump", h, d, CFrame.new(0, h / 2, 0), bark, M.Wood, m, true)
	local v = rng:NextInteger(1, 3)
	if v == 1 then
		Build.Cyl("Cut", 0.1, d * 0.88, CFrame.new(0, h + 0.03, 0), vary(rng, CUT_WOOD, 0.08), M.Wood, m, false)
		local a0 = rng:NextNumber(0, TAU)
		for i = 0, 2 do
			local a = a0 + i * TAU / 3 + rng:NextNumber(-0.3, 0.3)
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			limb("Root", dir * d * 0.3 + Vector3.new(0, h * 0.5, 0), dir * d * 0.95 + Vector3.new(0, -0.2, 0), d * 0.28, bark, M.Wood, m, false)
		end
	elseif v == 2 then
		local a = rng:NextNumber(0, TAU)
		for i = 0, 2 do
			block("Jag", Vector3.new(d * 0.35, rng:NextNumber(0.8, 1.6) * s, d * 0.4), CFrame.new(0, h + 0.4 * s, 0) * CFrame.Angles(0, a + i * 2.1, 0) * CFrame.new(d * 0.25, 0, 0),
				Build.Tint(CUT_WOOD, rng:NextNumber(0.65, 0.8)), M.Wood, m, "WedgePart")
		end
	else
		Build.Cyl("Moss", 0.35, d * 1.02, CFrame.new(0, h + 0.1, 0), shade(rng, MOSS, 0.06), M.Grass, m, false)
		Build.Cyl("Moss", 0.25, d * 1.5, CFrame.new(0, 0.1, 0), shade(rng, MOSS, 0.06), M.Grass, m, false)
		Build.Cyl("Fungus", 0.22, 1.1 * s, CFrame.new(0, h * 0.5, 0) * spin(rng) * CFrame.new(d * 0.5, 0, 0), vary(rng, CAP_TAN, 0.1), M.SmoothPlastic, m, false)
	end
	return finish(m, st, cf, parent)
end

--- Sapling: young broadleaf (stem + leaf balls) or young conifer (stem + tiers).
--- Parts: <= 4.
function Flora.Sapling(cf: CFrame, rng: Random, scale: number?, parent: Instance?): Model
	local s = newScale(rng, scale)
	local m = Build.Model("Sapling")
	local H = rng:NextNumber(4, 6.5) * s
	local stem = Build.Cyl("Stem", H, 0.35 * s, CFrame.new(0, H / 2, 0) * CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.06, 0.06)), vary(rng, BARK, 0.1), M.Wood, m, false)
	if rng:NextNumber() < 0.5 then
		for i = 1, 3 do
			Build.Ball("Leaves", rng:NextNumber(1.4, 2.2) * s, CFrame.new(rng:NextNumber(-0.6, 0.6) * s, H * (0.6 + i * 0.13), rng:NextNumber(-0.6, 0.6) * s), shade(rng, LEAF, 0.06), M.LeafyGrass, m)
		end
	else
		tierStack(m, rng, CFrame.new(), H * 0.3, H * 0.9, 3, 3 * s, 1.1 * s, H * 0.25, NEEDLE, nil, 0.1)
	end
	return finish(m, stem, cf, parent, true)
end

--- Bush. Variants: round (3-4 balls), spiky (fanned leaf blades), flowering
--- (2 balls + 3 blossoms). Parts: <= 5.
function Flora.Bush(cf: CFrame, rng: Random, scale: number?, parent: Instance?): Model
	local s = newScale(rng, scale)
	local m = Build.Model("Bush")
	local v = rng:NextInteger(1, 3)
	local main: BasePart
	if v == 1 then
		main = Build.Ball("Bush", 4.4 * s, CFrame.new(0, 1.6 * s, 0), shade(rng, BUSH, 0.06), M.LeafyGrass, m)
		local n = rng:NextInteger(2, 3)
		local a0 = rng:NextNumber(0, TAU)
		for i = 1, n do
			local a = a0 + i * TAU / n + rng:NextNumber(-0.3, 0.3)
			local r = rng:NextNumber(2.8, 3.6) * s
			Build.Ball("Bush", r, CFrame.new(math.cos(a) * 1.8 * s, r * 0.38, math.sin(a) * 1.8 * s), shade(rng, BUSH, 0.08), M.LeafyGrass, m)
		end
	elseif v == 2 then
		main = Build.Ball("Bush", 2.4 * s, CFrame.new(0, 0.8 * s, 0), shade(rng, BUSH, 0.06), M.Grass, m)
		local a0 = rng:NextNumber(0, TAU)
		for i = 0, 3 do
			local h = rng:NextNumber(3, 4.2) * s
			block("Blade", Vector3.new(0.3 * s, h, 1.6 * s), CFrame.Angles(0, a0 + i * TAU / 4, 0) * CFrame.new(0, h * 0.45, 0.5 * s) * CFrame.Angles(math.rad(rng:NextNumber(18, 32)), 0, 0),
				shade(rng, GRASS, 0.08), M.Grass, m, "WedgePart")
		end
	else
		main = Build.Ball("Bush", 3.8 * s, CFrame.new(0, 1.4 * s, 0), shade(rng, BUSH, 0.06), M.LeafyGrass, m)
		Build.Ball("Bush", 2.8 * s, CFrame.new(1.5 * s, 1.0 * s, 0.6 * s), shade(rng, BUSH, 0.08), M.LeafyGrass, m)
		local fc = pick(rng, FLOWER)
		for _ = 1, 3 do
			local a = rng:NextNumber(0, TAU)
			local el = rng:NextNumber(0.3, 1.2)
			local dir = Vector3.new(math.cos(el) * math.cos(a), math.sin(el), math.cos(el) * math.sin(a))
			Build.Ball("Flower", 0.7 * s, CFrame.new(Vector3.new(0, 1.4 * s, 0) + dir * 1.85 * s), vary(rng, fc, 0.08), M.SmoothPlastic, m)
		end
	end
	return finish(m, main, cf, parent, true)
end

--------------------------------------------------------------------------------
-- Ground cover (<= 4 parts, no shadows, no collision)
--------------------------------------------------------------------------------

--- Fern: arching wedge fronds. Variants: upright, spreading, fiddlehead. Parts: 4.
function Flora.Fern(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("Fern")
	local v = rng:NextInteger(1, 3)
	local tilt = if v == 1 then 28 else 55
	local n = if v == 3 then 3 else 4
	local a0 = rng:NextNumber(0, TAU)
	local first: BasePart
	for i = 0, n - 1 do
		local len = rng:NextNumber(2.4, 3.2)
		local f = block("Frond", Vector3.new(0.18, len, 1.1), CFrame.Angles(0, a0 + i * TAU / n + rng:NextNumber(-0.25, 0.25), 0) * CFrame.new(0, len * 0.4, 0.7) * CFrame.Angles(math.rad(tilt + rng:NextNumber(-8, 8)), 0, 0),
			shade(rng, FERN, 0.07), M.Grass, m, "WedgePart")
		first = first or f
	end
	if v == 3 then
		Build.Ball("Fiddlehead", 0.6, CFrame.new(0.1, 1.2, 0), vary(rng, FERN[1], 0.08), M.Grass, m)
	end
	return finish(m, first, cf, parent, true)
end

--- Tall grass tuft: 3-4 blade wedges; green or dry. Parts: <= 4.
function Flora.TallGrass(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("TallGrass")
	local pal = if rng:NextNumber() < 0.25 then GRASS_DRY else GRASS
	local n = rng:NextInteger(3, 4)
	local first: BasePart
	for i = 1, n do
		local h = rng:NextNumber(1.8, 3.2)
		local b = block("Blade", Vector3.new(0.12, h, rng:NextNumber(0.6, 1.0)),
			CFrame.new(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.4, 0.4)) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0) * CFrame.Angles(math.rad(rng:NextNumber(-14, 14)), 0, 0) * CFrame.new(0, h / 2, 0),
			shade(rng, pal, 0.08), M.Grass, m, "WedgePart")
		first = first or b
	end
	return finish(m, first, cf, parent, true)
end

--- Flower patch: a leafy clump with 3 blossoms of one or two colours. Parts: 4.
function Flora.FlowerPatch(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("FlowerPatch")
	local base = Build.Cyl("Leaves", 0.4, rng:NextNumber(1.8, 2.4), CFrame.new(0, 0.2, 0), shade(rng, GRASS, 0.06), M.Grass, m, false)
	local c1, c2 = pick(rng, FLOWER), pick(rng, FLOWER)
	for i = 1, 3 do
		local a = rng:NextNumber(0, TAU)
		local dist = rng:NextNumber(0.2, 0.8)
		Build.Ball("Flower", rng:NextNumber(0.45, 0.65), CFrame.new(math.cos(a) * dist, rng:NextNumber(0.6, 1.1), math.sin(a) * dist), vary(rng, if i == 3 then c2 else c1, 0.08), M.SmoothPlastic, m)
	end
	return finish(m, base, cf, parent, true)
end

--- Mushrooms: red toadstool pair, or brown flat-cap pair. Parts: 4.
function Flora.Mushrooms(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("Mushrooms")
	local red = rng:NextNumber() < 0.4
	local first: BasePart
	for i = 0, 1 do
		local h = if i == 0 then rng:NextNumber(0.8, 1.2) else rng:NextNumber(0.4, 0.7)
		local p = if i == 0 then Vector3.zero else Vector3.new(rng:NextNumber(-0.7, 0.7), 0, rng:NextNumber(0.4, 0.7))
		local st = Build.Cyl("Stem", h, 0.28, CFrame.new(p + Vector3.new(0, h / 2, 0)), STEM, M.SmoothPlastic, m, false)
		first = first or st
		if red then
			Build.Ball("Cap", h * 0.9 + 0.3, CFrame.new(p + Vector3.new(0, h, 0)), vary(rng, CAP_RED, 0.08), M.SmoothPlastic, m)
		else
			Build.Cyl("Cap", 0.25, h + 0.3, CFrame.new(p + Vector3.new(0, h, 0)) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15)), vary(rng, CAP_BROWN, 0.1), M.SmoothPlastic, m, false)
		end
	end
	return finish(m, first, cf, parent, true)
end

--- Surface roots: 3-4 half-buried arcs radiating from a point. Parts: <= 4.
function Flora.Roots(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("Roots")
	local n = rng:NextInteger(3, 4)
	local bark = vary(rng, BARK, 0.1)
	local a0 = rng:NextNumber(0, TAU)
	local first: BasePart
	for i = 1, n do
		local a = a0 + i * TAU / n + rng:NextNumber(-0.4, 0.4)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local r = limb("Root", dir * 0.3 + Vector3.new(0, 0.5, 0), dir * rng:NextNumber(2.5, 4) + Vector3.new(0, -0.3, 0), rng:NextNumber(0.4, 0.7), bark, M.Wood, m, false)
		first = first or r
	end
	return finish(m, first, cf, parent, true)
end

--- Moss patch: 2-3 overlapping flat pads. Parts: <= 3.
function Flora.MossPatch(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("MossPatch")
	local n = rng:NextInteger(2, 3)
	local first: BasePart
	for i = 1, n do
		local p = if i == 1 then Vector3.zero else Vector3.new(rng:NextNumber(-1.2, 1.2), 0, rng:NextNumber(-1.2, 1.2))
		local pad = Build.Cyl("Moss", 0.18 + i * 0.03, rng:NextNumber(1.8, 3.2), CFrame.new(p + Vector3.new(0, 0.06, 0)), shade(rng, MOSS, 0.08), if i == 2 then M.LeafyGrass else M.Grass, m, false)
		first = first or pad
	end
	return finish(m, first, cf, parent, true)
end

--- Leaf litter: 3-4 thin autumn-coloured flakes. Parts: <= 4.
function Flora.LeafLitter(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("LeafLitter")
	local n = rng:NextInteger(3, 4)
	local first: BasePart
	for _ = 1, n do
		local b = block("Leaves", Vector3.new(rng:NextNumber(1.2, 2.2), 0.08, rng:NextNumber(1.0, 1.8)),
			CFrame.new(rng:NextNumber(-1, 1), 0.05, rng:NextNumber(-1, 1)) * spin(rng) * CFrame.Angles(rng:NextNumber(-0.05, 0.05), 0, rng:NextNumber(-0.05, 0.05)),
			shade(rng, LITTER, 0.1), M.Grass, m)
		first = first or b
	end
	return finish(m, first, cf, parent, true)
end

--- Twigs: 3-4 thin sticks lying on the ground. Parts: <= 4.
function Flora.Twigs(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("Twigs")
	local n = rng:NextInteger(3, 4)
	local first: BasePart
	for _ = 1, n do
		local c = Vector3.new(rng:NextNumber(-0.8, 0.8), 0.1, rng:NextNumber(-0.8, 0.8))
		local a = rng:NextNumber(0, TAU)
		local half = Vector3.new(math.cos(a), 0.03, math.sin(a)) * rng:NextNumber(0.6, 1.2)
		local t = limb("Twig", c - half, c + half, rng:NextNumber(0.12, 0.2), vary(rng, pick(rng, { BARK, BARK_GREY, BARK_DARK }), 0.1), M.Wood, m, false)
		first = first or t
	end
	return finish(m, first, cf, parent, true)
end

--- Pebbles: 3-4 small stones. Parts: <= 4.
function Flora.Pebbles(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("Pebbles")
	local n = rng:NextInteger(3, 4)
	local pal = if rng:NextNumber() < 0.5 then ROCK else ROCK_WARM
	local first: BasePart
	for _ = 1, n do
		local s = Vector3.new(rng:NextNumber(0.4, 0.9), rng:NextNumber(0.25, 0.5), rng:NextNumber(0.4, 0.8))
		local p = block("Pebble", s, CFrame.new(rng:NextNumber(-1, 1), s.Y * 0.35, rng:NextNumber(-1, 1)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, TAU), rng:NextNumber(-0.3, 0.3)),
			shade(rng, pal, 0.1), pick(rng, { M.Pebble, M.Slate, M.Rock }), m)
		first = first or p
	end
	return finish(m, first, cf, parent, true)
end

--------------------------------------------------------------------------------
-- Rocks and water
--------------------------------------------------------------------------------

--- Boulder. Variants: rounded (ball + block), flat slab, stacked, mossy cap.
--- All rock parts collide. Parts: <= 4.
function Flora.Boulder(cf: CFrame, rng: Random, scale: number?, parent: Instance?): Model
	local s = newScale(rng, scale)
	local m = Build.Model("Boulder")
	local pal = if rng:NextNumber() < 0.6 then ROCK else ROCK_WARM
	local mat = pick(rng, { M.Rock, M.Slate, M.Basalt })
	local v = rng:NextInteger(1, 4)
	local main: BasePart
	local function rot()
		return CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, TAU), rng:NextNumber(-0.25, 0.25))
	end
	if v == 1 then
		local d = rng:NextNumber(4.5, 6) * s
		main = Build.Ball("Rock", d, CFrame.new(0, d * 0.3, 0), shade(rng, pal, 0.06), mat, m, true)
		solid("Rock", Vector3.new(d * 0.7, d * 0.5, d * 0.6), CFrame.new(d * 0.3, d * 0.2, d * 0.1) * rot(), shade(rng, pal, 0.08), mat, m)
	elseif v == 2 then
		local sz = Vector3.new(rng:NextNumber(6, 9), rng:NextNumber(1.6, 2.4), rng:NextNumber(4, 6)) * s
		main = solid("Rock", sz, CFrame.new(0, sz.Y * 0.4, 0) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(0, TAU), rng:NextNumber(-0.12, 0.12)), shade(rng, pal, 0.06), mat, m)
		solid("Rock", sz * Vector3.new(0.45, 0.8, 0.5), CFrame.new(sz.X * 0.35, sz.Y * 0.35, sz.Z * 0.25) * rot(), shade(rng, pal, 0.08), mat, m, "WedgePart")
	elseif v == 3 then
		local base = Vector3.new(rng:NextNumber(4, 5.5), rng:NextNumber(2.6, 3.4), rng:NextNumber(3.6, 5)) * s
		main = solid("Rock", base, CFrame.new(0, base.Y * 0.42, 0) * rot(), shade(rng, pal, 0.06), mat, m)
		local up = base * Vector3.new(0.6, 0.7, 0.6)
		solid("Rock", up, CFrame.new(rng:NextNumber(-0.5, 0.5) * s, base.Y * 0.85 + up.Y * 0.4, rng:NextNumber(-0.5, 0.5) * s) * rot(), shade(rng, pal, 0.08), mat, m)
		solid("Rock", base * Vector3.new(0.35, 0.4, 0.35), CFrame.new(base.X * 0.55, base.Y * 0.15, -base.Z * 0.3) * rot(), shade(rng, pal, 0.08), mat, m)
	else
		local d = rng:NextNumber(5, 7) * s
		main = Build.Ball("Rock", d, CFrame.new(0, d * 0.28, 0), shade(rng, pal, 0.06), mat, m, true)
		solid("Rock", Vector3.new(d * 0.8, d * 0.45, d * 0.7), CFrame.new(-d * 0.25, d * 0.15, 0) * rot(), shade(rng, pal, 0.08), mat, m)
		Build.Ball("Moss", d * 0.72, CFrame.new(d * 0.05, d * 0.47, 0), shade(rng, MOSS, 0.06), M.LeafyGrass, m)
	end
	return finish(m, main, cf, parent)
end

--- Cliff rock: a jagged wall segment of roughly `size` (X = length, Y = height,
--- Z = thickness), bottom slightly buried. Parts: <= 10.
function Flora.CliffRock(cf: CFrame, rng: Random, size: Vector3, parent: Instance?): Model
	local m = Build.Model("CliffRock")
	local mat = pick(rng, { M.Slate, M.Rock, M.Basalt })
	local pal = if mat == M.Basalt then { Color3.fromRGB(78, 78, 84), Color3.fromRGB(92, 90, 94), Color3.fromRGB(70, 70, 76) } else ROCK
	local W, H, D = size.X, size.Y, size.Z
	local core = solid("Rock", Vector3.new(W * 0.9, H * 0.82, D * 0.8), CFrame.new(0, H * 0.82 / 2 - 0.5, 0), shade(rng, pal, 0.05), mat, m) -- 1
	local k = rng:NextInteger(5, 7)
	local topY = 0
	for i = 1, k do -- <= 8: jagged faces/crags
		local x = -W / 2 + (i - 0.5) * W / k + rng:NextNumber(-0.15, 0.15) * W / k
		local h = H * rng:NextNumber(0.55, 1.05)
		topY = math.max(topY, h)
		local sz = Vector3.new(W / k * rng:NextNumber(1.1, 1.5), h, D * rng:NextNumber(0.6, 1.05))
		local z = rng:NextNumber(-0.2, 0.2) * D
		solid("Rock", sz, CFrame.new(x, h / 2 - 0.6, z) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(-0.25, 0.25), rng:NextNumber(-0.1, 0.1)),
			shade(rng, pal, 0.08), mat, m, if rng:NextNumber() < 0.2 then "WedgePart" else nil)
	end
	block("Moss", Vector3.new(W * 0.7, 0.5, D * 0.5), CFrame.new(rng:NextNumber(-0.1, 0.1) * W, H * 0.82 - 0.35, 0), shade(rng, MOSS, 0.06), M.Grass, m) -- 9
	solid("Scree", Vector3.new(W * 0.4, math.min(H * 0.25, 3), D * 0.5), CFrame.new(rng:NextNumber(-0.25, 0.25) * W, math.min(H * 0.25, 3) / 2 - 0.2, D * 0.55) * CFrame.Angles(0, if rng:NextNumber() < 0.5 then 0 else math.pi, 0),
		shade(rng, pal, 0.08), mat, m, "WedgePart") -- 10
	return finish(m, core, cf, parent)
end

--- Waterfall rocks: 2-4 stepped rock ledges descending toward +Z, each with a
--- side boulder and a thin translucent water sheet over its lip, a pool rim at
--- the bottom and a mist ParticleEmitter. `height` = top ledge height.
--- Parts: 3 per step + 2 (<= 14).
function Flora.WaterfallRocks(cf: CFrame, rng: Random, height: number, parent: Instance?): Model
	local m = Build.Model("WaterfallRocks")
	local mat = if rng:NextNumber() < 0.5 then M.Slate else M.Rock
	local n = math.clamp(math.floor(height / 4 + 0.5), 2, 4)
	local stepD = rng:NextNumber(4, 5.5)
	local W = rng:NextNumber(9, 12)
	local waterW = W * rng:NextNumber(0.35, 0.5)
	local z0 = -(n * stepD) / 2
	local first: BasePart
	for i = 1, n do
		local top = height * (1 - (i - 1) / n)
		local nextTop = if i < n then height * (1 - i / n) else 0
		local z = z0 + (i - 0.5) * stepD
		local ledge = solid("Rock", Vector3.new(W * rng:NextNumber(0.9, 1.05), top + 0.6, stepD * 1.08),
			CFrame.new(rng:NextNumber(-0.3, 0.3), (top + 0.6) / 2 - 0.6, z) * CFrame.Angles(0, rng:NextNumber(-0.05, 0.05), 0),
			shade(rng, ROCK, 0.06), mat, m)
		first = first or ledge
		local side = if rng:NextNumber() < 0.5 then 1 else -1
		local bs = Vector3.new(rng:NextNumber(2.5, 3.5), top * 0.35 + rng:NextNumber(1.5, 2.5), rng:NextNumber(2.5, 3.5))
		solid("Rock", bs, CFrame.new(side * W * 0.42, top + bs.Y * 0.3, z + rng:NextNumber(-0.8, 0.8)) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, TAU), rng:NextNumber(-0.2, 0.2)),
			shade(rng, ROCK, 0.08), mat, m)
		local drop = top - nextTop + 0.4
		local sheet = block("Water", Vector3.new(waterW, drop, 0.25), CFrame.new(0, nextTop + drop / 2 - 0.2, z + stepD * 0.54 + 0.15), WATER, M.Glass, m)
		sheet.Transparency = 0.35
		sheet.CastShadow = false
	end
	local zEnd = z0 + n * stepD
	local pool = block("PoolRim", Vector3.new(W * 0.9, 0.5, 3), CFrame.new(0, 0.1, zEnd + 3.2), shade(rng, ROCK, 0.08), mat, m)
	pool.CastShadow = false
	local mistPart = block("Mist", Vector3.new(waterW, 0.2, 1), CFrame.new(0, 0.3, zEnd + 1), WATER, M.SmoothPlastic, m)
	mistPart.Transparency = 1
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Mist"
	pe.Rate = 14
	pe.Lifetime = NumberRange.new(1.5, 2.8)
	pe.Speed = NumberRange.new(1.5, 3.5)
	pe.SpreadAngle = Vector2.new(50, 50)
	pe.EmissionDirection = Enum.NormalId.Top
	pe.Acceleration = Vector3.new(0, 0.8, 0)
	pe.Drag = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 5) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	pe.Color = ColorSequence.new(Color3.fromRGB(235, 245, 255))
	pe.LightEmission = 0.2
	pe.Parent = mistPart
	return finish(m, first, cf, parent)
end

--- Decorative tree builder names (all take `(cf, rng, scale?, parent)`), for random picking.
Flora.DecorKinds = { "Pine", "Spruce", "Oak", "Birch", "Aspen" }

return Flora

end)()
local __m_Camp = (function()
-- Camp models: campfire (burning / extinguished states), workbench (3 levels),
-- spawn pads, banners and a clan-themed hut. Pivot = ground centre.

local Build = __m_Build
local Skins = __m_Skins

local Camp = {}

local STONE = Color3.fromRGB(120, 118, 112)
local WOOD = Color3.fromRGB(130, 92, 58)
local WOOD_DARK = Color3.fromRGB(92, 64, 40)
local CHAR = Color3.fromRGB(40, 34, 30)

local function place(m: Model, primary: BasePart, cf: CFrame, parent: Instance?): Model
	Build.SetPivot(m, primary, CFrame.new())
	m:PivotTo(cf)
	if parent then
		m.Parent = parent
	end
	return m
end

function Camp.Campfire(cf: CFrame, teamColor: Color3, parent: Instance?): Model
	local m = Build.Model("Campfire")
	local base = Build.Part({ Name = "Hearth", Size = Vector3.new(7, 0.6, 7), CFrame = CFrame.new(0, 0.3, 0), Color = Color3.fromRGB(70, 62, 56), Material = Enum.Material.Slate, Parent = m })
	-- stone ring
	for i = 0, 9 do
		local a = math.rad(i * 36)
		Build.Part({ Name = "RingStone", Size = Vector3.new(1.6, 1.2, 1.3), CFrame = CFrame.new(math.cos(a) * 3.6, 0.6, math.sin(a) * 3.6) * CFrame.Angles(0, -a, 0.1 * (i % 3)), Color = if i % 2 == 0 then STONE else Color3.fromRGB(100, 98, 94), Material = Enum.Material.Slate, Parent = m })
	end
	-- logs in a teepee
	for i = 0, 4 do
		local a = math.rad(i * 72)
		Build.Part({ Name = "Log", Size = Vector3.new(0.9, 4.6, 0.9), CFrame = CFrame.new(math.cos(a) * 0.9, 1.9, math.sin(a) * 0.9) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, math.rad(-22)), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = m, CanCollide = false })
	end
	local embers = Build.Decor({ Name = "Embers", Size = Vector3.new(3, 0.4, 3), CFrame = CFrame.new(0, 0.7, 0), Color = Color3.fromRGB(255, 120, 40), Material = Enum.Material.Neon, Parent = m })
	local core = Build.Decor({ Name = "FireCore", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(0, 2.6, 0), Transparency = 1, Parent = m })

	local fire = Instance.new("Fire")
	fire.Name = "Flame"
	fire.Size = 9
	fire.Heat = 14
	fire.Color = Color3.fromRGB(255, 140, 50)
	fire.SecondaryColor = Color3.fromRGB(255, 220, 90)
	fire.Parent = core

	local light = Instance.new("PointLight")
	light.Name = "Glow"
	light.Range = 40
	light.Brightness = 2.2
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Shadows = true
	light.Parent = core

	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Rate = 8
	sparks.Lifetime = NumberRange.new(1, 2)
	sparks.Speed = NumberRange.new(4, 8)
	sparks.SpreadAngle = Vector2.new(20, 20)
	sparks.Size = NumberSequence.new(0.25, 0)
	sparks.LightEmission = 1
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 80, 20))
	sparks.Acceleration = Vector3.new(0, 3, 0)
	sparks.Parent = core

	local smoke = Instance.new("Smoke")
	smoke.Name = "Smoke"
	smoke.Color = Color3.fromRGB(90, 90, 90)
	smoke.Opacity = 0.15
	smoke.RiseVelocity = 4
	smoke.Size = 2
	smoke.Enabled = false
	smoke.Parent = core
	-- a smoke column that rises above the canopy: bigger fires are seen from further away
	-- (the trade-off: a strong fire keeps you alive and gives your camp away)
	local column = Instance.new("ParticleEmitter")
	column.Name = "SmokeColumn"
	column.Texture = "rbxasset://textures/particles/smoke_main.dds"
	column.Color = ColorSequence.new(Color3.fromRGB(120, 118, 115))
	column.LightInfluence = 0.8
	column.Rate = 0
	column.Lifetime = NumberRange.new(9, 13)
	column.Speed = NumberRange.new(6, 9)
	column.SpreadAngle = Vector2.new(8, 8)
	column.Acceleration = Vector3.new(1.2, 0.6, 0.4) -- a slight drift with the wind
	column.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 16) })
	column.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(0.3, 0.72), NumberSequenceKeypoint.new(1, 1) })
	column.RotSpeed = NumberRange.new(-10, 10)
	column.Rotation = NumberRange.new(0, 360)
	column.EmissionDirection = Enum.NormalId.Top
	column.Parent = core

	-- Light-radius ring (visible guide for "animals avoid this"), faint team tint.
	local ring = Build.Decor({ Name = "SafeRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 90, 90), CFrame = CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = teamColor, Material = Enum.Material.ForceField, Transparency = 0.85, Parent = m, CastShadow = false })
	ring:SetAttribute("TeamTint", true)

	embers:SetAttribute("Burning", true)
	place(m, base, cf, parent)
	-- mesh-pack look; the Fire/Glow/Sparks/Smoke on FireCore and the team SafeRing stay
	if Skins.Enabled() then
		Skins.Dress(m, "SM_Campfire_Burning", { scale = 1.2, keep = { SafeRing = true } })
	end
	return m
end

-- Burning look for a fire level (1-5) and fuel (0..1): higher levels are bigger,
-- brighter and smokier; a nearly empty fire shrinks so owners can read it at a glance.
function Camp.SetFire(m: Model, level: number, fuel: number)
	local core = m:FindFirstChild("FireCore")
	if not core then
		return
	end
	local lv = math.clamp(level, 1, 5) - 1
	local f = 0.45 + 0.55 * math.clamp(fuel / 0.3, 0, 1) -- full size above 30% fuel
	local flame = core:FindFirstChild("Flame") :: Fire?
	if flame and flame.Enabled then
		flame.Size = (9 + lv * 2.2) * f
		flame.Heat = 14 + lv * 3
	end
	local glow = core:FindFirstChild("Glow") :: PointLight?
	if glow and glow.Enabled then
		glow.Range = math.min(60, (40 + lv * 5) * (0.6 + 0.4 * f))
		glow.Brightness = (2.2 + lv * 0.35) * f
		-- a starving fire burns deep red; a healthy one warm gold
		if not m:GetAttribute("FlameSkin") then
			local starving = math.clamp(1 - fuel / 0.15, 0, 1)
			glow.Color = Color3.fromRGB(255, 190, 110):Lerp(Color3.fromRGB(255, 90, 40), starving)
		end
	end
	if flame and flame.Enabled and not m:GetAttribute("FlameSkin") then
		local starving = math.clamp(1 - fuel / 0.15, 0, 1)
		flame.Color = Color3.fromRGB(255, 150, 50):Lerp(Color3.fromRGB(200, 60, 20), starving)
		flame.SecondaryColor = Color3.fromRGB(255, 220, 120):Lerp(Color3.fromRGB(120, 30, 10), starving)
	end
	local sparks = core:FindFirstChild("Sparks") :: ParticleEmitter?
	if sparks and sparks.Enabled then
		sparks.Rate = (8 + lv * 5) * f
	end
	local smoke = core:FindFirstChild("Smoke") :: Smoke?
	if smoke then
		smoke.Enabled = lv > 0
		smoke.Opacity = 0.08 + lv * 0.05
		smoke.Size = 2 + lv
	end
	local column = core:FindFirstChild("SmokeColumn") :: ParticleEmitter?
	if column then
		-- tier sets how tall/thick the column is; a starving fire smoulders dark and heavy
		local starving = math.clamp(1 - fuel / 0.15, 0, 1)
		column.Rate = if flame and flame.Enabled then 0.8 + lv * 0.9 + starving * 1.5 else 0
		column.Speed = NumberRange.new(6 + lv, 9 + lv * 1.5)
		column.Color = ColorSequence.new(Color3.fromRGB(120, 118, 115):Lerp(Color3.fromRGB(45, 42, 40), starving))
	end
end

-- Switches a campfire model to its extinguished look (permanent).
function Camp.Extinguish(m: Model)
	Skins.Swap(m, "SM_Campfire_Extinguished")
	local core = m:FindFirstChild("FireCore")
	if core then
		local flame = core:FindFirstChild("Flame") :: Fire?
		if flame then
			flame.Enabled = false
		end
		local glow = core:FindFirstChild("Glow") :: PointLight?
		if glow then
			glow.Enabled = false
		end
		local column = core:FindFirstChild("SmokeColumn") :: ParticleEmitter?
		if column then
			column.Rate = 0
		end
		local sparks = core:FindFirstChild("Sparks") :: ParticleEmitter?
		if sparks then
			sparks.Enabled = false
		end
		local smoke = core:FindFirstChild("Smoke") :: Smoke?
		if smoke then
			smoke.Enabled = true
			smoke.Opacity = 0.35
		end
	end
	local embers = m:FindFirstChild("Embers") :: BasePart?
	if embers then
		embers.Color = CHAR
		embers.Material = Enum.Material.Slate
	end
	for _, d in m:GetChildren() do
		if d:IsA("BasePart") and d.Name == "Log" then
			d.Color = CHAR
		end
	end
	local ring = m:FindFirstChild("SafeRing") :: BasePart?
	if ring then
		ring.Transparency = 1
	end
end

-- Workbench. Level changes add visible upgrades (vice, tool rack, anvil + banner).
function Camp.Workbench(cf: CFrame, level: number, teamColor: Color3, parent: Instance?): Model
	local m = Build.Model("Workbench")
	local top = Build.Part({ Name = "Top", Size = Vector3.new(8, 0.8, 4), CFrame = CFrame.new(0, 3.4, 0), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = m })
	for _, x in { -3.4, 3.4 } do
		for _, z in { -1.5, 1.5 } do
			Build.Part({ Name = "Leg", Size = Vector3.new(0.7, 3, 0.7), CFrame = CFrame.new(x, 1.5, z), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = m })
		end
	end
	Build.Part({ Name = "Shelf", Size = Vector3.new(7.4, 0.4, 3.4), CFrame = CFrame.new(0, 1, 0), Color = WOOD_DARK, Material = Enum.Material.WoodPlanks, Parent = m, CanCollide = false })
	-- level 1: saw + log
	Build.Decor({ Name = "Saw", Size = Vector3.new(3, 0.1, 0.8), CFrame = CFrame.new(-1.5, 3.85, 0.6), Color = Color3.fromRGB(190, 190, 196), Material = Enum.Material.Metal, Parent = m })
	Build.Cyl("LogPiece", 2.2, 1.2, CFrame.new(2.2, 4.4, -0.6) * CFrame.Angles(math.rad(90), 0, 0), WOOD, Enum.Material.Wood, m, false)
	if level >= 2 then
		-- tool rack with rope coil
		Build.Part({ Name = "Rack", Size = Vector3.new(8, 4, 0.4), CFrame = CFrame.new(0, 5.8, 1.9), Color = WOOD_DARK, Material = Enum.Material.WoodPlanks, Parent = m, CanCollide = false })
		Build.Cyl("Rope", 0.6, 1.6, CFrame.new(-2.5, 6, 1.6) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(205, 180, 120), Enum.Material.Fabric, m, false)
		Build.Decor({ Name = "Hide", Size = Vector3.new(2.2, 2.4, 0.15), CFrame = CFrame.new(1.6, 6, 1.65), Color = Color3.fromRGB(150, 92, 60), Material = Enum.Material.Fabric, Parent = m })
	end
	if level >= 3 then
		-- anvil + team pennant
		Build.Part({ Name = "Anvil", Size = Vector3.new(2.2, 1.2, 1.2), CFrame = CFrame.new(5.6, 2.2, 0), Color = Color3.fromRGB(70, 72, 78), Material = Enum.Material.Metal, Parent = m })
		Build.Part({ Name = "AnvilBase", Size = Vector3.new(1.2, 1.6, 1.2), CFrame = CFrame.new(5.6, 0.8, 0), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = m })
		Build.Decor({ Name = "Pennant", Class = "WedgePart", Size = Vector3.new(0.1, 2.4, 3), CFrame = CFrame.new(-4.2, 7.6, 1.9) * CFrame.Angles(0, math.rad(90), math.rad(180)), Color = teamColor, Material = Enum.Material.Fabric, Parent = m })
	end
	if level >= 4 then
		-- Tier IV: stone forge with glowing coals and a chimney
		Build.Part({ Name = "Forge", Size = Vector3.new(3.4, 2.6, 3), CFrame = CFrame.new(-6.4, 1.3, 0.4), Color = Color3.fromRGB(96, 90, 86), Material = Enum.Material.Brick, Parent = m })
		local coals = Build.Decor({ Name = "ForgeCoals", Size = Vector3.new(2.4, 0.3, 2), CFrame = CFrame.new(-6.4, 2.7, 0.4), Color = Color3.fromRGB(255, 110, 40), Material = Enum.Material.Neon, Parent = m })
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 140, 70)
		glow.Range = 12
		glow.Brightness = 1.4
		glow.Parent = coals
		Build.Part({ Name = "ForgeChimney", Size = Vector3.new(1.4, 5, 1.4), CFrame = CFrame.new(-6.9, 5.2, 1.3), Color = Color3.fromRGB(80, 76, 72), Material = Enum.Material.Brick, Parent = m, CanCollide = false })
	end
	if level >= 5 then
		-- Tier V: steel-plated top and a rack of steel tools
		Build.Decor({ Name = "SteelPlate", Size = Vector3.new(8.1, 0.12, 4.1), CFrame = CFrame.new(0, 3.86, 0), Color = Color3.fromRGB(170, 176, 186), Material = Enum.Material.DiamondPlate, Parent = m })
		for i = -1, 1 do
			Build.Decor({ Name = "SteelTool", Size = Vector3.new(0.25, 2.6, 0.25), CFrame = CFrame.new(i * 1.6 + 0.5, 6.4, 1.62), Color = Color3.fromRGB(196, 202, 212), Material = Enum.Material.Metal, Parent = m })
		end
	end
	local lvl = Build.Decor({ Name = "LevelPlate", Size = Vector3.new(2.4, 1, 0.1), CFrame = CFrame.new(0, 2.6, -2.05), Color = teamColor, Material = Enum.Material.SmoothPlastic, Parent = m })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(120, 50)
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Text = ({ "I", "II", "III", "IV", "V" })[level] or ("LV " .. level)
	tl.Font = Enum.Font.GothamBlack
	tl.TextScaled = true
	tl.TextColor3 = Color3.new(1, 1, 1)
	tl.Parent = sg
	sg.Parent = lvl
	m:SetAttribute("Level", level)
	place(m, top, cf, parent)
	if Skins.Enabled() then
		-- Tier IV/V have their own meshes (forge, steel top); without them the L3 mesh
		-- is used and the procedural forge / steel parts stay visible.
		local own = level >= 4 and Skins.Has("SM_Workbench_Level0" .. math.min(level, 5))
		local name = if own then "SM_Workbench_Level0" .. math.min(level, 5) else "SM_Workbench_Level0" .. math.clamp(level, 1, 3)
		local scale = if own then 1.0 else ({ 1.3, 1.12, 1.0 })[math.clamp(level, 1, 3)]
		local keep = if own then { Pennant = true, ForgeCoals = true } else { Pennant = true, Forge = true, ForgeCoals = true, ForgeChimney = true, SteelPlate = true, SteelTool = true }
		Skins.Dress(m, name, { scale = scale, keep = keep })
	end
	return m
end

function Camp.SpawnPad(cf: CFrame, teamColor: Color3, parent: Instance?): Model
	local m = Build.Model("SpawnPad")
	local pad = Build.Part({ Name = "Pad", Size = Vector3.new(5, 0.4, 5), CFrame = CFrame.new(0, 0.2, 0), Color = Color3.fromRGB(120, 100, 80), Material = Enum.Material.WoodPlanks, Parent = m })
	Build.Decor({ Name = "Mark", Size = Vector3.new(3, 0.1, 3), CFrame = CFrame.new(0, 0.45, 0) * CFrame.Angles(0, math.rad(45), 0), Color = teamColor, Material = Enum.Material.Fabric, Parent = m, CastShadow = false })
	return place(m, pad, cf, parent)
end

function Camp.Banner(cf: CFrame, teamColor: Color3, symbol: string, parent: Instance?): Model
	local m = Build.Model("Banner")
	local pole = Build.Cyl("Pole", 14, 0.6, CFrame.new(0, 7, 0), WOOD_DARK, Enum.Material.Wood, m)
	Build.Part({ Name = "Cross", Size = Vector3.new(5, 0.4, 0.4), CFrame = CFrame.new(0, 13.4, 0), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = m, CanCollide = false })
	local cloth = Build.Decor({ Name = "Cloth", Size = Vector3.new(4.4, 6, 0.15), CFrame = CFrame.new(0, 10.2, 0.2), Color = teamColor, Material = Enum.Material.Fabric, Parent = m })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.CanvasSize = Vector2.new(100, 140)
		sg.LightInfluence = 1
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.fromScale(1, 1)
		tl.BackgroundTransparency = 1
		tl.Text = symbol
		tl.TextScaled = true
		tl.Font = Enum.Font.GothamBlack
		tl.TextColor3 = Color3.fromRGB(255, 248, 230)
		tl.Parent = sg
		sg.Parent = cloth
	end
	return place(m, pole, cf, parent)
end

-- Decorative hut whose style depends on the clan motif.
function Camp.Hut(cf: CFrame, motif: string, teamColor: Color3, parent: Instance?): Model
	local m = Build.Model("Hut")
	local wallColor = if motif == "Cedar" then Color3.fromRGB(150, 84, 58)
		elseif motif == "Slate" then Color3.fromRGB(110, 114, 120)
		elseif motif == "Antler" then Color3.fromRGB(120, 100, 84)
		else Color3.fromRGB(170, 140, 90)
	local roofColor = if motif == "Slate" then Color3.fromRGB(70, 76, 88)
		elseif motif == "Thatch" then Color3.fromRGB(200, 170, 90)
		else Build.Tint(teamColor, 0.7)
	local roofMat = if motif == "Thatch" then Enum.Material.Grass elseif motif == "Slate" then Enum.Material.Slate else Enum.Material.WoodPlanks
	local floor = Build.Part({ Name = "Floor", Size = Vector3.new(12, 0.6, 10), CFrame = CFrame.new(0, 0.3, 0), Color = WOOD_DARK, Material = Enum.Material.WoodPlanks, Parent = m })
	Build.Part({ Name = "Back", Size = Vector3.new(12, 7, 0.8), CFrame = CFrame.new(0, 3.8, 4.6), Color = wallColor, Material = Enum.Material.WoodPlanks, Parent = m })
	Build.Part({ Name = "Side", Size = Vector3.new(0.8, 7, 9.2), CFrame = CFrame.new(5.6, 3.8, 0), Color = wallColor, Material = Enum.Material.WoodPlanks, Parent = m })
	Build.Part({ Name = "Side", Size = Vector3.new(0.8, 7, 9.2), CFrame = CFrame.new(-5.6, 3.8, 0), Color = wallColor, Material = Enum.Material.WoodPlanks, Parent = m })
	-- open front with posts
	for _, x in { -5.6, 5.6 } do
		Build.Part({ Name = "Post", Size = Vector3.new(0.9, 7, 0.9), CFrame = CFrame.new(x, 3.8, -4.6), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = m })
	end
	Build.Part({ Class = "WedgePart", Name = "Roof", Size = Vector3.new(13.4, 3.5, 5.8), CFrame = CFrame.new(0, 9.05, -2.5) * CFrame.Angles(0, math.rad(180), 0), Color = roofColor, Material = roofMat, Parent = m })
	Build.Part({ Class = "WedgePart", Name = "Roof", Size = Vector3.new(13.4, 3.5, 5.8), CFrame = CFrame.new(0, 9.05, 2.9), Color = roofColor, Material = roofMat, Parent = m })
	if motif == "Antler" then
		for _, x in { -2, 2 } do
			for i = 0, 2 do
				Build.Decor({ Name = "Antler", Size = Vector3.new(0.35, 2.2, 0.35), CFrame = CFrame.new(x, 11 + i * 0.6, 0.2) * CFrame.Angles(0, 0, math.rad((x > 0 and -1 or 1) * (20 + i * 25))), Color = Color3.fromRGB(230, 220, 196), Material = Enum.Material.SmoothPlastic, Parent = m })
			end
		end
	elseif motif == "Slate" then
		local lantern = Build.Decor({ Name = "Lantern", Size = Vector3.new(1, 1.4, 1), CFrame = CFrame.new(4.6, 6.4, -4.9), Color = teamColor, Material = Enum.Material.Neon, Parent = m })
		local l = Instance.new("PointLight")
		l.Color = teamColor
		l.Range = 14
		l.Brightness = 1.2
		l.Parent = lantern
	end
	-- bedrolls in team colour
	for _, x in { -3, 0, 3 } do
		Build.Decor({ Name = "Bedroll", Size = Vector3.new(2.2, 0.5, 5), CFrame = CFrame.new(x, 0.85, 1.4), Color = Build.Tint(teamColor, 0.85), Material = Enum.Material.Fabric, Parent = m })
	end
	return place(m, floor, cf, parent)
end

function Camp.Lantern(cf: CFrame, teamColor: Color3, parent: Instance?): Model
	local m = Build.Model("LanternPost")
	local post = Build.Cyl("Post", 7, 0.5, CFrame.new(0, 3.5, 0), WOOD_DARK, Enum.Material.Wood, m)
	Build.Part({ Name = "Arm", Size = Vector3.new(1.8, 0.3, 0.3), CFrame = CFrame.new(0.8, 6.8, 0), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = m, CanCollide = false })
	local lamp = Build.Decor({ Name = "Lamp", Size = Vector3.new(0.9, 1.2, 0.9), CFrame = CFrame.new(1.5, 6, 0), Color = Color3.fromRGB(255, 214, 140), Material = Enum.Material.Neon, Parent = m })
	local l = Instance.new("PointLight")
	l.Range = 16
	l.Brightness = 1.4
	l.Color = Color3.fromRGB(255, 200, 130):Lerp(teamColor, 0.25)
	l.Parent = lamp
	place(m, post, cf, parent)
	if Skins.Enabled() then
		Skins.Dress(m, "SM_Camp_Lantern", { scale = 1.3, offset = CFrame.Angles(0, math.pi, 0) }) -- the PointLight keeps working in the hidden lamp
	end
	return m
end

return Camp

end)()
local __m_Structures = (function()
-- Player-built structures. Each model's PrimaryPart is "Root": an invisible,
-- non-colliding box matching the footprint (Items[id].Size) with its bottom on
-- the ground. Visible parts carry collision. Pivot = ground centre.

local Build = __m_Build
local Skins = __m_Skins

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

end)()
local __m_ItemModels = (function()
-- Hand-held item models and world-pickup visuals.
-- Held models: PrimaryPart "Handle", built so that the Handle's CFrame is the
-- grip. The server welds Handle to the character's RightHand with `Grip`.

local Build = __m_Build
local Skins = __m_Skins

local ItemModels = {}

-- Mesh-pack look for held items. The pack's tools point their barrel/blade
-- along -Z with up +Y; this game's grips differ per item, so each entry maps
-- the pack frame onto this game's Handle frame.
local UP_TO_FORWARD = CFrame.Angles(0, 0, math.pi) * CFrame.Angles(-math.pi / 2, 0, 0) -- haft up -> haft along -Z, head up
local HELD_SKINS: { [string]: { string | CFrame } } = {
	Spear = { "Spear", CFrame.new() },
	Bow = { "Bow", CFrame.new() },
	HuntingBow = { "HuntingBow", CFrame.new() },
	Sword = { "Sword", UP_TO_FORWARD },
	Shield = { "Shield", CFrame.Angles(0, math.pi / 2, 0) },
	Pistol = { "Pistol", CFrame.new() },
	Rifle = { "Rifle", CFrame.new() },
	StoneAxe = { "StoneAxe", UP_TO_FORWARD },
	CrudeAxe = { "StoneAxe", UP_TO_FORWARD },
	IronAxe = { "Axe_Iron", UP_TO_FORWARD },
	SteelAxe = { "Axe_Iron", UP_TO_FORWARD },
	CrudePickaxe = { "Pickaxe_Stone", UP_TO_FORWARD },
	StonePickaxe = { "Pickaxe_Stone", UP_TO_FORWARD },
	IronPickaxe = { "Pickaxe_Iron", UP_TO_FORWARD },
	SteelPickaxe = { "Pickaxe_Iron", UP_TO_FORWARD },
	Crowbar = { "Crowbar", UP_TO_FORWARD },
	Sledgehammer = { "Sledgehammer", UP_TO_FORWARD },
	Crossbow = { "Crossbow", CFrame.new() },
	CrudeSpear = { "Spear", CFrame.new() },
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

-- Tiered axes and pickaxes (Crude / Stone / Iron / Steel). The pack has a stone axe
-- mesh (used for Crude + Stone); pickaxes and metal heads are procedural until the
-- Blender tool set covers them.
local TIER_HEAD = {
	Crude = { Color3.fromRGB(150, 146, 140), Enum.Material.Slate },
	Stone = { STONE, Enum.Material.Slate },
	Iron = { Color3.fromRGB(120, 110, 104), Enum.Material.Metal },
	Steel = { STEEL, Enum.Material.Metal },
}
for tn, head in TIER_HEAD do
	builders[tn .. "Axe"] = builders[tn .. "Axe"] or function(m)
		handle(m, Vector3.new(0.35, 0.35, 1), WOOD_DARK, Enum.Material.Wood)
		piece(m, { Name = "Haft", Size = Vector3.new(0.32, 0.32, 3.4), CFrame = CFrame.new(0, 0, -1.4), Color = WOOD, Material = Enum.Material.Wood })
		piece(m, { Name = "Head", Class = "WedgePart", Size = Vector3.new(0.45, 1.6, 1.3), CFrame = CFrame.new(0, 0.7, -2.9), Color = head[1], Material = head[2] })
		piece(m, { Name = "Lash", Size = Vector3.new(0.45, 0.5, 0.6), CFrame = CFrame.new(0, 0.15, -2.9), Color = if tn == "Crude" or tn == "Stone" then ROPE else Color3.fromRGB(70, 60, 50), Material = Enum.Material.Fabric })
	end
	builders[tn .. "Pickaxe"] = function(m)
		handle(m, Vector3.new(0.35, 0.35, 1), WOOD_DARK, Enum.Material.Wood)
		piece(m, { Name = "Haft", Size = Vector3.new(0.32, 0.32, 3.6), CFrame = CFrame.new(0, 0, -1.5), Color = WOOD, Material = Enum.Material.Wood })
		piece(m, { Name = "Pick", Class = "WedgePart", Size = Vector3.new(0.4, 0.5, 1.6), CFrame = CFrame.new(0, 0.9, -3.1) * CFrame.Angles(0, math.rad(180), 0), Color = head[1], Material = head[2] })
		piece(m, { Name = "Pick", Class = "WedgePart", Size = Vector3.new(0.4, 0.5, 1.6), CFrame = CFrame.new(0, -0.7, -3.1) * CFrame.Angles(math.rad(180), 0, 0), Color = head[1], Material = head[2] })
		piece(m, { Name = "Collar", Size = Vector3.new(0.5, 0.5, 0.6), CFrame = CFrame.new(0, 0.1, -3.1), Color = if tn == "Crude" or tn == "Stone" then ROPE else Color3.fromRGB(70, 60, 50), Material = Enum.Material.Fabric })
	end
end
builders.HuntingBow = function(m)
	builders.Bow(m)
	for _, d in m:GetChildren() do
		if d:IsA("BasePart") and string.find(d.Name, "^Limb") then
			d.Color = Color3.fromRGB(96, 60, 36)
		end
	end
end
builders.Crossbow = function(m)
	handle(m, Vector3.new(0.4, 0.8, 0.5), WOOD_DARK, Enum.Material.Wood)
	piece(m, { Name = "Stock", Size = Vector3.new(0.4, 0.4, 3), CFrame = CFrame.new(0, 0.35, -0.9), Color = WOOD, Material = Enum.Material.Wood })
	piece(m, { Name = "Prod", Size = Vector3.new(3.2, 0.25, 0.3), CFrame = CFrame.new(0, 0.45, -2.3), Color = Color3.fromRGB(110, 110, 116), Material = Enum.Material.Metal })
	piece(m, { Name = "String", Size = Vector3.new(3, 0.05, 0.05), CFrame = CFrame.new(0, 0.5, -1.7), Color = Color3.fromRGB(230, 226, 210), Material = Enum.Material.SmoothPlastic })
end
builders.Crowbar = function(m)
	handle(m, Vector3.new(0.3, 0.3, 1), Color3.fromRGB(150, 60, 50), Enum.Material.Metal)
	piece(m, { Name = "Bar", Size = Vector3.new(0.22, 0.22, 3), CFrame = CFrame.new(0, 0, -1.4), Color = Color3.fromRGB(150, 60, 50), Material = Enum.Material.Metal })
	piece(m, { Name = "Claw", Size = Vector3.new(0.2, 0.6, 0.2), CFrame = CFrame.new(0, 0.25, -2.9), Color = Color3.fromRGB(80, 80, 86), Material = Enum.Material.Metal })
end
builders.Sledgehammer = function(m)
	handle(m, Vector3.new(0.35, 0.35, 1), WOOD_DARK, Enum.Material.Wood)
	piece(m, { Name = "Haft", Size = Vector3.new(0.32, 0.32, 3.8), CFrame = CFrame.new(0, 0, -1.6), Color = WOOD, Material = Enum.Material.Wood })
	piece(m, { Name = "Head", Size = Vector3.new(0.7, 1.6, 0.7), CFrame = CFrame.new(0, 0, -3.5), Color = Color3.fromRGB(70, 72, 78), Material = Enum.Material.Metal })
end
builders.Bolt = function(m)
	handle(m, Vector3.new(0.14, 0.14, 1.8), Color3.fromRGB(110, 110, 116), Enum.Material.Metal)
end
builders.CrudeSpear = function(m)
	builders.Spear(m)
	for _, d in m:GetChildren() do
		if d.Name == "Tip" and d:IsA("BasePart") then
			d.Color = Color3.fromRGB(150, 146, 140)
		end
	end
end
builders.FirstAid = function(m)
	handle(m, Vector3.new(1, 0.7, 0.8), Color3.fromRGB(235, 235, 235), Enum.Material.SmoothPlastic)
	piece(m, { Name = "Cross", Size = Vector3.new(0.5, 0.12, 0.5), CFrame = CFrame.new(0, 0.36, 0), Color = Color3.fromRGB(210, 60, 60), Material = Enum.Material.SmoothPlastic })
end
builders.Medkit = function(m)
	handle(m, Vector3.new(1.4, 0.9, 1), Color3.fromRGB(60, 150, 90), Enum.Material.SmoothPlastic)
	piece(m, { Name = "Cross", Size = Vector3.new(0.6, 0.12, 0.6), CFrame = CFrame.new(0, 0.46, 0), Color = Color3.fromRGB(240, 240, 240), Material = Enum.Material.SmoothPlastic })
end

for _, packId in { "FibrePack", "HidePack", "FramePack", "IronPack", "ExpeditionPack" } do
	builders[packId] = function(m)
		handle(m, Vector3.new(1.8, 2.2, 0.9), if packId == "FibrePack" then Color3.fromRGB(150, 170, 110) else LEATHER, Enum.Material.Fabric)
		piece(m, { Name = "Flap", Size = Vector3.new(1.9, 0.8, 1), CFrame = CFrame.new(0, 0.9, 0), Color = Color3.fromRGB(100, 70, 50), Material = Enum.Material.Fabric })
		piece(m, { Name = "Roll", Size = Vector3.new(2, 0.6, 0.6), CFrame = CFrame.new(0, 1.35, 0.2), Color = ROPE, Material = Enum.Material.Fabric })
	end
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

end)()
local __m_LootModels = (function()
-- Care package (with parachute + beacon) and hidden forest crate.

local Build = __m_Build
local Skins = __m_Skins

local LootModels = {}

local CRATE = Color3.fromRGB(120, 140, 90)
local CRATE_DARK = Color3.fromRGB(80, 96, 60)

function LootModels.CarePackage(cf: CFrame, parent: Instance?): Model
	local m = Build.Model("CarePackage")
	local box = Build.Part({ Name = "Box", Size = Vector3.new(5, 4, 5), CFrame = CFrame.new(0, 2, 0), Color = CRATE, Material = Enum.Material.WoodPlanks, Parent = m })
	for _, y in { 0.4, 3.6 } do
		Build.Decor({ Name = "Trim", Size = Vector3.new(5.2, 0.5, 5.2), CFrame = CFrame.new(0, y, 0), Color = CRATE_DARK, Material = Enum.Material.Wood, Parent = m })
	end
	for _, x in { -2.4, 2.4 } do
		Build.Decor({ Name = "Strap", Size = Vector3.new(0.5, 4.2, 5.25), CFrame = CFrame.new(x, 2, 0), Color = Color3.fromRGB(230, 120, 40), Material = Enum.Material.Fabric, Parent = m })
	end
	-- Icon plates on four sides
	for i = 0, 3 do
		local plate = Build.Decor({ Name = "Plate", Size = Vector3.new(2, 2, 0.1), CFrame = CFrame.Angles(0, math.rad(90 * i), 0) * CFrame.new(0, 2, -2.56), Color = Color3.fromRGB(245, 240, 225), Material = Enum.Material.SmoothPlastic, Parent = m })
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front
		sg.CanvasSize = Vector2.new(100, 100)
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.fromScale(1, 1)
		tl.BackgroundTransparency = 1
		tl.Text = "✚"
		tl.TextScaled = true
		tl.TextColor3 = Color3.fromRGB(230, 120, 40)
		tl.Font = Enum.Font.GothamBlack
		tl.Parent = sg
		sg.Parent = plate
	end
	-- Parachute (removed on landing)
	local chute = Build.Model("Parachute", m)
	local canopy = Build.Decor({ Name = "Canopy", Shape = Enum.PartType.Ball, Size = Vector3.new(16, 7, 16), CFrame = CFrame.new(0, 17, 0), Color = Color3.fromRGB(235, 120, 50), Material = Enum.Material.Fabric, Parent = chute })
	Build.Decor({ Name = "Inner", Shape = Enum.PartType.Ball, Size = Vector3.new(15, 6, 15), CFrame = CFrame.new(0, 16.6, 0), Color = Color3.fromRGB(245, 240, 225), Material = Enum.Material.Fabric, Parent = chute })
	for i = 0, 3 do
		local a = math.rad(45 + 90 * i)
		local top = Vector3.new(math.cos(a) * 6.5, 15, math.sin(a) * 6.5)
		local bottom = Vector3.new(math.cos(a) * 2.2, 4, math.sin(a) * 2.2)
		local mid = (top + bottom) / 2
		Build.Decor({ Name = "Line", Size = Vector3.new(0.1, 0.1, (top - bottom).Magnitude), CFrame = CFrame.lookAt(mid, top), Color = Color3.fromRGB(230, 230, 230), Material = Enum.Material.SmoothPlastic, Parent = chute, CastShadow = false })
	end
	chute.PrimaryPart = canopy
	-- Beacon (smoke + light) shown after landing
	local beacon = Build.Decor({ Name = "Beacon", Size = Vector3.new(0.8, 0.8, 0.8), CFrame = CFrame.new(0, 4.4, 0), Color = Color3.fromRGB(255, 120, 40), Material = Enum.Material.Neon, Parent = m })
	local smoke = Instance.new("Smoke")
	smoke.Name = "Signal"
	smoke.Color = Color3.fromRGB(255, 130, 60)
	smoke.Opacity = 0.35
	smoke.RiseVelocity = 12
	smoke.Size = 4
	smoke.Enabled = false
	smoke.Parent = beacon
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 70)
	light.Range = 18
	light.Brightness = 2
	light.Parent = beacon
	Build.SetPivot(m, box, CFrame.new())
	m:PivotTo(cf)
	if Skins.Enabled() then
		local k = 5 / Skins.Width("SM_CarePackage_Crate")
		-- crate (with lid) on the model; canopy + lines inside Parachute so Land() removes them
		Skins.Dress(m, "SM_CarePackage_Crate", { scale = k })
		local top = m:GetPivot() * CFrame.new(0, 3.4 * k, 0)
		Skins.Dress(m, "SM_Parachute_Canopy", { scale = k, cf = top, parent = chute, noHide = true, extra = true })
		Skins.Dress(m, "SM_Parachute_Lines", { scale = k, cf = top, parent = chute, noHide = true, extra = true })
	end
	if parent then
		m.Parent = parent
	end
	return m
end

function LootModels.Land(m: Model)
	local chute = m:FindFirstChild("Parachute")
	if chute then
		chute:Destroy()
	end
	local beacon = m:FindFirstChild("Beacon")
	local smoke = beacon and beacon:FindFirstChild("Signal") :: Smoke?
	if smoke then
		smoke.Enabled = true
	end
end

function LootModels.ForestCrate(cf: CFrame, parent: Instance?): Model
	local m = Build.Model("ForestCrate")
	local box = Build.Part({ Name = "Box", Size = Vector3.new(2.6, 2, 2.2), CFrame = CFrame.new(0, 1, 0), Color = Color3.fromRGB(128, 96, 62), Material = Enum.Material.WoodPlanks, Parent = m })
	Build.Decor({ Name = "Lid", Size = Vector3.new(2.8, 0.35, 2.4), CFrame = CFrame.new(0, 2.1, 0) * CFrame.Angles(0, 0, math.rad(4)), Color = Color3.fromRGB(96, 70, 44), Material = Enum.Material.Wood, Parent = m })
	Build.Decor({ Name = "Rope", Size = Vector3.new(0.25, 2.1, 2.3), CFrame = CFrame.new(0.4, 1.05, 0), Color = Color3.fromRGB(205, 180, 120), Material = Enum.Material.Fabric, Parent = m })
	-- Moss so it blends into the forest floor.
	Build.Decor({ Name = "Moss", Size = Vector3.new(1.4, 0.2, 1.2), CFrame = CFrame.new(-0.6, 2.3, 0.3), Color = Color3.fromRGB(84, 118, 64), Material = Enum.Material.Grass, Parent = m })
	Build.SetPivot(m, box, CFrame.new())
	m:PivotTo(cf)
	if Skins.Enabled() then
		local name = Skins.Pick({ "SM_SupplyCrate_Small01", "SM_SupplyCrate_Small02", "SM_SupplyCrate_Small03" }, cf)
		Skins.Dress(m, name, { scale = 2.6 / Skins.Width(name) * 1.1 })
	end
	if parent then
		m.Parent = parent
	end
	return m
end

return LootModels

end)()
local __m_Animals = (function()
-- Wildlife rigs built from primitives: wolf, bear, deer, rabbit, boar (+ bat).
--
-- Wolf and Bear: a Humanoid with an invisible HumanoidRootPart. Visible body
-- parts are welded/Motor6D'd so the client-side CreatureAnimator can drive
-- leg, head and tail joints procedurally (no uploaded animations exist; see
-- DECISIONS D34). Motor6D names used by the animator: LegFL, LegFR, LegBL,
-- LegBR, Neck, Tail.
-- Bat: a physics-driven flyer (AlignPosition/AlignOrientation) with WingL/WingR motors.

local Build = __m_Build

local Animals = {}

export type Spec = { Body: Color3, Dark: Color3, Belly: Color3, Scale: number, Eye: Color3 }

local function motor(name: string, p0: BasePart, p1: BasePart, c0: CFrame, c1: CFrame): Motor6D
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = c0
	m.C1 = c1
	m.Parent = p0
	return m
end

local function bodyPart(parent: Instance, name: string, size: Vector3, color: Color3, material: Enum.Material?, shape: Enum.PartType?): BasePart
	return Build.Part({ Name = name, Size = size, CFrame = CFrame.new(), Color = color, Material = material or Enum.Material.Fabric, Parent = parent, Anchored = false, CanCollide = false, CanQuery = true, Massless = true, Shape = shape })
end

local function weld(p0: BasePart, p1: BasePart, offset: CFrame)
	p1.CFrame = p0.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = p0
	w.Part1 = p1
	w.Parent = p1
end

-- Shared quadruped builder.
local function quadruped(name: string, spec: Spec, dims: { [string]: number }): Model
	local s = spec.Scale
	local m = Build.Model(name)
	local hrp = Build.Part({ Name = "HumanoidRootPart", Size = Vector3.new(dims.W, dims.H, dims.L) * s, CFrame = CFrame.new(0, 0, 0), Transparency = 1, Parent = m, Anchored = false, CanCollide = true, CanQuery = true })
	m.PrimaryPart = hrp

	local torso = bodyPart(m, "Torso", Vector3.new(dims.W, dims.H * 0.9, dims.L) * s, spec.Body)
	motor("Body", hrp, torso, CFrame.new(0, 0, 0), CFrame.new())
	local belly = bodyPart(m, "Belly", Vector3.new(dims.W * 0.8, dims.H * 0.3, dims.L * 0.8) * s, spec.Belly)
	weld(torso, belly, CFrame.new(0, -dims.H * 0.35 * s, 0))
	local chest = bodyPart(m, "Chest", Vector3.new(dims.W * 1.1, dims.H * 1.05, dims.L * 0.4) * s, spec.Dark)
	weld(torso, chest, CFrame.new(0, 0.1 * s, -dims.L * 0.35 * s))

	-- Head on a neck motor
	local head = bodyPart(m, "Head", Vector3.new(dims.W * 0.8, dims.H * 0.75, dims.L * 0.3) * s, spec.Body)
	motor("Neck", torso, head, CFrame.new(0, dims.H * 0.35 * s, -dims.L * 0.55 * s), CFrame.new(0, 0, dims.L * 0.05 * s))
	local snout = bodyPart(m, "Snout", Vector3.new(dims.W * 0.45, dims.H * 0.35, dims.L * 0.25) * s, spec.Belly)
	weld(head, snout, CFrame.new(0, -dims.H * 0.12 * s, -dims.L * 0.2 * s))
	local nose = bodyPart(m, "Nose", Vector3.new(0.3, 0.25, 0.2) * s, Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic)
	weld(snout, nose, CFrame.new(0, 0.1 * s, -dims.L * 0.13 * s))
	for _, x in { -1, 1 } do
		local eye = bodyPart(m, "Eye", Vector3.new(0.22, 0.22, 0.1) * s, spec.Eye, Enum.Material.Neon)
		weld(head, eye, CFrame.new(x * dims.W * 0.22 * s, dims.H * 0.12 * s, -dims.L * 0.151 * s))
		local ear = bodyPart(m, "Ear", Vector3.new(dims.W * 0.18, dims.H * dims.Ear, 0.2 * s) * s, spec.Dark)
		weld(head, ear, CFrame.new(x * dims.W * 0.28 * s, dims.H * 0.45 * s, dims.L * 0.05 * s) * CFrame.Angles(0, 0, math.rad(-x * 12)))
	end

	-- Legs
	local legLen = dims.Leg * s
	for _, leg in { { "LegFL", -1, -1 }, { "LegFR", 1, -1 }, { "LegBL", -1, 1 }, { "LegBR", 1, 1 } } do
		local part = bodyPart(m, leg[1], Vector3.new(dims.W * 0.28 * s, legLen, dims.W * 0.3 * s), spec.Dark)
		motor(leg[1], torso, part,
			CFrame.new(leg[2] * dims.W * 0.32 * s, -dims.H * 0.3 * s, leg[3] * dims.L * 0.36 * s),
			CFrame.new(0, legLen / 2, 0))
		local paw = bodyPart(m, "Paw", Vector3.new(dims.W * 0.32 * s, 0.3 * s, dims.W * 0.4 * s), spec.Dark)
		weld(part, paw, CFrame.new(0, -legLen / 2, -0.1 * s))
	end

	-- Tail
	local tail = bodyPart(m, "TailPart", Vector3.new(dims.W * 0.2, dims.W * 0.2, dims.Tail) * s, spec.Body)
	motor("Tail", torso, tail, CFrame.new(0, dims.H * 0.25 * s, dims.L * 0.5 * s), CFrame.new(0, 0, -dims.Tail * 0.5 * s) * CFrame.Angles(math.rad(-25), 0, 0))

	local hum = Instance.new("Humanoid")
	-- R15 rig type makes the Humanoid honour HipHeight (R6 would look for leg parts).
	hum.RigType = Enum.HumanoidRigType.R15
	-- leg top sits 0.3H below centre, root bottom is 0.5H below centre, paws add ~0.15
	hum.HipHeight = legLen - dims.H * 0.2 * s + 0.15 * s
	hum.DisplayName = name
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	hum.NameDisplayDistance = 0
	hum.HealthDisplayDistance = 60
	hum.RequiresNeck = false
	hum.BreakJointsOnDeath = false
	hum.Parent = m
	-- Hitbox parts stay queryable for melee/arrow detection
	return m
end

function Animals.Wolf(): Model
	return quadruped("Wolf", {
		Body = Color3.fromRGB(110, 108, 104),
		Dark = Color3.fromRGB(70, 68, 66),
		Belly = Color3.fromRGB(170, 164, 150),
		Eye = Color3.fromRGB(255, 210, 90),
		Scale = 1,
	}, { W = 1.6, H = 1.7, L = 4.2, Leg = 2.4, Tail = 2.4, Ear = 0.45 })
end

function Animals.Bear(): Model
	return quadruped("Bear", {
		Body = Color3.fromRGB(96, 64, 40),
		Dark = Color3.fromRGB(66, 44, 28),
		Belly = Color3.fromRGB(140, 104, 72),
		Eye = Color3.fromRGB(255, 120, 60),
		Scale = 1.8,
	}, { W = 2.2, H = 2.2, L = 4, Leg = 2.1, Tail = 0.6, Ear = 0.3 })
end

-- Prey and boar (Survival Wars). Same quadruped rig, so the client animator drives them.
local function headOf(m: Model): BasePart
	return m:FindFirstChild("Head") :: BasePart
end

function Animals.Deer(): Model
	local m = quadruped("Deer", {
		Body = Color3.fromRGB(150, 104, 66),
		Dark = Color3.fromRGB(108, 72, 46),
		Belly = Color3.fromRGB(226, 206, 176),
		Eye = Color3.fromRGB(30, 24, 20),
		Scale = 1.1,
	}, { W = 1.3, H = 1.6, L = 3.8, Leg = 3.2, Tail = 0.5, Ear = 0.5 })
	local head = headOf(m)
	for _, x in { -1, 1 } do
		local beam = bodyPart(m, "Antler", Vector3.new(0.18, 1.6, 0.18), Color3.fromRGB(214, 196, 160), Enum.Material.Wood)
		weld(head, beam, CFrame.new(x * 0.35, 1.2, 0.1) * CFrame.Angles(0, 0, math.rad(-x * 25)))
		local tine = bodyPart(m, "Antler", Vector3.new(0.14, 0.8, 0.14), Color3.fromRGB(214, 196, 160), Enum.Material.Wood)
		weld(head, tine, CFrame.new(x * 0.7, 1.6, -0.2) * CFrame.Angles(math.rad(-30), 0, math.rad(-x * 10)))
	end
	return m
end

function Animals.Rabbit(): Model
	local m = quadruped("Rabbit", {
		Body = Color3.fromRGB(150, 130, 110),
		Dark = Color3.fromRGB(120, 100, 84),
		Belly = Color3.fromRGB(236, 228, 214),
		Eye = Color3.fromRGB(20, 20, 20),
		Scale = 0.45,
	}, { W = 1.4, H = 1.4, L = 2.2, Leg = 1.1, Tail = 0.6, Ear = 1.2 })
	return m
end

function Animals.Boar(): Model
	local m = quadruped("Boar", {
		Body = Color3.fromRGB(84, 66, 54),
		Dark = Color3.fromRGB(54, 42, 34),
		Belly = Color3.fromRGB(120, 100, 86),
		Eye = Color3.fromRGB(200, 90, 50),
		Scale = 1.05,
	}, { W = 1.8, H = 1.8, L = 3.4, Leg = 1.5, Tail = 0.6, Ear = 0.35 })
	local snout = m:FindFirstChild("Snout") :: BasePart
	for _, x in { -1, 1 } do
		local tusk = bodyPart(m, "Tusk", Vector3.new(0.16, 0.6, 0.16), Color3.fromRGB(236, 226, 200), Enum.Material.SmoothPlastic)
		weld(snout, tusk, CFrame.new(x * 0.35, 0.2, -0.2) * CFrame.Angles(math.rad(-30), 0, math.rad(-x * 15)))
	end
	return m
end

function Animals.Build(species: string): Model
	local f = (Animals :: any)[species]
	return f()
end

function Animals.Bat(): Model
	local m = Build.Model("Bat")
	local body = Build.Part({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), CFrame = CFrame.new(), Color = Color3.fromRGB(50, 40, 48), Material = Enum.Material.Fabric, Parent = m, Anchored = false, CanCollide = false, CanQuery = true })
	m.PrimaryPart = body
	local head = bodyPart(m, "Head", Vector3.new(1, 1, 1), Color3.fromRGB(60, 48, 56), Enum.Material.Fabric, Enum.PartType.Ball)
	weld(body, head, CFrame.new(0, 0.3, -0.9))
	for _, x in { -1, 1 } do
		local eye = bodyPart(m, "Eye", Vector3.new(0.18, 0.18, 0.1), Color3.fromRGB(255, 60, 60), Enum.Material.Neon)
		weld(head, eye, CFrame.new(x * 0.22, 0.1, -0.48))
		local ear = bodyPart(m, "Ear", Vector3.new(0.2, 0.6, 0.2), Color3.fromRGB(50, 40, 48))
		weld(head, ear, CFrame.new(x * 0.25, 0.55, 0))
		local wing = bodyPart(m, if x < 0 then "WingLPart" else "WingRPart", Vector3.new(3.2, 0.1, 1.8), Color3.fromRGB(40, 30, 40), Enum.Material.Fabric)
		motor(if x < 0 then "WingL" else "WingR", body, wing, CFrame.new(x * 0.7, 0.2, 0), CFrame.new(-x * 1.6, 0, 0))
		local tip = Build.Part({ Class = "WedgePart", Name = "WingTip", Size = Vector3.new(0.1, 1.2, 1.6), CFrame = CFrame.new(), Color = Color3.fromRGB(40, 30, 40), Material = Enum.Material.Fabric, Parent = m, Anchored = false, CanCollide = false, CanQuery = false, Massless = true })
		weld(wing, tip, CFrame.new(x * 2, 0, 0.2) * CFrame.Angles(0, 0, math.rad(90 * x)))
	end
	local att = Instance.new("Attachment")
	att.Name = "Fly"
	att.Parent = body
	local ap = Instance.new("AlignPosition")
	ap.Name = "Mover"
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Attachment0 = att
	ap.MaxForce = 4000
	ap.MaxVelocity = 26
	ap.Responsiveness = 18
	ap.Parent = body
	local ao = Instance.new("AlignOrientation")
	ao.Name = "Facing"
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.MaxTorque = 4000
	ao.Responsiveness = 20
	ao.Parent = body
	local hum = Instance.new("Humanoid")
	hum.DisplayName = "Bat"
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
	hum.HealthDisplayDistance = 50
	hum.NameDisplayDistance = 0
	hum.RequiresNeck = false
	hum.BreakJointsOnDeath = false
	hum.PlatformStand = true
	hum.Parent = m
	return m
end

return Animals

end)()
local __m_Decor = (function()
-- Mesh-first forest decoration. Each layout decoration kind maps to asset-pack
-- meshes (one MeshPart each, far cheaper than a procedural model) with a
-- procedural Flora fallback when the pack isn't loaded.
--
-- Solid kinds (logs, boulders, snags) get ONE simple invisible box collider
-- (spec: visual and collision need not match; tiny roots/rocks never snag players).
-- Everything else is non-colliding, non-queryable decor.

local Skins = __m_Skins
local Flora = __m_Flora
local Build = __m_Build

local Decor = {}

-- kind -> pack meshes (variant picked by position so every client agrees)
Decor.Meshes = {
	Fern = { "SM_Fern01", "SM_Fern02" },
	TallGrass = { "SM_Grass_Clump01", "SM_Grass_Clump02", "SM_Grass_Clump03" },
	Bush = { "SM_Bush01", "SM_Bush02", "SM_Bush03_Berry" },
	FallenLog = { "SM_FallenLog01", "SM_FallenLog02_Hollow" },
	Boulder = { "SM_Boulder01", "SM_Boulder02", "SM_Boulder03" },
	Stump = { "SM_Stump_Old01", "SM_Stump_Old02" },
	DeadSnag = { "SM_Tree_Dead_Large01" },
	LeafLitter = { "SM_LeafLitter01" },
	Mushrooms = { "SM_Mushrooms01", "SM_Mushrooms02_Glow" },
	MossPatch = { "SM_MossPatch01" },
	Pebbles = { "SM_Rock_Small01", "SM_Rock_Small02", "SM_Rock_Small03", "SM_Pinecones01" },
	Twigs = { "SM_Sticks_Loose01", "SM_Branch01", "SM_Branch02" },
	Roots = { "SM_Roots01", "SM_Roots02" },
	FlowerPatch = { "SM_Flowers01", "SM_Flowers02" },
	Sapling = { "SM_Sapling01" },
	Spruce = { "SM_Tree_Spruce01", "SM_Tree_Spruce02", "SM_Tree_Pine_Medium02" },
	Aspen = { "SM_Tree_Aspen01", "SM_Tree_Birch_Medium01" },
	GiantTree = { "SM_Tree_Oak_Large01" },
	Cliff = { "SM_Cliff_Face01", "SM_Cliff_Face02" },
	Riverbank = { "SM_Riverbank_Straight" },
}

-- Target size for mesh variants: kind -> approx height (studs) at scale 1.
Decor.Height = {
	Fern = 1.6, TallGrass = 1.8, Bush = 3.2, FallenLog = 2.2, Boulder = 3.6, Stump = 2.2, DeadSnag = 18,
	Sapling = 5, Spruce = 20, Aspen = 18, GiantTree = 34, FlowerPatch = 0.9, Roots = 1.2, Cliff = 26,
}

-- Kinds that block movement: collider box as a fraction of the mesh bounds.
Decor.Solid = { FallenLog = 0.8, Boulder = 0.8, DeadSnag = 0.25, Stump = 0.8, Spruce = 0.12, Aspen = 0.1, GiantTree = 0.12 }

-- Flora fallbacks: name -> { builder, takesScale }
local FALLBACK = {
	Fern = { "Fern", false }, TallGrass = { "TallGrass", false }, Bush = { "Bush", true }, FallenLog = { "FallenLog", true },
	Boulder = { "Boulder", true }, Stump = { "Stump", true }, DeadSnag = { "DeadSnag", true }, LeafLitter = { "LeafLitter", false },
	Mushrooms = { "Mushrooms", false }, MossPatch = { "MossPatch", false }, Pebbles = { "Pebbles", false }, Twigs = { "Twigs", false },
	Roots = { "Roots", false }, FlowerPatch = { "FlowerPatch", false }, Sapling = { "Sapling", true },
	Spruce = { "Spruce", true }, Aspen = { "Aspen", true }, GiantTree = { "GiantTree", true },
}

local function firstAvailable(list: { string }, cf: CFrame): string?
	local avail = {}
	for _, n in list do
		if Skins.Has(n) then
			table.insert(avail, n)
		end
	end
	if #avail == 0 then
		return nil
	end
	return Skins.Pick(avail, cf)
end

-- Places one decoration. Returns the Instance (Model) or nil.
function Decor.Place(kind: string, cf: CFrame, rng: Random, scale: number?, parent: Instance?): Instance?
	local s = scale or 1
	local list = Decor.Meshes[kind]
	local name = list and Skins.Enabled() and firstAvailable(list, cf)
	if name then
		local v = Skins.Visual(name)
		if v then
			local h = Decor.Height[kind]
			local k = s * (if h then h / math.max(0.2, Skins.Height(name)) else 1)
			if math.abs(k - 1) > 1e-3 then
				v:ScaleTo(k)
			end
			v:PivotTo(cf)
			v.Name = kind
			v:SetAttribute("Decor", kind)
			local solidFrac = Decor.Solid[kind]
			if solidFrac then
				local bcf, size = v:GetBoundingBox()
				local csize = Vector3.new(size.X * solidFrac, size.Y * math.max(0.5, solidFrac), size.Z * solidFrac)
				if kind == "Spruce" or kind == "Aspen" or kind == "GiantTree" or kind == "DeadSnag" then
					-- trunk only
					csize = Vector3.new(math.max(1, size.X * solidFrac), size.Y * 0.6, math.max(1, size.Z * solidFrac))
					bcf = cf * CFrame.new(0, csize.Y / 2, 0)
				end
				Build.Part({ Name = "Collider", Size = csize, CFrame = bcf, Transparency = 1, Parent = v, CanQuery = true })
			end
			v.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			v.Parent = parent
			return v
		end
	end
	local fb = FALLBACK[kind]
	local f = fb and (Flora :: any)[fb[1]]
	if f then
		local m = if fb[2] then f(cf, rng, s, parent) else f(cf, rng, parent)
		m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		return m
	end
	return nil
end

return Decor

end)()
local __m_Landmarks = (function()
-- Points of interest (spec: "caves, cabins/houses, ranger structures, shelters,
-- campsites, ruins, supply areas, hidden locations"), built from primitives with
-- real collision. The mesh pack dresses them when a matching asset exists
-- (Skins); the procedural parts stay as colliders.
--
-- Contract (see docs/OVERHAUL.md):
--   * builder(cf, rng, parent) -> Model, PrimaryPart "Root" (invisible, no collide),
--     pivot = ground centre, entrance on local +Z (LayoutGen turns +Z toward the camp).
--   * Chest spots are Attachments named "ChestMount" on Root (WorldService spawns chests).
--   * Walkable interiors: door gaps >= 5 wide x 7 tall; clutter never collides.
-- Caves are the exception: the interior runs along local +Z (into the cliff) and
-- the terrain tunnel is carved by WorldService.

local Build = __m_Build
local Skins = __m_Skins

local Landmarks = {}

local WOOD = Color3.fromRGB(128, 92, 60)
local WOOD_DARK = Color3.fromRGB(88, 62, 40)
local WOOD_OLD = Color3.fromRGB(110, 100, 86)
local ROOF = Color3.fromRGB(86, 70, 58)
local STONE = Color3.fromRGB(122, 120, 116)
local CONCRETE = Color3.fromRGB(150, 148, 140)
local RUST = Color3.fromRGB(128, 84, 58)
local CANVAS = Color3.fromRGB(110, 120, 84)
local STEEL = Color3.fromRGB(96, 100, 108)

local M = Enum.Material

local function root(m: Model, w: number, h: number, d: number): BasePart
	local r = Build.Part({ Name = "Root", Size = Vector3.new(w, h, d), CFrame = CFrame.new(0, h / 2, 0), Transparency = 1, CanCollide = false, CanQuery = true, Parent = m })
	m.PrimaryPart = r
	return r
end

local function place(m: Model, cf: CFrame, parent: Instance?): Model
	Build.SetPivot(m, m.PrimaryPart :: BasePart, CFrame.new())
	m:PivotTo(cf)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	if parent then
		m.Parent = parent
	end
	return m
end

local function solid(m: Model, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material): BasePart
	return Build.Part({ Name = name, Size = size, CFrame = cf, Color = color, Material = mat, Parent = m })
end

local function decor(m: Model, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material): BasePart
	return Build.Decor({ Name = name, Size = size, CFrame = cf, Color = color, Material = mat, Parent = m })
end

local function mount(m: Model, x: number, y: number, z: number, yaw: number?)
	local r = m.PrimaryPart :: BasePart
	local a = Instance.new("Attachment")
	a.Name = "ChestMount"
	-- Root's centre is at h/2; mounts are given from the ground centre
	a.CFrame = CFrame.new(x, y - r.Size.Y / 2, z) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	a.Parent = r
end

-- A walled room on a floor, door gap centred on the +Z wall (and optional window gaps).
local function room(m: Model, w: number, d: number, h: number, color: Color3, mat: Enum.Material, opts: { [string]: any }?)
	local o = opts or {}
	local t = o.Thick or 0.8
	local doorW, doorH = o.DoorW or 5.5, o.DoorH or 7.5
	local ox, oz = o.X or 0, o.Z or 0
	local floorY = o.FloorY or 0
	solid(m, "Floor", Vector3.new(w, 0.6, d), CFrame.new(ox, floorY + 0.3, oz), o.FloorColor or WOOD_DARK, M.WoodPlanks)
	-- back (-Z) and sides
	local function wall(name: string, size: Vector3, cf: CFrame)
		if o.Broken and o.Broken[name] then
			-- partially collapsed: keep a low course
			solid(m, name, Vector3.new(size.X, size.Y * 0.35, size.Z), cf * CFrame.new(0, -size.Y * 0.325, 0), Build.Tint(color, 0.9), mat)
		else
			solid(m, name, size, cf, color, mat)
		end
	end
	wall("WallBack", Vector3.new(w, h, t), CFrame.new(ox, floorY + h / 2, oz - d / 2 + t / 2))
	if o.Window then
		-- side walls with a window hole (collider in 4 pieces)
		for _, sx in { -1, 1 } do
			local x = ox + sx * (w / 2 - t / 2)
			wall("WallSide" .. sx, Vector3.new(t, h * 0.42, d), CFrame.new(x, floorY + h * 0.21, oz))
			wall("WallSideTop" .. sx, Vector3.new(t, h * 0.28, d), CFrame.new(x, floorY + h - h * 0.14, oz))
			wall("WallSideL" .. sx, Vector3.new(t, h * 0.3, d * 0.35), CFrame.new(x, floorY + h * 0.57, oz - d * 0.325))
			wall("WallSideR" .. sx, Vector3.new(t, h * 0.3, d * 0.35), CFrame.new(x, floorY + h * 0.57, oz + d * 0.325))
		end
	else
		for _, sx in { -1, 1 } do
			wall("WallSide" .. sx, Vector3.new(t, h, d), CFrame.new(ox + sx * (w / 2 - t / 2), floorY + h / 2, oz))
		end
	end
	-- front (+Z) with door gap
	local side = (w - doorW) / 2
	for _, sx in { -1, 1 } do
		wall("WallFront" .. sx, Vector3.new(side, h, t), CFrame.new(ox + sx * (doorW / 2 + side / 2), floorY + h / 2, oz + d / 2 - t / 2))
	end
	solid(m, "Lintel", Vector3.new(doorW, h - doorH, t), CFrame.new(ox, floorY + doorH + (h - doorH) / 2, oz + d / 2 - t / 2), Build.Tint(color, 0.85), mat)
end

-- Gable roof over a w x d room at height y.
local function roof(m: Model, w: number, d: number, y: number, color: Color3, mat: Enum.Material?, ox: number?, oz: number?, broken: boolean?)
	local x0, z0 = ox or 0, oz or 0
	local rise = w * 0.32
	for _, sx in { -1, 1 } do
		if broken and sx == 1 then
			-- caved-in half: a slanted slab lying inside
			decor(m, "RoofFallen", Vector3.new(w / 2, 0.4, d * 0.6), CFrame.new(x0 + w * 0.2, y * 0.45, z0 - d * 0.1) * CFrame.Angles(0, 0, math.rad(35)), Build.Tint(color, 0.8), mat or M.WoodPlanks)
		else
			local part = Build.Part({ Class = "WedgePart", Name = "Roof", Size = Vector3.new(d + 1, rise, w / 2 + 0.6), CFrame = CFrame.new(x0 + sx * (w / 4 + 0.15), y + rise / 2, z0) * CFrame.Angles(0, math.rad(90 * sx), 0), Color = color, Material = mat or M.WoodPlanks, Parent = m })
			part.CanCollide = true
		end
	end
end

local function crate(m: Model, cf: CFrame, s: number)
	decor(m, "Crate", Vector3.new(2, 2, 2) * s, cf, WOOD, M.WoodPlanks)
end

local function logSeat(m: Model, cf: CFrame)
	local p = Build.Cyl("LogSeat", 4, 1.1, cf * CFrame.Angles(0, 0, math.rad(90)), WOOD_DARK, M.Wood, m, false)
	p.CanQuery = false
end

local function firePit(m: Model, cf: CFrame, rng: Random)
	for i = 0, 7 do
		local a = i * math.pi / 4
		decor(m, "PitStone", Vector3.new(0.9, 0.6, 0.9), cf * CFrame.new(math.cos(a) * 1.6, 0.3, math.sin(a) * 1.6) * CFrame.Angles(0, a, 0), Build.Tint(STONE, rng:NextNumber(0.85, 1.05)), M.Slate)
	end
	decor(m, "Ash", Vector3.new(2.4, 0.15, 2.4), cf * CFrame.new(0, 0.08, 0), Color3.fromRGB(50, 46, 44), M.Slate)
end

local function tent(m: Model, cf: CFrame, color: Color3)
	for _, sx in { -1, 1 } do
		local part = Build.Part({ Class = "WedgePart", Name = "Tent", Size = Vector3.new(5, 3.4, 2.6), CFrame = cf * CFrame.new(sx * 1.3, 1.7, 0) * CFrame.Angles(0, math.rad(-90 * sx), 0), Color = color, Material = M.Fabric, Parent = m })
		part.CanCollide = true
	end
end

-- Lights and markers stay visible when a pack mesh replaces the procedural look.
local KEEP = { Lantern = true, Crystal = true, Lamp = true, Flag = true, Map = true }

-- Dress with a pack mesh if it exists (procedural parts stay as colliders).
local function dress(m: Model, name: string)
	if Skins.Has(name) then
		Skins.Dress(m, name, { keep = KEEP })
	end
end

-- Common ---------------------------------------------------------------------------------------

function Landmarks.Campsite(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("Campsite")
	root(m, 22, 4, 22)
	firePit(m, CFrame.new(0, 0, 1), rng)
	tent(m, CFrame.new(-6, 0, -5) * CFrame.Angles(0, math.rad(20), 0), CANVAS)
	tent(m, CFrame.new(6, 0, -6) * CFrame.Angles(0, math.rad(-15), 0), Color3.fromRGB(150, 90, 60))
	logSeat(m, CFrame.new(0, 0.5, 5))
	logSeat(m, CFrame.new(-4.5, 0.5, 2) * CFrame.Angles(0, math.rad(70), 0))
	crate(m, CFrame.new(3, 1, -2), 0.8)
	decor(m, "Backpack", Vector3.new(1.2, 1.6, 0.8), CFrame.new(-3, 0.8, -1), Color3.fromRGB(90, 110, 70), M.Fabric)
	mount(m, 4, 0, -4, 180)
	return place(m, cf, parent)
end

function Landmarks.Shed(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("Shed")
	root(m, 10, 7, 8)
	room(m, 8, 6, 6.5, WOOD_OLD, M.WoodPlanks, { DoorW = 5, DoorH = 6 })
	local lean = Build.Part({ Class = "WedgePart", Name = "Roof", Size = Vector3.new(9, 1.6, 7), CFrame = CFrame.new(0, 7.3, 0) * CFrame.Angles(0, math.rad(180), 0), Color = ROOF, Material = M.CorrodedMetal, Parent = m })
	lean.CanCollide = true
	crate(m, CFrame.new(-2.5, 0.9, -1.5), 0.7)
	decor(m, "Shovel", Vector3.new(0.2, 3.5, 0.6), CFrame.new(3.2, 2, -2) * CFrame.Angles(0, 0, math.rad(12)), WOOD, M.Wood)
	mount(m, 1.5, 0.6, -1.2, 180)
	return place(m, cf, parent)
end

function Landmarks.HuntingBlind(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("HuntingBlind")
	root(m, 9, 10, 9)
	for _, x in { -2.6, 2.6 } do
		for _, z in { -2.6, 2.6 } do
			Build.Cyl("Post", 6, 0.6, CFrame.new(x, 3, z), WOOD_DARK, M.Wood, m)
		end
	end
	solid(m, "Platform", Vector3.new(6.4, 0.5, 6.4), CFrame.new(0, 6, 0), WOOD, M.WoodPlanks)
	for _, s in { { 0, -3, 6.4, 0.3 }, { -3, 0, 0.3, 6.4 }, { 3, 0, 0.3, 6.4 } } do
		solid(m, "Screen", Vector3.new(s[3], 2.4, s[4]), CFrame.new(s[1], 7.4, s[2]), Color3.fromRGB(96, 110, 70), M.Fabric)
	end
	local ladder = Instance.new("TrussPart")
	ladder.Name = "Ladder"
	ladder.Size = Vector3.new(2, 6, 2)
	ladder.CFrame = CFrame.new(0, 3, 3.6)
	ladder.Color = WOOD_DARK
	ladder.Material = M.Wood
	ladder.Anchored = true
	ladder.Style = Enum.Style.NoSupports
	ladder.Parent = m
	mount(m, 0, 6.25, -1.5, 180)
	return place(m, cf, parent)
end

function Landmarks.BrokenVehicle(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("BrokenVehicle")
	root(m, 16, 6, 12)
	local body = CFrame.new(0, 0, -2) * CFrame.Angles(0, math.rad(15), math.rad(6))
	solid(m, "Chassis", Vector3.new(12, 1.2, 5), body * CFrame.new(0, 1.4, 0), RUST, M.CorrodedMetal)
	solid(m, "Bed", Vector3.new(7, 2.4, 5), body * CFrame.new(-2.5, 3.2, 0), Build.Tint(RUST, 0.9), M.CorrodedMetal)
	solid(m, "Cab", Vector3.new(3.6, 3.2, 4.6), body * CFrame.new(3.6, 3.6, 0), Color3.fromRGB(70, 90, 80), M.CorrodedMetal)
	decor(m, "Windshield", Vector3.new(0.2, 1.6, 4), body * CFrame.new(5.4, 4.2, 0) * CFrame.Angles(0, 0, math.rad(-15)), Color3.fromRGB(150, 170, 170), M.Glass)
	for _, p in { { -4, -2.6 }, { 4, -2.6 }, { -4, 2.6 }, { 4, 2.6 } } do
		Build.Cyl("Tire", 1, 2.2, body * CFrame.new(p[1], 1.1, p[2]) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(30, 30, 30), M.Rubber, m, false)
	end
	decor(m, "Door", Vector3.new(2.6, 2.4, 0.2), CFrame.new(5, 0.25, 3) * CFrame.Angles(math.rad(85), math.rad(20), 0), Color3.fromRGB(70, 90, 80), M.CorrodedMetal)
	mount(m, -2, 0, 4.2, 0)
	return place(m, cf, parent)
end

function Landmarks.SmallCabin(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("SmallCabin")
	root(m, 13, 10, 11)
	room(m, 10, 8, 7.5, WOOD, M.Wood, { Window = true })
	roof(m, 10, 8, 7.5, ROOF, M.WoodPlanks)
	Build.Cyl("StovePipe", 3, 0.6, CFrame.new(3, 10, -2), Color3.fromRGB(60, 60, 64), M.Metal, m, false)
	solid(m, "Porch", Vector3.new(10, 0.4, 2.4), CFrame.new(0, 0.2, 5.2), WOOD_DARK, M.WoodPlanks)
	decor(m, "Bed", Vector3.new(3, 1, 6), CFrame.new(-3, 1, -0.5), Color3.fromRGB(110, 60, 50), M.Fabric)
	mount(m, 3, 0.6, -2.4, 180)
	return place(m, cf, parent)
end

-- Uncommon -------------------------------------------------------------------------------------

function Landmarks.Cabin(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("Cabin")
	root(m, 18, 11, 14)
	room(m, 14, 10, 8, WOOD, M.Wood, { Window = true })
	roof(m, 14, 10, 8, ROOF, M.WoodPlanks)
	solid(m, "Porch", Vector3.new(14, 0.4, 3), CFrame.new(0, 0.2, 6.4), WOOD_DARK, M.WoodPlanks)
	for _, x in { -6.6, 6.6 } do
		Build.Cyl("PorchPost", 7, 0.5, CFrame.new(x, 3.5, 7.6), WOOD_DARK, M.Wood, m)
	end
	Build.Cyl("Chimney", 11, 1.8, CFrame.new(-5, 5.5, -4), STONE, M.Cobblestone, m)
	decor(m, "Table", Vector3.new(4, 0.3, 2.4), CFrame.new(2, 2.6, -1), WOOD_DARK, M.WoodPlanks)
	decor(m, "Bed", Vector3.new(3.2, 1, 6), CFrame.new(-4.2, 1, 0), Color3.fromRGB(90, 60, 50), M.Fabric)
	mount(m, 4.5, 0.6, -3.2, 180)
	mount(m, -4.5, 0.6, 3, 90)
	return place(m, cf, parent)
end

function Landmarks.RangerStation(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("RangerStation")
	root(m, 20, 16, 16)
	room(m, 14, 11, 8, Color3.fromRGB(96, 110, 84), M.WoodPlanks, { Window = true })
	roof(m, 14, 11, 8, Color3.fromRGB(70, 80, 64), M.CorrodedMetal)
	-- lookout on stilts behind
	for _, x in { -2.4, 2.4 } do
		for _, z in { -8, -12.8 } do
			Build.Cyl("Stilt", 12, 0.6, CFrame.new(x, 6, z), WOOD_DARK, M.Wood, m)
		end
	end
	solid(m, "Lookout", Vector3.new(6, 0.5, 6), CFrame.new(0, 12, -10.4), WOOD, M.WoodPlanks)
	local ladder = Instance.new("TrussPart")
	ladder.Name = "Ladder"
	ladder.Size = Vector3.new(2, 12, 2)
	ladder.CFrame = CFrame.new(3.8, 6, -10.4)
	ladder.Color = WOOD_DARK
	ladder.Material = M.Wood
	ladder.Anchored = true
	ladder.Style = Enum.Style.NoSupports
	ladder.Parent = m
	Build.Cyl("Flagpole", 12, 0.3, CFrame.new(8, 6, 6), Color3.fromRGB(200, 200, 200), M.Metal, m, false)
	decor(m, "Flag", Vector3.new(0.1, 1.6, 2.6), CFrame.new(8, 11, 7.4), Color3.fromRGB(70, 110, 70), M.Fabric)
	decor(m, "Desk", Vector3.new(4, 0.3, 2), CFrame.new(-3, 2.7, -3.5), WOOD_DARK, M.WoodPlanks)
	decor(m, "Map", Vector3.new(3, 2, 0.1), CFrame.new(-3, 5, -5.05), Color3.fromRGB(220, 210, 170), M.SmoothPlastic)
	mount(m, 4, 0.6, -3.5, 180)
	mount(m, 0, 12.25, -11.5, 180)
	return place(m, cf, parent)
end

function Landmarks.LoggingCamp(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("LoggingCamp")
	root(m, 24, 8, 24)
	room(m, 8, 7, 6.5, WOOD_OLD, M.WoodPlanks, { X = -6, Z = -5 })
	roof(m, 8, 7, 6.5, ROOF, M.CorrodedMetal, -6, -5)
	for row = 0, 2 do
		for i = 0, 3 - row do
			local p = Build.Cyl("Log", 9, 1.3, CFrame.new(6 + (i - (3 - row) / 2) * 1.35, 0.65 + row * 1.15, -4) * CFrame.Angles(0, math.rad(90), 0), Build.Tint(WOOD, rng:NextNumber(0.85, 1.05)), M.Wood, m)
			p.CanQuery = false
		end
	end
	decor(m, "Sawhorse", Vector3.new(3, 2.4, 0.4), CFrame.new(3, 1.2, 5), WOOD_DARK, M.Wood)
	decor(m, "Saw", Vector3.new(4, 0.1, 0.8), CFrame.new(3, 2.5, 5), Color3.fromRGB(190, 190, 196), M.Metal)
	mount(m, -6, 0.6, -6.5, 180)
	mount(m, 8, 0, 6, 0)
	return place(m, cf, parent)
end

function Landmarks.AbandonedHouse(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("AbandonedHouse")
	root(m, 22, 12, 18)
	room(m, 16, 12, 8.5, WOOD_OLD, M.WoodPlanks, { Window = true, Broken = { WallBack = rng:NextNumber() < 0.5, ["WallSide1"] = true } })
	roof(m, 16, 12, 8.5, Build.Tint(ROOF, 0.8), M.WoodPlanks, 0, 0, true)
	-- interior wall splitting two rooms (door gap)
	solid(m, "Partition", Vector3.new(0.6, 8.5, 5), CFrame.new(0, 4.25, -3.2), WOOD_OLD, M.WoodPlanks)
	decor(m, "BrokenChair", Vector3.new(1.4, 1.2, 1.4), CFrame.new(4, 0.9, 1) * CFrame.Angles(0, 0, math.rad(70)), WOOD_DARK, M.Wood)
	decor(m, "Rubble", Vector3.new(3, 0.8, 2.4), CFrame.new(6, 0.7, -4), STONE, M.Slate)
	mount(m, -5, 0.6, -4, 180)
	mount(m, 5, 0.6, -4.5, 180)
	return place(m, cf, parent)
end

function Landmarks.MineEntrance(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("MineEntrance")
	root(m, 18, 12, 14)
	-- rock mound with a timbered mouth facing +Z
	for i = 0, 5 do
		local a = math.rad(-150 + i * 60)
		local s = rng:NextNumber(5, 7)
		solid(m, "Mound", Vector3.new(s, s * 0.9, s), CFrame.new(math.cos(a) * 5, s * 0.4, -3 + math.sin(a) * 3) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), 0), Build.Tint(STONE, rng:NextNumber(0.8, 1)), M.Slate)
	end
	for _, x in { -2.8, 2.8 } do
		solid(m, "Timber", Vector3.new(0.8, 7, 0.8), CFrame.new(x, 3.5, 2), WOOD_DARK, M.Wood)
	end
	solid(m, "Header", Vector3.new(6.8, 0.9, 0.9), CFrame.new(0, 7.2, 2), WOOD_DARK, M.Wood)
	decor(m, "Dark", Vector3.new(4.8, 6.4, 0.2), CFrame.new(0, 3.3, 1.2), Color3.fromRGB(12, 10, 10), M.SmoothPlastic)
	for _, x in { -0.9, 0.9 } do
		decor(m, "Rail", Vector3.new(0.2, 0.2, 10), CFrame.new(x, 0.1, 6.5), STEEL, M.Metal)
	end
	decor(m, "Cart", Vector3.new(2.4, 1.6, 3), CFrame.new(0, 1.2, 8), RUST, M.CorrodedMetal)
	mount(m, 4.5, 0, 5.5, 0)
	return place(m, cf, parent)
end

-- Rare -----------------------------------------------------------------------------------------

function Landmarks.Bunker(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("Bunker")
	root(m, 18, 9, 16)
	room(m, 13, 11, 7, CONCRETE, M.Concrete, { Thick = 1.4, DoorW = 5, DoorH = 6.4, FloorColor = CONCRETE })
	solid(m, "Slab", Vector3.new(14.4, 1.4, 12.4), CFrame.new(0, 7.7, 0), Build.Tint(CONCRETE, 0.9), M.Concrete)
	decor(m, "Moss", Vector3.new(14.6, 0.2, 12.6), CFrame.new(0, 8.5, 0), Color3.fromRGB(80, 110, 60), M.Grass)
	for i = -2, 2 do
		decor(m, "Sandbag", Vector3.new(2, 0.8, 1), CFrame.new(i * 2.1, 0.4, 8.2), Color3.fromRGB(170, 150, 110), M.Fabric)
	end
	decor(m, "Lamp", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, 6.4, 0), Color3.fromRGB(255, 220, 150), M.Neon)
	mount(m, -4, 0.6, -3.5, 180)
	mount(m, 4, 0.6, -3.5, 180)
	mount(m, 0, 0.6, -4.2, 180)
	return place(m, cf, parent)
end

function Landmarks.Outpost(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("Outpost")
	root(m, 30, 14, 30)
	-- palisade ring, open toward +Z
	for i = 0, 17 do
		local a = math.rad(i * 20)
		local x, z = math.sin(a) * 13, -math.cos(a) * 13
		if z < 9 then
			local st = Build.Cyl("Stake", 7, 1.1, CFrame.new(x, 3.5, z), WOOD_DARK, M.Wood, m)
			st.CanQuery = true
		end
	end
	for _, x in { -4, 4 } do
		tent(m, CFrame.new(x, 0, -4) * CFrame.Angles(0, 0, 0), CANVAS)
	end
	for _, x in { -1.6, 1.6 } do
		for _, z in { -8.4, -11.6 } do
			Build.Cyl("TowerLeg", 9, 0.6, CFrame.new(x + 7, 4.5, z), WOOD_DARK, M.Wood, m)
		end
	end
	solid(m, "TowerDeck", Vector3.new(4.4, 0.4, 4.4), CFrame.new(7, 9, -10), WOOD, M.WoodPlanks)
	firePit(m, CFrame.new(0, 0, 2), rng)
	mount(m, -8, 0, -2, 90)
	mount(m, 8, 0, 2, -90)
	mount(m, 0, 0, -8, 180)
	return place(m, cf, parent)
end

function Landmarks.IndustrialSite(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Build.Model("IndustrialSite")
	root(m, 34, 14, 30)
	-- steel shed frame (no walls on +Z)
	for _, x in { -9, 0, 9 } do
		for _, z in { -8, 4 } do
			solid(m, "Beam", Vector3.new(0.8, 10, 0.8), CFrame.new(x, 5, z), STEEL, M.Metal)
		end
	end
	solid(m, "ShedRoof", Vector3.new(20, 0.6, 14), CFrame.new(0, 10.3, -2), Build.Tint(STEEL, 0.8), M.CorrodedMetal)
	solid(m, "ShedBack", Vector3.new(19, 9, 0.6), CFrame.new(0, 4.5, -8.6), Build.Tint(STEEL, 0.9), M.CorrodedMetal)
	-- containers and tanks
	solid(m, "Container", Vector3.new(6, 6, 14), CFrame.new(-14, 3, 2), Color3.fromRGB(150, 70, 50), M.CorrodedMetal)
	solid(m, "Container", Vector3.new(6, 6, 14), CFrame.new(14, 3, 0) * CFrame.Angles(0, math.rad(8), 0), Color3.fromRGB(60, 90, 120), M.CorrodedMetal)
	Build.Cyl("Tank", 8, 5, CFrame.new(-6, 4, 11) * CFrame.Angles(0, 0, 0), RUST, M.CorrodedMetal, m)
	decor(m, "Barrels", Vector3.new(2, 2.6, 2), CFrame.new(5, 1.3, 9), Color3.fromRGB(70, 90, 70), M.Metal)
	mount(m, -4, 0, -5, 180)
	mount(m, 4, 0, -5, 180)
	mount(m, -14, 0, 11, 0)
	return place(m, cf, parent)
end

function Landmarks.LargeMine(cf: CFrame, rng: Random, parent: Instance?): Model
	local m = Landmarks.MineEntrance(CFrame.new(), rng, nil)
	m.Name = "LargeMine"
	local r = m.PrimaryPart :: BasePart
	r.Size = Vector3.new(22, 14, 20)
	r.CFrame = CFrame.new(0, 7, 0)
	-- headframe tower and an ore shed
	for _, x in { -8, -4 } do
		solid(m, "Headframe", Vector3.new(0.7, 12, 0.7), CFrame.new(x, 6, -6), WOOD_DARK, M.Wood)
	end
	solid(m, "Wheel", Vector3.new(0.4, 3, 3), CFrame.new(-6, 12, -6), STEEL, M.Metal)
	solid(m, "OreShed", Vector3.new(6, 5, 5), CFrame.new(8, 2.5, -2), WOOD_OLD, M.WoodPlanks)
	mount(m, -6, 0, 7, 0)
	return place(m, cf, parent)
end

-- Caves ----------------------------------------------------------------------------------------

-- Rock arch around the mouth (local -Z faces the forest, the tunnel runs along +Z).
-- `length` = tunnel depth; lanterns and chest mounts run along it.
function Landmarks.CaveEntrance(cf: CFrame, rng: Random, length: number, size: string, parent: Instance?): Model
	local m = Build.Model("Cave")
	root(m, 20, 12, length + 6)
	local rootPart = m.PrimaryPart :: BasePart
	rootPart.CFrame = CFrame.new(0, 6, length / 2)
	for i = 0, 6 do
		local a = math.rad(-10 + i * 33.3) -- arch from right to left
		local s = rng:NextNumber(4, 6)
		solid(m, "ArchRock", Vector3.new(s, s, s * 0.9), CFrame.new(math.cos(a) * 7, math.sin(a) * 7.5 + 1, rng:NextNumber(-1, 1)) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0), Build.Tint(STONE, rng:NextNumber(0.7, 0.95)), M.Slate)
	end
	-- moss and hanging roots on the arch
	decor(m, "Moss", Vector3.new(10, 0.3, 3), CFrame.new(0, 8.8, 0), Color3.fromRGB(70, 110, 60), M.Grass)
	-- lanterns (and blue crystals deeper in medium/large caves)
	local lights = math.max(2, math.floor(length / 10))
	for i = 1, lights do
		local z = i * length / (lights + 0.5)
		local side = if i % 2 == 0 then 1 else -1
		local deep = z > length * 0.6 and size ~= "Small"
		local lamp = decor(m, if deep then "Crystal" else "Lantern", if deep then Vector3.new(0.8, 2.2, 0.8) else Vector3.new(0.7, 1, 0.7), CFrame.new(side * 3.6, if deep then 1.1 else 4.5, z) * CFrame.Angles(0, 0, if deep then math.rad(15 * side) else 0),
			if deep then Color3.fromRGB(110, 190, 255) else Color3.fromRGB(255, 200, 120), M.Neon)
		local pl = Instance.new("PointLight")
		pl.Range = if deep then 14 else 18
		pl.Brightness = if deep then 1.4 else 1.8
		pl.Color = lamp.Color
		pl.Shadows = false
		pl.Parent = lamp
	end
	-- chest mounts deep inside
	mount(m, 0, 0.2, length - 3, 180)
	mount(m, -3, 0.2, length * 0.6, 90)
	mount(m, 3, 0.2, length * 0.8, -90)
	mount(m, 0, 0.2, length * 0.45, 180)
	Build.SetPivot(m, rootPart, CFrame.new())
	m:PivotTo(cf)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	if parent then
		m.Parent = parent
	end
	dress(m, "SM_CaveEntrance")
	return m
end

-- Chests ------------------------------------------------------------------------------------------

Landmarks.ChestTiers = {
	Common = { Body = WOOD, Trim = Color3.fromRGB(90, 90, 96), Glow = nil, Mesh = "SM_Chest_Common" },
	Uncommon = { Body = Color3.fromRGB(96, 120, 84), Trim = Color3.fromRGB(150, 150, 160), Glow = nil, Mesh = "SM_Chest_Uncommon" },
	Rare = { Body = Color3.fromRGB(70, 90, 140), Trim = Color3.fromRGB(210, 180, 90), Glow = Color3.fromRGB(120, 160, 255), Mesh = "SM_Chest_Rare" },
	VeryRare = { Body = Color3.fromRGB(110, 60, 140), Trim = Color3.fromRGB(240, 200, 90), Glow = Color3.fromRGB(220, 140, 255), Mesh = "SM_Chest_VeryRare" },
}

function Landmarks.Chest(cf: CFrame, tier: string, parent: Instance?): Model
	local spec = Landmarks.ChestTiers[tier] or Landmarks.ChestTiers.Common
	local m = Build.Model("Chest")
	local r = Build.Part({ Name = "Root", Size = Vector3.new(3.6, 2.6, 2.4), CFrame = CFrame.new(0, 1.3, 0), Transparency = 1, CanCollide = false, CanQuery = true, Parent = m })
	m.PrimaryPart = r
	Build.Part({ Name = "Body", Size = Vector3.new(3.4, 1.6, 2.2), CFrame = CFrame.new(0, 0.8, 0), Color = spec.Body, Material = M.WoodPlanks, Parent = m })
	local lid = Build.Part({ Name = "Lid", Size = Vector3.new(3.5, 0.7, 2.3), CFrame = CFrame.new(0, 1.95, 0), Color = Build.Tint(spec.Body, 0.85), Material = M.WoodPlanks, Parent = m })
	lid.CanCollide = false
	for _, x in { -1.2, 1.2 } do
		Build.Decor({ Name = "Trim", Size = Vector3.new(0.3, 2.4, 2.35), CFrame = CFrame.new(x, 1.2, 0), Color = spec.Trim, Material = M.Metal, Parent = m })
	end
	Build.Decor({ Name = "Lock", Size = Vector3.new(0.5, 0.6, 0.2), CFrame = CFrame.new(0, 1.5, -1.2), Color = spec.Trim, Material = M.Metal, Parent = m })
	if spec.Glow then
		local g = Instance.new("PointLight")
		g.Color = spec.Glow
		g.Range = 10
		g.Brightness = 0.9
		g.Parent = r
	end
	m:SetAttribute("Tier", tier)
	Build.SetPivot(m, r, CFrame.new())
	m:PivotTo(cf)
	if parent then
		m.Parent = parent
	end
	if Skins.Has(spec.Mesh) then
		Skins.Dress(m, spec.Mesh, { keep = { Lid = true } })
	end
	return m
end

-- Opens a chest lid (server; replicates).
function Landmarks.OpenChest(m: Model)
	local lid = m:FindFirstChild("Lid") :: BasePart?
	local r = m.PrimaryPart
	if lid and r and not m:GetAttribute("Open") then
		lid.CFrame = r.CFrame * CFrame.new(0, 1.1, 1.3) * CFrame.Angles(math.rad(-70), 0, 0)
		m:SetAttribute("Open", true)
	end
	for _, d in m:GetDescendants() do
		if d:IsA("PointLight") then
			d.Enabled = false
		end
	end
end

-- Dispatcher --------------------------------------------------------------------------------------

function Landmarks.Build(kind: string, cf: CFrame, rng: Random, parent: Instance?): Model?
	local f = (Landmarks :: any)[kind]
	if type(f) ~= "function" or kind == "Chest" or kind == "CaveEntrance" or kind == "Build" or kind == "OpenChest" then
		return nil
	end
	local m = f(cf, rng, parent)
	dress(m, "SM_POI_" .. kind)
	return m
end

return Landmarks

end)()
local __m_Refuge = (function()
-- The lobby as a forest refuge (over a voxel forest floor with a stream and
-- ponds, built by WorldService): layered forest ring, lobby props (gathering deck, stalls, party area, ready arch, class stands),
-- signposts, lanterns and the Hall of Fame board. Mesh-first over the
-- procedural lobby, which keeps every collider, prompt and label.

local Build = __m_Build
local Skins = __m_Skins
local Decor = __m_Decor

local Refuge = {}

-- Forest-refuge dressing for the lobby: layered forest ring, Blender ground
-- sections, lobby props and signposts. Everything is mesh-first with the
-- procedural lobby underneath (colliders, prompts and labels stay on it).
export type Water = { Ponds: { { X: number, Z: number, R: number } }, Stream: { { number } } }

function Refuge.Dress(folder: Instance, O: Vector3, readyCenter: Vector3, stations: { [string]: Model }, water: Water?): TextLabel?
	local board: TextLabel? = nil
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
		local pos = ringSpot(56, 70)
		if not clearOfStations(pos) then
			continue
		end
		local kind = ({ "Spruce", "Spruce", "Aspen", "GiantTree" })[rng:NextInteger(1, 4)]
		Decor.Place(kind, flatCF(pos), rng, rng:NextNumber(0.8, 1.15), deco)
	end
	for _ = 1, 40 do
		local pos = ringSpot(44, 60)
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
	-- Central gathering deck around the fire
	if Skins.Has("SM_Lobby_GatheringArea") then
		local v = Skins.Visual("SM_Lobby_GatheringArea")
		if v then
			v:PivotTo(CFrame.new(O + Vector3.new(0, -0.3, 0)))
			v.Name = "GatheringDeck"
			v.Parent = deco
			for _, seat in folder:GetChildren() do
				if seat.Name == "LogSeat" and seat:IsA("BasePart") then
					seat.Transparency = 1
				end
			end
		end
	end
	-- Stations get their Blender props (procedural counters stay as colliders)
	local DRESS = { Shop = "SM_Lobby_ShopDisplay", Party = "SM_Lobby_PartyArea", Locker = "SM_Lobby_ShopDisplay" }
	for name, mesh in DRESS do
		local m = stations[name]
		if m and m.PrimaryPart then
			local pos = m.PrimaryPart.Position
			Skins.Dress(m, mesh, { cf = flatCF(Vector3.new(pos.X, O.Y, pos.Z), O), keep = { Awning = name == "Locker" } })
		end
	end
	local shrine = stations.Classes
	if shrine and Skins.Has("SM_Lobby_PowerupStand") then
		for _, ped in shrine:GetChildren() do
			if ped.Name == "Pedestal" and ped:IsA("BasePart") then
				local v = Skins.Visual("SM_Lobby_PowerupStand")
				if v then
					v:PivotTo(flatCF(Vector3.new(ped.Position.X, O.Y, ped.Position.Z), O))
					v.Parent = shrine
					ped.Transparency = 1
				end
			end
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
	-- Hall of Fame board: live leaderboard surface
	local profile = stations.Profile
	if profile and profile.PrimaryPart then
		local counter = profile.PrimaryPart
		-- panel centre matches SM_Sign_Board_Panel (5 studs above its base), just in front of it
		local boardCF = counter.CFrame * CFrame.new(0, 3.3, 1.15)
		local boardPart = Build.Part({ Name = "Board", Size = Vector3.new(9, 4.5, 0.3), CFrame = boardCF, Color = Color3.fromRGB(70, 52, 36), Material = Enum.Material.WoodPlanks, Parent = profile })
		if Skins.Has("SM_Sign_Board") then
			Skins.Dress(profile, "SM_Sign_Board", { cf = counter.CFrame * CFrame.new(0, -1.7, 1.4), noHide = true, extra = true })
		end
		local sg = Instance.new("SurfaceGui")
		sg.Name = "Leaderboard"
		sg.Face = Enum.NormalId.Front
		sg.CanvasSize = Vector2.new(540, 270)
		sg.LightInfluence = 0.2
		sg.Parent = boardPart
		local tl = Instance.new("TextLabel")
		tl.Name = "Text"
		tl.Size = UDim2.fromScale(1, 1)
		tl.BackgroundTransparency = 1
		tl.Font = Enum.Font.GothamBold
		tl.TextColor3 = Color3.fromRGB(255, 225, 160)
		tl.TextScaled = true
		tl.Text = "HALL OF FAME\nMost wins — updating…"
		tl.Parent = sg
		board = tl
	end
	-- Signposts toward each station
	local SIGNS = {
		{ Dir = Vector3.new(1, 0, 0), Text = "→ TRADING POST" },
		{ Dir = Vector3.new(-1, 0, 0), Text = "→ CLASS SHRINE" },
		{ Dir = Vector3.new(0, 0, 1), Text = "→ PARTY" },
		{ Dir = Vector3.new(0, 0, -1), Text = "→ READY UP" },
		{ Dir = Vector3.new(1, 0, 1).Unit, Text = "→ OUTFITTER" },
		{ Dir = Vector3.new(-1, 0, 1).Unit, Text = "→ HALL OF FAME" },
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
	-- Lanterns along the paths (warm pools of light for the golden hour)
	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		for _, r in { 26, 44 } do
			for _, side in { -1, 1 } do
				local pos = O + dir * r + dir:Cross(Vector3.yAxis) * 6 * side
				local pole = Build.Cyl("LanternPole", 6, 0.35, CFrame.new(pos + Vector3.new(0, 3, 0)), Color3.fromRGB(70, 56, 44), Enum.Material.Wood, deco)
				local glow = Build.Part({ Name = "Lantern", Size = Vector3.new(0.8, 1, 0.8), CFrame = CFrame.new(pos + Vector3.new(0, 6.3, 0)), Color = Color3.fromRGB(255, 190, 110), Material = Enum.Material.Neon, Parent = deco, CanCollide = false })
				local light = Instance.new("PointLight")
				light.Color = Color3.fromRGB(255, 180, 110)
				light.Range = 14
				light.Brightness = 1.2
				light.Shadows = false
				light.Parent = glow
				pole.CanQuery = false
			end
		end
	end
	return board
end

return Refuge

end)()

local Skins = __m_Skins
local Nature = __m_Nature
local Flora = __m_Flora
local Camp = __m_Camp
local Structures = __m_Structures
local ItemModels = __m_ItemModels
local LootModels = __m_LootModels
local Animals = __m_Animals
local Refuge = __m_Refuge
local Decor = __m_Decor
local Landmarks = __m_Landmarks

-- helpers -----------------------------------------------------------------------
local passed, failed = 0, 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name .. " -> " .. tostring(err))
	end
end
local function check(v, msg)
	if not v then
		error(msg or "check failed", 2)
	end
end
local function skins(m)
	local out = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Skin") then
			table.insert(out, d)
		end
	end
	return out
end
local function visibleProcedural(m, keep)
	local n = 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and not d:GetAttribute("Skin") and d.Transparency < 1 and not d:GetAttribute("TeamTint")
			and not (keep and keep[d.Name]) then
			n += 1
		end
	end
	return n
end
local function skinOf(m, name)
	for _, d in skins(m) do
		if d:GetAttribute("SkinOf") == name then
			return d
		end
	end
	return nil
end
local function near(a, b, tol, msg)
	check(math.abs(a - b) <= (tol or 0.05), string.format("%s: %.3f vs %.3f", msg or "near", a, b))
end
local at = CFrame.new(20, 3, -7) * CFrame.Angles(0, 0.7, 0)

-- decor -------------------------------------------------------------------------
for _, case in {
	{ "Pine", function() return Nature.Pine(at, 1, workspace) end, 30 },
	{ "Oak", function() return Nature.Oak(at, 1, workspace) end, 28 },
	{ "Birch", function() return Nature.Birch(at, 1, workspace) end, 27 },
	{ "GrassClump", function() return Nature.GrassClump(at, workspace) end, 4 },
} do
	test("decor " .. case[1], function()
		local m = case[2]()
		local s = skins(m)
		check(#s >= 1, "no mesh")
		check(visibleProcedural(m) == 0, "procedural parts still visible")
		near(s[1].Size.Y, case[3], 0.05, "height")
		-- sits on the model's ground pivot
		near(s[1].Position.Y - s[1].Size.Y / 2, 3, 1.2, "mesh base on ground")
		check(not s[1].CanCollide and not s[1].CanQuery, "mesh must not collide/query")
	end)
end
test("decor Pine keeps trunk collision", function()
	local m = Nature.Pine(at, 1, workspace)
	check(m:FindFirstChild("Trunk").CanCollide, "trunk collision lost")
end)
test("decor Bush/BigRock/FallenGiant dressed", function()
	check(#skins(Nature.Bush(at, 1, workspace)) == 1, "bush")
	check(#skins(Nature.BigRock(at, 1, workspace)) == 1, "rock")
	check(skinOf(Nature.FallenGiant(at, workspace), "SM_Landmark_GiantLog"), "giant log")
end)

-- resource nodes ------------------------------------------------------------------
test("ResourceTree mesh in Top + hidden stump", function()
	for _, sp in { "Pine", "Oak", "Birch" } do
		for _, size in { "Small", "Medium", "Large" } do
			local m = Flora.ResourceTree(at, Random.new(3), size, sp, workspace)
			local top = m:FindFirstChild("Top")
			check(#skins(top) == 1, sp .. size .. ": tree mesh not inside Top")
			local stump
			for _, d in m:GetChildren() do
				if d:IsA("BasePart") and d:GetAttribute("SkinStump") then
					stump = d
				end
			end
			check(stump and stump.Transparency == 1, "stump mesh should start hidden")
			Skins.SetTagged(m, "SkinStump", true)
			check(stump.Transparency == 0, "stump not shown")
			check(visibleProcedural(m) == 0, "procedural visible")
			check(m:FindFirstChild("Stump") and m:FindFirstChild("Stump").CanCollide, "stump collider lost")
		end
	end
end)
test("DeadTree dressed", function()
	local m = Flora.DeadTree(at, Random.new(4), workspace)
	check(#skins(m:FindFirstChild("Top")) == 1, "dead tree mesh")
end)
test("RockPile: yield mesh + depleted mesh", function()
	local m = Flora.RockPile(at, Random.new(5), workspace)
	local full, dep = skinOf(m, "SM_StoneDeposit01"), skinOf(m, "SM_StoneDeposit01_Depleted")
	check(full and full:GetAttribute("Yield"), "deposit must be Yield")
	check(dep and not dep:GetAttribute("Yield"), "depleted rubble must stay")
	check(m:FindFirstChild("Boulder").CanCollide, "boulder collision lost")
end)
test("FibrePlant / TwigPile / Mushrooms / LooseStones / BerryBush", function()
	local f = Flora.FibrePlant(at, Random.new(6), workspace)
	check(skinOf(f, "SM_FiberPlant01"):GetAttribute("Yield") and skinOf(f, "SM_FiberPlant01_Harvested"), "fibre")
	local t = Flora.TwigPile(at, Random.new(7), workspace)
	check(skinOf(t, "SM_Sticks_Loose01"):GetAttribute("Yield"), "twigs")
	check(t:FindFirstChild("Litter").Transparency < 1, "litter should stay visible")
	check(skinOf(Flora.MushroomPatch(at, Random.new(8), workspace), "SM_Mushrooms01"), "mushrooms")
	check(skinOf(Flora.LooseStones(at, Random.new(9), workspace), "SM_StreamRocks01"), "stones")
	local b = Flora.BerryBush(at, Random.new(10), workspace)
	check(skinOf(b, "SM_Bush01") and not skinOf(b, "SM_Bush01"):GetAttribute("Yield"), "berry bush mesh")
	check(visibleProcedural(b, { Berry = true }) == 0 and b:FindFirstChild("Berry").Transparency == 0, "berries stay visible")
end)

-- camp ---------------------------------------------------------------------------
test("Campfire: mesh, effects kept, extinguish swap", function()
	local m = Camp.Campfire(at, Color3.new(1, 0, 0), workspace)
	check(skinOf(m, "SM_Campfire_Burning"), "burning mesh")
	check(m:FindFirstChild("FireCore"):FindFirstChild("Flame"), "fire effect")
	check(m:FindFirstChild("SafeRing").Transparency < 1, "safe ring hidden")
	Camp.Extinguish(m)
	check(skinOf(m, "SM_Campfire_Extinguished") and not skinOf(m, "SM_Campfire_Burning"), "extinguish swap")
end)
test("Campfire: level/fuel visuals", function()
	local m = Camp.Campfire(at, Color3.new(1, 0, 0), workspace)
	local core = m:FindFirstChild("FireCore")
	local flame, glow = core:FindFirstChild("Flame"), core:FindFirstChild("Glow")
	Camp.SetFire(m, 1, 1)
	local s1, r1 = flame.Size, glow.Range
	Camp.SetFire(m, 5, 1)
	check(flame.Size > s1 and glow.Range > r1, "level 5 bigger and brighter")
	check(core:FindFirstChild("Smoke").Enabled, "higher fires smoke")
	Camp.SetFire(m, 5, 0.05)
	check(flame.Size < s1 * 2, "low fuel shrinks")
end)
test("Workbench levels", function()
	for lvl = 1, 3 do
		local m = Camp.Workbench(at, lvl, Color3.new(0, 0, 1), workspace)
		check(skinOf(m, "SM_Workbench_Level0" .. lvl), "level " .. lvl)
		check(m:FindFirstChild("Top").CanCollide, "bench top collision")
	end
	check(skinOf(Camp.Lantern(at, Color3.new(1, 1, 1), workspace), "SM_Camp_Lantern"), "lantern")
end)
test("Workbench tiers IV-V keep their upgrades visible", function()
	local m4 = Camp.Workbench(at, 4, Color3.new(0, 0, 1), workspace)
	check(skinOf(m4, "SM_Workbench_Level04"), "tier 4 mesh")
	check(m4:FindFirstChild("Forge") and m4:FindFirstChild("Forge").CanCollide, "forge collider kept")
	check(m4:FindFirstChild("ForgeCoals").Transparency == 0, "coals glow stays visible")
	local m5 = Camp.Workbench(at, 5, Color3.new(0, 0, 1), workspace)
	check(skinOf(m5, "SM_Workbench_Level05"), "tier 5 mesh")
end)
test("LargeRockPile: bigger yield mesh", function()
	local m = Flora.LargeRockPile(at, Random.new(5), workspace)
	check(skinOf(m, "SM_StoneDeposit01"), "deposit mesh")
	check(m.PrimaryPart.Size.X > 10, "double-size root")
end)
test("POIs: every landmark builds with a Root and chest mounts", function()
	for _, kind in { "Campsite", "Shed", "HuntingBlind", "BrokenVehicle", "SmallCabin", "Cabin", "RangerStation", "LoggingCamp", "AbandonedHouse", "MineEntrance", "Bunker", "Outpost", "IndustrialSite", "LargeMine" } do
		local m = Landmarks.Build(kind, at, Random.new(4), workspace)
		check(m and m.PrimaryPart and m.PrimaryPart.Name == "Root", kind .. " root")
		local mounts = 0
		for _, d in m:GetDescendants() do
			if d:IsA("Attachment") and d.Name == "ChestMount" then
				mounts += 1
			end
		end
		check(mounts >= 1, kind .. " chest mounts")
	end
	check(skinOf(Landmarks.Build("Cabin", at, Random.new(4), workspace), "SM_POI_Cabin"), "cabin mesh")
	check(skinOf(Landmarks.Chest(at, "Rare", workspace), "SM_Chest_Rare"), "rare chest mesh")
	local cave = Landmarks.CaveEntrance(at, Random.new(2), 34, "Medium", workspace)
	check(skinOf(cave, "SM_CaveEntrance"), "cave arch mesh")
	check(cave:FindFirstChild("Crystal") or cave:FindFirstChild("Lantern"), "cave lights")
	for _, tier in { "Common", "Uncommon", "Rare", "VeryRare" } do
		local c = Landmarks.Chest(at, tier, workspace)
		check(c:FindFirstChild("Lid"), tier .. " chest lid")
		Landmarks.OpenChest(c)
		check(c:GetAttribute("Open"), tier .. " opens")
	end
end)
test("Decor: mesh-first with colliders for solid kinds", function()
	local log = Decor.Place("FallenLog", at, Random.new(1), 1, workspace)
	check(log and log:FindFirstChild("Collider"), "log collider")
	local fern = Decor.Place("Fern", at, Random.new(1), 1, workspace)
	check(fern and not fern:FindFirstChild("Collider"), "fern is decor only")
	check(Decor.Place("FlowerPatch", at, Random.new(1), 1, workspace), "flowers")
	check(Decor.Place("Spruce", at, Random.new(1), 1, workspace):FindFirstChild("Collider"), "spruce trunk collider")
	for _, id in { "ScrapWall", "MetalWall", "WoodFloor", "ReinforcedChest", "MetalLocker", "SurvivalSafe", "BearTrap", "Snare", "TripwireAlarm" } do
		check(#skins(Structures.Build(id, at, Color3.new(1, 0, 0), workspace)) >= 1, id .. " mesh")
	end
	for _, id in { "StonePickaxe", "IronAxe", "Crowbar", "Sledgehammer", "Crossbow", "HuntingBow" } do
		check(#skins(ItemModels.Held(id)) >= 1, id .. " held mesh")
	end
	for _, id in { "ScrapPile", "CoalDeposit", "IronDeposit", "RichIronDeposit" } do
		local m = Flora[id](at, Random.new(3), workspace)
		local yields = 0
		for _, d in m:GetDescendants() do
			if d:GetAttribute("Yield") then
				yields += 1
			end
		end
		check(yields > 0, id .. " yield parts")
	end
end)
test("Wildlife rigs: deer, rabbit, boar", function()
	for _, sp in { "Deer", "Rabbit", "Boar", "Wolf", "Bear" } do
		local m = Animals.Build(sp)
		check(m:FindFirstChildOfClass("Humanoid"), sp .. " humanoid")
		check(m:FindFirstChild("HumanoidRootPart"), sp .. " root")
	end
	check(Animals.Build("Deer"):FindFirstChild("Antler"), "deer antlers")
	check(Animals.Build("Boar"):FindFirstChild("Tusk"), "boar tusks")
end)
test("Ranged tiers + armour pieces build", function()
	for _, id in { "HuntingBow", "Crossbow", "Bolt" } do
		check(ItemModels.Held(id), id)
	end
end)
test("Tiered tools build (axes, pickaxes, crude spear, meds)", function()
	for _, tn in { "Crude", "Stone", "Iron", "Steel" } do
		for _, kind in { "Axe", "Pickaxe" } do
			local m = ItemModels.Held(tn .. kind)
			check(m and m.PrimaryPart and m.PrimaryPart.Name == "Handle", tn .. kind)
		end
	end
	check(skinOf(ItemModels.Held("CrudeAxe"), "StoneAxe"), "crude axe uses the stone axe mesh")
	check(ItemModels.Held("CrudeSpear"), "crude spear")
	check(ItemModels.Pickup("Medkit", 1, at, workspace), "medkit pickup")
end)

-- structures -------------------------------------------------------------------------
test("Survival Wars structures build (tiers, storage, traps)", function()
	for _, id in { "WoodFloor", "WindowWall", "ScrapWall", "MetalWall", "ReinforcedDoor", "HeavyGate", "ReinforcedChest", "MetalLocker", "SurvivalSafe", "TripwireAlarm", "Snare", "BearTrap", "AdvancedAlarm" } do
		local m = Structures.Build(id, at, Color3.new(1, 0, 0), workspace)
		check(m.PrimaryPart and m.PrimaryPart.Name == "Root", id .. " root")
	end
	local win = Structures.Build("WindowWall", at, Color3.new(1, 0, 0), workspace)
	check(#skins(win) == 0, "window wall shows the procedural wall (the pack wall has no window)")
	local door = Structures.Build("ReinforcedDoor", at, Color3.new(1, 0, 0), workspace)
	check(door:FindFirstChild("Door") and door:FindFirstChild("Door").PrimaryPart, "door panel")
	Structures.SetGateOpen(door, true)
	check(door:GetAttribute("Open") == true, "tiered doors open")
	local crate = Structures.Build("StorageBox", at, Color3.new(1, 0, 0), workspace)
	Structures.SetBreached(crate, true)
	check(crate:FindFirstChild("BreachTag"), "breach tag")
	Structures.SetBreached(crate, false)
	check(not crate:FindFirstChild("BreachTag"), "resecured")
	for _, id in { "Snare", "BearTrap", "TripwireAlarm" } do
		check(Structures.Build(id, at, Color3.new(1, 0, 0), workspace):FindFirstChild("Trigger"), id .. " trigger")
	end
end)
test("Structures dressed + collision intact", function()
	for _, id in { "WoodWall", "ReinforcedWall", "Gate", "Spikes", "StorageBox", "Watchtower" } do
		local m = Structures.Build(id, at, Color3.new(1, 0, 0), workspace)
		check(#skins(m) >= 1, id .. " no mesh")
		check(visibleProcedural(m, { Lock = true }) == 0, id .. " procedural visible")
	end
end)
test("WoodWall stretched to the 10-stud grid", function()
	local m = Structures.WoodWall(CFrame.new(), workspace)
	local s = skinOf(m, "SM_WoodenWall")
	near(s.Size.X, 8.59 * 1.25, 0.02, "wall width")
	check(m:FindFirstChild("Collider").CanCollide, "collider lost")
end)
test("Damage swap and repair", function()
	local m = Structures.WoodWall(at, workspace)
	Structures.ApplyDamageState(m, 0.5)
	check(skinOf(m, "SM_WoodenWall_Damaged") and not skinOf(m, "SM_WoodenWall"), "damaged mesh")
	Structures.ApplyDamageState(m, 1)
	check(skinOf(m, "SM_WoodenWall") and not skinOf(m, "SM_WoodenWall_Damaged"), "repaired mesh")
	near(skinOf(m, "SM_WoodenWall").Size.X, 8.59 * 1.25, 0.02, "stretch kept after swap")
	local box = Structures.StorageBox(at, Color3.new(1, 1, 1), workspace)
	Structures.ApplyDamageState(box, 0.2)
	check(skinOf(box, "SM_StorageBox_Damaged"), "box damaged")
end)
test("Gate door mesh rides the Door model", function()
	local m = Structures.Gate(CFrame.new(), Color3.new(1, 0, 0), workspace)
	local door = m:FindFirstChild("Door")
	local dm = door:FindFirstChild("SM_Gate_Door")
	check(dm and dm:GetAttribute("Skin"), "door mesh not in Door")
	local y0 = dm.Position.Y
	Structures.SetGateOpen(m, true)
	near(dm.Position.Y - y0, 7.4, 0.05, "door mesh opens with the door")
	check(skinOf(m, "SM_WallPost"), "second post")
end)
test("Watchtower ladder follows the mesh", function()
	local m = Structures.Watchtower(CFrame.new(), Color3.new(1, 0, 0), workspace)
	local l = m:FindFirstChild("Ladder")
	near(l.Position.Z, -3.0, 0.01, "ladder z")
end)

-- items & loot --------------------------------------------------------------------
test("Held items: mesh welded to Handle", function()
	for _, id in { "Spear", "Bow", "Sword", "Shield", "Pistol", "Rifle", "StoneAxe", "RepairHammer", "Canteen", "Bandage", "Arrow", "Bullet" } do
		local m = ItemModels.Held(id)
		local s = skins(m)
		check(#s >= 1, id .. " no mesh")
		for _, p in s do
			check(not p.Anchored, id .. " mesh anchored")
			local w = p:FindFirstChildOfClass("WeldConstraint")
			check(w and w.Part0 == m.PrimaryPart and w.Part1 == p, id .. " not welded to Handle")
		end
		check(m.PrimaryPart.Transparency == 1, id .. " procedural handle visible")
	end
	check(#skins(ItemModels.Held("Armor")) == 0, "armor stays procedural")
end)
test("Pistol slide comes along", function()
	check(skinOf(ItemModels.Held("Pistol"), "Pistol") and ItemModels.Held("Pistol"):FindFirstChild("SM_Pistol_Slide"), "slide")
end)
test("StoneAxe head points up along the haft", function()
	local m = ItemModels.Held("StoneAxe")
	local h = m.PrimaryPart
	local s = skinOf(m, "StoneAxe")
	local rel = h.CFrame:ToObjectSpace(s.CFrame)
	-- pack axe: haft along +Y; here the haft must run along -Z from the grip
	check(rel.Position.Z < -0.5, "haft should extend along -Z, got z=" .. rel.Position.Z)
end)
test("Pickups", function()
	check(skinOf(ItemModels.Pickup("Wood", 3, at, workspace), "SM_Pickup_Wood"), "wood pickup")
	check(#skins(ItemModels.Pickup("Sword", 1, at, workspace)) >= 1, "sword pickup")
end)
test("Care package + parachute + land", function()
	local m = LootModels.CarePackage(at, workspace)
	local chute = m:FindFirstChild("Parachute")
	check(skinOf(chute, "SM_Parachute_Canopy") and skinOf(chute, "SM_Parachute_Lines"), "parachute meshes in Parachute")
	check(skinOf(m, "SM_CarePackage_Crate"), "crate")
	LootModels.Land(m)
	check(m:FindFirstChild("Parachute") == nil and not skinOf(m, "SM_Parachute_Canopy"), "parachute removed on landing")
	check(#skins(LootModels.ForestCrate(at, workspace)) >= 1, "forest crate")
end)

-- lobby refuge ----------------------------------------------------------------------
local function lobbyStations(folder)
	local O = Vector3.new(0, 0, 0)
	local out = {}
	for name, pos in { Shop = Vector3.new(40, 0, 0), Classes = Vector3.new(-40, 0, 0), Party = Vector3.new(0, 0, 40), Locker = Vector3.new(30, 0, 30), Profile = Vector3.new(-30, 0, 30) } do
		local m = Instance.new("Model")
		m.Name = name
		local c = Instance.new("Part")
		c.Name = "Counter"
		c.Size = Vector3.new(10, 3.4, 3)
		c.CFrame = CFrame.lookAt(pos + Vector3.new(0, 1.7, 0), O + Vector3.new(0, 1.7, 0))
		c.Parent = m
		m.PrimaryPart = c
		if name == "Classes" then
			for i = 1, 3 do
				local ped = Instance.new("Part")
				ped.Name = "Pedestal"
				ped.Size = Vector3.new(2.4, 3, 2.4)
				ped.CFrame = CFrame.new(pos + Vector3.new(i * 3, 1.5, 0))
				ped.Parent = m
			end
		end
		m.Parent = folder
		out[name] = m
	end
	return out
end
test("Lobby refuge: forest, props, signs, board", function()
	local folder = Instance.new("Folder")
	folder.Parent = workspace
	local st = lobbyStations(folder)
	local water = { Ponds = { { X = 34, Z = -30, R = 9 } }, Stream = { { 50, -41 } } }
	local board = Refuge.Dress(folder, Vector3.new(0, 0, 0), Vector3.new(0, 0, -38), st, water)
	check(board ~= nil and board:IsA("TextLabel"), "hall of fame board label")
	local forest = folder:FindFirstChild("Forest")
	check(forest ~= nil, "forest folder")
	local n, deck, arch, wet = 0, false, false, 0
	for _, c in forest:GetChildren() do
		n += 1
		if c.Name == "GatheringDeck" then
			deck = true
		elseif c.Name == "ReadyArch" then
			arch = true
		end
		if c:IsA("Model") and c.Name ~= "GatheringDeck" and c.Name ~= "ReadyArch" then
			local p = c:GetPivot().Position
			if (p - Vector3.new(34, 0, -30)).Magnitude < 9 then
				wet += 1
			end
		end
	end
	check(n > 60, "layered forest placed (" .. n .. ")")
	check(deck and arch, "deck + ready arch")
	check(wet == 0, "no decoration placed in the pond (" .. wet .. ")")
	check(skinOf(st.Shop, "SM_Lobby_ShopDisplay") and skinOf(st.Party, "SM_Lobby_PartyArea"), "station props")
	check(skinOf(st.Classes, "SM_Lobby_PowerupStand"), "class stands")
	check(st.Shop.PrimaryPart.CanCollide ~= false, "counter keeps collision")
	local signs = 0
	for _, d in forest:GetDescendants() do
		if d:IsA("SurfaceGui") then
			signs += 1
		end
	end
	check(signs == 6, "six signposts (" .. signs .. ")")
end)
test("Lobby refuge without the pack stays procedural", function()
	RS:SetAttribute("MeshSkins", false)
	local folder = Instance.new("Folder")
	folder.Parent = workspace
	local st = lobbyStations(folder)
	local board = Refuge.Dress(folder, Vector3.new(0, 0, 0), Vector3.new(0, 0, -38), st)
	check(board ~= nil, "board without pack")
	check(#skins(st.Shop) == 0 and st.Shop.PrimaryPart.Transparency < 1, "shop stays procedural")
	RS:SetAttribute("MeshSkins", nil)
end)

-- disabled library ------------------------------------------------------------------
test("MeshSkins=false leaves the procedural look", function()
	RS:SetAttribute("MeshSkins", false)
	local m = Nature.Pine(at, 1, workspace)
	check(#skins(m) == 0, "mesh added while disabled")
	check(visibleProcedural(m) > 0, "procedural hidden while disabled")
	local w = Structures.WoodWall(at, workspace)
	Structures.ApplyDamageState(w, 0.2)
	check(#skins(w) == 0, "damage swap while disabled")
	RS:SetAttribute("MeshSkins", nil)
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	error("skins tests failed")
end
