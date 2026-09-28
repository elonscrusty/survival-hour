--!nonstrict
-- Classes + power-ups (Shared/Classes, Shared/Perks) and in-match XP / Coin
-- rewards (Shared/Progression, Logic/ProfileRules).
--
-- The equipped class and power-up are read from the profile when the player
-- joins a match and are LOCKED for that match (changed only in the lobby).
-- Every effect is a sidegrade exposed through the multiplier hooks below, which
-- other services already call; nothing here adds raw damage or health.
--
-- Rewards are granted live (so leaving early keeps what you earned) and summed
-- per match for the end screen. Anti-farm: repeat kills on the same victim and
-- wildlife kills are capped per match; nothing is granted in under-filled live
-- matches (Studio always counts).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Classes = require(Shared:WaitForChild("Classes"))
local Perks = require(Shared:WaitForChild("Perks"))
local Progression = require(Shared:WaitForChild("Progression"))
local ProfileRules = require(Shared:WaitForChild("Logic"):WaitForChild("ProfileRules"))

local PowerupService = {}

local KILL_REWARDS_PER_VICTIM = 2
local WILDLIFE_REWARDS_PER_MATCH = 25
local POI_RADIUS = 34
local SENSE_INTERVAL = 3
local TRACK_RADIUS = 70
local BLOOD_DELAY = 4 -- seconds before a blood trail point becomes visible (no live tracking)
local BLOOD_LIFE = 20
local HURT_CUE_RADIUS = 60
local SECOND_WIND_HP = 25
local SECOND_WIND_TIME = 5
local SECOND_WIND_SPEED = 0.2

local PREDATORS = { Wolf = true, Bear = true, Boar = true }

type PState = {
	Class: string,
	Perk: string?,
	Effects: { [string]: number },
	Earned: { XP: number, Coins: number, Diamonds: number, Levels: number, Lines: { [string]: number } },
	KillsOn: { [number]: number },
	WildlifeRewards: number,
	Stats: { [string]: number }, -- per-match tallies for the recap (Kills, Animals, Bears, Chests, Resources, DamageDealt, DamageTaken, FiresOut, Breaches)
	Notoriety: number, -- aggressive actions this match (Dangerous Survivor callouts)
	FinalLife: boolean?, -- was on Final Life at some point this match
	Story: { string }, -- chronicle lines for the end screen (only things that happened)
	Told: { [string]: boolean }, -- one-off story keys already used
	NightAttack: string?, -- predator that hurt this player during the current night
	Pois: { [number]: boolean },
	SecondWindUsed: boolean,
	SecondWindUntil: number,
	LastSense: number,
}

local ctx: any
local states: { [Player]: PState } = {}
local blood: { { Pos: Vector3, At: number, UserId: number } } = {}
local workbenchRewarded: { [number]: boolean } = {}
local trophies: { [number]: { [string]: number } } = {} -- camp trophies placed per team/kind
local fights: { [string]: { [number]: number } } = {} -- kills between each pair (rivalries)

-- Camp trophies (CampService.AddTrophy): at most `cap` of a kind per team per match.
local TROPHY_CAP = { Bear = 2, Wolf = 1, Raid = 1, Explorer = 1 }
local function trophy(p: Player, kind: string)
	local team = ctx.Util.Team(p)
	local t = trophies[team] or {}
	trophies[team] = t
	if (t[kind] or 0) < (TROPHY_CAP[kind] or 1) then
		t[kind] = (t[kind] or 0) + 1
		ctx.CampService.AddTrophy(team, kind)
	end
end


local function now(): number
	return workspace:GetServerTimeNow()
end

local function eff(p: Player, key: string): number
	local st = states[p]
	return if st then st.Effects[key] or 0 else 0
end

local function merge(into: { [string]: number }, from: { [string]: number })
	for k, v in from do
		into[k] = (into[k] or 0) + v
	end
end

