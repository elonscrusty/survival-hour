--!strict
-- Local-only life in the world (each player sees their own copy, so the server and network
-- stay quiet): a hot-dog blimp, hot-air balloons, cloud puffs and birds in the sky; customers
-- that walk up to the player's businesses (more as businesses level up); delivery vehicles on
-- the road; bobbing pickups and a spinning portal. Purely cosmetic: no rewards come from here.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Economy = require(Shared.Logic.Economy)
local Layout = require(Shared.Layout)
local Models = require(Shared.Models)
local State = require(script.Parent.State)

local Ambient = {}
local player = Players.LocalPlayer

local folder: Folder
local movers: { { model: Model, update: (number) -> CFrame } } = {}

local function spawnModel(name: string, scale: number?): Model
	local m = Models.build(name)
	if scale and scale ~= 1 then
		pcall(function()
			m:ScaleTo(scale)
		end)
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		end
	end
	m.Parent = folder
	return m
end

local function addMover(m: Model, update: (number) -> CFrame)
	table.insert(movers, { model = m, update = update })
end

local function plotOrigin(): CFrame?
	local i = player:GetAttribute("Plot")
	return if type(i) == "number" then Layout.plotOrigin(i) else nil
end

---------------------------------------------------------------- sky
local function buildSky()
	local centre = Vector3.new(Layout.PLOT_SPACING * 1.5, 0, 180)
	-- hot-dog blimp on a slow wide loop
	local blimp = spawnModel("Blimp")
	addMover(blimp, function(t)
		local a = t * 0.025
		local pos = centre + Vector3.new(math.cos(a) * 420, 150 + math.sin(t * 0.3) * 4, math.sin(a) * 260)
		local dir = Vector3.new(-math.sin(a), 0, math.cos(a))
		return CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.rad(90), 0)
	end)
	-- hot-air balloons drifting
	for i = 1, 4 do
		local b = spawnModel("HotAirBalloon")
		local seed = i * 1.7
		addMover(b, function(t)
			local x = ((t * (3 + i) + i * 300) % 1600) - 400
			return CFrame.new(x, 95 + i * 18 + math.sin(t * 0.5 + seed) * 6, -140 + i * 120) * CFrame.Angles(0, t * 0.05 + seed, 0)
		end)
	end
	-- cloud puffs low on the horizon
	for i = 1, 10 do
		local c = spawnModel("CloudPuff", 1.5 + (i % 3) * 0.5)
		local z = if i % 2 == 0 then -260 - i * 12 else 620 + i * 10
		addMover(c, function(t)
			local x = ((t * 2 + i * 190) % 1800) - 500
			return CFrame.new(x, 120 + (i % 4) * 20, z)
		end)
	end
	-- a few flocks of birds
	for f = 1, 3 do
		for k = 1, 5 do
			local bird = spawnModel("Bird", 1.5)
			local wings = bird:FindFirstChild("Wings", true) :: BasePart?
			addMover(bird, function(t)
				local a = t * 0.12 + f * 2
				local r = 160 + f * 60
				local pos = centre + Vector3.new(math.cos(a) * r + k * 4, 70 + f * 15 + (k % 2) * 3, math.sin(a) * r + (k % 3) * 4)
				if wings then
					wings.Size = Vector3.new(3, 0.15, 0.9 + math.abs(math.sin(t * 8 + k)) * 0.6)
				end
				return CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a)))
			end)
		end
	end
end

---------------------------------------------------------------- road traffic
local function buildTraffic()
	local names = { "DeliveryVan", "DeliveryBike", "DepotTruck", "BigVan", "FridgeTruck" }
	for i = 1, 5 do
		local v = spawnModel(names[i])
		local lane = if i % 2 == 0 then 4 else -4
		local speed = 18 + i * 3
		local span = Layout.PLOT_SPACING * 4 + 400
		addMover(v, function(t)
			local x = ((t * speed + i * 260) % span) - 200
			if lane > 0 then
				x = span - 400 - x
			end
			return CFrame.new(x, 0.3, Layout.ROAD_Z + lane) * CFrame.Angles(0, if lane > 0 then math.pi else 0, 0)
		end)
	end
end

