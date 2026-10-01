--!strict
-- Client-side posable models. A Rig wraps one of the shared part models (Models/Chicken, Worker,
-- Vehicle, Crate): every visible part keeps its offset from the model origin, and parts tagged
-- with a "Rig" group (head, legL, armR, tail, ...) can be swung about that group's pivot.
-- Nothing is ever simulated: Visuals poses all rigs once per frame and moves every part with a
-- single workspace:BulkMoveTo call. Rigs are pooled per kind+tier and reused.

local Workspace = game:GetService("Workspace")

local Rig = {}

export type Rig = {
	key: string,
	model: Model,
	parts: { BasePart },
	offsets: { CFrame },
	groups: { string },
	pivots: { [string]: Vector3 },
	attrs: { [string]: any },
	active: boolean,
}

local HIDDEN = CFrame.new(0, -2000, 0)

function Rig.new(key: string, model: Model): Rig
	local origin = model:GetPivot()
	local rig: Rig = {
		key = key,
		model = model,
		parts = {},
		offsets = {},
		groups = {},
		pivots = {},
		attrs = model:GetAttributes(),
		active = false,
	}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			table.insert(rig.parts, d)
			table.insert(rig.offsets, origin:ToObjectSpace(d.CFrame))
			local g = d:GetAttribute("Rig")
			table.insert(rig.groups, if type(g) == "string" then g else "")
		end
	end
	for name, value in rig.attrs do
		if typeof(value) == "Vector3" and string.sub(name, 1, 6) == "Pivot_" then
			rig.pivots[string.sub(name, 7)] = value
		end
	end
	return rig
end

-- Append the parts and target CFrames of `rig` posed at `root` to the bulk-move lists.
-- `angles` swings groups about their pivot (radians about the model's X axis).
function Rig.Pose(rig: Rig, root: CFrame, angles: { [string]: number }?, outParts: { BasePart }, outCFs: { CFrame })
	local parts, offsets, groups, pivots = rig.parts, rig.offsets, rig.groups, rig.pivots
	local swings: { [string]: CFrame }? = nil
	if angles then
		local s: { [string]: CFrame } = {}
		for g, a in angles do
			local pv = pivots[g]
			if pv and a ~= 0 then
				s[g] = CFrame.new(pv) * CFrame.Angles(a, 0, 0) * CFrame.new(-pv)
			end
		end
		swings = s
	end
	for i, part in parts do
		local sw = swings and swings[groups[i]]
		outParts[#outParts + 1] = part
		outCFs[#outCFs + 1] = if sw then root * sw * offsets[i] else root * offsets[i]
	end
end

-- ------------------------------------------------------------------ pool
local free: { [string]: { Rig } } = {}
local builders: { [string]: (number) -> Model } = {}
local container: Instance? = nil
local MAX_FREE = 40

function Rig.SetContainer(c: Instance)
	container = c
end

function Rig.Register(kind: string, build: (number) -> Model)
	builders[kind] = build
end

function Rig.Get(kind: string, variant: number): Rig
	local key = kind .. ":" .. variant
	local list = free[key]
	local rig: Rig
	if list and #list > 0 then
		rig = table.remove(list) :: Rig
	else
		local build = builders[kind]
		assert(build, "no rig builder for " .. kind)
		rig = Rig.new(key, build(variant))
	end
	rig.active = true
	rig.model.Parent = container or Workspace
	return rig
end

-- Return a rig to the pool (hidden, unparented). Excess rigs are destroyed so pools stay bounded.
function Rig.Release(rig: Rig)
	if not rig.active then
		return
	end
	rig.active = false
	rig.model.Parent = nil
	local list = free[rig.key]
	if not list then
		list = {}
		free[rig.key] = list
	end
	if #list < MAX_FREE then
		table.insert(list, rig)
	else
		rig.model:Destroy()
	end
end

-- Park a rig out of sight without returning it to the pool (e.g. a vehicle inside the tunnel).
function Rig.Hide(rig: Rig, outParts: { BasePart }, outCFs: { CFrame })
	Rig.Pose(rig, HIDDEN, nil, outParts, outCFs)
end

function Rig.DestroyPools()
	for _, list in free do
		for _, rig in list do
			rig.model:Destroy()
		end
	end
	table.clear(free)
end

return Rig