function PowerupService.Init(c)
	ctx = c
	ctx.MatchService.On("PlayerJoinedMatch", PowerupService._lock)
	ctx.MatchService.On("MatchCleanup", function()
		states = {}
		blood = {}
		workbenchRewarded = {}
		trophies = {}
		fights = {}
	end)
	ctx.MatchService.On("PhaseChanged", function(phase: string, day: number)
		-- Surviving a night: everyone still alive at sunrise (Day 2 onwards).
		if phase == "Day" and day > 1 then
			for p in states do
				if p.Parent and ctx.Util.IsAlive(p) then
					local st = states[p]
					if st and st.NightAttack then
						PowerupService.Tell(p, "Survived Night " .. (day - 1) .. " after a " .. string.lower(st.NightAttack) .. " attack.")
					elseif day == 2 then
						PowerupService.Tell(p, "Survived your first night.")
					end
					if st then
						st.NightAttack = nil
					end
					PowerupService.Reward(p, "SurviveNight", "Survived night " .. (day - 1))
					PowerupService.Tally(p, "Nights", 1)
					ctx.Util.AwardBadge(p, "FirstNight")
				end
			end
		end
	end)
	-- Final Life: anyone alive on a team whose fire goes out (Untouchable badge check)
	ctx.MatchService.On("FireOut", function(team: number, byPlayer: Player?)
		for p, st in states do
			if p.Parent and ctx.Util.Team(p) == team then
				st.FinalLife = true
				PowerupService.Tell(p, "Your Campfire was put out" .. (if byPlayer then " by " .. byPlayer.DisplayName else "") .. ". Final Life.")
			end
		end
	end)
	ctx.Util.OnPlayerRemoving(function(p)
		states[p] = nil
	end)
	-- Retired active abilities: tell clients there is none.
	ctx.Util.Connect("UseAbility", "Default", function() end)
end

-- Reads (and locks) class + power-up for this match.
function PowerupService._lock(p: Player)
	local session = ctx.DataService.Get(p)
	local profile = session and session.Profile
	local classId = if profile and Classes.ById[profile.Class] and profile.OwnedClasses[profile.Class] then profile.Class else Classes.Default
	local perkId = if profile and profile.Perk and Perks.ById[profile.Perk] and profile.OwnedPerks[profile.Perk] then profile.Perk else nil
	local effects = {}
	merge(effects, Classes.ById[classId].Effects)
	if perkId then
		merge(effects, Perks.ById[perkId].Effects)
	end
	states[p] = {
		Class = classId,
		Perk = perkId,
		Effects = effects,
		Earned = { XP = 0, Coins = 0, Diamonds = 0, Levels = 0, Lines = {} },
		KillsOn = {},
		WildlifeRewards = 0,
		Stats = { Kills = 0, Eliminations = 0, Animals = 0, Bears = 0, Chests = 0, Resources = 0, DamageDealt = 0, DamageTaken = 0, FiresOut = 0, Breaches = 0 },
		Notoriety = 0,
		Story = {},
		Told = {},
		Pois = {},
		SecondWindUsed = false,
		SecondWindUntil = 0,
		LastSense = 0,
	}
	PowerupService._sync(p)
end

function PowerupService.Start()
	while true do
		task.wait(0.25)
		if ctx.MatchService.Active then
			PowerupService._tick()
		end
	end
end

