local LobbyBoards = require("../src/shared/Logic/LobbyBoards")

local DAY = 86400

return {
	reset_counts_to_utc_midnight = function(t)
		local midnight = 20000 * DAY
		t.eq(LobbyBoards.SecondsToReset(midnight), DAY)
		t.eq(LobbyBoards.SecondsToReset(midnight + 60), DAY - 60)
		t.eq(LobbyBoards.SecondsToReset(midnight + DAY - 1), 1)
	end,
	reset_text_hours_and_minutes = function(t)
		local midnight = 20000 * DAY
		-- 2h 27m in: 21h 33m left
		t.eq(LobbyBoards.ResetText(midnight + 2 * 3600 + 27 * 60), "Resets in 21h 33m")
		t.eq(LobbyBoards.ResetText(midnight + DAY - 30), "Resets in 1m")
		t.eq(LobbyBoards.ResetText(midnight + DAY - 45 * 60), "Resets in 45m")
		t.eq(LobbyBoards.ResetText(midnight), "Resets in 24h")
	end,
	daily_rows_skip_weeklies_and_junk = function(t)
		local rows = LobbyBoards.DailyRows({
			{ Id = "D_Hunt", Text = "Hunt 3 animals", Progress = 1, Need = 3, Coins = 60, Claimed = false, Weekly = false },
			{ Id = "D_Craft", Text = "Craft 5 items", Progress = 9, Need = 5, Coins = 60, Claimed = false, Weekly = false },
			{ Id = "D_Loot", Text = "Search 4 chests", Progress = 4, Need = 4, Coins = 60, Claimed = true, Weekly = false },
			{ Id = "W_Win", Text = "Win 2 matches", Progress = 0, Need = 2, Coins = 300, Claimed = false, Weekly = true },
			"junk",
			{ Progress = 1 },
		})
		t.eq(#rows, 3)
		t.eq(rows[1].Progress, "1/3")
		t.eq(rows[1].Reward, "+60 🪙")
		t.no(rows[1].Done)
		t.eq(rows[2].Progress, "5/5")
		t.ok(rows[2].Done)
		t.eq(rows[3].Reward, "Claimed")
		t.eq(#LobbyBoards.DailyRows(nil), 0)
	end,
	queue_counts_toward_min_then_max = function(t)
		local title, sub = LobbyBoards.QueueText({ Queue = { Searching = 1 }, MinPlayers = 4, MaxPlayers = 16, Members = {} })
		t.eq(title, "READY UP · 1/4")
		t.eq(sub, "Stand in the ring to ready up")
		title, sub = LobbyBoards.QueueText({ Queue = { Searching = 5 }, MinPlayers = 4, MaxPlayers = 16, Queued = true })
		t.eq(title, "READY UP · 5/16")
		t.eq(sub, "Match starting soon…")
		title, sub = LobbyBoards.QueueText({ Queue = { Searching = 2 }, MinPlayers = 4, MaxPlayers = 16, Queued = true })
		t.eq(sub, "Searching for survivors…")
	end,
	queue_party_ready_and_missing_view = function(t)
		local _, sub = LobbyBoards.QueueText({ Ready = true, MinPlayers = 4, MaxPlayers = 4, Members = { { Ready = true }, { Ready = false } } })
		t.eq(sub, "Party ready 1/2")
		local title = LobbyBoards.QueueText(nil)
		t.eq(title, "READY UP")
		title = LobbyBoards.QueueText({})
		t.eq(title, "READY UP · 0/1")
	end,
}
