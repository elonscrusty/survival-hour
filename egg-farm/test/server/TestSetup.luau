--!nonstrict
-- TEST PLACE ONLY. Swaps in memory persistence and the simulated checkout, adds test-only codes and
-- a DevCommand remote (ReplicatedStorage.DevCommand) used by the test client's dev panel.
-- None of this exists in build/EggFarm.rbxlx.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")
local State = require(Shared.Logic.State)
local Products = require(Shared.Data.Products)
local MemoryAdapter = require(Server.Persistence.MemoryAdapter)
local TestCheckout = require(Server.Commerce.TestCheckout)
local Codes = require(Server.Data.Codes)
local Fixtures = require(ReplicatedStorage:WaitForChild("TestFixtures"):WaitForChild("Fixtures"))

local cat = {
	Eggs = require(Shared.Data.Eggs),
	Housing = require(Shared.Data.Housing),
	Vehicles = require(Shared.Data.Vehicles),
	Workers = require(Shared.Data.Workers),
	Upgrades = require(Shared.Data.Upgrades),
	Boosts = require(Shared.Data.Boosts),
}

local TestSetup = {}

function TestSetup.Configure(ctx)
	ctx.PersistenceAdapter = MemoryAdapter.new(function()
		local s = State.New(0)
		s.createdAt = 0
		return s
	end, "test-" .. game.JobId)
	local checkout = TestCheckout.new(Products, "success")
	ctx.TestCheckout = checkout
	ctx.CommerceService.SetTestCheckout(checkout)
	local codes = table.clone(Codes)
	codes.TESTEXPIRED = { reward = { gold = 1 }, expires = 1 } -- exercises the "expired" response
	ctx.Codes = codes
	ctx.AfterInit = TestSetup.AfterInit
end

local commands = {}

local function farmOf(ctx, player)
	return ctx.FarmService.Get(player)
end

commands.cash = function(ctx, player, f)
	f.state.cash += 1e6 * cat.Eggs.List[f.state.egg].costScale
end
commands.gold = function(ctx, player, f)
	f.state.gold += 1000
end
commands.tutorial = function(ctx, player, f)
	f.state.tutorial.step, f.state.tutorial.done = 8, true
end
commands.maxed = function(ctx, player, f)
	Fixtures.Maxed(f.state, cat)
end
commands.egg = function(ctx, player, f, n)
	Fixtures.AtEgg(f.state, tonumber(n) or 1, cat)
end
commands.boosts = function(ctx, player, f)
	Fixtures.AllBoosts(f.state, cat)
end
commands.quests = function(ctx, player, f)
	Fixtures.QuestsReady(f.state)
end
commands.forward = function(ctx, player, f, seconds)
	local s = math.clamp(tonumber(seconds) or 600, 1, 86400)
	f:Step(s, ctx.FarmService.Now())
end
commands.offline = function(ctx, player, f, seconds)
	f.state.lastSeen = ctx.FarmService.Now() - math.clamp(tonumber(seconds) or 7200, 1, 86400 * 3)
	f:ComputeOffline(ctx.FarmService.Now())
end
commands.nextday = function(ctx, player, f)
	ctx.DayOffset = (ctx.DayOffset or 0) + 86400
	ctx.FarmService.SetTimeOffset(ctx.DayOffset)
end
commands.fox = function(ctx, player, f)
	ctx.FoxService.SpawnNow(player)
end
commands.checkout = function(ctx, player, f, mode)
	if mode == "success" or mode == "cancel" or mode == "fail" then
		ctx.TestCheckout.mode = mode
	end
end
commands.failload = function(ctx)
	ctx.PersistenceAdapter.store.failLoads += 1
end
commands.failsave = function(ctx)
	ctx.PersistenceAdapter.store.failSaves += 1
end
commands.reset = function(ctx, player, f)
	local fresh = State.New(ctx.FarmService.Now())
	for k in f.state do
		f.state[k] = nil
	end
	for k, v in fresh do
		f.state[k] = v
	end
end
commands.rejoin = function(ctx, player)
	player:Kick("(Test) Rejoin to test reconnect: your memory save is kept while this server runs.")
end

function TestSetup.AfterInit(ctx)
	local remote = Instance.new("RemoteFunction")
	remote.Name = "DevCommand"
	remote.OnServerInvoke = function(player: Player, name: any, arg: any)
		if type(name) ~= "string" or not commands[name] then
			return { ok = false, message = "unknown command" }
		end
		local f = farmOf(ctx, player)
		if not f and name ~= "failload" and name ~= "failsave" then
			return { ok = false, message = "farm not loaded" }
		end
		local ok, err = pcall(commands[name], ctx, player, f, arg)
		if f then
			f.dirty = true
			ctx.FarmService.Push(player, true)
		end
		return { ok = ok, message = if ok then name .. " done" else tostring(err) }
	end
	remote.Parent = ReplicatedStorage
	ReplicatedStorage:SetAttribute("TestPlace", true)
	ReplicatedStorage:SetAttribute("CheckoutKind", "test")
end

TestSetup.Players = Players
return TestSetup