function PowerupService._tick()
	local map = ctx.MatchService.Map
	local t = now()
	for p, st in states do
		local hum = ctx.Util.Humanoid(p)
		local root = ctx.Util.Root(p)
		if hum and root and hum.Health > 0 then
			-- Movement speed (brush slowdown; Hunter moves through it more easily)
			local speed = Config.Player.WalkSpeed
			if map then
				for _, b in map.Brush do
					if Vector3.new(root.Position.X - b.Pos.X, 0, root.Position.Z - b.Pos.Z).Magnitude < b.R then
						speed *= if (st.Effects.QuietBrush or 0) > 0 then 0.92 else 0.82
						break
					end
				end
			end
			if t < st.SecondWindUntil then
				speed *= 1 + SECOND_WIND_SPEED
			end
			local want = if ctx.BuildService.IsHeld(p) then 0 else speed * ctx.StaminaService.SpeedMult(p) * (if ctx.ChannelService.IsBusy(p, "Heal") then Config.Healing.MoveSlow else 1)
			-- ease speed changes (sprint builds up over ~0.5 s, stopping is quicker); traps snap to 0
			local cur = hum.WalkSpeed
			if want == 0 or math.abs(want - cur) < 0.5 then
				hum.WalkSpeed = want
			else
				hum.WalkSpeed = cur + (want - cur) * (if want > cur then 0.55 else 0.8)
			end
			-- Second Wind (automatic, once per life)
			if (st.Effects.SecondWind or 0) > 0 and not st.SecondWindUsed and hum.Health < SECOND_WIND_HP then
				st.SecondWindUsed = true
				st.SecondWindUntil = t + SECOND_WIND_TIME
				ctx.StaminaService.Refill(p, math.huge)
				p:SetAttribute("Bursting", st.SecondWindUntil)
				ctx.Util.Notify(p, "Second Wind! Stamina refilled.", "success")
			end
			-- In a cave (Miner sight; client lighting reads this)
			local inCave = false
			if map then
				for _, cave in map.Caves or {} do
					local l = cave.CF:PointToObjectSpace(root.Position)
					if l.Z > 0 and l.Z < cave.Length + 4 and math.abs(l.X) < cave.Width / 2 + 2 and root.Position.Y < cave.FloorY + 16 then
						inCave = true
						break
					end
				end
				-- POI discovery
				for i, poi in map.Pois or {} do
					if not st.Pois[i] and (poi.Pos - root.Position).Magnitude <= POI_RADIUS then
						st.Pois[i] = true
						PowerupService.Reward(p, "PoiDiscovered", "Discovered a " .. poi.Type)
						if poi.Tier == "Rare" or poi.Tier == "Uncommon" then
							PowerupService.Tell(p, "Discovered the " .. string.lower((string.gsub(poi.Type, "(%l)(%u)", "%1 %2"))) .. ".", "poi" .. poi.Type)
						end
						local found = 0
						for _ in st.Pois do
							found += 1
						end
						if found == 5 then
							trophy(p, "Explorer")
						end
					end
				end
			end
			if p:GetAttribute("InCave") ~= inCave then
				p:SetAttribute("InCave", inCave)
			end
			-- Periodic senses
			if t - st.LastSense >= SENSE_INTERVAL then
				st.LastSense = t
				PowerupService._sense(p, st, root.Position)
			end
			-- Blood trail sample for Trackers (injured players only)
			if hum.Health < hum.MaxHealth * 0.6 and math.random() < 0.25 then
				table.insert(blood, { Pos = root.Position, At = t, UserId = p.UserId })
			end
		end
	end
	for i = #blood, 1, -1 do
		if t - blood[i].At > BLOOD_LIFE then
			table.remove(blood, i)
		end
	end
end

function PowerupService._sense(p: Player, st: PState, pos: Vector3)
	local fx = st.Effects
	if (fx.TrackWildlife or 0) > 0 then
		local list = {}
		for _, a in ctx.WildlifeService.List() do
			if (a.Root.Position - pos).Magnitude <= TRACK_RADIUS then
				table.insert(list, { Species = a.Species, Pos = a.Root.Position })
			end
		end
		if #list > 0 then
			Net.FireClient("Reveal", p, "Animals", list, SENSE_INTERVAL + 0.5)
		end
	end
	if (fx.ContainerSense or 0) > 0 then
		local list = ctx.LootService.CratesNear(pos, fx.ContainerSense)
		for _, c in ctx.LootService.ChestsNear(pos, fx.ContainerSense) do
			table.insert(list, c)
		end
		if #list > 0 then
			Net.FireClient("Reveal", p, "Crates", list, SENSE_INTERVAL + 0.5)
		end
	end
	if (fx.BloodTrails or 0) > 0 then
		local t = now()
		local list = {}
		for _, b in blood do
			if b.UserId ~= p.UserId and t - b.At >= BLOOD_DELAY and (b.Pos - pos).Magnitude <= TRACK_RADIUS then
				table.insert(list, b.Pos)
			end
		end
		if #list > 0 then
			Net.FireClient("Reveal", p, "Blood", list, SENSE_INTERVAL + 0.5)
		end
	end
