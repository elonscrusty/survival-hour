--!nonstrict
-- Spawning, deaths, free respawns, paid revives, elimination and spectating state.
-- Rules live in Shared/Logic/LivesRules (unit-tested); this service drives timers,
-- characters and replication.
--
-- Player attributes (replicated): LifeState, FreeRespawns, PaidRevives,
-- WindowEnds (server time), ReviveTier, ReviveLockBy (userId), ProtectedUntil.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Products = require(Shared:WaitForChild("Products"))
local Logic = Shared:WaitForChild("Logic")
local LivesRules = require(Logic:WaitForChild("LivesRules"))
local ProfileRules = require(Logic:WaitForChild("ProfileRules"))

local LivesService = {}

local ctx: any
local lives: { [number]: LivesRules.Life } = {} -- userId -> life (match participants)
local lastDamage: { [Player]: { Kind: string, By: Player?, Name: string?, Time: number } } = {}
local spawnIndex: { [number]: number } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

function LivesService.Init(c)
	ctx = c
	ctx.Util.OnPlayerAdded(function(p: Player)
		p:SetAttribute("LifeState", "Lobby")
		p.CharacterAdded:Connect(function(char)
			LivesService._setupCharacter(p, char)
		end)
		if ctx.Mode == "Lobby" then
			ctx.DataService.WaitFor(p, 30)
			if p.Parent and not p:GetAttribute("InMatch") then
				LivesService.SpawnInLobby(p)
			end
		end
	end)
	ctx.Util.OnPlayerRemoving(function(p: Player)
		local life = lives[p.UserId]
		if life and life.State ~= "Eliminated" then
			life.State = "Left"
		end
		lastDamage[p] = nil
	end)

	ctx.MatchService.On("MatchStarting", function()
		lives = {}
		spawnIndex = {}
	end)
	ctx.MatchService.On("PlayerJoinedMatch", function(p: Player)
		lives[p.UserId] = LivesRules.New(Config.Lives.FreeRespawns)
		LivesService._sync(p)
	end)
	ctx.MatchService.On("FireOut", LivesService._onFireOut)
	ctx.MatchService.On("PhaseChanged", LivesService._onPhase)
	ctx.MatchService.On("MatchCleanup", function()
		lives = {}
	end)

	ctx.Util.Connect("RequestRevive", "Purchase", LivesService._onRequestRevive)
	ctx.PurchaseService.OnGranted("Revive", LivesService._onReviveGranted)
end

function LivesService.Start()
	while true do
		task.wait(0.25)
		if ctx.MatchService.Active then
			local t = now()
			for uid, life in lives do
				if LivesRules.Tick(life, t) then
					local p = Players:GetPlayerByUserId(uid)
					if p then
						LivesService._sync(p)
						ctx.Util.Notify(p, "Revive window closed. You are eliminated — spectating.", "danger")
					end
					ctx.MatchService.CheckOutcome()
				elseif life.PurchaseLockUntil and t >= life.PurchaseLockUntil then
					life.PurchaseLockBy = nil
					life.PurchaseLockUntil = nil
					local p = Players:GetPlayerByUserId(uid)
					if p then
						LivesService._sync(p)
					end
				end
			end
		end
	end
end

function LivesService.GetLife(p: Player): LivesRules.Life?
	return lives[p.UserId]
end

function LivesService.TeamLives(team: number): { LivesRules.Life }
	local out = {}
	for uid, life in lives do
		if ctx.MatchService.Roster[uid] == team then
			table.insert(out, life)
		end
	end
	return out
end

