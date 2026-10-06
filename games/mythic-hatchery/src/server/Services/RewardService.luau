--!strict
-- Daily streak, playtime gifts (per server session), daily quests and Index
-- rewards. All checks live in Logic/Rewards; this file wires the remotes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Species = require(Shared:WaitForChild("Species"))
local Logic = Shared:WaitForChild("Logic")
local Rewards = require(Logic:WaitForChild("Rewards"))

local RewardService = {}

local ctx: any

function RewardService.Init(c)
	ctx = c
	local U = ctx.Util

	ctx.DataService.OnLoaded(function(_, s)
		s.LastPlayClock = os.clock()
		Rewards.EnsurePlaytimeDay(s.Profile, os.time())
	end)
	-- Count the last partial minute before the leave save.
	U.OnPlayerRemoving(function(p)
		local s = ctx.DataService.Get(p)
		if s then
			RewardService.AccruePlaytime(s)
			ctx.DataService.Touch(s)
		end
	end, true)

	U.Function("ClaimDaily", function(player, s)
		local reward, streak, err = Rewards.ClaimDaily(s.Profile, os.time())
		if not reward then
			return U.Fail(err or "Not ready")
		end
		ctx.StateService.Dirty(player)
		return { ok = true, reward = reward, streak = streak }
	end)

	U.Function("ClaimPlaytime", function(player, s, index)
		if not U.IsInt(index, 1, #Config.PlaytimeGifts) then
			return U.Fail("Unknown gift")
		end
		RewardService.AccruePlaytime(s)
		local reward, err = Rewards.ClaimPlaytime(s.Profile, index, os.time())
		if not reward then
			return U.Fail(err or "Not ready")
		end
		ctx.StateService.Dirty(player)
		return { ok = true, reward = reward }
	end)

	U.Function("ClaimQuest", function(player, s, index)
		if not U.IsInt(index, 1, Config.QuestsPerDay) then
			return U.Fail("Unknown quest")
		end
		local reward, err = Rewards.ClaimQuest(s.Profile, index, os.time())
		if not reward then
			return U.Fail(err or "Not ready")
		end
		ctx.StateService.Dirty(player)
		return { ok = true, reward = reward }
	end)

	U.Function("ClaimIndex", function(player, s, tier)
		if not U.IsInt(tier, 1, #Config.IndexRewards) then
			return U.Fail("Unknown reward")
		end
		local reward, err = Rewards.ClaimIndex(s.Profile, tier, os.time())
		if not reward then
			return U.Fail(err or "Not ready")
		end
		ctx.StateService.Dirty(player)
		return { ok = true, reward = reward }
	end)
end

-- Adds the time since the last accrual to today's minutes (profile field,
-- so it carries over between sessions and servers within a UTC day).
function RewardService.AccruePlaytime(s)
	local now = os.clock()
	local last = s.LastPlayClock or now
	s.LastPlayClock = now
	Rewards.AddPlaytime(s.Profile, now - last, os.time())
end

function RewardService.Start()
	while true do
		task.wait(30)
		for p, s in ctx.DataService.All() do
			if s.Ready and not s.Released and not s.Leaving then
				RewardService.AccruePlaytime(s)
				ctx.StateService.Dirty(p)
			end
		end
	end
end

-- Tells the player a species just entered their Index.
function RewardService.Discovered(player: Player, petId: string, element: string?)
	if Species.ById[petId] then
		ctx.Util.Notify(player, "Discovered", { Species = petId, Element = element, PetId = petId })
	end
end

return RewardService
