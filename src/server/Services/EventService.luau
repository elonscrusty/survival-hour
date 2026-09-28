--!nonstrict
-- World events and match conditions.
--
-- Every match rolls one subtle condition (Logic/MatchEvents) that nudges event odds, rain,
-- wildlife pacing or predator aggression, and is announced at the start. During play an
-- occasional event breaks the rhythm: a thunderstorm, heavy fog, a wolf surge at night, a
-- migrating herd by day, or a hidden survivor's cache found by clues rather than a waypoint.
-- Events never overlap, never start in the first minutes of Day 1, and are followed by a quiet
-- gap so the forest has calm stretches. Nothing here changes campfire, lives or combat rules.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local MatchEvents = require(Shared:WaitForChild("Logic"):WaitForChild("MatchEvents"))
local Build = require(Shared:WaitForChild("Models"):WaitForChild("Build"))
local Director = require(Shared:WaitForChild("Logic"):WaitForChild("Director"))

local EventService = {}

local E = Config.Events
local ctx: any
local rng = Random.new()
local roll = function()
	return rng:NextNumber()
end

local condition: MatchEvents.Condition? = nil
local active: { Kind: string, Ends: number, Cleanup: (() -> ())? }? = nil
local nextRoll = math.huge -- os.clock() when the next event may start
local lastKind: string? = nil
local held: string? = nil -- weather an event is holding (Storm / Fog)
local phaseWeather = "Clear"
local cacheFolder: Folder? = nil
local bonusCaches = 0
-- Match Director inputs (activity clocks) and its current plan
local lastAction = os.clock() -- PvP hit, raid, snuff or elimination
local lastWildlife = -math.huge
local eventStarts: { number } = {}
local lastOpportunity = -math.huge
local plan: Director.Plan? = nil
local cacheFocus: string? = nil
local firstDay: number? = nil -- os.clock() when Day 1 began

local function state(): Instance
	return ctx.MatchService.State
end

-- Clamp a flat point into the playable map.
local function inMap(x: number, z: number, margin: number): Vector3
	local map = ctx.MatchService.Map
	local H = map.Layout.HalfSize - margin
	x = math.clamp(x, map.Origin.X - H, map.Origin.X + H)
	z = math.clamp(z, map.Origin.Z - H, map.Origin.Z + H)
	return Vector3.new(x, ctx.WorldService.GroundY(x, z), z)
end

local function nearCamp(pos: Vector3, extra: number): boolean
	for team = 1, Config.Match.TeamCount do
		local camp = ctx.CampService.GetCamp(team)
		if camp and (camp.FirePos - pos).Magnitude < Config.Build.ZoneRadius + extra then
			return true
		end
	end
	return false
end

