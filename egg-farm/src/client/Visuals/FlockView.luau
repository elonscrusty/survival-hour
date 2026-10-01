--!strict
-- Draws the bounded, representative flock: how many birds per house comes from the pure planner
-- (Shared/Logic/Flock: caps per setting, own plot vs others, distance), the birds themselves are
-- pooled chicken rigs wandering inside each house's Anchor yard. Birds far from the camera are
-- re-posed less often (Flock.UpdateInterval); idle far birds cost nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Flock = require(Shared:WaitForChild("Logic"):WaitForChild("Flock"))
local Housing = require(Shared:WaitForChild("Data"):WaitForChild("Housing"))
local ChickenModel = require(Shared:WaitForChild("Models"):WaitForChild("Chicken"))
local Rig = require(script.Parent:WaitForChild("Rig"))

local FlockView = {}

type Bird = {
	state: Flock.Bird,
	rig: Rig.Rig,
	acc: number,
}

type HouseView = {
	anchor: BasePart?,
	birds: { Bird },
}

type PlotView = {
	houses: { HouseView },
	interval: number,
}

local views: { [Model]: PlotView } = {}
local rng = Random.new()
local function rand(): number
	return rng:NextNumber()
end

local function parseTiers(s: any, n: number): { number }
	local out = {}
	local i = 0
	if type(s) == "string" then
		for part in string.gmatch(s, "[^,]+") do
			i += 1
			out[i] = tonumber(part) or 0
		end
	end
	for k = i + 1, n do
		out[k] = 0
	end
	return out
end
FlockView.ParseTiers = parseTiers

local function yard(anchor: BasePart): (number, number)
	return math.max(0.5, anchor.Size.X / 2 - 0.9), math.max(0.5, anchor.Size.Z / 2 - 0.9)
end

local function releaseBird(b: Bird)
	Rig.Release(b.rig)
end

function FlockView.ClearPlot(plot: Model)
	local v = views[plot]
	if not v then
		return
	end
	for _, h in v.houses do
		for _, b in h.birds do
			releaseBird(b)
		end
		table.clear(h.birds)
	end
	views[plot] = nil
end

local function occupantsFor(info: any, snapshot: any): { number }
	local plot: Model = info.plot
	if info.own and snapshot and type(snapshot.housing) == "table" then
		local occ = {}
		for i = 1, Housing.Slots do
			local h = snapshot.housing[i]
			occ[i] = if h and (h.tier or 0) > 0 then tonumber(h.occupants) or 0 else 0
		end
		return occ
	end
	local tiers = parseTiers(plot:GetAttribute("HouseTiers"), Housing.Slots)
	local caps = {}
	for i = 1, Housing.Slots do
		local t = Housing.Tiers[tiers[i]]
		caps[i] = if t then t.capacity else 0
	end
	return Flock.Distribute(tonumber(plot:GetAttribute("Population")) or 0, caps)
end

function FlockView.Replan(ctx: any)
	for plot in views do
		if not ctx.plots[plot] then
			FlockView.ClearPlot(plot)
		end
	end
	for plot, info in ctx.plots do
		local counts = Flock.Plan({
			occupants = occupantsFor(info, ctx.snapshot),
			setting = ctx.flock,
			own = info.own,
			distance = info.dist,
		})
		local v = views[plot]
		if not v then
			v = { houses = {}, interval = 0 }
			views[plot] = v
		end
		assert(v)
		v.interval = Flock.UpdateInterval(info.dist)
		for slot = 1, Housing.Slots do
			local hv = v.houses[slot]
			if not hv then
				hv = { anchor = nil, birds = {} }
				v.houses[slot] = hv
			end
			assert(hv)
			if not hv.anchor or not hv.anchor.Parent then
				local houses = plot:FindFirstChild("Houses")
				local house = houses and houses:FindFirstChild("House" .. slot)
				local a = house and house:FindFirstChild("Anchor")
				hv.anchor = if a and a:IsA("BasePart") then a else nil
			end
			local want = if hv.anchor then counts[slot] or 0 else 0
			while #hv.birds > want do
				releaseBird(table.remove(hv.birds) :: Bird)
			end
			local anchor = hv.anchor
			if anchor then
				local hx, hz = yard(anchor)
				while #hv.birds < want do
					local b: Bird = {
						state = Flock.NewBird(hx, hz, rand),
						rig = Rig.Get("chicken", rng:NextInteger(1, ChickenModel.Variants)),
						acc = 10, -- pose on the next frame
					}
					table.insert(hv.birds, b)
				end
			end
		end
	end
end

local angles: { [string]: number } = { head = 0, legL = 0, legR = 0 } -- reused every pose

function FlockView.Update(dt: number, _ctx: any, parts: { BasePart }, cfs: { CFrame })
	for _, v in views do
		local interval = v.interval
		for _, hv in v.houses do
			local anchor = hv.anchor
			if not anchor or #hv.birds == 0 then
				continue
			end
			local base = anchor.CFrame * CFrame.new(0, -anchor.Size.Y / 2 + 0.05, 0)
			local hx, hz = yard(anchor)
			for _, b in hv.birds do
				b.acc += dt
				if b.acc < interval then
					continue
				end
				local s = Flock.Wander(b.state, math.min(b.acc, 0.5), hx, hz, rand)
				b.acc = 0
				local root = base * CFrame.new(s.x, s.hop, s.z) * CFrame.Angles(0, s.heading, 0)
				local swing = if s.mode == "walk" then math.sin(s.phase * 14) * 0.6 else 0
				angles.head = -s.peck * 0.9
				angles.legL = swing
				angles.legR = -swing
				Rig.Pose(b.rig, root, angles, parts, cfs)
			end
		end
	end
end

return FlockView
