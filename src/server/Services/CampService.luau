--!nonstrict
-- Camps: campfires (fuel, levels, snuffing), workbench level + prompt, enemy camp
-- discovery, healing near your own fire, and fire-light queries for wildlife.
--
-- Fire rules live in Shared/Logic/FireRules (unit-tested). Replicated state:
--   MatchState.FireLevel<team>; owner player attributes FireFuel (0..1), FireLevel,
--   FireNeeds ("Wood 12 · Stone 4" toward the next level, "" when maxed).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Models = Shared:WaitForChild("Models")
local Camp = require(Models:WaitForChild("Camp"))
local Logic = Shared:WaitForChild("Logic")
local FireRules = require(Logic:WaitForChild("FireRules"))
local InventoryModel = require(Logic:WaitForChild("InventoryModel"))
local Items = require(Shared:WaitForChild("Items"))

local CampService = {}

local ctx: any
local camps: { [number]: any } = {}
local levels: { [number]: number } = {}
local revealed: { [number]: { [number]: boolean } } = {} -- team -> discovered camp teams
local lastAlert: { [number]: number } = {}
local lastHurt: { [Player]: number } = {}
local fires: { [number]: FireRules.Fire } = {}
local warned: { [number]: boolean } = {}
local FIRE = Config.Fire :: any

function CampService.Init(c)
	ctx = c
	ctx.MatchService.On("MatchStarting", CampService._setup)
	ctx.MatchService.On("FireOut", function(team: number)
		local camp = camps[team]
		if camp then
			Camp.Extinguish(camp.Fire)
			local prompt = camp.Fire:FindFirstChild("PourPrompt", true) :: ProximityPrompt?
			if prompt then
				prompt.Enabled = false
			end
			for _, name in { "FeedPrompt", "FireUpgradePrompt" } do
				local pr = camp.Fire:FindFirstChild(name, true) :: ProximityPrompt?
				if pr then
					pr.Enabled = false
				end
			end
			ctx.Util.PlaySound("FireOut", camp.Fire.PrimaryPart)
		end
		local fire = fires[team]
		if fire then
			fire.Out = true
			fire.Fuel = 0
			CampService._syncFire(team)
		end
	end)
	ctx.MatchService.On("MatchCleanup", function()
		camps = {}
		levels = {}
		revealed = {}
		fires = {}
		warned = {}
	end)
	ctx.ChannelService.OnPrompt("Feed", CampService._onFeed)
	ctx.ChannelService.OnPrompt("FireUpgrade", CampService._onFireUpgrade)
	ctx.MatchService.On("PlayerJoinedMatch", function(p: Player)
		task.delay(1, CampService.SendMapData, p)
	end)
	ctx.ChannelService.OnPrompt("Pour", CampService._onPour)
	ctx.ChannelService.OnPrompt("Workbench", function(player: Player, prompt: ProximityPrompt)
		local team = prompt:GetAttribute("Team")
		if team ~= ctx.Util.Team(player) or not ctx.Util.IsAlive(player) then
			return
		end
		ctx.CraftService.OpenFor(player)
	end)
end

function CampService.Start()
	-- Discovery, healing and fuel loops
	local tick = 0
	local last = os.clock()
	while true do
		task.wait(0.5)
		tick += 1
		local t = os.clock()
		local dt = t - last
		last = t
		if ctx.MatchService.Active and next(camps) then
			CampService._discover()
			if tick % 2 == 0 then
				CampService._heal()
			end
			local phase = ctx.MatchService.Phase
			if phase == "Day" or phase == "Night" then
				CampService._burn(dt)
			end
		end
	end
end

-- Fuel -------------------------------------------------------------------------------------

function CampService._burn(dt: number)
	for team, fire in fires do
		if not fire.Out and ctx.MatchService.FireBurning(team) then
			if FireRules.Burn(fire, dt, FIRE) then
				ctx.Util.NotifyTeam(team, "Your fire ran out of fuel and died. You're on your FINAL LIFE.", "danger")
				ctx.MatchService.ExtinguishFire(team, nil)
			else
				if fire.Fuel < FIRE.FuelWarning and not warned[team] then
					warned[team] = true
					ctx.Util.NotifyTeam(team, "Your fire is low on fuel! Add Wood before it dies for good.", "warn")
				elseif fire.Fuel >= FIRE.FuelWarning + 0.05 then
					warned[team] = false
				end
				CampService._syncFire(team)
			end
		end
	end
