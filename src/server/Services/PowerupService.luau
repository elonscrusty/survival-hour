--!nonstrict
-- Permanent powerups: passives, active abilities with cooldowns, and
-- anti-farm challenge tracking (Shared/Logic/ChallengeRules).
--
-- The equipped powerup is read from the profile when the match starts and
-- can't change mid-match (it can only be changed in the lobby).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Powerups = require(Shared:WaitForChild("Powerups"))
local Logic = Shared:WaitForChild("Logic")
local ChallengeRules = require(Logic:WaitForChild("ChallengeRules"))
local ProfileRules = require(Logic:WaitForChild("ProfileRules"))

local PowerupService = {}

type PState = {
	Id: string?,
	Level: number,
	CooldownEnds: number,
	ActiveUntil: number,
	FreeRepairs: number,
	FreeRepairUntil: number,
	MarkReadyAt: number,
	Tracker: ChallengeRules.Tracker,
	LastPos: Vector3?,
	LastSample: number,
}

local ctx: any
local states: { [Player]: PState } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function level(p: Player): (string?, number, any)
	local st = states[p]
	if not st or not st.Id then
		return nil, 0, nil
	end
	local def = Powerups.ById[st.Id]
	return st.Id, st.Level, def and def.Levels[st.Level]
end

function PowerupService.Init(c)
	ctx = c
	ctx.MatchService.On("PlayerJoinedMatch", function(p: Player)
		local session = ctx.DataService.Get(p)
		local id = session and session.Profile.Equipped
		local lvl = if id and session then session.Profile.Owned[id] or 0 else 0
		states[p] = {
			Id = if lvl > 0 then id else nil,
			Level = lvl,
			CooldownEnds = 0,
			ActiveUntil = 0,
			FreeRepairs = 0,
			FreeRepairUntil = 0,
			MarkReadyAt = 0,
			Tracker = ChallengeRules.NewTracker(),
			LastPos = nil,
			LastSample = os.clock(),
		}
		PowerupService._sync(p)
	end)
	ctx.MatchService.On("MatchCleanup", function()
		for p in states do
			if p.Parent then
				p:SetAttribute("Bursting", nil)
			end
		end
		states = {}
	end)
	ctx.MatchService.On("MatchEnded", function()
		for p in states do
			if p.Parent then
				ctx.DataService.Push(p)
			end
		end
	end)
	ctx.Util.OnPlayerRemoving(function(p)
		states[p] = nil
	end)
	ctx.Util.Connect("UseAbility", "Default", PowerupService._onUse)
end

function PowerupService.Start()
	-- Movement: passives, brush slowdown, burst, climb bonus and distance challenge.
	while true do
		task.wait(0.25)
		if ctx.MatchService.Active then
			local map = ctx.MatchService.Map
			for p, st in states do
				local hum = ctx.Util.Humanoid(p)
				local root = ctx.Util.Root(p)
				if hum and root and hum.Health > 0 then
					local speed = Config.Player.WalkSpeed
					local _, _, lv = level(p)
					if st.Id == "Trailblazer" and lv then
						speed *= 1 + lv.Passive.SpeedPct / 100
					end
					local bursting = st.Id == "Trailblazer" and now() < st.ActiveUntil
					if bursting and lv then
						speed *= 1 + lv.Ability.BurstPct / 100
					elseif map then
						for _, b in map.Brush do
							if Vector3.new(root.Position.X - b.Pos.X, 0, root.Position.Z - b.Pos.Z).Magnitude < b.R then
								speed *= 0.82
								break
							end
						end
					end
					hum.WalkSpeed = if ctx.BuildService.IsHeld(p) then 0 else speed * ctx.StaminaService.SpeedMult(p) * (if ctx.ChannelService.IsBusy(p, "Heal") then Config.Healing.MoveSlow else 1)
					-- Distance challenge (sampled once per second)
					local t = os.clock()
					if t - st.LastSample >= 1 then
						local dt = t - st.LastSample
						st.LastSample = t
						local pos = root.Position
						if st.LastPos and ctx.Util.IsAlive(p) then
							local d = Vector3.new(pos.X - st.LastPos.X, 0, pos.Z - st.LastPos.Z).Magnitude
							PowerupService._stat(p, "DistanceTravelled", math.floor(d), nil, dt)
						end
						st.LastPos = pos
					end
				elseif st then
					st.LastPos = nil
				end
			end
		end
	end
