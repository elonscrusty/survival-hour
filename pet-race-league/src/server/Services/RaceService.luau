-- Races: players standing on the lobby portal are queued; after a short wait they're
-- sent to a freshly built track, race to the finish, and get coins and trophies.
-- Progress is measured from server-side positions with an anti-cheat speed check.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Tracks = require(Shared.Tracks)
local Net = require(Shared.Net)
local TrackLayout = require(Shared.Logic.TrackLayout)
local RaceRules = require(Shared.Logic.RaceRules)
local PetStats = require(Shared.Logic.PetStats)
local Profile = require(Shared.Logic.Profile)

local RaceService = {}

type Racer = {
	Player: Player,
	Id: number,
	Cp: number, -- checkpoint index reached
	CpX: number,
	CpAt: number,
	Progress: number,
	Finished: boolean,
	Time: number?,
	Char: Model?,
	Walk: number, -- ride speed at the start (anti-cheat)
	FrozenUntil: number,
	Left: boolean,
}

local ctx: any
local Util: any
local phase = "Idle" -- Idle | Queue | Racing | Results
local queueEnds = 0
local trackIndex = 0
local racers: { Racer } = {}
local built: any = nil
local startAt = 0
local endAt = 0
local firstFinish: number? = nil
local lastQueueSig = -1
local abort: () -> ()

local function send(p: Player, kind: string, data: any?)
	Net.Event("Race"):FireClient(p, kind, data)
end

local function sendAll(kind: string, data: any?)
	for _, r in racers do
		if not r.Left then
			send(r.Player, kind, data)
		end
	end
end

local function racerOf(p: Player): Racer?
	for _, r in racers do
		if r.Player == p and not r.Left then
			return r
		end
	end
	return nil
end

-- Puts a racer at a local track position (x along the track, y floor height).
local function place(r: Racer, x: number, y: number, z: number?)
	local root = Util.Root(r.Player)
	if not root or not built then
		return
	end
	local pos = built.ToWorld(x, y + 12, z or 0)
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = CFrame.lookAt(pos, pos + Vector3.new(1, 0, 0))
end

local function queued(): { Player }
	local out = {}
	local portal = ctx.WorldService.Portal
	for _, p in Players:GetPlayers() do
		local root = Util.Root(p)
		if root and ctx.DataService.Get(p) and not p:GetAttribute("InRace") and ctx.WorldService.InBox(root.Position, portal.Center, portal.Size) then
			table.insert(out, p)
		end
	end
	return out
end

local function walkFor(p: Player): number
	local d = ctx.DataService.Get(p)
	local pet = d and Profile.EquippedPet(d)
	return if pet then PetStats.Ride(pet).WalkSpeed else Config.Ride.OnFootSpeed
end

local function startRace(players: { Player })
	trackIndex = trackIndex % #Tracks.List + 1
	local track = Tracks.List[trackIndex]
	built = ctx.TrackBuilder.Build(track)
	racers = {}
	firstFinish = nil
	local layout = built.Layout
	for i, p in players do
		if i > Config.Race.MaxPlayers then
			break
		end
		local r: Racer = {
			Player = p,
			Id = i,
			Cp = 1,
			CpX = 0,
			CpAt = 0,
			Progress = 0,
			Finished = false,
			Char = p.Character,
			Walk = walkFor(p),
			FrozenUntil = 0,
			Left = false,
		}
		table.insert(racers, r)
		p:SetAttribute("InRace", true)
		ctx.PetService.SetLocked(p, true)
		ctx.PetService.SetRiding(p, true, true)
		ctx.PetService.ResetCharges(p)
		ctx.PetService.SetFrozen(p, true)
		local sp = built.StartPositions[i]
		local root = Util.Root(p)
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame = CFrame.lookAt(sp + Vector3.new(0, 6, 0), sp + Vector3.new(1, 6, 0))
		end
	end
	phase = "Racing"
	local medals = RaceRules.MedalTimes(layout.Length)
	local names = {}
	for _, r in racers do
		table.insert(names, r.Player.DisplayName)
	end
	sendAll("Start", {
		Track = track.Name,
		Length = layout.Length,
		Medals = medals,
		Checkpoints = #layout.Checkpoints,
		Countdown = Config.Race.Countdown,
		Racers = names,
	})
	ctx.WorldService.SetPortalText("Race in progress: " .. track.Name)
	for n = Config.Race.Countdown, 1, -1 do
		sendAll("Count", n)
		task.wait(1)
	end
	startAt = os.clock()
	endAt = startAt + Config.Race.TimeLimit
	for _, r in racers do
		r.CpAt = startAt
		if not r.Left then
			ctx.PetService.SetFrozen(r.Player, false)
		end
	end
	sendAll("Go", { EndsIn = Config.Race.TimeLimit })
end