end

local function needsText(fire: FireRules.Fire): string
	local parts = {}
	for id, n in FireRules.Remaining(fire, FIRE) do
		local def = Items[id]
		table.insert(parts, string.format("%s %d", if def then def.Name else id, n))
	end
	table.sort(parts)
	return table.concat(parts, " · ")
end

function CampService._syncFire(team: number)
	local fire = fires[team]
	local camp = camps[team]
	if not fire or not camp then
		return
	end
	local fuel = math.floor(fire.Fuel * 200 + 0.5) / 200
	ctx.MatchService.State:SetAttribute("FireLevel" .. team, fire.Level)
	for _, p in ctx.Util.TeamPlayers(team) do
		p:SetAttribute("FireFuel", fuel)
		p:SetAttribute("FireLevel", fire.Level)
		p:SetAttribute("FireNeeds", needsText(fire))
	end
	if not fire.Out then
		Camp.SetFire(camp.Fire, fire.Level, fire.Fuel)
		local feed = camp.Fire:FindFirstChild("FeedPrompt", true) :: ProximityPrompt?
		if feed then
			feed.ObjectText = string.format("Campfire L%d · fuel %d%% (%s)", fire.Level, math.floor(fire.Fuel * 100 + 0.5), string.format("%d:%02d left", FireRules.SecondsLeft(fire, FIRE) // 60, math.floor(FireRules.SecondsLeft(fire, FIRE)) % 60))
		end
		local up = camp.Fire:FindFirstChild("FireUpgradePrompt", true) :: ProximityPrompt?
		if up then
			up.Enabled = FireRules.CanUpgrade(fire, FIRE)
			up.ActionText = "Upgrade Fire → L" .. (fire.Level + 1)
			up.ObjectText = "Needs " .. needsText(fire)
		end
	end
end

function CampService.GetFire(team: number): FireRules.Fire?
	return fires[team]
end

local function ownFire(player: Player, prompt: ProximityPrompt): (number?, FireRules.Fire?, any)
	local team = prompt:GetAttribute("Team") :: number
	if team ~= ctx.Util.Team(player) or not ctx.Util.IsAlive(player) or not ctx.MatchService.Active then
		return nil, nil, nil
	end
	local fire = fires[team]
	if not fire or fire.Out or not ctx.MatchService.FireBurning(team) then
		return nil, nil, nil
	end
	if ctx.Util.DistTo(player, camps[team].FirePos) > Config.Fire.PourRange + 1 then
		return nil, nil, nil
	end
	return team, fire, ctx.InventoryService.Get(player)
end

-- Adds as much Wood from the pack as the fire can take.
function CampService._onFeed(player: Player, prompt: ProximityPrompt)
	local team, fire, inv = ownFire(player, prompt)
	if not team or not fire or not inv then
		return
	end
	local have = inv.Resources.Wood or 0
	if have <= 0 then
		ctx.Util.Notify(player, "You have no Wood. Chop trees to fuel your fire.", "error")
		return
	end
	local n = FireRules.WoodAccepted(fire, have, FIRE)
	if n <= 0 then
		ctx.Util.Notify(player, "Your fire is already full.", "info")
		return
	end
	if InventoryModel.TakeResource(inv, "Wood", n) ~= n then
		return
	end
	FireRules.AddWood(fire, n, FIRE)
	ctx.InventoryService.Sync(player)
	CampService._syncFire(team)
	ctx.Util.Notify(player, string.format("Added %d Wood · fuel %d%%", n, math.floor(fire.Fuel * 100 + 0.5)), "success")
end

-- Contributes pack materials toward the next fire level.
function CampService._onFireUpgrade(player: Player, prompt: ProximityPrompt)
	local team, fire, inv = ownFire(player, prompt)
	if not team or not fire or not inv or not FireRules.CanUpgrade(fire, FIRE) then
		return
	end
	local have = {}
	for id in FireRules.Remaining(fire, FIRE) do
		have[id] = inv.Resources[id] or 0
	end
	local before = fire.Level
	local taken, levelled = FireRules.Contribute(fire, have, FIRE)
	if next(taken) == nil then
		ctx.Util.Notify(player, "You don't carry anything this upgrade needs (" .. needsText(fire) .. ").", "error")
		return
	end
	for id, n in taken do
		InventoryModel.TakeResource(inv, id, n)
	end
	ctx.InventoryService.Sync(player)
	CampService._syncFire(team)
	if levelled then
		ctx.Util.NotifyTeam(team, string.format("Campfire upgraded to Level %d! It burns longer and takes %d s to snuff.", fire.Level, FireRules.SnuffTime(fire, FIRE)), "success")
		ctx.Util.PlaySound("Craft", camps[team].Fire.PrimaryPart)
		print(string.format("[Camp] %s fire L%d -> L%d", Config.Teams[team].Name, before, fire.Level))
	else
		ctx.Util.Notify(player, "Added to the fire upgrade. Still needs " .. needsText(fire) .. ".", "info")
	end
end

function CampService._setup(map: any)
	camps = map.Camps
	for team, camp in camps do
		levels[team] = 1
		revealed[team] = { [team] = true }
		fires[team] = FireRules.New(FIRE)
		warned[team] = false
		local core = camp.Fire:FindFirstChild("FireCore") :: BasePart
		local pour = ctx.ChannelService.MakePrompt(core, "Pour", "Hold: Snuff Fire", Config.Teams[team].Name .. " Campfire", Config.Fire.PourRange, "Enemy", team)
		pour.KeyboardKeyCode = Enum.KeyCode.E
		pour:SetAttribute("Snuff", true)
		local feed = ctx.ChannelService.MakePrompt(core, "Feed", "Add Wood", "Campfire", Config.Fire.PourRange, "Team", team)
		feed.KeyboardKeyCode = Enum.KeyCode.E
		local up = ctx.ChannelService.MakePrompt(core, "FireUpgrade", "Upgrade Fire", "Campfire", Config.Fire.PourRange, "Team", team)
		up.KeyboardKeyCode = Enum.KeyCode.F
		up.UIOffset = Vector2.new(0, 72)
		local top = camp.Workbench.PrimaryPart :: BasePart
		ctx.ChannelService.MakePrompt(top, "Workbench", "Craft", "Workbench", 10, "Team", team)
		local sound = ctx.Util.MakeSound("FireCrackle", core)
		if sound then
			sound:Play()
		end
	end
end

function CampService.GetCamp(team: number): any
	return camps[team]
end

function CampService.GetLevel(team: number): number
	return levels[team] or 1
end

function CampService.SetLevel(team: number, level: number)
	local camp = camps[team]
	if not camp then
		return
	end
	levels[team] = level
	local old = camp.Workbench
	local nb = Camp.Workbench(camp.WorkbenchCF, level, Config.Teams[team].Color, camp.Folder)
	nb.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	nb:SetAttribute("Team", team)
	ctx.ChannelService.MakePrompt(nb.PrimaryPart, "Workbench", "Craft", "Workbench", 10, "Team", team)
	camp.Workbench = nb
	old:Destroy()
	ctx.MatchService.State:SetAttribute("Bench" .. team, level)
end

-- True if pos is inside the light of any burning campfire (wildlife avoids it).
function CampService.InFireLight(pos: Vector3, extra: number?): boolean
	for team, camp in camps do
		if ctx.MatchService.FireBurning(team) then
			local d = Vector3.new(pos.X - camp.FirePos.X, 0, pos.Z - camp.FirePos.Z).Magnitude
			if d < Config.Fire.LightRadius + (extra or 0) then
				return true
			end
		end
	end
	return false
end

-- Returns the nearest burning fire position within range, or nil.
function CampService.NearestLitFire(pos: Vector3, range: number): Vector3?
	local best, bestD = nil, range
	for team, camp in camps do
		if ctx.MatchService.FireBurning(team) then
			local d = (camp.FirePos - pos).Magnitude
			if d < bestD then
				best, bestD = camp.FirePos, d
			end
		end
	end
	return best
end

function CampService.InBuildZone(team: number, pos: Vector3): boolean
	local camp = camps[team]
	if not camp then
		return false
	end
	return Vector3.new(pos.X - camp.FirePos.X, 0, pos.Z - camp.FirePos.Z).Magnitude <= Config.Build.ZoneRadius
end

-- Discovery -------------------------------------------------------------------------------

function CampService._discover()
	for _, p in ctx.Util.MatchPlayers() do
		if ctx.Util.IsAlive(p) then
			local root = ctx.Util.Root(p)
			local team = ctx.Util.Team(p)
			if root and revealed[team] then
				for campTeam, camp in camps do
					if not revealed[team][campTeam] and (root.Position - camp.FirePos).Magnitude <= Config.Fire.RevealRadius then
						revealed[team][campTeam] = true
						local info = CampService._campMapInfo(campTeam)
						for _, mate in ctx.Util.TeamPlayers(team) do
							Net.FireClient("MatchEvent", mate, "CampRevealed", { Team = campTeam, By = p.DisplayName, Camp = info })
						end
					end
				end
			end
		end
	end
end

function CampService.IsRevealed(viewerTeam: number, campTeam: number): boolean
	return revealed[viewerTeam] ~= nil and revealed[viewerTeam][campTeam] == true
end

-- Healing ----------------------------------------------------------------------------------

function CampService.NoteHurt(p: Player)
	lastHurt[p] = os.clock()
end

function CampService._heal()
	local t = os.clock()
	for _, p in ctx.Util.MatchPlayers() do
		local team = ctx.Util.Team(p)
		local camp = camps[team]
		local hum = ctx.Util.Humanoid(p)
		local root = ctx.Util.Root(p)
		if camp and hum and root and hum.Health > 0 and hum.Health < hum.MaxHealth and ctx.MatchService.FireBurning(team) then
			if t - (lastHurt[p] or 0) >= Config.Player.FireHealDelayAfterDamage
				and (root.Position - camp.FirePos).Magnitude <= Config.Player.FireHealRadius then
				hum.Health = math.min(hum.MaxHealth, hum.Health + Config.Player.FireHealPerSecond)
				p:SetAttribute("Warming", t)
			end
		end
	end
end

-- Pouring ----------------------------------------------------------------------------------

function CampService._onPour(player: Player, prompt: ProximityPrompt)
	local fireTeam = prompt:GetAttribute("Team") :: number
	local camp = camps[fireTeam]
	if not camp or not ctx.Util.IsAlive(player) or not ctx.MatchService.Active then
		return
	end
	local myTeam = ctx.Util.Team(player)
	local function fail(msg: string)
		ctx.Util.Notify(player, msg, "error")
	end
	if myTeam == fireTeam then
		return fail("You can't put out your own fire.")
	end
	if not FireRules.SnuffAllowed(ctx.MatchService.Phase, ctx.MatchService.Day, FIRE) then
		return fail(string.format("Campfires are protected until Night %d.", FIRE.ProtectedNights + 1))
	end
	local fire = fires[fireTeam]
	if not fire or fire.Out then
		return fail("That fire is already out.")
	end
	if not ctx.MatchService.FireBurning(fireTeam) then
		return fail("That fire is already out.")
	end
	if not ctx.InventoryService.HasFilledCanteen(player) then
		return fail(if ctx.InventoryService.HasCanteen(player) then "Your canteen is empty. Fill it at a stream." else "You need a filled canteen (Workbench level 2).")
	end
	local other = ctx.ChannelService.AnyOnTarget("Pour", fireTeam)
	if other and other ~= player then
		return fail("Another raider is already pouring on this fire.")
	end
	if ctx.Util.DistTo(player, camp.FirePos) > Config.Fire.PourRange + 1 then
		return fail("Get closer to the fire.")
	end
	ctx.InventoryService.EquipUtility(player)
	ctx.ChannelService.Begin(player, {
		Kind = "Pour",
		Label = "Snuffing the " .. Config.Teams[fireTeam].Name .. " fire",
		Duration = FireRules.SnuffTime(fire, FIRE),
		Range = Config.Fire.PourRange,
		Hold = true,
		InterruptOnDamage = true,
		MoveTolerance = 2.5,
		Prompt = prompt,
		TargetKey = fireTeam,
		Action = "Pour",
		Position = function()
			return camp.FirePos
		end,
		CanContinue = function()
			if not FireRules.SnuffAllowed(ctx.MatchService.Phase, ctx.MatchService.Day, FIRE) then
				return false, "The fire can't be snuffed right now."
			end
			if not ctx.MatchService.FireBurning(fireTeam) then
				return false, "The fire is already out."
			end
			if not ctx.InventoryService.HasFilledCanteen(player) then
				return false, "Your canteen is empty."
			end
			return true
		end,
		OnComplete = function()
			if ctx.MatchService.FireBurning(fireTeam) and ctx.InventoryService.UseCanteen(player) then
				ctx.MatchService.ExtinguishFire(fireTeam, player)
				ctx.PowerupService.OnFireExtinguished(player)
			end
		end,
	})
	-- Alert the defenders (throttled)
	local t = os.clock()
	if t - (lastAlert[fireTeam] or 0) > Config.Fire.AlertCooldown then
		lastAlert[fireTeam] = t
		-- Direction only (from the fire toward the raider), never the raider's position.
		local root = ctx.Util.Root(player)
		local dir = if root then (root.Position - camp.FirePos) * Vector3.new(1, 0, 1) else Vector3.zero
		local bearing = if dir.Magnitude > 0.1 then math.deg(math.atan2(dir.X, -dir.Z)) % 360 else nil
		for _, mate in ctx.Util.TeamPlayers(fireTeam) do
			Net.FireClient("MatchEvent", mate, "FireUnderAttack", { By = myTeam, Pos = camp.FirePos, Bearing = bearing, Seconds = FireRules.SnuffTime(fire, FIRE) })
		end
	end
	Net.FireAll("Fx", "PourStart", { Player = player, Pos = camp.FirePos })
end

-- Map data -----------------------------------------------------------------------------------

function CampService._campMapInfo(team: number)
	local camp = camps[team]
	return { Team = team, X = camp.FirePos.X, Z = camp.FirePos.Z }
end

function CampService.SendMapData(p: Player)
	local map = ctx.MatchService.Map
	if not map or not p.Parent then
		return
	end
	local team = ctx.Util.Team(p)
	local layout = map.Layout
	local O = map.Origin
	local function pts(list)
		local out = {}
		for _, pt in list do
			table.insert(out, { pt.X + O.X, pt.Z + O.Z })
		end
		return out
	end
	local paths, streams, landmarks = {}, {}, {}
	for _, path in layout.Paths do
		table.insert(paths, pts(path.Points))
	end
	for _, s in layout.Streams do
		table.insert(streams, pts(s.Points))
	end
	for _, f in layout.Features do
		table.insert(landmarks, { Type = f.Type, X = f.X + O.X, Z = f.Z + O.Z, R = f.R })
	end
	local campsOut = {}
	for campTeam in camps do
		if CampService.IsRevealed(team, campTeam) then
			table.insert(campsOut, CampService._campMapInfo(campTeam))
		end
	end
	local own = camps[team]
	local myCamp = own and {
		X = own.FirePos.X,
		Z = own.FirePos.Z,
		Clearances = own.Clearances,
		StaticRects = own.StaticRects,
	} or nil
	Net.FireClient("MapData", p, {
		HalfSize = layout.HalfSize,
		Origin = { O.X, O.Z },
		Paths = paths,
		Streams = streams,
		Landmarks = landmarks,
		Camps = campsOut,
		MyTeam = team,
		MyCamp = myCamp,
		BuildRadius = Config.Build.ZoneRadius,
	})
end

-- Players leaving mid-alert cleanup
Players.PlayerRemoving:Connect(function(p)
	lastHurt[p] = nil
end)

return CampService
