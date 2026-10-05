-- Daily login streak, daily quests, promo codes, badges and the sound setting.
local Players = game:GetService("Players")
local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Daily = require(Shared.Logic.Daily)
local Profile = require(Shared.Logic.Profile)
local RaceRules = require(Shared.Logic.RaceRules)

local DailyService = {}

local ctx: any

local function rollover(p: Player)
	local d = ctx.DataService.Get(p)
	if d and Daily.Rollover(d.Daily, Daily.Today(os.time()), d.Stats) then
		ctx.DataService.Changed(p)
	end
end

-- Awards a badge once (skipped while its id isn't set in Config.Badges).
function DailyService.Badge(p: Player, key: string)
	local id = (Config.Badges :: any)[key]
	local d = ctx.DataService.Get(p)
	if not id or not d or d.Badges[key] then
		return
	end
	task.spawn(function()
		local ok = pcall(function()
			BadgeService:AwardBadge(p.UserId, id)
		end)
		if ok and p.Parent then
			d.Badges[key] = true
			ctx.DataService.Changed(p)
		end
	end)
end

-- Checks the badges that depend on profile state (league, pet levels).
function DailyService.CheckBadges(p: Player)
	local d = ctx.DataService.Get(p)
	if not d then
		return
	end
	local idx = RaceRules.League(d.Trophies)
	if idx >= 3 then
		DailyService.Badge(p, "Gold")
	end
	if idx >= #Config.Leagues then
		DailyService.Badge(p, "Champion")
	end
	for _, pet in d.Pets do
		for _, lvl in pet.Levels do
			if lvl >= Config.Stats.MaxLevel then
				DailyService.Badge(p, "MaxLevel")
				return
			end
		end
	end
end

function DailyService.Init(c)
	ctx = c
end

function DailyService.Start()
	ctx.DataService.OnLoaded(function(p: Player)
		rollover(p)
		DailyService.CheckBadges(p)
	end)
	ctx.Util.Connect("ClaimDaily", 0.3, function(p: Player, what)
		local d = ctx.DataService.Get(p)
		if not d or type(what) ~= "string" then
			return
		end
		rollover(p)
		local coins = Daily.Claim(d.Daily, d.Stats, what)
		if coins > 0 then
			d.Coins += coins
			ctx.DataService.Changed(p)
			ctx.Util.Notify(p, "+" .. coins .. " coins!", "Coins")
		end
	end)
	ctx.Util.Invoke("Redeem", 1, function(p: Player, code)
		local d = ctx.DataService.Get(p)
		if not d or type(code) ~= "string" or #code > 30 then
			return false, "That code doesn't exist."
		end
		local coins, err = Profile.Redeem(d, code, Config.Codes)
		if not coins then
			return false, err
		end
		ctx.DataService.Changed(p)
		return true, "+" .. coins .. " coins!"
	end)
	ctx.Util.Connect("SetMuted", 0.3, function(p: Player, on)
		local d = ctx.DataService.Get(p)
		if d then
			d.Muted = on == true
			ctx.DataService.Changed(p)
		end
	end)
	-- New day while playing (the day starts at midnight UTC).
	while true do
		task.wait(60)
		for _, p in Players:GetPlayers() do
			pcall(rollover, p)
		end
	end
end

return DailyService
