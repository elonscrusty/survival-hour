--!strict
-- Text for the in-world lobby boards (tested by tests/LobbyBoards.spec.luau): the Daily
-- Challenges board's reset timer and rows, and the queue counter above the ready ring.
-- Pure formatting only; the client controller (Controllers/LobbyBoards) draws it.

local LobbyBoards = {}

local DAY = 86400

-- Seconds until the daily challenges reset (UTC midnight, matching Progression.DayNumber).
function LobbyBoards.SecondsToReset(now: number): number
	local left = DAY - (math.floor(now) % DAY)
	return math.clamp(left, 0, DAY)
end

-- "Resets in 21h 33m" (minutes rounded up so it never shows "0m" before the reset).
function LobbyBoards.ResetText(now: number): string
	local mins = math.max(1, math.ceil(LobbyBoards.SecondsToReset(now) / 60))
	local h, m = math.floor(mins / 60), mins % 60
	if h >= 24 then
		return "Resets in 24h"
	elseif h > 0 then
		return string.format("Resets in %dh %dm", h, m)
	end
	return string.format("Resets in %dm", m)
end

export type Row = { Text: string, Progress: string, Reward: string, Done: boolean, Claimed: boolean }

-- One board row per daily challenge (weeklies stay in the Profile panel). Accepts the
-- Profile view's Challenges list (Challenges.View); anything malformed is skipped.
function LobbyBoards.DailyRows(list: any): { Row }
	local out: { Row } = {}
	if type(list) ~= "table" then
		return out
	end
	for _, v in list do
		if type(v) ~= "table" or v.Weekly or type(v.Text) ~= "string" then
			continue
		end
		local need = if type(v.Need) == "number" then v.Need else 0
		local prog = math.min(if type(v.Progress) == "number" then v.Progress else 0, need)
		local claimed = v.Claimed == true
		local done = need > 0 and prog >= need
		table.insert(out, {
			Text = v.Text,
			Progress = string.format("%d/%d", prog, need),
			Reward = if claimed then "Claimed" else string.format("+%d 🪙", if type(v.Coins) == "number" then v.Coins else 0),
			Done = done,
			Claimed = claimed,
		})
	end
	return out
end

-- Queue counter over the ready ring: a big title ("READY UP · 1/4") and a status line.
-- The count is players searching on this server's queue against the match start size;
-- once a match could start it counts toward the full size instead.
function LobbyBoards.QueueText(view: any): (string, string)
	if type(view) ~= "table" then
		return "READY UP", "Stand in the ring"
	end
	local q = if type(view.Queue) == "table" then view.Queue else {}
	local searching = if type(q.Searching) == "number" then math.max(0, math.floor(q.Searching)) else 0
	local minP = if type(view.MinPlayers) == "number" then view.MinPlayers else 1
	local maxP = if type(view.MaxPlayers) == "number" then view.MaxPlayers else minP
	local goal = if searching >= minP then maxP else minP
	local title = string.format("READY UP · %d/%d", searching, math.max(goal, 1))
	local sub: string
	if view.Queued then
		sub = if searching >= minP then "Match starting soon…" else "Searching for survivors…"
	elseif view.Ready then
		local ready, total = 0, 0
		for _, m in (if type(view.Members) == "table" then view.Members else {}) :: { any } do
			total += 1
			if type(m) == "table" and m.Ready then
				ready += 1
			end
		end
		sub = string.format("Party ready %d/%d", ready, math.max(total, 1))
	else
		sub = "Stand in the ring to ready up"
	end
	return title, sub
end

return LobbyBoards