-- A random living player out in the world (not sitting in their fire light).
local function focusPlayer(): (Player?, Vector3?)
	local list = {}
	for _, p in ctx.Util.MatchPlayers() do
		local r = ctx.Util.Root(p)
		if r and ctx.Util.IsAlive(p) then
			table.insert(list, { p, r.Position })
		end
	end
	if #list == 0 then
		return nil, nil
	end
	local pick = list[rng:NextInteger(1, #list)]
	return pick[1], pick[2]
end

-- Tells every match player where something is, as a compass word from where they stand.
local function announceBearing(kind: string, title: string, sub: string, at: Vector3)
	for _, p in ctx.Util.MatchPlayers() do
		local r = ctx.Util.Root(p)
		local dir = if r then MatchEvents.Compass(at.X - r.Position.X, at.Z - r.Position.Z) else "distance"
		Net.FireClient("MatchEvent", p, "WorldEvent", { Kind = kind, Stage = "Start", Title = title, Sub = string.gsub(sub, "{dir}", dir) })
	end
end

local function broadcast(kind: string, stage: string, title: string?, sub: string?)
	ctx.MatchService.Broadcast("WorldEvent", { Kind = kind, Stage = stage, Title = title, Sub = sub })
end

-- Weather -------------------------------------------------------------------------------------------------

function EventService.PhaseWeather(day: number): string
	phaseWeather = MatchEvents.BaseWeather(day, Config.Lighting.RainChance, condition, roll)
	return held or phaseWeather
end

local function holdWeather(w: string?)
	held = w
	ctx.WorldService.SetWeather(w or phaseWeather)
end

-- Match Director --------------------------------------------------------------------------------------------

-- Other services report what just happened (no positions are kept or shared).
function EventService.Note(kind: string)
	if kind == "Wildlife" then
		lastWildlife = os.clock()
	else
		lastAction = os.clock()
	end
end

local function livingPositions(): { Vector3 }
	local out = {}
	for _, p in ctx.Util.MatchPlayers() do
		local r = ctx.Util.Root(p)
		if r and ctx.Util.IsAlive(p) then
			table.insert(out, r.Position)
		end
	end
	return out
end

function EventService._snapshot(): Director.Snapshot
	local now = os.clock()
	local recent = 0
	for _, t in eventStarts do
		if now - t < 600 then
			recent += 1
		end
	end
	local map = ctx.MatchService.Map
	local remaining = state():GetAttribute("Remaining")
	return {
		MatchAge = now - (firstDay or now),
		Night = ctx.MatchService.IsNight(),
		Remaining = if type(remaining) == "number" then remaining else #ctx.MatchService.StartedTeams,
		Started = #ctx.MatchService.StartedTeams,
		Spread = Director.Spread(livingPositions(), if map then map.Layout.HalfSize * 2 else 1),
		QuietFor = now - lastAction,
		SinceWildlifeFight = now - lastWildlife,
		RecentEvents = recent,
		PoisExplored = ctx.PowerupService.PoisExploredShare(),
	}
end

function EventService._replan()
	local p = Director.Plan(EventService._snapshot())
	plan = p
	state():SetAttribute("DirectorReason", p.Reason)
	local now = os.clock()
	-- a long lull pulls the next roll forward instead of waiting out the whole gap
	if not active and p.GapMult < 1 and nextRoll ~= math.huge and nextRoll - now > 45 then
		nextRoll = now + 45
	end
	-- late-game standoff by day: one extra contested supply drop (at most every 6 minutes)
	if p.Opportunity and now - lastOpportunity > 360 then
		lastOpportunity = now
		ctx.LootService.QueueFree()
	end
end

-- Hooks read by other services ------------------------------------------------------------------------------

function EventService.WildlifeIntervalMult(): number
	return (condition and condition.WildlifeInterval) or 1
end

function EventService.PredatorAggroMult(): number
	return (condition and condition.PredatorAggro) or 1
end

function EventService.Active(): string?
	return active and active.Kind
end

-- Events ------------------------------------------------------------------------------------------------------

local START: { [string]: (duration: number) -> ((() -> ())?, boolean) } = {}

START.Thunderstorm = function()
	holdWeather("Storm")
	broadcast("Thunderstorm", "Start", "⛈ THUNDERSTORM", "A storm rolls over the forest. Sight and sound won't carry far.")
	return function()
		holdWeather(nil)
		broadcast("Thunderstorm", "End", nil, "The storm passes.")
	end, true
end

START.Fog = function()
	holdWeather("Fog")
	broadcast("Fog", "Start", "🌫 FOG ROLLS IN", "You won't see far. Neither will they.")
	return function()
		holdWeather(nil)
		broadcast("Fog", "End", nil, "The fog lifts.")
	end, true
end

START.PredatorSurge = function(duration)
	local _, from = focusPlayer()
	if not from then
		return nil, false
	end
	local ang = rng:NextNumber() * math.pi * 2
	local centre = inMap(from.X + math.cos(ang) * rng:NextNumber(90, 130), from.Z + math.sin(ang) * rng:NextNumber(90, 130), 20)
	if nearCamp(centre, 25) then
		return nil, false
	end
	local n = ctx.WildlifeService.SpawnGroup("Wolf", centre, 2, E.SurgeRadius, E.SurgeWolves, nil)
	if n == 0 then
		return nil, false
	end
	state():SetAttribute("SurgePos", centre)
	state():SetAttribute("SurgeUntil", workspace:GetServerTimeNow() + duration)
	announceBearing("PredatorSurge", "🐺 THE WOLVES ARE RESTLESS", "Howling to the {dir}. Something is hunting out there.", centre)
	-- the rest of the pack arrives while the event runs
	task.delay(duration * 0.4, function()
		if active and active.Kind == "PredatorSurge" then
			ctx.WildlifeService.SpawnGroup("Wolf", centre, E.SurgeWolves - 1, E.SurgeRadius, E.SurgeWolves, nil)
		end
	end)
	return function()
		state():SetAttribute("SurgePos", nil)
		state():SetAttribute("SurgeUntil", nil)
		broadcast("PredatorSurge", "End", nil, "The howling fades.")
	end, true
end

START.Migration = function()
	local _, from = focusPlayer()
	if not from then
		return nil, false
	end
	local ang = rng:NextNumber() * math.pi * 2
	local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
	local side = Vector3.new(-dir.Z, 0, dir.X) * rng:NextNumber(-40, 40)
	local start = inMap(from.X + dir.X * 110 + side.X, from.Z + dir.Z * 110 + side.Z, 20)
	local goal = inMap(from.X - dir.X * 110 + side.X, from.Z - dir.Z * 110 + side.Z, 20)
	local herd = rng:NextInteger(E.MigrationHerd[1], E.MigrationHerd[2])
	local n = ctx.WildlifeService.SpawnGroup("Deer", start, herd, 10, herd, goal)
	if n == 0 then
		return nil, false
	end
	announceBearing("Migration", "🦌 MIGRATION", "A herd is moving through the woods to the {dir}.", start)
	return function()
		broadcast("Migration", "End", nil, nil)
	end, true
end

-- Survivor cache: an unlit chest somewhere off the paths, with a trail of dropped gear leading
-- to it and only a vague "near the ranger station" hint.
local function cacheSpot(): (Vector3?, string, Vector3?)
	local map = ctx.MatchService.Map
	-- the Director may ask for the cache between spread-out players or at the map centre
	local focus: Vector3? = nil
	if cacheFocus == "Centre" then
		focus = map.Origin
	elseif cacheFocus == "Between" then
		local pts = livingPositions()
		if #pts > 0 then
			local c = Vector3.zero
			for _, v in pts do
				c += v
			end
			focus = c / #pts
		end
	end
	for attempt = 1, 30 do
		local pos
		if focus and attempt <= 20 then
			local a, d = rng:NextNumber() * math.pi * 2, rng:NextNumber(10, 70)
			pos = inMap(focus.X + math.cos(a) * d, focus.Z + math.sin(a) * d, 30)
		else
			pos = inMap(map.Origin.X + rng:NextNumber(-1, 1) * map.Layout.HalfSize, map.Origin.Z + rng:NextNumber(-1, 1) * map.Layout.HalfSize, 30)
		end
		local ok = not nearCamp(pos, 45)
		for _, poi in map.Pois or {} do
			if (poi.Pos - pos).Magnitude < 22 then
				ok = false
			end
		end
		for _, w in map.WaterPoints or {} do
			if (w.Pos - pos).Magnitude < 18 then
				ok = false
			end
		end
		if ok then
			-- describe it by the nearest landmark within reach, else by map region
			local best, bestD = nil, 95
			for _, poi in map.Pois or {} do
				local d = (poi.Pos - pos).Magnitude
				if d < bestD then
					best, bestD = poi, d
				end
			end
			if best then
				local name = string.lower((string.gsub(best.Type, "(%l)(%u)", "%1 %2")))
				return pos, "near the " .. name, best.Pos
			end
			for _, cave in map.Caves or {} do
				if (cave.CF.Position - pos).Magnitude < 80 then
					return pos, "near a cave mouth", cave.CF.Position
				end
			end
			return pos, "in the " .. MatchEvents.Compass(pos.X - map.Origin.X, pos.Z - map.Origin.Z) .. "ern woods", nil
		end
	end
	return nil, "", nil
end

local CLUES = {
	{ Size = Vector3.new(1.4, 0.5, 1.0), Color = Color3.fromRGB(92, 70, 48), Mat = Enum.Material.Fabric }, -- torn pack
	{ Size = Vector3.new(0.5, 0.7, 0.5), Color = Color3.fromRGB(150, 150, 155), Mat = Enum.Material.Metal }, -- tin can
	{ Size = Vector3.new(1.6, 0.15, 0.9), Color = Color3.fromRGB(180, 170, 150), Mat = Enum.Material.Fabric }, -- rag
	{ Size = Vector3.new(0.3, 0.3, 2.2), Color = Color3.fromRGB(110, 84, 60), Mat = Enum.Material.Wood }, -- dropped stick
}

local function spawnCache(duration: number): ((() -> ())?, boolean)
	local pos, where, toward = cacheSpot()
	if not pos then
		return nil, false
	end
	local folder = cacheFolder
	if not folder then
		return nil, false
	end
	local key
	local found = false
	key = ctx.LootService.AddCache(CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber() * 6.28, 0), E.CacheTier, "Rare", function(p: Player)
		found = true
		ctx.MatchService.Broadcast("WorldEvent", { Kind = "SurvivorCache", Stage = "Found", Sub = "Someone found the survivor's cache." })
		if active and active.Kind == "SurvivorCache" then
			active.Ends = 0 -- end the event now
		end
		local _ = p
	end)
	if not key then
		return nil, false
	end
	-- trail of dropped gear leading from the landmark side toward the cache
	local dir = if toward then (toward - pos) * Vector3.new(1, 0, 1) else Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
	dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.new(1, 0, 0)
	local clueParts = {}
	for i = 1, E.CacheTrail do
		local off = dir * (6 + i * 8) + Vector3.new(-dir.Z, 0, dir.X) * rng:NextNumber(-3, 3)
		local c = CLUES[(i - 1) % #CLUES + 1]
		local x, z = pos.X + off.X, pos.Z + off.Z
		local y = ctx.WorldService.GroundY(x, z)
		local part = Build.Decor({ Name = "Clue", Size = c.Size, CFrame = CFrame.new(x, y + c.Size.Y / 2, z) * CFrame.Angles(0, rng:NextNumber() * 6.28, math.rad(rng:NextNumber(-12, 12))), Color = c.Color, Material = c.Mat, Parent = folder })
		table.insert(clueParts, part)
	end
	-- a torn backpack slumped against the cache
	table.insert(clueParts, Build.Decor({ Name = "Backpack", Size = Vector3.new(1.6, 2, 1), CFrame = CFrame.new(pos + Vector3.new(2.4, 1, 0.6)) * CFrame.Angles(0, 0.4, math.rad(18)), Color = Color3.fromRGB(70, 82, 60), Material = Enum.Material.Fabric, Parent = folder }))
	broadcast("SurvivorCache", "Start", "🎒 LOST CACHE", "A survivor hid supplies " .. where .. ". Look for dropped gear.")
	local _ = duration
	return function()
		for _, part in clueParts do
			part:Destroy()
		end
		if not found then
			ctx.LootService.RemoveCache(key)
			broadcast("SurvivorCache", "End", nil, "The survivor's cache was never found.")
		end
	end, true
end
START.SurvivorCache = spawnCache

-- Scheduler ---------------------------------------------------------------------------------------------------

local function blocked(): { [string]: boolean }
	local b = {}
	local day1 = ctx.MatchService.Day <= 1
	for k in E.Weights do
		if (day1 and E.NotOnDay1[k]) or k == lastKind then
			b[k] = true
		end
	end
	-- wolves are night animals; herds and caches are daytime stories
	if ctx.MatchService.IsNight() then
		b.Migration = true
		b.SurvivorCache = true
	else
		b.PredatorSurge = true
	end
	return b
end

function EventService._tryStart(kind: string?): boolean
	if not kind then
		local weights = {}
		for k, w in E.Weights do
			weights[k] = w * Director.Weight(k, plan)
		end
		kind = MatchEvents.PickEvent(weights, condition, blocked(), roll)
	end
	cacheFocus = plan and plan.CacheFocus or nil
	if not kind or not START[kind] then
		return false
	end
	local range = E.Duration[kind] or { 120, 120 }
	local duration = rng:NextNumber(range[1], range[2])
	local ok, cleanup, started = pcall(START[kind], duration)
	if not ok then
		warn("[Events] " .. kind .. " failed:", cleanup)
		return false
	end
	if not started then
		return false
	end
	active = { Kind = kind, Ends = os.clock() + duration, Cleanup = cleanup }
	table.insert(eventStarts, os.clock())
	lastKind = kind
	state():SetAttribute("Event", kind)
	return true
end

function EventService._stop()
	local a = active
	active = nil
	state():SetAttribute("Event", nil)
	if a and a.Cleanup then
		pcall(a.Cleanup)
	end
	nextRoll = os.clock() + rng:NextNumber(E.GapMin, E.GapMax) * (plan and plan.GapMult or 1)
end

-- Dev helper: force an event now (ends the current one first).
function EventService.Force(kind: string): boolean
	if active then
		EventService._stop()
	end
	return EventService._tryStart(kind)
end

function EventService.Init(c)
	ctx = c
	ctx.MatchService.On("MatchStarting", function(map)
		active, lastKind, held = nil, nil, nil
		nextRoll = math.huge
		lastAction, lastWildlife, lastOpportunity = os.clock(), -math.huge, -math.huge
		eventStarts, plan, cacheFocus, firstDay = {}, nil, nil, nil
		local f = Instance.new("Folder")
		f.Name = "Events"
		f.Parent = map.Folder
		cacheFolder = f
		condition = MatchEvents.PickCondition(E.ConditionChance, roll)
		bonusCaches = (condition and condition.BonusCaches) or 0
		state():SetAttribute("Condition", condition and condition.Name or nil)
	end)
	ctx.MatchService.On("PhaseChanged", function(phase: string, day: number)
		if phase == "Day" and day == 1 then
			nextRoll = os.clock() + E.FirstDelay
			firstDay = os.clock()
			lastAction = os.clock()
			if condition then
				local c = condition
				task.delay(4, function()
					broadcast("Condition", "Start", "MATCH CONDITION: " .. string.upper(c.Name), c.Line)
				end)
			end
		end
	end)
	ctx.MatchService.On("FireOut", function()
		EventService.Note("FireOut")
	end)
	ctx.MatchService.On("TeamEliminated", function()
		EventService.Note("Elimination")
	end)
	ctx.MatchService.On("MatchCleanup", function()
		if active and active.Cleanup then
			pcall(active.Cleanup)
		end
		active, condition, held = nil, nil, nil
		nextRoll = math.huge
		cacheFolder = nil
		ctx.WorldService.Weather = "Clear"
		state():SetAttribute("Event", nil)
		state():SetAttribute("Condition", nil)
		state():SetAttribute("SurgePos", nil)
		state():SetAttribute("SurgeUntil", nil)
	end)
end

function EventService.Start()
	local replanAcc = 0
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(function()
				if not ctx.MatchService.Active or not ctx.MatchService.IsPlaying() then
					return
				end
				local now = os.clock()
				replanAcc += 1
				if replanAcc >= 20 and firstDay then
					replanAcc = 0
					EventService._replan()
				end
				if active then
					if now >= active.Ends then
						EventService._stop()
					end
				elseif now >= nextRoll then
					-- the "Lost Survivors" condition guarantees extra caches before random picks
					local started
					if bonusCaches > 0 and not ctx.MatchService.IsNight() then
						bonusCaches -= 1
						started = EventService._tryStart("SurvivorCache")
					else
						started = rng:NextNumber() < E.Chance and EventService._tryStart(nil)
					end
					if not started then
						nextRoll = now + rng:NextNumber(E.GapMin, E.GapMax) * 0.5
					end
				end
			end)
			if not ok then
				warn("[Events] tick error:", err)
			end
		end
	end)
	local _ = Players
end

return EventService