function LivesService._sync(p: Player)
	local life = lives[p.UserId]
	if not life then
		return
	end
	p:SetAttribute("LifeState", life.State)
	-- -1 = unlimited while the fire burns (attributes can't carry math.huge reliably)
	p:SetAttribute("FreeRespawns", if LivesRules.Unlimited(life) then -1 else life.FreeRespawns)
	p:SetAttribute("Deaths", life.Deaths)
	p:SetAttribute("PaidRevives", life.PaidRevives)
	p:SetAttribute("WindowEnds", life.WindowEndsAt or 0)
	p:SetAttribute("ReviveTier", LivesRules.ReviveTier(life, Config.Lives.MaxReviveTier))
	p:SetAttribute("ReviveLockBy", life.PurchaseLockBy or 0)
end

-- Spawning ---------------------------------------------------------------------------------

function LivesService._setupCharacter(p: Player, char: Model)
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hum then
		return
	end
	hum.MaxHealth = Config.Player.MaxHealth
	hum.Health = Config.Player.MaxHealth
	hum.BreakJointsOnDeath = false
	hum.NameDisplayDistance = 60
	hum.MaxSlopeAngle = 55 -- grounded: no scrambling up near-vertical cliffs
	hum.HealthDisplayDistance = 0
	for _, part in char:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Characters"
		end
	end
	char.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			d.CollisionGroup = "Characters"
		end
	end)
	hum.Died:Connect(function()
		LivesService._onDied(p, char)
	end)
end

-- LoadCharacterAsync replaces the deprecated LoadCharacter; fall back if unavailable.
function LivesService._load(p: Player)
	local ok = pcall(function()
		(p :: any):LoadCharacterAsync()
	end)
	if not ok and p.Parent then
		p:LoadCharacter()
	end
end

local function protect(p: Player, seconds: number?)
	local untilT = now() + (seconds or Config.Lives.SpawnProtection)
	local prev = p:GetAttribute("ProtectedUntil")
	p:SetAttribute("ProtectedUntil", math.max(untilT, if type(prev) == "number" then prev else 0))
end

-- Sunrise (from Day 2): everyone alive at that moment is invincible for a short
-- time and can't deal damage (CombatService / BuildService check IsProtected).
function LivesService._onPhase(phase: string, day: number)
	if phase ~= "Day" or day < 2 then
		return
	end
	for uid, life in lives do
		local p = Players:GetPlayerByUserId(uid)
		if p and life.State == "Alive" and ctx.Util.IsAlive(p) then
			protect(p, Config.Match.SunriseProtection)
			ctx.Util.Notify(p, string.format("Sunrise! You're protected for %d s, and can't deal damage.", Config.Match.SunriseProtection), "info")
		end
	end
end

function LivesService.SpawnInLobby(p: Player)
	if not p.Parent then
		return
	end
	p:SetAttribute("LifeState", "Lobby")
	LivesService._load(p)
	local char = p.Character
	if char then
		local spawnCF = ctx.WorldService.LobbySpawn * CFrame.new(math.random(-6, 6), 0, math.random(-4, 4))
		char:PivotTo(spawnCF)
	end
	ctx.InventoryService.OnSpawn(p)
	ctx.PowerupService.OnSpawn(p)
end

