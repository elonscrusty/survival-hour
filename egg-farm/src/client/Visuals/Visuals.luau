--!strict
-- Client visuals: bounded flock, vehicles, workers, effects and theme lighting.
--   Visuals.Start(Store)   call once from the client bootstrap (after Store.Start()).
--   Visuals.Stop()         tears everything down (also runs when the local player leaves).
-- Everything here is decoration: nothing is sent to the server and no physics runs. All moving
-- parts are anchored and posed by ONE Heartbeat loop that ends in a single BulkMoveTo call.
-- Plots are tracked through Workspace.Plots/Plot<N> attributes (OwnerUserId, Population,
-- HouseTiers, VehicleTiers, WorkerTiers, Egg); the local player's own farm also uses the Store
-- snapshot for exact vehicle/worker phases. A plot whose OwnerUserId becomes 0 is cleared.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Models = Shared:WaitForChild("Models")
local Layout = require(Shared:WaitForChild("Logic"):WaitForChild("PlotLayout"))
local Chicken = require(Models:WaitForChild("Chicken"))
local WorkerModel = require(Models:WaitForChild("Worker"))
local VehicleModel = require(Models:WaitForChild("Vehicle"))
local Crate = require(Models:WaitForChild("Crate"))

local Rig = require(script.Parent:WaitForChild("Rig"))
local FlockView = require(script.Parent:WaitForChild("FlockView"))
local Vehicles = require(script.Parent:WaitForChild("Vehicles"))
local Workers = require(script.Parent:WaitForChild("Workers"))
local Effects = require(script.Parent:WaitForChild("Effects"))
local ThemeLighting = require(script.Parent:WaitForChild("ThemeLighting"))

local Visuals = {}

export type PlotInfo = {
	plot: Model,
	index: number,
	owner: number,
	own: boolean,
	cf: CFrame, -- plot frame (PlotLayout local -> world)
	center: Vector3,
	dist: number, -- studs from the camera to the plot centre (refreshed every replan)
}

export type Ctx = {
	Store: any,
	player: Player,
	container: Folder,
	plots: { [Model]: PlotInfo },
	own: PlotInfo?,
	snapshot: any,
	elapsed: number, -- seconds since the snapshot was taken (server clock estimate)
	effects: boolean,
	flock: string,
}

local ctx: Ctx? = nil
local connections: { RBXScriptConnection } = {}
local unsubs: { () -> () } = {}
local REPLAN_EVERY = 0.5

local function plotCF(index: number): CFrame
	local o, yaw = Layout.Origin(index)
	return CFrame.new(o.x, 0, o.z) * CFrame.Angles(0, yaw, 0)
end

local function cameraPos(): Vector3
	local cam = Workspace.CurrentCamera
	return if cam then cam.CFrame.Position else Vector3.zero
end

local function clearPlot(c: Ctx, plot: Model)
	FlockView.ClearPlot(plot)
	Vehicles.ClearPlot(plot)
	Workers.ClearPlot(plot)
	if c.own and c.own.plot == plot then
		c.own = nil
		Effects.SetOwnPlot(nil)
	end
	c.plots[plot] = nil
end

local function refreshPlot(c: Ctx, plot: Model)
	local owner = tonumber(plot:GetAttribute("OwnerUserId")) or 0
	local index = tonumber(plot:GetAttribute("PlotIndex")) or tonumber(string.match(plot.Name, "%d+")) or 0
	if owner == 0 or index < 1 or index > Layout.PlotCount then
		if c.plots[plot] then
			clearPlot(c, plot)
		end
		return
	end
	local info: PlotInfo? = c.plots[plot]
	local own = owner == c.player.UserId
	if info and info.owner ~= owner then
		clearPlot(c, plot) -- new owner: start from scratch
		info = nil
	end
	if not info then
		local cf = plotCF(index)
		local fresh: PlotInfo = { plot = plot, index = index, owner = owner, own = own, cf = cf, center = cf.Position, dist = 0 }
		info = fresh
		c.plots[plot] = fresh
	end
	assert(info)
	info.own = own
	if own then
		c.own = info
		Effects.SetOwnPlot(info)
	end
