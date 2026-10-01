-- Headless Roblox mock, part 0: value types (Vector3, CFrame, Color3, UDim2, Enum, ...).
-- This is a MOCK for offline integration runs. It follows Roblox semantics where the game relies
-- on them, but it is not Roblox: no physics, no rendering, no real networking.
-- All mock files are concatenated into one chunk by tools/headless/run.py; they share `M`.

local TYPE = setmetatable({}, { __mode = "k" }) -- metatable -> typeof name
M.TYPE = TYPE

local function fmt(n)
	return string.format("%.4g", n)
end

------------------------------------------------------------------------------------------ Vector3
local V3 = {}
TYPE[V3] = "Vector3"
local V3m = {}
local function V(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
end
local function vmag(v)
	return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
end
V3.__index = function(v, k)
	if k == "Magnitude" then
		return vmag(v)
	elseif k == "Unit" then
		local m = vmag(v)
		if m == 0 then
			return V(0 / 0, 0 / 0, 0 / 0)
		end
		return V(v.X / m, v.Y / m, v.Z / m)
	elseif k == "x" then
		return v.X
	elseif k == "y" then
		return v.Y
	elseif k == "z" then
		return v.Z
	end
	local f = V3m[k]
	if f then
		return f
	end
	error(tostring(k) .. " is not a valid member of Vector3", 2)
end
V3.__newindex = function()
	error("Vector3 is immutable", 2)
end
V3.__add = function(a, b)
	return V(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return V(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__unm = function(a)
	return V(-a.X, -a.Y, -a.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return V(b.X * a, b.Y * a, b.Z * a)
	elseif type(b) == "number" then
		return V(a.X * b, a.Y * b, a.Z * b)
	end
	return V(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return V(a.X / b, a.Y / b, a.Z / b)
	end
	return V(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__idiv = function(a, b)
	if type(b) == "number" then
		return V(a.X // b, a.Y // b, a.Z // b)
	end
	return V(a.X // b.X, a.Y // b.Y, a.Z // b.Z)
end
V3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3.__tostring = function(v)
	return fmt(v.X) .. ", " .. fmt(v.Y) .. ", " .. fmt(v.Z)
end
function V3m.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
function V3m.Cross(a, b)
	return V(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function V3m.Lerp(a, b, t)
	return V(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t)
end
function V3m.Min(a, b)
	return V(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
end
function V3m.Max(a, b)
	return V(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
end
function V3m.Abs(a)
	return V(math.abs(a.X), math.abs(a.Y), math.abs(a.Z))
end
function V3m.Floor(a)
	return V(math.floor(a.X), math.floor(a.Y), math.floor(a.Z))
end
function V3m.Ceil(a)
	return V(math.ceil(a.X), math.ceil(a.Y), math.ceil(a.Z))
end
function V3m.Sign(a)
	return V(math.sign(a.X), math.sign(a.Y), math.sign(a.Z))
end
function V3m.FuzzyEq(a, b, eps)
	eps = eps or 1e-5
	return math.abs(a.X - b.X) <= eps and math.abs(a.Y - b.Y) <= eps and math.abs(a.Z - b.Z) <= eps
end
function V3m.Angle(a, b)
	local d = V3m.Dot(a, b) / math.max(vmag(a) * vmag(b), 1e-12)
	return math.acos(math.clamp(d, -1, 1))
end
local Vector3 = {
	new = V,
	zero = V(0, 0, 0),
	one = V(1, 1, 1),
	xAxis = V(1, 0, 0),
	yAxis = V(0, 1, 0),
	zAxis = V(0, 0, 1),
	FromNormalId = function()
		return V(0, 1, 0)
	end,
}
M.V3meta = V3
M.Vector3 = Vector3

------------------------------------------------------------------------------------------ Vector2
local V2 = {}
TYPE[V2] = "Vector2"
local V2m = {}
local function V2new(x, y)
	return setmetatable({ X = x or 0, Y = y or 0 }, V2)
end
V2.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y)
		return V2new(v.X / m, v.Y / m)
	elseif k == "x" then
		return v.X
	elseif k == "y" then
		return v.Y
	end
	local f = V2m[k]
	if f then
		return f
	end
	error(tostring(k) .. " is not a valid member of Vector2", 2)
end
V2.__add = function(a, b)
	return V2new(a.X + b.X, a.Y + b.Y)
end
V2.__sub = function(a, b)
	return V2new(a.X - b.X, a.Y - b.Y)
end
V2.__unm = function(a)
	return V2new(-a.X, -a.Y)
end
V2.__mul = function(a, b)
	if type(a) == "number" then
		return V2new(b.X * a, b.Y * a)
	elseif type(b) == "number" then
		return V2new(a.X * b, a.Y * b)
	end
	return V2new(a.X * b.X, a.Y * b.Y)
end
V2.__div = function(a, b)
	if type(b) == "number" then
		return V2new(a.X / b, a.Y / b)
	end
	return V2new(a.X / b.X, a.Y / b.Y)
end
V2.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
V2.__tostring = function(v)
	return fmt(v.X) .. ", " .. fmt(v.Y)
end
function V2m.Dot(a, b)
	return a.X * b.X + a.Y * b.Y
end
function V2m.Lerp(a, b, t)
	return V2new(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t)
end
function V2m.Min(a, b)
	return V2new(math.min(a.X, b.X), math.min(a.Y, b.Y))
end
function V2m.Max(a, b)
	return V2new(math.max(a.X, b.X), math.max(a.Y, b.Y))
end
local Vector2 = { new = V2new, zero = V2new(0, 0), one = V2new(1, 1), xAxis = V2new(1, 0), yAxis = V2new(0, 1) }
M.Vector2 = Vector2

------------------------------------------------------------------------------------------ CFrame
-- rotation matrix r = {r00,r01,r02,r10,r11,r12,r20,r21,r22} (row major), position p
local CFm = {}
TYPE[CFm] = "CFrame"
local CFmethods = {}
local I3 = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function CF(p, r)
	return setmetatable({ p = p, r = r }, CFm)
end
local function mm(a, b)
	return {
		a[1] * b[1] + a[2] * b[4] + a[3] * b[7],
		a[1] * b[2] + a[2] * b[5] + a[3] * b[8],
		a[1] * b[3] + a[2] * b[6] + a[3] * b[9],
		a[4] * b[1] + a[5] * b[4] + a[6] * b[7],
		a[4] * b[2] + a[5] * b[5] + a[6] * b[8],
		a[4] * b[3] + a[5] * b[6] + a[6] * b[9],
		a[7] * b[1] + a[8] * b[4] + a[9] * b[7],
		a[7] * b[2] + a[8] * b[5] + a[9] * b[8],
		a[7] * b[3] + a[8] * b[6] + a[9] * b[9],
	}
end
local function mv(r, v)
	return V(r[1] * v.X + r[2] * v.Y + r[3] * v.Z, r[4] * v.X + r[5] * v.Y + r[6] * v.Z, r[7] * v.X + r[8] * v.Y + r[9] * v.Z)
end
local function tr(r)
	return { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] }
end
local function rx(a)
	local c, s = math.cos(a), math.sin(a)
	return { 1, 0, 0, 0, c, -s, 0, s, c }
end
local function ry(a)
	local c, s = math.cos(a), math.sin(a)
	return { c, 0, s, 0, 1, 0, -s, 0, c }
end
local function rz(a)
	local c, s = math.cos(a), math.sin(a)
	return { c, -s, 0, s, c, 0, 0, 0, 1 }
end
local function lookRot(at, target, up)
	up = up or V(0, 1, 0)
	local d = target - at
	if vmag(d) < 1e-9 then
		return I3
	end
	local look = d.Unit
	local right = V3m.Cross(look, up)
	if vmag(right) < 1e-6 then
		right = V3m.Cross(look, V(0, 0, 1))
		if vmag(right) < 1e-6 then
			right = V(1, 0, 0)
		end
	end
	right = right.Unit
	local up2 = V3m.Cross(right, look)
	return { right.X, up2.X, -look.X, right.Y, up2.Y, -look.Y, right.Z, up2.Z, -look.Z }
end
local CFrame = {}
function CFrame.new(a, b, c, ...)
	if a == nil then
		return CF(V(0, 0, 0), I3)
	end
	if type(a) == "table" then
		if b ~= nil then
			return CF(a, lookRot(a, b))
		end
		return CF(a, I3)
	end
	local n = select("#", ...)
	if n >= 9 then
		local r = { ... }
		return CF(V(a, b, c), { r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9] })
	elseif n == 4 then
		-- quaternion qx,qy,qz,qw
		local qx, qy, qz, qw = ...
		local m = math.sqrt(qx * qx + qy * qy + qz * qz + qw * qw)
		qx, qy, qz, qw = qx / m, qy / m, qz / m, qw / m
		return CF(V(a, b, c), {
			1 - 2 * (qy * qy + qz * qz), 2 * (qx * qy - qz * qw), 2 * (qx * qz + qy * qw),
			2 * (qx * qy + qz * qw), 1 - 2 * (qx * qx + qz * qz), 2 * (qy * qz - qx * qw),
			2 * (qx * qz - qy * qw), 2 * (qy * qz + qx * qw), 1 - 2 * (qx * qx + qy * qy),
		})
	end
	return CF(V(a, b or 0, c or 0), I3)
end
function CFrame.Angles(a, b, c)
	return CF(V(0, 0, 0), mm(mm(rx(a), ry(b)), rz(c)))
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.fromEulerAnglesYXZ(a, b, c)
	return CF(V(0, 0, 0), mm(mm(ry(b), rx(a)), rz(c)))
end
CFrame.fromOrientation = CFrame.fromEulerAnglesYXZ
function CFrame.fromEulerAngles(a, b, c)
	return CFrame.Angles(a, b, c)
end
function CFrame.fromAxisAngle(axis, ang)
	local u = axis.Unit
	local c, s = math.cos(ang), math.sin(ang)
	local t = 1 - c
	local x, y, z = u.X, u.Y, u.Z
	return CF(V(0, 0, 0), {
		t * x * x + c, t * x * y - s * z, t * x * z + s * y,
		t * x * y + s * z, t * y * y + c, t * y * z - s * x,
		t * x * z - s * y, t * y * z + s * x, t * z * z + c,
	})
end
function CFrame.lookAt(at, target, up)
	return CF(at, lookRot(at, target, up))
end
function CFrame.lookAlong(at, dir, up)
	return CF(at, lookRot(at, at + dir, up))
end
function CFrame.fromMatrix(pos, vx, vy, vz)
	vz = vz or V3m.Cross(vx, vy).Unit
	return CF(pos, { vx.X, vy.X, vz.X, vx.Y, vy.Y, vz.Y, vx.Z, vy.Z, vz.Z })
end
CFrame.identity = CF(V(0, 0, 0), I3)
CFm.__mul = function(a, b)
	if getmetatable(b) == CFm then
		return CF(a.p + mv(a.r, b.p), mm(a.r, b.r))
	elseif getmetatable(b) == V3 then
		return a.p + mv(a.r, b)
	end
	error("invalid CFrame multiplication with " .. tostring(b), 2)
end
CFm.__add = function(a, v)
	return CF(a.p + v, a.r)
end
CFm.__sub = function(a, v)
	return CF(a.p - v, a.r)
end
CFm.__eq = function(a, b)
	if a.p ~= b.p then
		return false
	end
	for i = 1, 9 do
		if a.r[i] ~= b.r[i] then
			return false
		end
	end
	return true
end
CFm.__tostring = function(c)
	return tostring(c.p) .. ", " .. table.concat(c.r, ", ")
end
local function toEulerXYZ(r)
	-- R = Rx(a) Ry(b) Rz(c)
	local b = math.asin(math.clamp(r[3], -1, 1))
	local a, c
	if math.abs(r[3]) < 0.99999 then
		a = math.atan2(-r[6], r[9])
		c = math.atan2(-r[2], r[1])
	else
		a = math.atan2(r[8], r[5])
		c = 0
	end
	return a, b, c
end
local function toEulerYXZ(r)
	-- R = Ry(b) Rx(a) Rz(c)
	local a = math.asin(math.clamp(-r[6], -1, 1))
	local b, c
	if math.abs(r[6]) < 0.99999 then
		b = math.atan2(r[3], r[9])
		c = math.atan2(r[4], r[5])
	else
		b = math.atan2(-r[7], r[1])
		c = 0
	end
	return a, b, c
end
M.toEulerYXZ = toEulerYXZ
CFm.__index = function(c, k)
	if k == "Position" or k == "p" then
		return rawget(c, "p")
	end
	local r = rawget(c, "r")
	if k == "LookVector" then
		return V(-r[3], -r[6], -r[9])
	elseif k == "RightVector" or k == "XVector" then
		return V(r[1], r[4], r[7])
	elseif k == "UpVector" or k == "YVector" then
		return V(r[2], r[5], r[8])
	elseif k == "ZVector" then
		return V(r[3], r[6], r[9])
	elseif k == "X" then
		return c.p.X
	elseif k == "Y" then
		return c.p.Y
	elseif k == "Z" then
		return c.p.Z
	elseif k == "Rotation" then
		return CF(V(0, 0, 0), r)
	end
	local f = CFmethods[k]
	if f then
		return f
	end
	error(tostring(k) .. " is not a valid member of CFrame", 2)
end
function CFmethods.Inverse(c)
	local t = tr(c.r)
	return CF(-mv(t, c.p), t)
end
function CFmethods.ToObjectSpace(a, b)
	return CFmethods.Inverse(a) * b
end
function CFmethods.ToWorldSpace(a, b)
	return a * b
end
function CFmethods.PointToObjectSpace(a, v)
	return mv(tr(a.r), v - a.p)
end
function CFmethods.PointToWorldSpace(a, v)
	return a * v
end
function CFmethods.VectorToWorldSpace(a, v)
	return mv(a.r, v)
end
function CFmethods.VectorToObjectSpace(a, v)
	return mv(tr(a.r), v)
end
function CFmethods.GetComponents(c)
	local r = c.r
	return c.p.X, c.p.Y, c.p.Z, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9]
end
CFmethods.components = CFmethods.GetComponents
function CFmethods.ToEulerAnglesXYZ(c)
	return toEulerXYZ(c.r)
end
function CFmethods.ToEulerAnglesYXZ(c)
	return toEulerYXZ(c.r)
end
CFmethods.ToOrientation = CFmethods.ToEulerAnglesYXZ
local function toQuat(r)
	local tr_ = r[1] + r[5] + r[9]
	local w, x, y, z
	if tr_ > 0 then
		local s = math.sqrt(tr_ + 1) * 2
		w, x, y, z = 0.25 * s, (r[8] - r[6]) / s, (r[3] - r[7]) / s, (r[4] - r[2]) / s
	elseif r[1] > r[5] and r[1] > r[9] then
		local s = math.sqrt(1 + r[1] - r[5] - r[9]) * 2
		w, x, y, z = (r[8] - r[6]) / s, 0.25 * s, (r[2] + r[4]) / s, (r[3] + r[7]) / s
	elseif r[5] > r[9] then
		local s = math.sqrt(1 + r[5] - r[1] - r[9]) * 2
		w, x, y, z = (r[3] - r[7]) / s, (r[2] + r[4]) / s, 0.25 * s, (r[6] + r[8]) / s
	else
		local s = math.sqrt(1 + r[9] - r[1] - r[5]) * 2
		w, x, y, z = (r[4] - r[2]) / s, (r[3] + r[7]) / s, (r[6] + r[8]) / s, 0.25 * s
	end
	return x, y, z, w
end
M.toQuat = toQuat
function CFmethods.Lerp(a, b, t)
	local ax, ay, az, aw = toQuat(a.r)
	local bx, by, bz, bw = toQuat(b.r)
	local d = ax * bx + ay * by + az * bz + aw * bw
	if d < 0 then
		bx, by, bz, bw, d = -bx, -by, -bz, -bw, -d
	end
	local x, y, z, w = ax + (bx - ax) * t, ay + (by - ay) * t, az + (bz - az) * t, aw + (bw - aw) * t
	local p = V3m.Lerp(a.p, b.p, t)
	return CFrame.new(p.X, p.Y, p.Z, x, y, z, w)
end
function CFmethods.Orthonormalize(c)
	return c
end
function CFmethods.FuzzyEq(a, b, eps)
	return V3m.FuzzyEq(a.p, b.p, eps)
end
M.CFrame = CFrame
M.CFmeta = CFm

------------------------------------------------------------------------------------------ Color3
local C3 = {}
TYPE[C3] = "Color3"
local C3m = {}
local function C3new(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3)
end
C3.__index = function(c, k)
	if k == "r" then
		return c.R
	elseif k == "g" then
		return c.G
	elseif k == "b" then
		return c.B
	end
	local f = C3m[k]
	if f then
		return f
	end
	error(tostring(k) .. " is not a valid member of Color3", 2)
end
C3.__eq = function(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end
C3.__tostring = function(c)
	return fmt(c.R) .. ", " .. fmt(c.G) .. ", " .. fmt(c.B)
end
function C3m.Lerp(a, b, t)
	return C3new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end
function C3m.ToHSV(c)
	local r, g, b = c.R, c.G, c.B
	local mx, mn = math.max(r, g, b), math.min(r, g, b)
	local d = mx - mn
	local h = 0
	if d > 0 then
		if mx == r then
			h = ((g - b) / d) % 6
		elseif mx == g then
			h = (b - r) / d + 2
		else
			h = (r - g) / d + 4
		end
		h /= 6
	end
	return h, if mx == 0 then 0 else d / mx, mx
end
function C3m.ToHex(c)
	return string.format("%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
local Color3 = {
	new = C3new,
	fromRGB = function(r, g, b)
		return C3new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
	end,
	fromHSV = function(h, s, v)
		local i = math.floor(h * 6)
		local f = h * 6 - i
		local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
		i %= 6
		if i == 0 then
			return C3new(v, t, p)
		elseif i == 1 then
			return C3new(q, v, p)
		elseif i == 2 then
			return C3new(p, v, t)
		elseif i == 3 then
			return C3new(p, q, v)
		elseif i == 4 then
			return C3new(t, p, v)
		end
		return C3new(v, p, q)
	end,
	fromHex = function(h)
		h = string.gsub(h, "#", "")
		return C3new(tonumber(string.sub(h, 1, 2), 16) / 255, tonumber(string.sub(h, 3, 4), 16) / 255, tonumber(string.sub(h, 5, 6), 16) / 255)
	end,
	toHSV = function(c)
		return C3m.ToHSV(c)
	end,
}
M.Color3 = Color3

------------------------------------------------------------------------------------------ UDim / UDim2
local UD = {}
TYPE[UD] = "UDim"
local function UDnew(s, o)
	return setmetatable({ Scale = s or 0, Offset = o or 0 }, UD)
end
UD.__index = function(_, k)
	error(tostring(k) .. " is not a valid member of UDim", 2)
end
UD.__add = function(a, b)
	return UDnew(a.Scale + b.Scale, a.Offset + b.Offset)
end
UD.__sub = function(a, b)
	return UDnew(a.Scale - b.Scale, a.Offset - b.Offset)
end
UD.__unm = function(a)
	return UDnew(-a.Scale, -a.Offset)
end
UD.__eq = function(a, b)
	return a.Scale == b.Scale and a.Offset == b.Offset
end
UD.__tostring = function(u)
	return fmt(u.Scale) .. ", " .. fmt(u.Offset)
end
local UDim = { new = UDnew }
M.UDim = UDim

local UD2 = {}
TYPE[UD2] = "UDim2"
local function UD2raw(x, y)
	return setmetatable({ X = x, Y = y }, UD2)
end
local function UD2new(a, b, c, d)
	if type(a) == "table" then
		return UD2raw(a, b)
	end
	return UD2raw(UDnew(a or 0, b or 0), UDnew(c or 0, d or 0))
end
UD2.__index = function(u, k)
	if k == "Width" then
		return u.X
	elseif k == "Height" then
		return u.Y
	elseif k == "Lerp" then
		return function(a, b, t)
			return UD2new(
				a.X.Scale + (b.X.Scale - a.X.Scale) * t,
				a.X.Offset + (b.X.Offset - a.X.Offset) * t,
				a.Y.Scale + (b.Y.Scale - a.Y.Scale) * t,
				a.Y.Offset + (b.Y.Offset - a.Y.Offset) * t
			)
		end
	end
	error(tostring(k) .. " is not a valid member of UDim2", 2)
end
UD2.__add = function(a, b)
	return UD2raw(a.X + b.X, a.Y + b.Y)
end
UD2.__sub = function(a, b)
	return UD2raw(a.X - b.X, a.Y - b.Y)
end
UD2.__unm = function(a)
	return UD2raw(-a.X, -a.Y)
end
UD2.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
UD2.__tostring = function(u)
	return "{" .. tostring(u.X) .. "}, {" .. tostring(u.Y) .. "}"
end
local UDim2 = {
	new = UD2new,
	fromScale = function(x, y)
		return UD2new(x or 0, 0, y or 0, 0)
	end,
	fromOffset = function(x, y)
		return UD2new(0, x or 0, 0, y or 0)
	end,
}
M.UDim2 = UDim2

------------------------------------------------------------------------------------------ misc
local function simpleType(name, ctor)
	local mt = { __index = function(_, k)
		error(tostring(k) .. " is not a valid member of " .. name, 2)
	end, __tostring = function()
		return name
	end }
	TYPE[mt] = name
	return function(fields)
		return setmetatable(fields, mt)
	end
end
local mkCSK = simpleType("ColorSequenceKeypoint")
local mkCS = simpleType("ColorSequence")
local mkNSK = simpleType("NumberSequenceKeypoint")
local mkNS = simpleType("NumberSequence")
local mkNR = simpleType("NumberRange")
local mkTI = simpleType("TweenInfo")
local mkRect = simpleType("Rect")
local mkFont = simpleType("Font")
local mkPP = simpleType("PhysicalProperties")
local mkRay = simpleType("Ray")
local mkRP = simpleType("RaycastParams")
local mkOP = simpleType("OverlapParams")
local mkBC = simpleType("BrickColor")
local mkDT = simpleType("DateTime")

local ColorSequenceKeypoint = { new = function(t, c)
	return mkCSK({ Time = t, Value = c })
end }
local ColorSequence = { new = function(a, b)
	if type(a) == "table" and getmetatable(a) == C3 then
		return mkCS({ Keypoints = { ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b or a) } })
	end
	return mkCS({ Keypoints = a })
end }
local NumberSequenceKeypoint = { new = function(t, v, e)
	return mkNSK({ Time = t, Value = v, Envelope = e or 0 })
end }
local NumberSequence = { new = function(a, b)
	if type(a) == "number" then
		return mkNS({ Keypoints = { NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b or a) } })
	end
	return mkNS({ Keypoints = a })
end }
local NumberRange = { new = function(a, b)
	return mkNR({ Min = a, Max = b or a })
end }
local TweenInfo = { new = function(time, style, dir, rep, rev, delay)
	return mkTI({ Time = time or 1, EasingStyle = style, EasingDirection = dir, RepeatCount = rep or 0, Reverses = rev or false, DelayTime = delay or 0 })
end }
local Rect = { new = function(a, b, c, d)
	if type(a) == "table" then
		return mkRect({ Min = a, Max = b, Width = b.X - a.X, Height = b.Y - a.Y })
	end
	return mkRect({ Min = V2new(a, b), Max = V2new(c, d), Width = c - a, Height = d - b })
end }
local Font = {
	new = function(family, weight, style)
		return mkFont({ Family = family, Weight = weight, Style = style, Bold = false })
	end,
	fromEnum = function(e)
		return mkFont({ Family = tostring(e), Bold = false })
	end,
	fromName = function(n, weight, style)
		return mkFont({ Family = n, Weight = weight, Style = style, Bold = false })
	end,
}
local PhysicalProperties = { new = function(...)
	return mkPP({ ... })
end }
local Ray = { new = function(o, d)
	return mkRay({ Origin = o, Direction = d })
end }
local RaycastParams = { new = function()
	return mkRP({})
end }
local OverlapParams = { new = function()
	return mkOP({})
end }
local BrickColor = {
	new = function(n)
		return mkBC({ Name = tostring(n), Color = C3new(0.64, 0.64, 0.65) })
	end,
	random = function()
		return mkBC({ Name = "random", Color = C3new(0.5, 0.5, 0.5) })
	end,
}
BrickColor.White = function()
	return BrickColor.new("White")
end
local DateTime = {
	now = function()
		local t = M.serverNow()
		return mkDT({ UnixTimestamp = math.floor(t), UnixTimestampMillis = math.floor(t * 1000) })
	end,
	fromUnixTimestamp = function(t)
		return mkDT({ UnixTimestamp = math.floor(t), UnixTimestampMillis = math.floor(t * 1000) })
	end,
}

-- Random: deterministic xorshift-ish LCG. Unseeded Random.new() gets a fixed sequence of seeds
-- so a scenario run is reproducible.
local RandomMt = {}
TYPE[RandomMt] = "Random"
local RandomMethods = {}
RandomMt.__index = RandomMethods
local seedCounter = 1000
local function rnext(self)
	self.s = (self.s * 48271) % 2147483647
	return self.s / 2147483647
end
function RandomMethods.NextNumber(self, a, b)
	local r = rnext(self)
	if a then
		return a + (b - a) * r
	end
	return r
end
function RandomMethods.NextInteger(self, a, b)
	return a + math.floor(rnext(self) * (b - a + 1))
end
function RandomMethods.NextUnitVector(self)
	local v = V(rnext(self) - 0.5, rnext(self) - 0.5, rnext(self) - 0.5)
	return v.Unit
end
function RandomMethods.Shuffle(self, t)
	for i = #t, 2, -1 do
		local j = RandomMethods.NextInteger(self, 1, i)
		t[i], t[j] = t[j], t[i]
	end
end
function RandomMethods.Clone(self)
	return setmetatable({ s = self.s }, RandomMt)
end
local Random = { new = function(seed)
	if seed == nil then
		seedCounter += 7919
		seed = seedCounter
	end
	local s = math.floor(math.abs(seed)) % 2147483647
	if s == 0 then
		s = 12345
	end
	return setmetatable({ s = s }, RandomMt)
end }

------------------------------------------------------------------------------------------ Enum
local EnumItemMt = {}
TYPE[EnumItemMt] = "EnumItem"
EnumItemMt.__tostring = function(e)
	return "Enum." .. rawget(e.EnumType, "_name") .. "." .. e.Name
end
EnumItemMt.__index = function(e, k)
	if k == "IsA" then
		return function(self, n)
			return rawget(self.EnumType, "_name") == n
		end
	end
	error(tostring(k) .. " is not a valid member of EnumItem", 2)
end
local EnumTypeMt = {}
TYPE[EnumTypeMt] = "Enum"
local enumValue = 0
EnumTypeMt.__index = function(t, k)
	if k == "GetEnumItems" then
		return function(self)
			local out = {}
			for _, it in rawget(self, "_items") do
				table.insert(out, it)
			end
			table.sort(out, function(a, b)
				return a.Value < b.Value
			end)
			return out
		end
	end
	local items = rawget(t, "_items")
	local it = items[k]
	if not it then
		enumValue += 1
		it = setmetatable({ Name = k, Value = enumValue, EnumType = t }, EnumItemMt)
		items[k] = it
	end
	return it
end
EnumTypeMt.__tostring = function(t)
	return rawget(t, "_name")
end
local enumTypes = {}
local Enum = setmetatable({}, {
	__index = function(_, k)
		local t = enumTypes[k]
		if not t then
			t = setmetatable({ _name = k, _items = {} }, EnumTypeMt)
			enumTypes[k] = t
		end
		return t
	end,
})
M.Enum = Enum
M.EnumItemMt = EnumItemMt

------------------------------------------------------------------------------------------ typeof
local realTypeof = typeof
local function mockTypeof(v)
	local t = type(v)
	if t == "table" or t == "userdata" then
		local mt = getmetatable(v)
		if mt then
			local n = TYPE[mt]
			if n then
				return n
			end
		end
	end
	return realTypeof(v)
end
M.typeof = mockTypeof

-- globals the game scripts see (builtins like typeof are passed as chunk locals, see 40_loader)
M.globals = {
	Vector3 = Vector3,
	Vector2 = Vector2,
	CFrame = CFrame,
	Color3 = Color3,
	UDim = UDim,
	UDim2 = UDim2,
	ColorSequence = ColorSequence,
	ColorSequenceKeypoint = ColorSequenceKeypoint,
	NumberSequence = NumberSequence,
	NumberSequenceKeypoint = NumberSequenceKeypoint,
	NumberRange = NumberRange,
	TweenInfo = TweenInfo,
	Rect = Rect,
	Font = Font,
	PhysicalProperties = PhysicalProperties,
	Ray = Ray,
	RaycastParams = RaycastParams,
	OverlapParams = OverlapParams,
	BrickColor = BrickColor,
	DateTime = DateTime,
	Random = Random,
	Enum = Enum,
}
