--!strict
-- Workers walk between WorkerPath/Start (by the warehouse) and the collect ring of the house they
-- serve. Own plot: driven by snapshot.workers (t within cycle; first half walking to the house,
-- second half walking back carrying a crate when load > 0). Other plots (WorkerTiers attribute):
-- the same loop on a fixed clock, only within OTHER_RADIUS studs and re-posed at 10 Hz.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared:WaitForChild("Logic"):WaitForChild("PlotLayout"))
local WorkerData = require(Shared:WaitForChild("Data"):WaitForChild("Workers"))
local Rig = require(script.Parent:WaitForChild("Rig"))
local FlockView = require(script.Parent:WaitForChild("FlockView"))

local Workers = {}

local OTHER_RADIUS = 220
local OTHER_INTERVAL = 0.1
local SLOTS = WorkerData.MaxSlots

type Slot = { rig: Rig.Rig?, crate: Rig.Rig?, tier: number }
type View = { slots: { Slot }, own: boolean, acc: number, houses: { number } }

local views: { [Model]: View } = {}
local routes: { [number]: { [number]: { Layout.Vec } } } = {} -- [slot][house] -> lane-shifted route
local clock = 0

local function route(slot: number, house: number): ({ Layout.Vec }, number)
	routes[slot] = routes[slot] or {}
	local r = routes[slot][house]
	if not r then
		-- spread workers over small lane offsets so they don't walk inside each other
		local shift = ((slot - 1) % 4 - 1.5) * 1.3
		r = {}
		for i, p in Layout.WorkerRoute(house) do
			local last = i == #Layout.WorkerRoute(house)
			r[i] = { x = p.x + (if last then 0 else shift), y = 0, z = p.z + (if last then shift else 0) }
		end
		routes[slot][house] = r
	end
	assert(r)
	return r, Layout.PolyLength(r)
end

local function releaseSlot(s: Slot)
	if s.rig then
		Rig.Release(s.rig)
		s.rig = nil
	end
	if s.crate then
		Rig.Release(s.crate)
		s.crate = nil
	end
	s.tier = 0
end

function Workers.ClearPlot(plot: Model)
	local v = views[plot]
	if v then
		for _, s in v.slots do
			releaseSlot(s)
		end
		views[plot] = nil
	end
end

function Workers.Replan(ctx: any)
	for plot in views do
		if not ctx.plots[plot] then
			Workers.ClearPlot(plot)
		end
	end
	local snap = ctx.snapshot
	for plot, info in ctx.plots do
		local tiers: { number }
		if info.own and snap and type(snap.workers) == "table" then
			tiers = {}
			for i = 1, SLOTS do
				local w = snap.workers[i]
				tiers[i] = if w then tonumber(w.tier) or 0 else 0
			end
		elseif not info.own and info.dist <= OTHER_RADIUS then
			tiers = FlockView.ParseTiers(plot:GetAttribute("WorkerTiers"), SLOTS)
		else
			tiers = table.create(SLOTS, 0)
		end
		local view = views[plot]
		if not view then
			local slots = {}
			for i = 1, SLOTS do
				slots[i] = { rig = nil, crate = nil, tier = 0 }
			end
			view = { slots = slots, own = info.own, acc = 0, houses = {} }
			views[plot] = view
		end
		assert(view)
		view.own = info.own
		-- houses that exist on this plot (other plots: workers rotate between them)
		local houseTiers = FlockView.ParseTiers(plot:GetAttribute("HouseTiers"), 4)
		table.clear(view.houses)
		for h, t in houseTiers do
			if t > 0 then
				table.insert(view.houses, h)
			end
		end
		for i, s in view.slots do
			local tier = math.clamp(tiers[i] or 0, 0, WorkerData.MaxTier)
			if tier ~= s.tier then
				releaseSlot(s)
				if tier > 0 then
					s.rig = Rig.Get("worker", tier)
					s.tier = tier
				end
			end
		end
	end
end