end

function PowerupService._sync(p: Player)
	local st = states[p]
	if not st then
		return
	end
	local id, lvl, lv = level(p)
	p:SetAttribute("Powerup", id or "")
	p:SetAttribute("PowerupLevel", lvl)
	p:SetAttribute("ClimbBonus", if id == "Climber" and lv then lv.Passive.ClimbPct / 100 else 0)
	Net.FireClient("AbilitySync", p, {
		Id = id or false,
		Level = lvl,
		CooldownEnds = st.CooldownEnds,
		ActiveUntil = st.ActiveUntil,
		FreeRepairs = st.FreeRepairs,
	})
end

function PowerupService.OnSpawn(p: Player)
	if states[p] then
		states[p].LastPos = nil
		PowerupService._sync(p)
	else
		p:SetAttribute("ClimbBonus", 0)
		local hum = ctx.Util.Humanoid(p)
		if hum then
			hum.WalkSpeed = Config.Player.WalkSpeed
		end
	end
end

-- Multipliers used by other services ------------------------------------------------------------

-- Chop/mine power multiplier for a tool class ("Axe" | "Pickaxe"). Classes (Phase 6) hook in here.
function PowerupService.ToolSpeedMult(p: Player, toolType: string): number
	return 1
end

-- Storage breaching speed (Raider class).
function PowerupService.BreachSpeedMult(p: Player): number
	return 1
end

-- Extra pack slots (Strong Back power-up, Scavenger class).
function PowerupService.BonusSlots(p: Player): number
	return 0
end

function PowerupService.HealSpeedMult(p: Player): number
	return 1
end

function PowerupService.StaminaMaxMult(p: Player): number
	return 1
end

function PowerupService.StaminaRegenMult(p: Player): number
	return 1
end

function PowerupService.SprintMult(p: Player): number
	return 1
end

-- Durability lost per successful tool hit (1 = one hit). Classes/power-ups reduce it.
function PowerupService.ToolWear(p: Player, toolType: string): number
	return 1
end

function PowerupService.GatherMult(p: Player): number
	local id, _, lv = level(p)
	return if id == "Scavenger" and lv then 1 + lv.Passive.GatherPct / 100 else 1
end

function PowerupService.DamageMult(p: Player, kind: string): number
	local id, _, lv = level(p)
	if kind == "Animal" and id == "Hunter" and lv then
		return 1 + lv.Passive.AnimalDmgPct / 100
	end
	return 1
end

function PowerupService.RepairMult(p: Player): number
	local id, _, lv = level(p)
	return if id == "Craftsman" and lv then 1 + lv.Passive.RepairPct / 100 else 1
end

function PowerupService.SpreadMult(p: Player): number
	local id, _, lv = level(p)
	return if id == "Sharpshooter" and lv then 1 - lv.Passive.SpreadPct / 100 else 1
end

function PowerupService.DrawMult(p: Player): number
	local id, _, lv = level(p)
	return if id == "Sharpshooter" and lv then 1 - lv.Passive.DrawPct / 100 else 1
end

function PowerupService.ConsumeFreeRepair(p: Player): boolean
	local st = states[p]
	if st and st.FreeRepairs > 0 and now() < st.FreeRepairUntil then
		st.FreeRepairs -= 1
		PowerupService._sync(p)
		return true
	end
	return false
end

-- Abilities -----------------------------------------------------------------------------------------

