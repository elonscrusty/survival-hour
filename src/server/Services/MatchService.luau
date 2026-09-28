--!nonstrict
-- Match state machine: arrival → intro → Day/Night cycle → end → return.
--
-- Public state replicates through attributes on ReplicatedStorage.MatchState:
--   Phase ("Idle" | "Loading" | "Intro" | "Day" | "Night" | "Ended"), PhaseEnds (server time),
--   Day (number), Fire1..4 (bool), Standing1..4 (bool), Alive1..4 (int), Winner (int), MatchId.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Logic = Shared:WaitForChild("Logic")
local LivesRules = require(Logic:WaitForChild("LivesRules"))
local ProfileRules = require(Logic:WaitForChild("ProfileRules"))
local TeamAssignment = require(Logic:WaitForChild("TeamAssignment"))
local FireRules = require(Logic:WaitForChild("FireRules"))

local MatchService = {}

local ctx: any
local state: Folder
local hooks: { [string]: { (...any) -> () } } = {}

MatchService.Active = false
MatchService.Phase = "Idle"
MatchService.Day = 0
MatchService.MatchId = ""
MatchService.StartedTeams = {} :: { number }
MatchService.Roster = {} :: { [number]: number } -- userId -> team
MatchService.Participants = {} :: { [number]: boolean } -- userId -> was in the match at start
MatchService.Map = nil :: any
MatchService.State = (nil :: any) :: Folder -- ReplicatedStorage.MatchState, set in Init
local phaseToken = 0
local ending = false
local matchStartedAt = os.clock()
local lastRemaining = 0 -- standing clans at the last outcome check (for Final Three / Two)
local elimOrder: { number } = {} -- teams in the order they were eliminated (for placements)

function MatchService.On(event: string, fn: (...any) -> ())
	hooks[event] = hooks[event] or {}
	table.insert(hooks[event], fn)
end

local function emit(event: string, ...: any)
	for _, fn in hooks[event] or {} do
		local args = table.pack(...)
		task.spawn(function()
			local ok, err = pcall(fn, table.unpack(args, 1, args.n))
			if not ok then
				warn("[MatchService] hook " .. event .. " error:", err)
			end
		end)
	end
end

function MatchService.Init(c)
	ctx = c
	ctx.Util.Connect("LeaveMatch", "Lobby", MatchService._onLeaveMatch)
	state = Instance.new("Folder")
	state.Name = "MatchState"
	state.Parent = ReplicatedStorage
	MatchService.State = state
	MatchService._setPhase("Idle", 0)
	ctx.Util.OnPlayerRemoving(MatchService._onLeave)
end

function MatchService.Start()
	if ctx.Mode == "Match" then
		MatchService._runReserved()
	end
end

function MatchService.Broadcast(eventName: string, payload: any)
	Net.FireList("MatchEvent", ctx.Util.MatchPlayers(), eventName, payload)
end

function MatchService._setPhase(phase: string, duration: number)
	MatchService.Phase = phase
	state:SetAttribute("Phase", phase)
	state:SetAttribute("PhaseEnds", workspace:GetServerTimeNow() + duration)
	state:SetAttribute("Day", MatchService.Day)
end

local function phaseLength(kind: string): number
	if ctx.IsStudio and Config.Dev.StudioPhaseLength then
		return Config.Dev.StudioPhaseLength
	end
	return if kind == "Day" then Config.Match.DayLength else Config.Match.NightLength
end

-- Reserved (production) match server -------------------------------------------------------