local function release(r: Racer)
	local p = r.Player
	p:SetAttribute("InRace", nil)
	ctx.PetService.SetLocked(p, false)
	ctx.PetService.SetFrozen(p, false)
	ctx.PetService.SetZone(p, 1)
	ctx.PetService.ResetCharges(p)
	local root = Util.Root(p)
	if root then
		local spawn = ctx.WorldService.SpawnPos + Vector3.new(math.random(-6, 6), 8, math.random(-6, 6))
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.new(spawn)
	end
end

local function finishRace()
	phase = "Results"
	local layout = built.Layout
	local list = {}
	for _, r in racers do
		table.insert(list, { Id = r.Id, Finished = r.Finished, Time = r.Time, Progress = r.Progress })
	end
	local order = RaceRules.Order(list)
	local count = #racers
	local rows = {}
	local mine = {}
	for place, o in order do
		local r = racers[o.Id]
		local medal = if r.Finished then RaceRules.Medal(layout.Length, r.Time) else nil
		local coins, trophies = RaceRules.Rewards(place, count, r.Finished, medal)
		table.insert(rows, {
			Name = r.Player.DisplayName,
			Place = place,
			Time = r.Time,
			Medal = medal,
			Finished = r.Finished,
		})
		local d = not r.Left and ctx.DataService.Get(r.Player)
		if d then
			d.Coins += coins
			d.Trophies += trophies
			local B = ctx.DailyService
			if r.Finished then
				Profile.Bump(d, "Races")
				B.Badge(r.Player, "FirstRace")
			end
			if place == 1 and count > 1 and r.Finished then
				Profile.Bump(d, "Wins")
				B.Badge(r.Player, "FirstWin")
			end
			if medal then
				Profile.Bump(d, "Medals")
			end
			if medal == "Gold" then
				Profile.Bump(d, "Golds")
				B.Badge(r.Player, "GoldMedal")
			end
			B.CheckBadges(r.Player)
			local best = d.BestTimes[built.Track.Id]
			local newBest = false
			if r.Time and (not best or r.Time < best) then
				d.BestTimes[built.Track.Id] = r.Time
				newBest = best ~= nil
			end
			ctx.DataService.Changed(r.Player)
			mine[r.Player] = { Place = place, Coins = coins, Trophies = trophies, Medal = medal, NewBest = newBest }
		end
	end
	for _, r in racers do
		if not r.Left then
			send(r.Player, "Results", { Rows = rows, Mine = mine[r.Player], Track = built.Track.Name })
		end
	end
	task.wait(Config.Race.ResultsTime)
	for _, r in racers do
		if not r.Left then
			release(r)
		end
	end
	racers = {}
	ctx.TrackBuilder.Clear()
	built = nil
	phase = "Idle"
	ctx.WorldService.SetPortalText("Stand here to race!")
end

-- Respawn spot just past the racer's checkpoint.
local function respawn(r: Racer)
	local cp = built.Layout.Checkpoints[r.Cp]
	local x = cp.X + 3
	place(r, x, TrackLayout.FloorAt(built.Layout, x) or cp.Y)
end

