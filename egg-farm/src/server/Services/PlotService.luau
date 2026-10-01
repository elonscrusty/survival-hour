--!nonstrict
-- Assigns each player one plot (PlotRegistry), publishes the plot's public attributes for every
-- client's visuals, asks World to show the right tiers/theme, and cleans the plot when the
-- owner leaves. Only the owner's farm is ever touched by actions on a plot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlotRegistry = require(Shared.Logic.PlotRegistry)

local PlotService = {}

local World
local registry
local lastApplied: { [Player]: string } = {}

function PlotService.Init(ctx)
	World = ctx.World
	World.Init()
	registry = PlotRegistry.new(World.PlotCount)
end

function PlotService.Claim(player: Player): (number?, Model?)
	local index = PlotRegistry.Claim(registry, player.UserId)
	if not index then
		return nil, nil
	end
	local plot = World.GetPlot(index)
	plot:SetAttribute("OwnerUserId", player.UserId)
	plot:SetAttribute("OwnerName", player.DisplayName)
	player:SetAttribute("PlotIndex", index)
	local zones = World.Zones(plot)
	if zones and zones.spawn then
		player.RespawnLocation = zones.spawn
	end
	return index, plot
end

function PlotService.PlotOf(player: Player): Model?
	local index = registry.plotOf[player.UserId]
	return if index then World.GetPlot(index) else nil
end

function PlotService.IndexOf(player: Player): number?
	return registry.plotOf[player.UserId]
end

function PlotService.Owns(player: Player, index: number): boolean
	return PlotRegistry.Owns(registry, player.UserId, index)
end

function PlotService.Zones(player: Player)
	local plot = PlotService.PlotOf(player)
	return plot and World.Zones(plot)
end

local function tiers(list, field)
	local out = {}
	for i, e in list do
		out[i] = e[field]
	end
	return out
end

-- Publishes public plot info and updates the world models. Cheap when nothing changed.
function PlotService.Sync(player: Player, state, snap)
	local plot = PlotService.PlotOf(player)
	if not plot then
		return
	end
	local houses = tiers(state.housing, "tier")
	local vehicles = tiers(state.vehicles, "tier")
	local workers = tiers(state.workers, "tier")
	plot:SetAttribute("Population", state.population)
	local key = table.concat({
		state.egg,
		table.concat(houses, ","),
		table.concat(vehicles, ","),
		table.concat(workers, ","),
		state.silos,
		snap.permanentSilos,
	}, "|")
	if lastApplied[player] == key then
		return
	end
	lastApplied[player] = key
	plot:SetAttribute("Egg", state.egg)
	plot:SetAttribute("HouseTiers", table.concat(houses, ","))
	plot:SetAttribute("VehicleTiers", table.concat(vehicles, ","))
	plot:SetAttribute("WorkerTiers", table.concat(workers, ","))
	plot:SetAttribute("Silos", state.silos)
	local ok, err = pcall(World.ApplyState, plot, {
		egg = state.egg,
		houses = houses,
		vehicles = vehicles,
		workers = workers,
		silos = state.silos,
		permanentSilos = snap.permanentSilos,
		ownerName = player.DisplayName,
	})
	if not ok then
		warn("[Plot] ApplyState failed: " .. tostring(err))
	end
end

function PlotService.OnFarmEvent(player: Player, name: string, data) end

function PlotService.Release(player: Player)
	lastApplied[player] = nil
	local index = PlotRegistry.Release(registry, player.UserId)
	if index then
		local plot = World.GetPlot(index)
		plot:SetAttribute("OwnerUserId", 0)
		plot:SetAttribute("OwnerName", "")
		plot:SetAttribute("Population", 0)
		local ok, err = pcall(World.ResetPlot, plot)
		if not ok then
			warn("[Plot] ResetPlot failed: " .. tostring(err))
		end
	end
end

function PlotService.Count(): number
	return World.PlotCount
end

PlotService.Players = Players
return PlotService
