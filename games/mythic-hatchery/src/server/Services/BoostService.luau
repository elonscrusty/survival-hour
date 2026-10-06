--!nonstrict
-- Personal boosts (2x Coins, 2x Luck) stored in the profile, and the
-- server-wide luck boost (this server only), broadcast to everyone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Logic = Shared:WaitForChild("Logic")
local Economy = require(Logic:WaitForChild("Economy"))

local BoostService = {}

local ctx: any
local serverLuckUntil = 0
local serverLuckAnnounced = false

function BoostService.Init(c)
	ctx = c
end

function BoostService.Start()
	-- Refresh everyone once when server luck runs out, so multipliers update.
	while true do
		task.wait(5)
		if serverLuckAnnounced and os.time() >= serverLuckUntil then
			serverLuckAnnounced = false
			ctx.StateService.DirtyAll()
		end
	end
end

function BoostService.ServerLuckUntil(): number
	return serverLuckUntil
end

-- Starts or extends a personal boost. Returns the new expiry (0 if unknown).
function BoostService.Apply(player: Player, s, key: string): number
	if not Config.Boosts[key] then
		return 0
	end
	local expires = Economy.ApplyBoost(s.Profile, key, os.time())
	ctx.StateService.Dirty(player)
	return expires
end

-- Starts or extends server luck and tells everyone who bought it.
function BoostService.ServerLuck(byName: string)
	serverLuckUntil = Economy.ExtendServerLuck(serverLuckUntil, os.time())
	serverLuckAnnounced = true
	ctx.Util.NotifyAll("ServerLuck", { By = byName, Until = serverLuckUntil })
	for _, p in Players:GetPlayers() do
		ctx.StateService.Dirty(p)
	end
end

return BoostService