local function racerTick(r: Racer, now: number)
	local p = r.Player
	local root = Util.Root(p)
	if not root or r.Finished then
		return
	end
	local layout = built.Layout
	-- Respawned after a reset: put them back at their checkpoint.
	if p.Character ~= r.Char then
		r.Char = p.Character
		-- skip fall checks until the delayed respawn has put them back on the track
		r.FrozenUntil = now + 0.8
		task.delay(0.6, function()
			if racerOf(p) == r and not r.Finished then
				ctx.PetService.SetRiding(p, true, true)
				respawn(r)
			end
		end)
		return
	end
	if now < r.FrozenUntil then
		return
	end
	if r.FrozenUntil > 0 then
		r.FrozenUntil = 0
		ctx.PetService.SetFrozen(p, false)
	end
	local rel = root.Position - built.ToWorld(0, 0, 0)
	local x, y = rel.X, rel.Y
	-- Fell off: back to the last checkpoint with a short freeze.
	if y < layout.MinY - Config.Race.FallDepth then
		respawn(r)
		r.FrozenUntil = now + Config.Race.FallPenalty
		ctx.PetService.SetFrozen(p, true)
		send(p, "Fell")
		return
	end
	r.Progress = math.max(r.Progress, math.min(x, layout.Length))
	-- Zones
	local zone = TrackLayout.ZoneAt(layout, x)
	ctx.PetService.SetZone(p, if zone == "Boost" then Config.Race.BoostMult elseif zone == "Mud" then Config.Race.MudMult else 1)
	-- Checkpoints, in order, at a believable speed.
	local nextCp = TrackLayout.CheckpointAt(layout, x)
	local finishing = x >= layout.Length and r.Cp == #layout.Checkpoints
	if nextCp > r.Cp or finishing then
		local targetX = if finishing then layout.Length else layout.Checkpoints[nextCp].X
		if nextCp > r.Cp + 1 and not finishing then
			-- Skipped a checkpoint (shouldn't happen on a straight track): only count the next one.
			nextCp = r.Cp + 1
			targetX = layout.Checkpoints[nextCp].X
		end
		if not RaceRules.Plausible(targetX, now - startAt, r.Walk) or not RaceRules.BurstOk(targetX - r.CpX, now - r.CpAt, r.Walk) then
			respawn(r)
			warn("[Race] " .. p.Name .. " moved too fast; sent back")
			return
		end
		if finishing then
			r.Finished = true
			r.Time = math.floor((now - startAt) * 100 + 0.5) / 100
			ctx.PetService.SetZone(p, 1)
			local placeNow = 0
			for _, o in racers do
				if o.Finished then
					placeNow += 1
				end
			end
			if not firstFinish then
				firstFinish = now
				endAt = math.min(endAt, now + Config.Race.HurryTime)
				sendAll("Hurry", { EndsIn = endAt - now })
			end
			sendAll("Finished", { Name = p.DisplayName, Place = placeNow, Time = r.Time })
		else
			r.Cp = nextCp
			r.CpX = targetX
			r.CpAt = now
			send(p, "Checkpoint", { Index = nextCp - 1, Total = #layout.Checkpoints - 1 })
		end
	end
end

local function raceTick()
	local now = os.clock()
	if now < startAt then
		return
	end
	local active = 0
	for _, r in racers do
		if not r.Left then
			local ok, err = pcall(racerTick, r, now)
			if not ok then
				warn("[Race] " .. tostring(err))
			end
			if not r.Finished then
				active += 1
			end
		end
	end
	if active == 0 or now >= endAt then
		finishRace()
	end
end

local lastStanding = 0
local function standings()
	local now = os.clock()
	if now - lastStanding < 0.5 then
		return
	end
	lastStanding = now
	local list = {}
	for _, r in racers do
		if not r.Left then
			table.insert(list, { Id = r.Id, Finished = r.Finished, Time = r.Time, Progress = r.Progress })
		end
	end
	local order = RaceRules.Order(list)
	for place, o in order do
		local r = racers[o.Id]
		send(r.Player, "Standing", {
			Place = place,
			Of = #order,
			Progress = r.Progress / built.Layout.Length,
			Time = now - startAt,
			EndsIn = endAt - now,
		})
	end
end

-- Something broke: send everyone back to the lobby and get ready for the next race.
abort = function()
	for _, r in racers do
		if not r.Left then
			pcall(release, r)
		end
	end
	racers = {}
	ctx.TrackBuilder.Clear()
	built = nil
	phase = "Idle"
	ctx.WorldService.SetPortalText("Stand here to race!")
end

function RaceService.Init(c)
	ctx = c
	Util = c.Util
end

function RaceService.Start()
	Players.PlayerRemoving:Connect(function(p)
		local r = racerOf(p)
		if r then
			r.Left = true
		end
	end)
	Util.Connect("LeaveRace", 1, function(p)
		local r = racerOf(p)
		if r and phase == "Racing" and not r.Finished then
			r.Left = true
			release(r)
			Util.Notify(p, "You left the race.", "Info")
		end
	end)
	while true do
		task.wait(0.1)
		if phase == "Idle" or phase == "Queue" then
			local q = queued()
			if #q < Config.Race.MinPlayers then
				if phase == "Queue" then
					phase = "Idle"
					ctx.WorldService.SetPortalText("Stand here to race!")
				end
			else
				if phase == "Idle" then
					phase = "Queue"
					queueEnds = os.clock() + Config.Race.QueueTime
				end
				if #q >= Config.Race.MaxPlayers then
					queueEnds = math.min(queueEnds, os.clock() + 3)
				end
				local left = math.max(0, math.ceil(queueEnds - os.clock()))
				ctx.WorldService.SetPortalText(string.format("Race in %d... (%d/%d)", left, #q, Config.Race.MaxPlayers))
				local sig = left * 100 + #q
				if sig ~= lastQueueSig then
					lastQueueSig = sig
					for _, p in q do
						send(p, "Queue", { In = left, Count = #q })
					end
				end
				if os.clock() >= queueEnds then
					local ok, err = pcall(startRace, q)
					if not ok then
						warn("[Race] start failed: " .. tostring(err))
						abort()
					end
				end
			end
		elseif phase == "Racing" then
			local ok, err = pcall(function()
				raceTick()
				if phase == "Racing" then
					standings()
				end
			end)
			if not ok then
				warn("[Race] race loop error: " .. tostring(err))
				abort()
			end
		end
	end
end

function RaceService.Phase(): string
	return phase
end

return RaceService
