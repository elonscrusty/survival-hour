-- Race results, rewards, medals and leagues.
local Config = require("../Config")

local RaceRules = {}

export type Racer = {
	Id: number,
	Finished: boolean,
	Time: number?, -- finish time in seconds
	Progress: number, -- distance reached (for racers who didn't finish)
}

-- Sorts racers: finishers by time, then everyone else by how far they got.
function RaceRules.Order(racers: { Racer }): { Racer }
	local out = table.clone(racers)
	table.sort(out, function(a, b)
		if a.Finished ~= b.Finished then
			return a.Finished
		end
		if a.Finished then
			if a.Time ~= b.Time then
				return (a.Time or math.huge) < (b.Time or math.huge)
			end
		elseif a.Progress ~= b.Progress then
			return a.Progress > b.Progress
		end
		return a.Id < b.Id
	end)
	return out
end

function RaceRules.MedalTimes(length: number): { Gold: number, Silver: number, Bronze: number }
	local s = Config.Race.MedalSpeeds
	return {
		Gold = math.floor(length / s.Gold * 10 + 0.5) / 10,
		Silver = math.floor(length / s.Silver * 10 + 0.5) / 10,
		Bronze = math.floor(length / s.Bronze * 10 + 0.5) / 10,
	}
end

function RaceRules.Medal(length: number, time: number?): string?
	if not time then
		return nil
	end
	local m = RaceRules.MedalTimes(length)
	if time <= m.Gold then
		return "Gold"
	elseif time <= m.Silver then
		return "Silver"
	elseif time <= m.Bronze then
		return "Bronze"
	end
	return nil
end

-- Coins and trophies for one racer. place is 1-based; count = racers who started.
function RaceRules.Rewards(place: number, count: number, finished: boolean, medal: string?): (number, number)
	local R = Config.Race
	if not finished then
		return R.DnfCoins, 0
	end
	local coins = R.FinishCoins
	local trophies = 0
	if count > 1 then
		coins += R.PlaceCoins[place] or R.PlaceCoins[#R.PlaceCoins]
		-- Beating more racers is worth more: scale by the share of the field you beat.
		local base = R.PlaceTrophies[place] or 0
		trophies += math.max(0, math.floor(base * math.min(1, (count - 1) / 3) + 0.5))
	end
	if medal then
		coins += R.MedalCoins[medal] or 0
		local mt = R.MedalTrophies[medal] or 0
		trophies += if count > 1 then mt else math.min(mt, R.SoloTrophyCap)
	end
	return coins, trophies
end

-- Anti-cheat: could someone move dx studs in dt seconds at this top speed?
function RaceRules.Plausible(dx: number, dt: number, maxSpeed: number): boolean
	return dx <= maxSpeed * Config.Race.SpeedSlack * dt + maxSpeed * Config.Race.TimeSlack
end

function RaceRules.League(trophies: number): (number, any)
	local idx = 1
	for i, l in Config.Leagues do
		if trophies >= l.Min then
			idx = i
		end
	end
	return idx, Config.Leagues[idx]
end

function RaceRules.PlaceText(place: number): string
	local suffix = "th"
	local mod100 = place % 100
	if mod100 < 11 or mod100 > 13 then
		local m = place % 10
		suffix = if m == 1 then "st" elseif m == 2 then "nd" elseif m == 3 then "rd" else "th"
	end
	return tostring(place) .. suffix
end

function RaceRules.FormatTime(t: number): string
	local m = math.floor(t / 60)
	local s = t - m * 60
	return string.format("%d:%05.2f", m, s)
end

return RaceRules