end

function PowerupService._sync(p: Player)
	local st = states[p]
	p:SetAttribute("Class", if st then st.Class else nil)
	p:SetAttribute("Perk", if st then st.Perk else nil)
	p:SetAttribute("DrawMult", PowerupService.DrawMult(p))
	p:SetAttribute("ClimbBonus", 0)
	-- There are no active abilities in Survival Wars.
	Net.FireClient("AbilitySync", p, { Id = false })
end

function PowerupService.OnSpawn(p: Player)
	local st = states[p]
	if st then
		st.SecondWindUsed = false
		st.SecondWindUntil = 0
		PowerupService._sync(p)
	else
		p:SetAttribute("ClimbBonus", 0)
		local hum = ctx.Util.Humanoid(p)
		if hum then
			hum.WalkSpeed = Config.Player.WalkSpeed
		end
	end
end

function PowerupService.ClassOf(p: Player): string?
	local st = states[p]
	return st and st.Class
end

function PowerupService.PerkOf(p: Player): string?
	local st = states[p]
	return st and st.Perk
end

-- Multipliers used by other services ------------------------------------------------------------

-- Chop/mine power multiplier for a tool class ("Axe" | "Pickaxe"). Never changes yields.
function PowerupService.ToolSpeedMult(p: Player, toolType: string): number
	return 1 + (if toolType == "Axe" then eff(p, "AxeSpeed") elseif toolType == "Pickaxe" then eff(p, "PickSpeed") else 0)
end

-- Durability lost per successful tool hit (1 = one hit).
function PowerupService.ToolWear(p: Player, toolType: string): number
	local w = 1 + eff(p, "ToolWear") + (if toolType == "Axe" then eff(p, "AxeWear") elseif toolType == "Pickaxe" then eff(p, "PickWear") else 0)
	return math.max(0.3, w)
end

function PowerupService.WildlifeDamageMult(p: Player): number
	return math.max(0.5, 1 + eff(p, "WildlifeDamage"))
end

function PowerupService.ExtraHide(p: Player): number
	return eff(p, "ExtraHide")
end

function PowerupService.SearchSpeedMult(p: Player): number
	return 1 + eff(p, "SearchSpeed")
end

function PowerupService.ExtraLootChance(p: Player): number
	return eff(p, "ExtraLoot")
end

function PowerupService.BreachSpeedMult(p: Player): number
	return 1 + eff(p, "BreachSpeed")
end

-- Durability multiplier for breaching tools (Raider: tools last longer).
function PowerupService.BreachWear(p: Player): number
	return math.max(0.3, 1 + eff(p, "BreachWear"))
end

-- Radius multiplier for the breach "raid noise" heard by nearby enemies.
function PowerupService.BreachNoiseMult(p: Player): number
	return if eff(p, "QuietBreach") > 0 then 0.5 else 1
end

function PowerupService.BonusSlots(p: Player): number
	return eff(p, "BonusSlots")
end

function PowerupService.HealSpeedMult(p: Player): number
	return 1 + eff(p, "HealSpeed")
end

function PowerupService.StaminaMaxMult(p: Player): number
	return 1 + eff(p, "StaminaMax")
end

function PowerupService.StaminaRegenMult(p: Player): number
	return 1 + eff(p, "StaminaRegen")
end

function PowerupService.SprintMult(p: Player): number
	return 1 + eff(p, "SprintSpeed")
