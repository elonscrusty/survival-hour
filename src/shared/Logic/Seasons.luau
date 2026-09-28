--!strict
-- Date-limited seasonal events (Config.Seasons). Pure rules so the date maths is tested
-- without Roblox (tests/Seasons.spec.luau). A season only changes what is on sale in the
-- Locker and how the world looks; it never touches match rules or numbers.
--
-- Times are unix seconds (UTC). A season is active for Start <= now < End.

export type Season = {
	Id: string,
	Name: string,
	Start: number,
	End: number,
	[string]: any, -- presentation extras (glyph, atmosphere) read by the client
}

local Seasons = {}

-- Matches played during a season are counted under this Profile.Stats key (the earned
-- seasonal title reads it through Cosmetics' Mastery field).
function Seasons.StatKey(id: string): string
	return "Season_" .. id
end

function Seasons.Find(list: { Season }, id: string?): Season?
	if type(id) ~= "string" then
		return nil
	end
	for _, s in list do
		if s.Id == id then
			return s
		end
	end
	return nil
end

-- The season running at `now`, or nil. `force` (a season id; Studio only, see
-- Config.Dev.ForceSeason) switches that season on regardless of its dates.
function Seasons.Active(list: { Season }, now: number, force: string?): Season?
	local forced = Seasons.Find(list, force)
	if forced then
		return forced
	end
	for _, s in list do
		if now >= s.Start and now < s.End then
			return s
		end
	end
	return nil
end

function Seasons.SecondsLeft(s: Season, now: number): number
	return math.max(0, s.End - now)
end

-- Short "time left" text for banners: "9 days left", "1 day left", "5 hours left", "ends soon".
function Seasons.LeftText(seconds: number): string
	if seconds >= 86400 then
		local days = math.floor(seconds / 86400)
		return days .. (if days == 1 then " day left" else " days left")
	elseif seconds >= 3600 then
		local hours = math.floor(seconds / 3600)
		return hours .. (if hours == 1 then " hour left" else " hours left")
	end
	return "ends soon"
end

-- Can a cosmetic tagged with `season` (nil = not limited) be bought while `activeId` runs?
function Seasons.OnSale(season: string?, activeId: string?): boolean
	return season == nil or season == activeId
end

return Seasons