function MatchService._runReserved()
	MatchService._setPhase("Loading", Config.Match.ArrivalTimeout)
	local manifest = ctx.MatchmakingService.ReadManifest(game.PrivateServerId)
	if not manifest then
		warn("[MatchService] no manifest for this reserved server; returning players")
		task.wait(5)
		MatchService.ReturnToLobby(Players:GetPlayers(), "Match could not be found.")
		return
	end
	-- manifest.Teams = { { { Id = partyId, Members = { userId... } } ... } x4 }
	local expected: { [number]: boolean } = {}
	for _, team in manifest.Teams do
		for _, party in team do
			for _, uid in party.Members do
				expected[uid] = true
			end
		end
	end
	-- Kick back anyone not in the manifest (late arrivals / strangers).
	ctx.Util.OnPlayerAdded(function(p: Player)
		if not expected[p.UserId] or MatchService.Active then
			task.wait(2)
			MatchService.ReturnToLobby({ p }, "That match already started. Queue again for the next one!")
		end
	end)
	local deadline = os.clock() + Config.Match.ArrivalTimeout
	while os.clock() < deadline do
		local allHere = true
		for uid in expected do
			if not Players:GetPlayerByUserId(uid) then
				allHere = false
				break
			end
		end
		if allHere then
			break
		end
		task.wait(1)
	end
	-- Build party lists with arrived members only, then rebalance if a team emptied (D4).
	local teams = {}
	for t, team in manifest.Teams do
		teams[t] = {}
		for _, party in team do
			local members = {}
			for _, uid in party.Members do
				if Players:GetPlayerByUserId(uid) then
					table.insert(members, uid)
				end
			end
			table.insert(teams[t], { Id = party.Id, Size = #members, Members = members })
		end
	end
	local balanced = TeamAssignment.Rebalance(teams, Config.Match.MaxPerTeam)
	local assignment: { [Player]: number } = {}
	local populated = 0
	for t = 1, Config.Match.TeamCount do
		local any = false
		for _, party in balanced[t] or {} do
			for _, uid in party.Members or {} do
				local p = Players:GetPlayerByUserId(uid)
				if p then
					assignment[p] = t
					any = true
				end
			end
		end
		if any then
			populated += 1
		end
	end
	if populated < 2 then
		MatchService.ReturnToLobby(Players:GetPlayers(), "Not enough players arrived for a fair match. Please ready up again.", true)
		return
	end
	MatchService.Begin(assignment, manifest.MatchId or game.PrivateServerId)
end

-- Starts a match with players already assigned to teams. Used by both the
-- reserved-server path and the Studio local mode.
function MatchService.Begin(assignment: { [Player]: number }, matchId: string?)
	assert(not MatchService.Active, "match already active")
	MatchService.Active = true
	matchStartedAt = os.clock()
	lastRemaining = 0
	ending = false
	MatchService.MatchId = matchId or HttpService:GenerateGUID(false)
	MatchService.Day = 0
	MatchService.Roster = {}
	MatchService.Participants = {}
	state:SetAttribute("MatchId", MatchService.MatchId)
	state:SetAttribute("Winner", 0)
	state:SetAttribute("SnuffOpen", false)
	MatchService._setPhase("Loading", 30)
	Net.FireList("MatchEvent", (function()
		local list = {}
		for p in assignment do
			table.insert(list, p)
		end
		return list
	end)(), "Loading", {})

	local seed = math.floor(os.time() % 1000000) + math.random(1, 9999)
	local buildStart = os.clock()
	local map = ctx.WorldService.BuildMatch(seed)
	print(string.format("[Match] forest built in %.2fs (seed %d)", os.clock() - buildStart, seed))
	MatchService.Map = map

	local started = {}
	for t = 1, Config.Match.TeamCount do
		state:SetAttribute("Fire" .. t, true)
		state:SetAttribute("Standing" .. t, false)
		state:SetAttribute("Alive" .. t, 0)
	end
	for p, t in assignment do
		if p.Parent then
			MatchService.Roster[p.UserId] = t
			MatchService.Participants[p.UserId] = true
			if not table.find(started, t) then
				table.insert(started, t)
			end
		end
	end
	table.sort(started)
	MatchService.StartedTeams = started
	elimOrder = {}
	for t = 1, Config.Match.TeamCount do
		state:SetAttribute("Standing" .. t, table.find(started, t) ~= nil)
	end

	emit("MatchStarting", map)
	for p, t in assignment do
		if p.Parent then
			p:SetAttribute("Team", t)
			p:SetAttribute("InMatch", true)
			emit("PlayerJoinedMatch", p, t)
		end
	end
	-- Give services a moment to set up camps/nodes, then spawn everyone.
	task.wait(0.5)
	for p, t in assignment do
		if p.Parent then
			ctx.LivesService.SpawnAtCamp(p)
		end
	end

	MatchService._setPhase("Intro", Config.Match.IntroLength)
	-- Publish the initial Alive counts (otherwise they read 0 until the first death).
	MatchService.CheckOutcome()
	MatchService.Broadcast("Intro", { Seconds = Config.Match.IntroLength })
	task.wait(Config.Match.IntroLength)
	if not MatchService.Active then
		return
	end
	MatchService._cycle()
end

-- Runs Day/Night forever (no time limit) starting at `first`.
function MatchService._cycle(first: string?)
	phaseToken += 1
	local token = phaseToken
	task.spawn(function()
		local phase = first or "Day"
		while MatchService.Active and not ending and token == phaseToken do
			if phase == "Day" then
				MatchService.Day += 1
			end
			MatchService._enterPhase(phase)
			task.wait(phaseLength(phase))
			phase = if phase == "Day" then "Night" else "Day"
		end
	end)
end

-- Dev/test helper: jump straight to the next phase.
function MatchService.SkipPhase()
	if MatchService.Active and not ending and (MatchService.Phase == "Day" or MatchService.Phase == "Night") then
		MatchService._cycle(if MatchService.Phase == "Day" then "Night" else "Day")
	end
end

function MatchService._enterPhase(phase: string)
	MatchService._setPhase(phase, phaseLength(phase))
	-- weather for the phase (visual only, never on Day 1); an event (storm/fog) can hold it
	ctx.WorldService.SetWeather(ctx.EventService.PhaseWeather(MatchService.Day))
	if phase == "Day" then
		-- Dawn -> Day -> Sunset across the day (cancelled if the phase changes).
		ctx.WorldService.ApplyLighting("Dawn", false)
		local token = phaseToken
		local len = phaseLength(phase)
		task.delay(math.min(Config.Lighting.DawnTime, len * 0.2), function()
			if token == phaseToken and MatchService.Phase == "Day" then
				ctx.WorldService.ApplyLighting("Day", false)
			end
		end)
		task.delay(len * Config.Lighting.AfternoonAt, function()
			if token == phaseToken and MatchService.Phase == "Day" then
				ctx.WorldService.ApplyLighting("Afternoon", false)
			end
		end)
		task.delay(len * Config.Lighting.SunsetAt, function()
			if token == phaseToken and MatchService.Phase == "Day" then
				ctx.WorldService.ApplyLighting("Sunset", false)
				MatchService.Broadcast("Sunset", { Day = MatchService.Day })
			end
		end)
	else
		ctx.WorldService.ApplyLighting(phase, false)
	end
	local wasOpen = state:GetAttribute("SnuffOpen") == true
	local open = FireRules.SnuffAllowed(phase, MatchService.Day, Config.Fire :: any)
	state:SetAttribute("SnuffOpen", open)
	MatchService.Broadcast("Phase", { Phase = phase, Day = MatchService.Day, SnuffOpen = open, ProtectionEnded = open and not wasOpen })
	emit("PhaseChanged", phase, MatchService.Day)
end

function MatchService.IsNight(): boolean
	return MatchService.Active and MatchService.Phase == "Night"
end

function MatchService.IsPlaying(): boolean
	return MatchService.Active and (MatchService.Phase == "Day" or MatchService.Phase == "Night" or MatchService.Phase == "Intro")
end

-- Fires --------------------------------------------------------------------------------

function MatchService.FireBurning(team: number): boolean
	return state:GetAttribute("Fire" .. team) == true
end

function MatchService.ExtinguishFire(team: number, byPlayer: Player?)
	if not MatchService.FireBurning(team) then
		return
	end
	state:SetAttribute("Fire" .. team, false)
	emit("FireOut", team, byPlayer)
	local teamDef = Config.Teams[team]
	MatchService.Broadcast("FireOut", { Team = team, By = if byPlayer then byPlayer.DisplayName else nil, ByTeam = if byPlayer then ctx.Util.Team(byPlayer) else nil })
	ctx.Util.NotifyTeam(team, "Your fire is OUT. You're on your FINAL LIFE — your next death eliminates you.", "danger")
	print(string.format("[Match] %s fire extinguished%s", teamDef.Name, if byPlayer then " by " .. byPlayer.Name else ""))
	MatchService.CheckOutcome()
end

-- Outcome ------------------------------------------------------------------------------

function MatchService.CheckOutcome()
	if not MatchService.Active or ending or MatchService.Phase == "Loading" then
		return
	end
	local standing = {}
	for t = 1, Config.Match.TeamCount do
		local lives = ctx.LivesService.TeamLives(t)
		standing[t] = LivesRules.TeamStanding(lives)
		local alive = 0
		for _, l in lives do
			if l.State == "Alive" then
				alive += 1
			end
		end
		state:SetAttribute("Alive" .. t, alive)
		local was = state:GetAttribute("Standing" .. t)
		state:SetAttribute("Standing" .. t, standing[t])
		if was and not standing[t] and table.find(MatchService.StartedTeams, t) then
			if not table.find(elimOrder, t) then
				table.insert(elimOrder, t)
			end
			MatchService.Broadcast("TeamEliminated", { Team = t })
			emit("TeamEliminated", t)
		end
	end
	-- survivors remaining: announce each drop, and make Final Three / Final Two moments
	local remaining = 0
	for _, t in MatchService.StartedTeams do
		if standing[t] then
			remaining += 1
		end
	end
	state:SetAttribute("Remaining", remaining)
	if lastRemaining > 0 and remaining < lastRemaining and remaining >= 2 then
		local final = if remaining == 3 and #MatchService.StartedTeams >= 4 then "Three" elseif remaining == 2 then "Two" else nil
		MatchService.Broadcast("SurvivorsLeft", { Left = remaining, Final = final })
	end
	lastRemaining = remaining
	local result, winner = LivesRules.Outcome(standing, MatchService.StartedTeams, ctx.IsStudio and Config.Dev.StudioAllowSingleTeam)
	if result == "Winner" then
		MatchService.End(winner)
	elseif result == "NoTeams" then
		MatchService.End(nil)
	end
end

function MatchService.End(winner: number?)
	if ending then
		return
	end
	ending = true
	phaseToken += 1
	state:SetAttribute("Winner", winner or 0)
	MatchService._setPhase("Ended", Config.Match.EndScreenLength)
	emit("MatchEnded", winner)

	-- Rewards: placements (1st / 2nd / 3rd by elimination order) are granted
	-- exactly once per MatchId (ProfileRules.AwardPlacement); everyone gets an
	-- XP / Coins summary of what they earned during the match.
	local started = #MatchService.StartedTeams
	local function placeOf(team: number): number?
		if winner and team == winner then
			return 1
		end
		local idx = table.find(elimOrder, team)
		return if idx then started - idx + 1 else nil
	end
	local summaries = {}
	for _, p in Players:GetPlayers() do
		local team = MatchService.Roster[p.UserId]
		if MatchService.Participants[p.UserId] and team then
			local place = placeOf(team)
			local session = ctx.DataService.Get(p)
			local earned = ctx.PowerupService.Earned(p) or { XP = 0, Coins = 0, Diamonds = 0, Levels = 0 }
			local sum = { Place = place, Of = started, XP = earned.XP, Coins = earned.Coins, Diamonds = earned.Diamonds, Levels = earned.Levels, Stats = ctx.PowerupService.Stats(p), Nights = MatchService.Day or 0, Bench = ctx.CampService.GetLevel(team), Duration = math.floor(os.clock() - matchStartedAt) }
			if session and ctx.DataService.CanGrant(p) then
				session.Profile.Matches += 1
				ProfileRules.NoteMatch(session.Profile, os.time(), place == 1)
				ctx.PowerupService.CommitMatch(p, session.Profile, place, MatchService.FireBurning(team))
				if place and place <= 3 then
					local before = session.Profile.Level
					local xp, coins, diamonds = ProfileRules.AwardPlacement(session.Profile, MatchService.MatchId, place, Config.Data.RewardedMatchMemory)
					sum.XP += xp
					sum.Coins += coins
					sum.Diamonds += diamonds
					sum.Levels += session.Profile.Level - before
				end
				sum.Level = session.Profile.Level
				task.spawn(function()
					ctx.DataService.Save(p, false)
					ctx.DataService.Push(p)
					ctx.DataService.PostLeaderboards(p)
				end)
			end
			summaries[p] = sum
		end
	end
	for _, p in ctx.Util.MatchPlayers() do
		local won = winner ~= nil and ctx.Util.Team(p) == winner
		local sum = summaries[p] or {}
		Net.FireClient("MatchEvent", p, "MatchEnded", {
			Winner = winner or 0,
			Won = won,
			Diamonds = sum.Diamonds or 0,
			Summary = sum,
		})
		if won then
			ctx.CosmeticService.OnVictory(p)
		end
	end
	print("[Match] ended; winner:", winner and Config.Teams[winner].Name or "none")

	task.delay(Config.Match.EndScreenLength, function()
		MatchService._teardown()
	end)
end

function MatchService._teardown()
	local players = ctx.Util.MatchPlayers()
	emit("MatchCleanup")
	MatchService.Active = false
	for _, p in players do
		p:SetAttribute("InMatch", false)
		p:SetAttribute("Team", 0)
	end
	if ctx.Mode == "Match" then
		MatchService.ReturnToLobby(Players:GetPlayers(), nil)
	else
		ctx.WorldService.ClearMatch()
		MatchService.Map = nil
		ctx.WorldService.ApplyLighting(if ctx.Mode == "Lobby" then "Lobby" else "Day", true)
		state:SetAttribute("Weather", nil)
		MatchService._setPhase("Idle", 0)
		for _, p in players do
			if p.Parent then
				ctx.LivesService.SpawnInLobby(p)
				Net.FireClient("MatchEvent", p, "ReturnedToLobby", {})
			end
		end
	end
end

-- Returns players to a public lobby server (production) or the local lobby (Studio).
function MatchService.ReturnToLobby(players: { Player }, message: string?, priority: boolean?)
	if #players == 0 then
		return
	end
	for _, p in players do
		if message then
			ctx.Util.Notify(p, message, "info")
		end
	end
	if ctx.Mode ~= "Match" or ctx.IsStudio then
		for _, p in players do
			p:SetAttribute("InMatch", false)
			ctx.LivesService.SpawnInLobby(p)
		end
		return
	end
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData({ ReturnFromMatch = true, Priority = priority == true })
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(game.PlaceId, players, options)
		end)
		if ok then
			return
		end
		warn("[MatchService] return teleport failed:", err)
		task.wait(attempt * 2)
	end
	for _, p in players do
		p:Kick("Match over — please rejoin Survival Hour.")
	end
end

-- Eliminated players may leave early (their placement is already decided).
function MatchService._onLeaveMatch(p: Player)
	if not MatchService.Active or not p:GetAttribute("InMatch") or p:GetAttribute("LifeState") ~= "Eliminated" then
		return
	end
	if ctx.Mode == "Match" then
		MatchService.ReturnToLobby({ p }, nil)
	else
		p:SetAttribute("InMatch", false)
		p:SetAttribute("Team", 0)
		ctx.LivesService.SpawnInLobby(p)
		Net.FireClient("MatchEvent", p, "ReturnedToLobby", {})
	end
end

-- Leavers --------------------------------------------------------------------------------

function MatchService._onLeave(player: Player)
	if not MatchService.Active then
		return
	end
	if player:GetAttribute("InMatch") then
		-- LivesService marks the life as Left; re-check next frame.
		task.defer(MatchService.CheckOutcome)
	end
	if ctx.Mode == "Match" then
		task.delay(1, function()
			if #Players:GetPlayers() == 0 and MatchService.Active then
				-- Everyone left: nothing left to do (reserved servers shut down when empty).
				MatchService.Active = false
				phaseToken += 1
			end
		end)
	end
end

return MatchService