end

function PowerupService.FireFuelMult(p: Player): number
	return 1 + eff(p, "FireFuel")
end

function PowerupService.CraftSpeedMult(p: Player): number
	return 1 + eff(p, "CraftSpeed")
end

-- Bow draw time multiplier (Hunter: faster draw).
function PowerupService.DrawMult(p: Player): number
	return 1 - eff(p, "DrawSpeed")
end

-- Retired multipliers (kept so callers stay simple): no class changes these.
function PowerupService.GatherMult(_p: Player): number
	return 1
end

function PowerupService.DamageMult(_p: Player, _kind: string): number
	return 1
end

function PowerupService.RepairMult(_p: Player): number
	return 1
end

function PowerupService.SpreadMult(_p: Player): number
	return 1
end

function PowerupService.ConsumeFreeRepair(_p: Player): boolean
	return false
end

-- Rewards ----------------------------------------------------------------------------------------

local function rewardsEnabled(): boolean
	if ctx.IsStudio then
		return true
	end
	local n = 0
	for _ in ctx.MatchService.Participants do
		n += 1
	end
	return n >= Config.Match.MinPlayers
end

-- Grants the XP / Coins for `key` (Progression.XP / Progression.Coins) to `p`.
function PowerupService.Reward(p: Player, key: string, line: string?)
	local xp = Progression.XP[key] or 0
	local coins = Progression.Coins[key] or 0
	PowerupService.Grant(p, xp, coins, 0, line or key)
end