function LivesService.SpawnAtCamp(p: Player)
	if not p.Parent or not p:GetAttribute("InMatch") then
		return
	end
	local team = ctx.Util.Team(p)
	local camp = ctx.CampService.GetCamp(team)
	local life = lives[p.UserId]
	if not camp or not life then
		return
	end
	life.State = "Alive"
	LivesService._sync(p)
	LivesService._load(p)
	local char = p.Character
	if not char then
		return
	end
	spawnIndex[team] = ((spawnIndex[team] or 0) % #camp.SpawnPads) + 1
	local pad = camp.SpawnPads[spawnIndex[team]]
	char:PivotTo(CFrame.lookAt(pad.Position, camp.FirePos + Vector3.new(0, 3.5, 0)))
	protect(p)
	ctx.StaminaService.OnSpawn(p)
	ctx.InventoryService.OnSpawn(p)
	ctx.PowerupService.OnSpawn(p)
	ctx.MatchService.CheckOutcome()
end

-- Damage bookkeeping ---------------------------------------------------------------------------

function LivesService.RecordDamage(victim: Player, kind: string, by: Player?, name: string?)
	lastDamage[victim] = { Kind = kind, By = by, Name = name, Time = os.clock() }
end

function LivesService.IsProtected(p: Player): boolean
	local t = p:GetAttribute("ProtectedUntil") :: number?
	return t ~= nil and now() < t
end

-- Death -----------------------------------------------------------------------------------------

function LivesService._onDied(p: Player, char: Model)
	if not p:GetAttribute("InMatch") or not ctx.MatchService.Active then
		task.delay(2, function()
			if p.Parent and p.Character == char and not p:GetAttribute("InMatch") then
				LivesService.SpawnInLobby(p)
			end
		end)
		return
	end
	local life = lives[p.UserId]
	if not life or life.State ~= "Alive" then
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local pos = if root then root.Position else nil

	-- Cause (only damage in the last 10 s counts as the killer)
	local dmg = lastDamage[p]
	local cause, killer = "Environment", nil
	if dmg and os.clock() - dmg.Time < 10 then
		cause = dmg.Kind
		killer = dmg.By
	end
	lastDamage[p] = nil

	ctx.ChannelService.CancelFor(p, "You died")
	if pos then
		ctx.InventoryService.DropOnDeath(p, pos)
	end

	local team = ctx.Util.Team(p)
	local burning = ctx.MatchService.FireBurning(team)
	local action = LivesRules.OnDeath(life, burning, now(), Config.Lives.ReviveWindow)
	LivesService._sync(p)

	ctx.MatchService.Broadcast("Death", {
		Victim = p.DisplayName,
		VictimTeam = team,
		Killer = if killer then killer.DisplayName else nil,
		KillerTeam = if killer then ctx.Util.Team(killer) else nil,
		KillerId = if killer then killer.UserId else nil,
		Cause = if cause == "Animal" and dmg then (dmg.Name or "Animal") else cause,
		Eliminated = action == "Eliminate",
	})
	if killer and killer ~= p then
		ctx.PowerupService.OnPlayerKill(killer, p, action == "Eliminate")
	end

	if action == "Respawn" then
		local delay = LivesRules.RespawnDelay(life, Config.Lives.RespawnDelays)
		p:SetAttribute("RespawnAt", now() + delay)
		Net.FireClient("MatchEvent", p, "Died", { Respawn = delay, Left = if LivesRules.Unlimited(life) then -1 else life.FreeRespawns, Cause = cause, Killer = if killer then killer.DisplayName else nil })
		task.delay(delay, function()
			if p.Parent and life.State == "Respawning" and ctx.MatchService.Active and ctx.MatchService.FireBurning(team) then
				LivesService.SpawnAtCamp(p)
			end
		end)
	elseif action == "ReviveWindow" then
		Net.FireClient("MatchEvent", p, "Died", { ReviveWindow = Config.Lives.ReviveWindow, Tier = LivesRules.ReviveTier(life, Config.Lives.MaxReviveTier), Cause = cause, Killer = if killer then killer.DisplayName else nil })
		for _, mate in ctx.Util.TeamPlayers(team) do
			if mate ~= p then
				Net.FireClient("MatchEvent", mate, "TeammateNeedsRevive", { UserId = p.UserId, Name = p.DisplayName, Ends = life.WindowEndsAt })
			end
		end
		-- A stored credit of a sufficient tier is used automatically (D8).
		LivesService._tryCredit(p, p)
	else
		Net.FireClient("MatchEvent", p, "Eliminated", { Cause = cause, Killer = if killer then killer.DisplayName else nil })
	end
	ctx.MatchService.CheckOutcome()
end

function LivesService._onFireOut(team: number)
	for uid, life in lives do
		if ctx.MatchService.Roster[uid] == team then
			if LivesRules.OnFireOut(life) then
				local p = Players:GetPlayerByUserId(uid)
				if p then
					LivesService._sync(p)
					Net.FireClient("MatchEvent", p, "Eliminated", { Cause = "FireOut" })
				end
			end
		end
	end
	for _, p in ctx.Util.TeamPlayers(team) do
		LivesService._sync(p)
	end
end

-- Revives -----------------------------------------------------------------------------------

-- Uses a revive credit from `payer`'s profile for `target` if one covers the tier.
function LivesService._tryCredit(payer: Player, target: Player): boolean
	local life = lives[target.UserId]
	local session = ctx.DataService.Get(payer)
	if not life or not session or not ctx.DataService.CanGrant(payer) then
		return false
	end
	local tier = LivesRules.ReviveTier(life, Config.Lives.MaxReviveTier)
	local creditTier = LivesRules.FindCredit(session.Profile.Credits.Revive, tier, Config.Lives.MaxReviveTier)
	if not creditTier then
		return false
	end
	local team = ctx.Util.Team(target)
	if not LivesRules.CanStartRevive(life, ctx.MatchService.FireBurning(team), now(), payer.UserId) then
		return false
	end
	if not ProfileRules.ConsumeReviveCredit(session.Profile, creditTier) then
		return false
	end
	if LivesRules.ApplyRevive(life, creditTier, ctx.MatchService.FireBurning(team), now(), Config.Lives.MaxReviveTier) then
		task.spawn(ctx.DataService.Save, payer, false)
		ctx.DataService.Push(payer)
		LivesService._revived(target, payer, true)
		return true
	end
	-- Could not apply: give the credit back.
	session.Profile.Credits.Revive[tostring(creditTier)] = (session.Profile.Credits.Revive[tostring(creditTier)] or 0) + 1
	return false
end

function LivesService._revived(target: Player, payer: Player, fromCredit: boolean)
	LivesService._sync(target)
	local msg = if payer == target then target.DisplayName .. " revived" else payer.DisplayName .. " revived " .. target.DisplayName
	ctx.Util.NotifyTeam(ctx.Util.Team(target), msg .. (if fromCredit then " (used a revive credit)" else "") .. "!", "success")
	task.delay(1, function()
		if target.Parent and lives[target.UserId] and lives[target.UserId].State == "Respawning" then
			LivesService.SpawnAtCamp(target)
		end
	end)
end

function LivesService._onRequestRevive(payer: Player, targetUserId: any)
	if not ctx.Util.IsInt(targetUserId) or not payer:GetAttribute("InMatch") then
		return
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or not target:GetAttribute("InMatch") or ctx.Util.Team(target) ~= ctx.Util.Team(payer) then
		ctx.Util.Notify(payer, "You can only revive yourself or a teammate.", "error")
		return
	end
	local life = lives[target.UserId]
	if not life then
		return
	end
	local team = ctx.Util.Team(target)
	local ok, why = LivesRules.CanStartRevive(life, ctx.MatchService.FireBurning(team), now(), payer.UserId)
	if not ok then
		ctx.Util.Notify(payer, why or "Can't revive right now.", "error")
		return
	end
	if not ctx.PurchaseService.GiftAllowed(payer, target) then
		ctx.Util.Notify(payer, "Regional pricing prevents paying for this teammate's revive.", "error")
		return
	end
	if LivesService._tryCredit(payer, target) then
		return
	end
	local tier = LivesRules.ReviveTier(life, Config.Lives.MaxReviveTier)
	LivesRules.Lock(life, payer.UserId, now(), Config.Lives.PurchaseLockTime)
	LivesService._sync(target)
	if payer ~= target then
		ctx.Util.Notify(target, payer.DisplayName .. " is buying your revive...", "info")
	end
	local started, reason = ctx.PurchaseService.Prompt(payer, Products.ReviveKey(tier), {
		Target = target.UserId,
		Tier = tier,
		MatchId = ctx.MatchService.MatchId,
	}, function()
		LivesRules.Unlock(life, payer.UserId)
		LivesService._sync(target)
	end)
	if not started then
		LivesRules.Unlock(life, payer.UserId)
		LivesService._sync(target)
		ctx.Util.Notify(payer, reason or "Purchase unavailable.", "error")
	end
end

-- Called after a revive receipt was durably credited to `buyer`.
function LivesService._onReviveGranted(buyer: Player, product: any, data: { [string]: any }?)
	local targetId = if data and data.Target then data.Target else buyer.UserId
	local target = Players:GetPlayerByUserId(targetId)
	local sameMatch = data ~= nil and data.MatchId == ctx.MatchService.MatchId and ctx.MatchService.Active
	if target and sameMatch and LivesService._tryCredit(buyer, target) then
		return
	end
	ctx.Util.Notify(buyer, string.format("Your revive (tier %d) couldn't be used right now, so it was saved as a Revive Credit. It will be used automatically next time.", product.Tier or 1), "info")
end

return LivesService
