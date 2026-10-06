--!strict
-- Studio-only test shortcuts for the client's DEV panel (remote "DevAction").
-- Every call is refused outside Studio, and Studio saves go to a separate
-- DataStore (DataService.StoreName), so none of this can touch live data.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared:WaitForChild("Areas"))
local Logic = Shared:WaitForChild("Logic")
local Economy = require(Logic:WaitForChild("Economy"))
local Profile = require(Logic:WaitForChild("Profile"))
local Rewards = require(Logic:WaitForChild("Rewards"))

local DevService = {}

local ctx: any

-- action -> handler(player, session) -> (ok, message?)
local ACTIONS: { [string]: (Player, any) -> (boolean, string?) } = {
	Coins1M = function(_player, s)
		Economy.AddCoins(s.Profile, 1e6, false)
		return true, "+1M coins"
	end,
	CoinsX1000 = function(_player, s)
		local p = s.Profile
		Economy.AddCoins(p, math.max(1000, p.Coins * 999), false)
		return true, "Coins x1000"
	end,
	Gems1000 = function(_player, s)
		Economy.AddGems(s.Profile, 1000)
		return true, "+1000 gems"
	end,
	FinishExpeditions = function(_player, s)
		local now = os.time()
		local n = 0
		for _, e in s.Profile.Expeditions do
			if e.EndAt > now then
				e.EndAt = now
				e.StartAt = math.min(e.StartAt, now - 1)
				n += 1
			end
		end
		return true, n .. " expedition(s) finished"
	end,
	OpenGates = function(_player, s)
		for _, a in Areas.List do
			s.Profile.Areas[a.Id] = true
		end
		return true, "All gates open"
	end,
	ResetData = function(player, s)
		if ctx.TradeService.InTrade(player) or ctx.BattleService.IsOccupied(player) then
			return false, "Cancel your trade first"
		end
		ctx.RideService.Stop(player)
		s.Profile = Profile.Default()
		Rewards.EnsureQuests(s.Profile, Rewards.DayNumber(os.time()))
		return true, "Data reset"
	end,
}

function DevService.Init(c)
	ctx = c
	ctx.Util.Function("DevAction", function(player, s, action)
		if not RunService:IsStudio() then
			return ctx.Util.Fail("Only available in Studio")
		end
		if not ctx.Util.IsStr(action, 32) or not ACTIONS[action] then
			return ctx.Util.Fail("Unknown dev action")
		end
		local ok, message = ACTIONS[action](player, s)
		if not ok then
			return ctx.Util.Fail(message or "Not possible right now")
		end
		ctx.DataService.Touch(s)
		ctx.StateService.Dirty(player)
		return { ok = true, message = message }
	end)
end

return DevService
