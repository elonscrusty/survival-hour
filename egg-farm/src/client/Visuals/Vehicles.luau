--!strict
-- Shipping vehicles. On the local player's plot each owned vehicle follows its snapshot phase:
-- "dock" parked in its bay (crate shown while loaded), "out" driving the bay -> road -> tunnel
-- path (hidden inside the hill), "back" returning and reversing into the bay. Positions are
-- interpolated locally from the snapshot (t + time since the snapshot), so motion is smooth
-- between the 4 Hz server updates. Other plots only park their vehicles (VehicleTiers
-- attribute), posed once, and only within OTHER_RADIUS studs of the camera.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared:WaitForChild("Logic"):WaitForChild("PlotLayout"))
local VehicleData = require(Shared:WaitForChild("Data"):WaitForChild("Vehicles"))
local Rig = require(script.Parent:WaitForChild("Rig"))
local FlockView = require(script.Parent:WaitForChild("FlockView"))

local Vehicles = {}

local OTHER_RADIUS = 350
local SLOTS = VehicleData.MaxSlots

type Slot = {
	rig: Rig.Rig?,
	crate: Rig.Rig?,
	tier: number,
	path: { Layout.Vec },
	len: number,
	tunnel: number,
	hidden: boolean,
	posed: boolean,
}

type View = { slots: { Slot }, own: boolean }

local views: { [Model]: View } = {}

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
	s.posed = false
	s.hidden = false
end

function Vehicles.ClearPlot(plot: Model)
	local v = views[plot]
	if v then
		for _, s in v.slots do
			releaseSlot(s)
		end
		views[plot] = nil
	end
end

local function newView(): View
	local slots = {}
	for i = 1, SLOTS do
		local path = Layout.VehiclePath(i)
		slots[i] = {
			rig = nil,
			crate = nil,
			tier = 0,
			path = path,
			len = Layout.PolyLength(path),
			tunnel = Layout.TunnelDistance(i),
			hidden = false,
			posed = false,
		}
	end
	return { slots = slots, own = false }
end

function Vehicles.Replan(ctx: any)
	for plot in views do
		if not ctx.plots[plot] then
			Vehicles.ClearPlot(plot)
		end
	end
	local snap = ctx.snapshot
	for plot, info in ctx.plots do
		local tiers: { number }
		if info.own and snap and type(snap.vehicles) == "table" then
			tiers = {}
			for i = 1, SLOTS do
				local v = snap.vehicles[i]
				tiers[i] = if v then tonumber(v.tier) or 0 else 0
			end
		elseif not info.own and info.dist <= OTHER_RADIUS then
			tiers = FlockView.ParseTiers(plot:GetAttribute("VehicleTiers"), SLOTS)
		else
			tiers = table.create(SLOTS, 0)
		end
		local view = views[plot]
		if not view then
			view = newView()
			views[plot] = view
		end
		assert(view)
		if view.own ~= info.own then
			view.own = info.own
			for _, s in view.slots do
				s.posed = false
			end
		end
		for i, s in view.slots do
			local tier = math.clamp(tiers[i] or 0, 0, VehicleData.MaxTier)
			if tier ~= s.tier then
				releaseSlot(s)
				if tier > 0 then
					s.rig = Rig.Get("vehicle", tier)
					s.tier = tier
				end
			end
		end
	end
end

local clock = 0

local function pose(info: any, s: Slot, d: number, out: boolean, loaded: boolean, parts: { BasePart }, cfs: { CFrame })
	local rig = s.rig
	if not rig then
		return
	end
	if d > s.tunnel + 2 then
		if not s.hidden then
			s.hidden = true
			Rig.Hide(rig, parts, cfs)
			if s.crate then
				Rig.Hide(s.crate, parts, cfs)
			end
		end
		return
	end
	s.hidden = false
	local p, dir, seg = Layout.PolyPoint(s.path, d)
	local fx, fz
	if seg <= 2 then
		fx, fz = Layout.BayFacing.x, Layout.BayFacing.z -- nose to the road; reverses into the bay
	elseif out then
		fx, fz = dir.x, dir.z
	else
		fx, fz = -dir.x, -dir.z
	end
	local pos = Vector3.new(p.x, 0, p.z)
	if s.tier >= 7 then
		pos += Vector3.new(0, math.sin(clock * 2 + s.len) * 0.35, 0)
	end
	local root = info.cf * CFrame.lookAt(pos, pos + Vector3.new(fx, 0, fz))
	Rig.Pose(rig, root, nil, parts, cfs)
	if loaded then
		if not s.crate then
			s.crate = Rig.Get("crate", 1)
		end
		local crate = s.crate
		assert(crate)
		local off = rig.attrs.LoadOffset
		Rig.Pose(crate, root * CFrame.new(if typeof(off) == "Vector3" then off else Vector3.new(0, 3, 0)), nil, parts, cfs)
	elseif s.crate then
		Rig.Release(s.crate)
		s.crate = nil
	end
end

function Vehicles.Update(dt: number, ctx: any, parts: { BasePart }, cfs: { CFrame })
	clock += dt
	local snap = ctx.snapshot
	for plot, view in views do
		local info = ctx.plots[plot]
		if not info then
			continue
		end
		if view.own and snap and type(snap.vehicles) == "table" then
			for i, s in view.slots do
				local v = snap.vehicles[i]
				if not s.rig or not v then
					continue
				end
				local trip = tonumber(v.trip) or 0
				if trip <= 0 then
					local t = VehicleData.Tiers[s.tier]
					trip = if t then t.trip else 10
				end
				local half = trip / 2
				local tt = (tonumber(v.t) or 0) + ctx.elapsed
				local f = math.clamp(tt / half, 0, 1)
				local load = tonumber(v.load) or 0
				if v.phase == "out" then
					pose(info, s, f * s.len, true, load > 0, parts, cfs)
				elseif v.phase == "back" then
					pose(info, s, (1 - f) * s.len, false, false, parts, cfs)
				else
					pose(info, s, 0, true, load > 0, parts, cfs)
				end
			end
		else
			for _, s in view.slots do
				if s.rig and not s.posed then
					s.posed = true
					pose(info, s, 0, true, false, parts, cfs)
				end
			end
		end
	end
end

return Vehicles