local angles: { [string]: number } = { legL = 0, legR = 0, armL = 0, armR = 0 }

local function pose(info: any, slot: number, s: Slot, house: number, f: number, back: boolean, loaded: boolean, parts: { BasePart }, cfs: { CFrame })
	local rig = s.rig
	if not rig then
		return
	end
	local r, len = route(slot, house)
	-- short pauses at both ends (picking up / dropping off) read better than constant walking
	local walkF = math.clamp((f - 0.08) / 0.84, 0, 1)
	local d = if back then (1 - walkF) * len else walkF * len
	local p, dir = Layout.PolyPoint(r, d)
	local fx, fz = dir.x, dir.z
	if back then
		fx, fz = -fx, -fz
	end
	local walking = walkF > 0 and walkF < 1
	local pos = Vector3.new(p.x, 0.1, p.z)
	local root = info.cf * CFrame.lookAt(pos, pos + Vector3.new(fx, 0, fz))
	local swing = if walking then math.sin(clock * 9 + slot) * 0.7 else 0
	if s.tier == 6 or s.tier == 8 then
		root *= CFrame.new(0, 0.4 + math.sin(clock * 3 + slot) * 0.2, 0) -- jetpack / star porter hover
		swing *= 0.4
	end
	if walking then
		root *= CFrame.new(0, math.abs(math.sin(clock * 9 + slot)) * 0.15, 0)
	end
	angles.legL, angles.legR = swing, -swing
	if loaded then
		angles.armL, angles.armR = 1.2, 1.2 -- arms raised forward, holding the crate
	else
		angles.armL, angles.armR = -swing * 0.8, swing * 0.8
	end
	Rig.Pose(rig, root, angles, parts, cfs)
	if loaded then
		if not s.crate then
			s.crate = Rig.Get("crate", 1)
		end
		local crate = s.crate
		assert(crate)
		local off = rig.attrs.CarryOffset
		Rig.Pose(crate, root * CFrame.new(if typeof(off) == "Vector3" then off else Vector3.new(0, 3, -1.5)), nil, parts, cfs)
	elseif s.crate then
		Rig.Release(s.crate)
		s.crate = nil
	end
end

function Workers.Update(dt: number, ctx: any, parts: { BasePart }, cfs: { CFrame })
	clock += dt
	local snap = ctx.snapshot
	for plot, view in views do
		local info = ctx.plots[plot]
		if not info then
			continue
		end
		if view.own and snap and type(snap.workers) == "table" then
			for i, s in view.slots do
				local w = snap.workers[i]
				if not s.rig or not w then
					continue
				end
				local cycle = tonumber(w.cycle) or 0
				if cycle <= 0 then
					local t = WorkerData.Tiers[s.tier]
					cycle = if t then t.cycle else 12
				end
				local half = cycle / 2
				local tt = ((tonumber(w.t) or 0) + ctx.elapsed) % cycle
				local house = math.clamp(math.floor(tonumber(w.house) or 1), 1, 4)
				local load = tonumber(w.load) or 0
				if tt < half then
					pose(info, i, s, house, tt / half, false, false, parts, cfs)
				else
					pose(info, i, s, house, (tt - half) / half, true, load > 0, parts, cfs)
				end
			end
		else
			view.acc += dt
			if view.acc < OTHER_INTERVAL then
				continue
			end
			view.acc = 0
			local nHouses = #view.houses
			for i, s in view.slots do
				if not s.rig then
					continue
				end
				local t = WorkerData.Tiers[s.tier]
				local cycle = if t then t.cycle else 12
				local half = cycle / 2
				local tt = (clock + i * 1.7) % cycle
				local lap = math.floor((clock + i * 1.7) / cycle)
				local house = if nHouses > 0 then view.houses[(lap + i) % nHouses + 1] else 1
				if tt < half then
					pose(info, i, s, house, tt / half, false, false, parts, cfs)
				else
					pose(info, i, s, house, (tt - half) / half, true, nHouses > 0, parts, cfs)
				end
			end
		end
	end
end

return Workers