function PowerupService._onUse(p: Player)
	local st = states[p]
	local id, _, lv = level(p)
	if not st or not id or not lv or not ctx.Util.IsAlive(p) or not ctx.MatchService.IsPlaying() then
		return
	end
	local t = now()
	if t < st.CooldownEnds then
		return
	end
	local ab = lv.Ability
	local root = ctx.Util.Root(p) :: BasePart
	local used = false
	if id == "Trailblazer" then
		st.ActiveUntil = t + ab.Duration
		p:SetAttribute("Bursting", st.ActiveUntil)
		used = true
	elseif id == "Scavenger" then
		local list = ctx.LootService.CratesNear(root.Position, ab.Radius)
		Net.FireClient("Reveal", p, "Crates", list, ab.Duration)
		ctx.Util.Notify(p, if #list > 0 then string.format("You sniff out %d crate%s nearby.", #list, if #list > 1 then "s" else "") else "No crates nearby.", "info")
		used = true
	elseif id == "Hunter" then
		if not ctx.MatchService.IsNight() then
			ctx.Util.Notify(p, "Tracking only works at night.", "warn")
			return
		end
		local list = {}
		for _, a in ctx.WildlifeService.List() do
			if (a.Root.Position - root.Position).Magnitude <= ab.Radius then
				table.insert(list, { Id = a.Id, Species = a.Species, Pos = a.Root.Position })
			end
		end
		Net.FireClient("Reveal", p, "Animals", list, ab.Duration)
		used = true
	elseif id == "Climber" then
		used = PowerupService._scramble(p, root, ab.MaxHeight)
		if not used then
			return
		end
	elseif id == "Craftsman" then
		st.FreeRepairs = ab.FreeSwings
		st.FreeRepairUntil = t + 20
		ctx.Util.Notify(p, string.format("Thrifty Repair: next %d repair swings are free (20s).", ab.FreeSwings), "success")
		used = true
	elseif id == "Sharpshooter" then
		ctx.Util.Notify(p, "Mark triggers automatically when your arrows hit an enemy.", "info")
		return
	end
	if used then
		st.CooldownEnds = t + ab.Cooldown
		local char = p.Character
		if char then
			char:SetAttribute("Action", "Ability")
			char:SetAttribute("ActionAt", t)
			char:SetAttribute("ActionItem", id)
		end
		Net.FireAll("Fx", "Ability", { Player = p, Id = id, Pos = root.Position })
		PowerupService._sync(p)
	end
end

-- Climber: vault over the wall directly ahead if it's short enough and the
-- far side is clear.
function PowerupService._scramble(p: Player, root: BasePart, maxHeight: number): boolean
	local char = p.Character :: Model
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	params.IgnoreWater = true
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	local hit = workspace:Raycast(root.Position, look * 6, params)
	if not hit or hit.Instance == workspace.Terrain then
		ctx.Util.Notify(p, "Face a wall to scramble over it.", "warn")
		return false
	end
	local groundY = ctx.WorldService.GroundY(root.Position.X, root.Position.Z)
	-- Find the top of the obstacle by probing downward from above.
	local top: number? = nil
	for h = maxHeight + 1, 1, -1 do
		local probeFrom = Vector3.new(hit.Position.X, groundY + h, hit.Position.Z) - look * 1
		local r = workspace:Raycast(probeFrom, look * 3, params)
		if not r then
			top = groundY + h
		else
			break
		end
	end
	local wallTop = workspace:Raycast(Vector3.new(hit.Position.X, groundY + maxHeight + 3, hit.Position.Z) + look * 0.5, Vector3.new(0, -(maxHeight + 4), 0), params)
	if not top or (wallTop and wallTop.Position.Y > groundY + maxHeight) then
		ctx.Util.Notify(p, "That's too tall to scramble over.", "warn")
		return false
	end
	-- Landing: far side of the obstacle
	local landing: Vector3? = nil
	for dist = 3, 8 do
		local probe = hit.Position + look * dist
		local gy = ctx.WorldService.GroundY(probe.X, probe.Z)
		local spot = Vector3.new(probe.X, gy + 3, probe.Z)
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Exclude
		overlap.FilterDescendantsInstances = { char, workspace.Terrain }
		local blockers = workspace:GetPartBoundsInBox(CFrame.new(spot), Vector3.new(2.5, 5, 2.5), overlap)
		local solid = false
		for _, b in blockers do
			if b.CanCollide then
				solid = true
				break
			end
		end
		if not solid then
			landing = spot
			break
		end
	end
	if not landing then
		ctx.Util.Notify(p, "No room to land on the other side.", "warn")
		return false
	end
	local s = ctx.BuildService.FromPart(hit.Instance)
	if s and s.Team ~= ctx.Util.Team(p) then
		PowerupService._stat(p, "EnemyWallsScaled", 1, s.Key)
	end
	-- Short arc over the wall (server-driven, replicated)
	local startPos = root.Position
	local peakY = math.max(startPos.Y, (top or startPos.Y)) + 3
	local rot = root.CFrame.Rotation
	task.spawn(function()
		for i = 1, 8 do
			local t = i / 8
			local pos = startPos:Lerp(landing :: Vector3, t)
			local y = pos.Y + math.sin(t * math.pi) * (peakY - math.min(startPos.Y, (landing :: Vector3).Y))
			if char.Parent then
				char:PivotTo(CFrame.new(pos.X, y, pos.Z) * rot)
			end
			task.wait(0.04)
		end
	end)
	return true
end

-- Hooks from other services ----------------------------------------------------------------------

-- Only matches with a real lobby (or Studio test sessions) count toward challenges.
local function challengesEnabled(): boolean
	if ctx.IsStudio then
		return true
	end
	local n = 0
	for _ in ctx.MatchService.Participants do
		n += 1
	end
	return n >= Config.Match.MinPlayers
end

function PowerupService._stat(p: Player, stat: string, amount: number, target: string?, dt: number?)
	local st = states[p]
	local session = ctx.DataService.Get(p)
	if not st or not session or not ctx.DataService.CanGrant(p) or not challengesEnabled() then
		return
	end
	if not ChallengeRules.StatRelevant(session.Profile.Owned, stat) then
		return
	end
	local accepted = ChallengeRules.Accept(st.Tracker, stat, amount, target, dt)
	if accepted > 0 then
		ProfileRules.AddStat(session.Profile, stat, accepted)
	end
end

function PowerupService.OnAnimalKilled(p: Player, animalId: number)
	PowerupService._stat(p, "AnimalsKilled", 1, tostring(animalId))
end

function PowerupService.OnCrateOpened(p: Player, crateId: number)
	PowerupService._stat(p, "CratesOpened", 1, tostring(crateId))
end

function PowerupService.OnRepair(p: Player, amount: number)
	PowerupService._stat(p, "HealthRepaired", math.floor(amount))
end

function PowerupService.OnArrowHit(p: Player, victim: Player, distance: number)
	if distance >= 40 then
		PowerupService._stat(p, "LongArrowHits", 1, tostring(victim.UserId))
	end
	local st = states[p]
	local id, _, lv = level(p)
	if st and id == "Sharpshooter" and lv and now() >= st.MarkReadyAt then
		st.MarkReadyAt = now() + lv.Ability.Cooldown
		victim:SetAttribute("MarkedTeam", ctx.Util.Team(p))
		victim:SetAttribute("MarkedUntil", now() + lv.Ability.Duration)
		ctx.Util.NotifyTeam(ctx.Util.Team(p), p.DisplayName .. " marked " .. victim.DisplayName .. "!", "info")
		st.CooldownEnds = st.MarkReadyAt
		PowerupService._sync(p)
	end
end

function PowerupService.OnPlayerKill(_killer: Player, _victim: Player) end
function PowerupService.OnPickup(_p: Player, _id: string) end
function PowerupService.OnFireExtinguished(_p: Player) end


return PowerupService