function PowerupService.Grant(p: Player, xp: number, coins: number, diamonds: number, line: string)
	local st = states[p]
	local session = ctx.DataService.Get(p)
	if not session or not ctx.DataService.CanGrant(p) or not rewardsEnabled() or (xp <= 0 and coins <= 0 and diamonds <= 0) then
		return
	end
	local res = ProfileRules.AddXP(session.Profile, xp)
	ProfileRules.AddCoins(session.Profile, coins)
	session.Profile.Diamonds += diamonds
	if st then
		st.Earned.XP += xp
		st.Earned.Coins += coins + res.Coins
		st.Earned.Diamonds += diamonds + res.Diamonds
		st.Earned.Levels += res.Levels
		st.Earned.Lines[line] = (st.Earned.Lines[line] or 0) + xp
	end
	Net.FireClient("MatchEvent", p, "Reward", { XP = xp, Coins = coins, Line = line })
	if res.Levels > 0 then
		local extra = {}
		if res.Coins > 0 then
			table.insert(extra, "+" .. res.Coins .. " Coins")
		end
		if res.Diamonds > 0 then
			table.insert(extra, "+" .. res.Diamonds .. " ◆")
		end
		if #res.Cosmetics > 0 then
			table.insert(extra, "new title / nameplate unlocked")
		end
		ctx.Util.Notify(p, "LEVEL " .. res.NewLevel .. "!" .. (if #extra > 0 then "  " .. table.concat(extra, " · ") else ""), "success")
		ctx.DataService.Push(p)
	end
end

-- Totals earned this match (for the end screen).
function PowerupService.Earned(p: Player): { XP: number, Coins: number, Diamonds: number, Levels: number, Lines: { [string]: number } }?
	local st = states[p]
	return st and st.Earned
end

-- Per-match tallies for the end screen (counted even when rewards are off).
function PowerupService.Stats(p: Player): { [string]: number }?
	local st = states[p]
	if not st then
		return nil
	end
	local out = table.clone(st.Stats)
	local pois = 0
	for _ in st.Pois do
		pois += 1
	end
	out.Pois = pois
	return out
end

-- Chronicle: "Day 2 — Discovered the ranger station." Only real server events are written.
-- `key` makes a line one-off (first axe, first wolf...). Capped so the recap stays readable.
local STORY_MAX = 14
function PowerupService.Tell(p: Player?, text: string, key: string?)
	local st = p and states[p]
	if not st then
		return
	end
	if key then
		if st.Told[key] then
			return
		end
		st.Told[key] = true
	end
	if #st.Story >= STORY_MAX then
		table.remove(st.Story, 2) -- keep the first line, drop the oldest middle one
	end
	local M = ctx.MatchService
	local stamp = if M.Phase == "Night" then "Night " .. M.Day elseif M.Phase == "Day" then "Day " .. M.Day else "Dawn"
	table.insert(st.Story, stamp .. " — " .. text)
end

function PowerupService.Story(p: Player): { string }
	local st = states[p]
	return if st then table.clone(st.Story) else {}
end

-- Close call: a line when a player wins a fight on almost no health.
local function closeCall(p: Player): string?
	local hum = ctx.Util.Humanoid(p)
	if hum and hum.Health > 0 and hum.Health <= hum.MaxHealth * 0.15 then
		return string.format(" with only %d HP left", math.ceil(hum.Health))
	end
	return nil
end

-- Rivalries: two players who keep killing each other get a RIVALRY tag in the feed (story only).
function PowerupService.RecordFight(killer: Player, victim: Player): boolean
	local a, b = math.min(killer.UserId, victim.UserId), math.max(killer.UserId, victim.UserId)
	local key = a .. ":" .. b
	local f = fights[key] or {}
	fights[key] = f
	f[killer.UserId] = (f[killer.UserId] or 0) + 1
	local ka, kb = f[a] or 0, f[b] or 0
	local rival = (ka >= 1 and kb >= 1) or ka + kb >= 3
	if rival then
		PowerupService.Tell(killer, "Your rivalry with " .. victim.DisplayName .. " grew.", "rival" .. victim.UserId)
		PowerupService.Tell(victim, "Your rivalry with " .. killer.DisplayName .. " grew.", "rival" .. killer.UserId)
	end
	return rival
end

function PowerupService.Tally(p: Player?, key: string, n: number)
	local st = p and states[p]
	if st and n > 0 then
		st.Stats[key] = (st.Stats[key] or 0) + n
		if key == "Breaches" then
			trophy(p :: Player, "Raid")
		end
	end
end

-- Share of POIs any player has visited this match (Match Director input).
function PowerupService.PoisExploredShare(): number
	local map = ctx.MatchService.Map
	local total = map and map.Pois and #map.Pois or 0
	if total == 0 then
		return 0
	end
	local seen = {}
	for _, st in states do
		for i in st.Pois do
			seen[i] = true
		end
	end
	local n = 0
	for _ in seen do
		n += 1
	end
	return n / total
end

-- Last chronicle line: how it ended.
function PowerupService.TellResult(p: Player, place: number?)
	local st = states[p]
	if place == 1 then
		PowerupService.Tell(p, if st and st.FinalLife then "VICTORY — on Final Life." else "VICTORY.")
	elseif place then
		PowerupService.Tell(p, "Finished " .. (({ "1st", "2nd", "3rd" })[place] or (tostring(place) .. "th")) .. ".")
	end
end

-- End of match: fold this match's tallies into lifetime stats, keep the win streak and award
-- the win badges. Called once per participant with a loaded profile (MatchService.End).
local LIFETIME = { "Animals", "Bears", "Predators", "Chests", "Resources", "DamageDealt", "FiresOut", "Breaches", "Nights", "Crafts", "BenchUpgrades" }
function PowerupService.CommitMatch(p: Player, profile: any, place: number?, fireBurning: boolean)
	local st = states[p]
	if st then
		for _, k in LIFETIME do
			local v = st.Stats[k] or 0
			if v > 0 then
				profile.Stats[k] = (profile.Stats[k] or 0) + v
			end
		end
		local pois = 0
		for _ in st.Pois do
			pois += 1
		end
		profile.Stats.Pois = (profile.Stats.Pois or 0) + pois
		if profile.Stats.Pois >= Config.ExplorerBadgePlaces then
			ctx.Util.AwardBadge(p, "Explorer")
		end
	end
	if place == 1 then
		profile.Stats.WinStreak = (profile.Stats.WinStreak or 0) + 1
		profile.Stats.BestStreak = math.max(profile.Stats.BestStreak or 0, profile.Stats.WinStreak)
		ctx.Util.AwardBadge(p, "Survivor")
		if st and not st.FinalLife and fireBurning then
			ctx.Util.AwardBadge(p, "Untouchable")
		end
		if not fireBurning then
			ctx.Util.AwardBadge(p, "FinalStand")
		end
	else
		profile.Stats.WinStreak = 0
	end
end

-- Dangerous Survivor: kills, eliminations and snuffed fires build notoriety. At each
-- threshold everyone hears the name (never a position), once per threshold per match.
local NOTORIETY = { { At = 3, Line = "has taken down several survivors." }, { At = 6, Line = "is hunting everyone. Watch your fire." } }
local function addNotoriety(p: Player, n: number)
	local st = states[p]
	if not st then
		return
	end
	local before = st.Notoriety
	st.Notoriety += n
	for _, t in NOTORIETY do
		if before < t.At and st.Notoriety >= t.At then
			ctx.MatchService.Broadcast("Dangerous", { Name = p.DisplayName, UserId = p.UserId, Line = t.Line, Level = t.At })
		end
	end
end

-- Hooks from other services ----------------------------------------------------------------------

function PowerupService.OnPlayerKill(killer: Player, victim: Player, eliminated: boolean?)
	local st = states[killer]
	if not st then
		return
	end
	st.Stats.Kills += 1
	ctx.Util.AwardBadge(killer, "FirstBlood")
	local close = closeCall(killer)
	local finalLife = if st.FinalLife then " while on Final Life" else ""
	PowerupService.Tell(killer, (if eliminated then "Eliminated " else "Took down ") .. victim.DisplayName .. finalLife .. (close or "") .. ".")
	PowerupService.Tell(victim, (if eliminated then "Eliminated by " else "Taken down by ") .. killer.DisplayName .. ".")
	if eliminated then
		st.Stats.Eliminations += 1
	end
	addNotoriety(killer, if eliminated then 2 else 1)
	local n = st.KillsOn[victim.UserId] or 0
	st.KillsOn[victim.UserId] = n + 1
	local session = ctx.DataService.Get(killer)
	if session and ctx.DataService.CanGrant(killer) then
		session.Profile.Kills += 1
		if eliminated then
			session.Profile.Eliminations += 1
		end
	end
	if eliminated then
		PowerupService.Reward(killer, "Elimination", "Eliminated " .. victim.DisplayName)
		ctx.CosmeticService.OnElimination(killer, victim)
	elseif n < KILL_REWARDS_PER_VICTIM then
		PowerupService.Reward(killer, "Kill", "Kills")
	end
end

function PowerupService.OnFireExtinguished(p: Player)
	PowerupService.Tally(p, "FiresOut", 1)
	addNotoriety(p, 2)
	PowerupService.Tell(p, "Put out an enemy Campfire.")
	ctx.Util.AwardBadge(p, "FireExtinguisher")
	PowerupService.Reward(p, "ExtinguishFire", "Snuffed a fire")
end

function PowerupService.OnWildlifeKill(p: Player, species: string, _night: boolean)
	local st = states[p]
	if st then
		st.Stats.Animals += 1
		if species == "Bear" then
			st.Stats.Bears += 1
			ctx.Util.AwardBadge(p, "BearHunter")
			trophy(p, "Bear")
			PowerupService.Tell(p, "Brought down a bear" .. (closeCall(p) or "") .. ".")
		elseif species == "Wolf" then
			trophy(p, "Wolf")
			local close = closeCall(p)
			if close then
				PowerupService.Tell(p, "Killed a wolf" .. close .. ".")
			else
				PowerupService.Tell(p, "Killed your first wolf.", "wolf")
			end
		end
		if PREDATORS[species] then
			st.Stats.Predators = (st.Stats.Predators or 0) + 1
		end
	end
	if not st or st.WildlifeRewards >= WILDLIFE_REWARDS_PER_MATCH then
		return
	end
	st.WildlifeRewards += 1
	PowerupService.Reward(p, if PREDATORS[species] then "Predator" else "Wildlife", "Hunting")
end

-- Hurt by anything: remembers a night-time predator attack for the chronicle.
function PowerupService.NoteHurt(victim: Player, kind: string?, name: string?)
	local st = states[victim]
	if st and kind == "Animal" and ctx.MatchService.IsNight() then
		st.NightAttack = name or "wildlife"
	end
end

-- Any death (the chronicle's line for deaths not caused by a player).
function PowerupService.OnDeath(p: Player, cause: string?, byPlayer: boolean, eliminated: boolean)
	if byPlayer then
		return -- OnPlayerKill tells this one
	end
	local what = if cause == "Animal" then "wildlife" elseif cause == "FireOut" then "the dark" else string.lower(tostring(cause or "the forest"))
	PowerupService.Tell(p, (if eliminated then "Eliminated by " else "Killed by ") .. what .. ".")
end

function PowerupService.OnChestOpened(p: Player, tier: string, _poi: string?)
	if _poi == "Cache" then
		PowerupService.Tell(p, "Found a lost survivor's cache.")
	elseif tier == "Rare" or tier == "VeryRare" then
		PowerupService.Tell(p, "Opened a " .. (if tier == "VeryRare" then "very rare" else "rare") .. " chest.", "chest" .. tier)
	end
	local st = states[p]
	if st then
		st.Stats.Chests += 1
	end
	PowerupService.Reward(p, if tier == "Rare" or tier == "VeryRare" then "RareChest" else "Chest", "Chests")
end

-- Workbench V: once per camp per match, to the player who finished it.
function PowerupService.OnWorkbenchLevel(p: Player, team: number, level: number)
	PowerupService.Tally(p, "BenchUpgrades", 1)
	if level == 3 or level == 5 then
		PowerupService.Tell(p, "Raised your Workbench to Tier " .. ({ "I", "II", "III", "IV", "V" })[level] .. ".")
	end
	if level >= 5 then
		ctx.Util.AwardBadge(p, "MasterCrafter")
	end
	if level >= 5 and not workbenchRewarded[team] then
		workbenchRewarded[team] = true
		PowerupService.Reward(p, "WorkbenchV", "Workbench Tier V")
	end
end

-- Tracker: directional cue when a nearby player is hurt (direction only, no position).
function PowerupService.OnPlayerHurt(victim: Player, _amount: number)
	local vroot = ctx.Util.Root(victim)
	if not vroot then
		return
	end
	for p, st in states do
		if p ~= victim and (st.Effects.HurtCues or 0) > 0 then
			local root = ctx.Util.Root(p)
			if root then
				local d = (vroot.Position - root.Position) * Vector3.new(1, 0, 1)
				if d.Magnitude > 4 and d.Magnitude <= HURT_CUE_RADIUS then
					Net.FireClient("MatchEvent", p, "HurtCue", { Bearing = math.deg(math.atan2(d.X, -d.Z)) % 360 })
				end
			end
		end
	end
end

-- Legacy hooks (no longer reward anything on their own).
function PowerupService.OnAnimalKilled(_p: Player, _animalId: number) end
function PowerupService.OnCrateOpened(_p: Player, _crateId: number) end
function PowerupService.OnRepair(_p: Player, _amount: number) end
function PowerupService.OnArrowHit(_p: Player, _victim: Player, _distance: number) end
function PowerupService.OnPickup(_p: Player, _id: string) end

-- Unused but kept for the end-of-match push.
function PowerupService.PushAll()
	for _, p in Players:GetPlayers() do
		if states[p] then
			ctx.DataService.Push(p)
		end
	end
end

return PowerupService