end

local function replan(c: Ctx)
	local cam = cameraPos()
	for _, info in c.plots do
		info.dist = (Vector3.new(info.center.X, cam.Y, info.center.Z) - cam).Magnitude
	end
	local snap = c.snapshot
	c.effects = not (snap and snap.settings and snap.settings.effects == false)
	c.flock = if snap and snap.settings and type(snap.settings.flock) == "string" then snap.settings.flock else "normal"
	FlockView.Replan(c)
	Vehicles.Replan(c)
	Workers.Replan(c)
end

function Visuals.Start(Store: any)
	if ctx then
		return
	end
	local player = Players.LocalPlayer
	local container = Instance.new("Folder")
	container.Name = "FarmVisuals"
	container.Parent = Workspace
	Rig.SetContainer(container)
	Rig.Register("chicken", Chicken.Build)
	Rig.Register("worker", WorkerModel.Build)
	Rig.Register("vehicle", VehicleModel.Build)
	Rig.Register("crate", function(_v: number)
		return Crate.Build(1)
	end)

	local c: Ctx = {
		Store = Store,
		player = player,
		container = container,
		plots = {},
		own = nil,
		snapshot = Store.Get(),
		elapsed = 0,
		effects = true,
		flock = "normal",
	}
	ctx = c
	Effects.Init(c)
	ThemeLighting.Init()

	local plotsFolder = Workspace:WaitForChild("Plots")
	local function watch(plot: Instance)
		if not plot:IsA("Model") then
			return
		end
		refreshPlot(c, plot)
		table.insert(connections, plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
			refreshPlot(c, plot)
			replan(c)
		end))
		for _, attr in { "HouseTiers", "VehicleTiers", "WorkerTiers", "Population" } do
			table.insert(connections, plot:GetAttributeChangedSignal(attr):Connect(function()
				if c.plots[plot] and not c.plots[plot].own then
					replan(c)
				end
			end))
		end
	end
	for _, p in plotsFolder:GetChildren() do
		watch(p)
	end
	table.insert(connections, plotsFolder.ChildAdded:Connect(watch))
	table.insert(connections, plotsFolder.ChildRemoved:Connect(function(p)
		if p:IsA("Model") and c.plots[p] then
			clearPlot(c, p)
		end
	end))

	table.insert(unsubs, Store.OnChanged(function(snap)
		c.snapshot = snap
		ThemeLighting.Apply(snap and snap.egg)
		Effects.OnSnapshot(snap)
		replan(c)
	end))

	local parts: { BasePart } = {}
	local cfs: { CFrame } = {}
	local sinceReplan = 0
	table.insert(connections, RunService.Heartbeat:Connect(function(dt)
		local snap = c.snapshot
		c.elapsed = if snap and snap.serverNow then math.clamp(Store.Now() - snap.serverNow, 0, 3) else 0
		sinceReplan += dt
		if sinceReplan >= REPLAN_EVERY then
			sinceReplan = 0
			replan(c)
		end
		table.clear(parts)
		table.clear(cfs)
		FlockView.Update(dt, c, parts, cfs)
		Vehicles.Update(dt, c, parts, cfs)
		Workers.Update(dt, c, parts, cfs)
		Effects.Update(dt, c)
		if #parts > 0 then
			Workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end))

	table.insert(connections, Players.PlayerRemoving:Connect(function(p)
		if p == player then
			Visuals.Stop()
		end
	end))
	replan(c)
end

function Visuals.Stop()
	local c = ctx
	if not c then
		return
	end
	ctx = nil
	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)
	for _, u in unsubs do
		u()
	end
	table.clear(unsubs)
	for plot in table.clone(c.plots) do
		clearPlot(c, plot)
	end
	Effects.Destroy()
	ThemeLighting.Destroy()
	Rig.DestroyPools()
	c.container:Destroy()
end

return Visuals