---------------------------------------------------------------- customers
local customers: { Model } = {}
local function rebuildCustomers()
	for _, c in customers do
		c:Destroy()
	end
	customers = {}
	local d = State.data
	local origin = plotOrigin()
	if not d or not origin then
		return
	end
	local kinds = { "CustomerA", "CustomerB", "CustomerC" }
	local n = 0
	for _, biz in Economy.businesses do
		local b = d.biz[biz.id]
		if b and b.owned then
			local count = math.min(5, 1 + (d.tiers and d.tiers[biz.id] or 0))
			local lot = Layout.lots[biz.id]
			for k = 1, count do
				n += 1
				if n > 24 then
					return
				end
				local m = spawnModel(kinds[(n % 3) + 1])
				table.insert(customers, m)
				-- walk from the central path to the front of the business and back
				local from = Vector3.new(if lot.pos.X > 0 then 4 else -4, 0, lot.pos.Z - 4 + k * 2)
				local to = lot.pos + Vector3.new((k - (count + 1) / 2) * 3, 0, -lot.size.Y / 2 + 3)
				if biz.id == "stand" then
					from = Vector3.new((k - 2) * 3, 0, 4)
					to = lot.pos + Vector3.new((k - (count + 1) / 2) * 3, 0, -7)
				end
				local period = 10 + k * 1.3
				local offset = k * 2.1 + n
				addMover(m, function(t)
					local u = ((t + offset) % period) / period
					local walkOut = u < 0.4
					local wait = u >= 0.4 and u < 0.6
					local f = if walkOut then u / 0.4 elseif wait then 1 else 1 - (u - 0.6) / 0.4
					local p = from:Lerp(to, f)
					local bob = if wait then 0 else math.abs(math.sin(t * 8)) * 0.25
					local look = if walkOut or wait then (to - from) else (from - to)
					local wpos = origin * (p + Vector3.new(0, bob, 0))
					return CFrame.lookAt(wpos, wpos + origin:VectorToWorldSpace(Vector3.new(look.X, 0, look.Z)))
				end)
			end
		end
	end
end

---------------------------------------------------------------- loop
function Ambient.init()
	local f = Instance.new("Folder")
	f.Name = "LocalAmbient"
	f.Parent = workspace
	folder = f
	buildSky()
	buildTraffic()
	local lastKey = ""
	State.Changed:Connect(function(d)
		local parts = {}
		for _, biz in Economy.businesses do
			local b = d.biz[biz.id]
			table.insert(parts, (b and b.owned and "1" or "0") .. tostring(d.tiers and d.tiers[biz.id] or 0))
		end
		local key = table.concat(parts) .. tostring(player:GetAttribute("Plot"))
		if key ~= lastKey then
			lastKey = key
			rebuildCustomers()
		end
	end)
	local t = 0
	RunService.RenderStepped:Connect(function(dt: number)
		t += dt
		for i = #movers, 1, -1 do
			local mv = movers[i]
			if mv.model.Parent == nil then
				table.remove(movers, i)
			else
				mv.model:PivotTo(mv.update(t))
			end
		end
		-- bob and spin the player's pickups; spin the portal disc
		local origin = plotOrigin()
		local plots = workspace:FindFirstChild("Plots")
		local plot = plots and plots:FindFirstChild("Plot" .. tostring(player:GetAttribute("Plot")))
		if plot and origin then
			local pickups = plot:FindFirstChild("Pickups")
			if pickups then
				for _, m in pickups:GetChildren() do
					if m:IsA("Model") then
						local base = m:GetAttribute("BaseY")
						local pivot = m:GetPivot()
						if base == nil then
							m:SetAttribute("BaseY", pivot.Position.Y)
							base = pivot.Position.Y
						end
						local p = pivot.Position
						m:PivotTo(CFrame.new(p.X, (base :: number) + 0.6 + math.sin(t * 3 + p.X) * 0.4, p.Z) * CFrame.Angles(0, t * 1.5, 0))
					end
				end
			end
			local portal = plot:FindFirstChild("Portal")
			local disc = portal and portal:FindFirstChild("Disc", true) :: BasePart?
			if disc then
				disc.CFrame = disc.CFrame * CFrame.Angles(dt * 1.5, 0, 0)
			end
		end
	end)
end

return Ambient
