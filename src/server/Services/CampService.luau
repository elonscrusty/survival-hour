--!nonstrict
-- Camps: campfires (pour-to-extinguish), workbench level + prompt, enemy camp
-- discovery, healing near your own fire, and fire-light queries for wildlife.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Models = Shared:WaitForChild("Models")
local Camp = require(Models:WaitForChild("Camp"))

local CampService = {}

local ctx: any
local camps: { [number]: any } = {}
local levels: { [number]: number } = {}
local revealed: { [number]: { [number]: boolean } } = {} -- team -> discovered camp teams
local lastAlert: { [number]: number } = {}
local lastHurt: { [Player]: number } = {}

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
			ctx.Util.PlaySound("FireOut", camp.Fire.PrimaryPart)
		end
	end)
	ctx.MatchService.On("MatchCleanup", function()
		camps = {}
		levels = {}
		revealed = {}
	end)
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
	-- Discovery + healing loops
	local tick = 0
	while true do
		task.wait(0.5)
		tick += 1
		if ctx.MatchService.Active and next(camps) then
			CampService._discover()
			if tick % 2 == 0 then
				CampService._heal()
			end
		end
	end
end

function CampService._setup(map: any)
	camps = map.Camps
	for team, camp in camps do
		levels[team] = 1
		revealed[team] = { [team] = true }
		local core = camp.Fire:FindFirstChild("FireCore") :: BasePart
		local pour = ctx.ChannelService.MakePrompt(core, "Pour", "Hold: Pour Water", Config.Teams[team].Name .. " Campfire", Config.Fire.PourRange, "Enemy", team)
		pour.KeyboardKeyCode = Enum.KeyCode.E
		pour:SetAttribute("Night", true)
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
	if not ctx.MatchService.IsNight() then
		return fail("Fires can only be put out at night.")
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
		Label = "Pouring water on the " .. Config.Teams[fireTeam].Name .. " fire",
		Duration = Config.Fire.PourDuration,
		Range = Config.Fire.PourRange,
		Hold = true,
		InterruptOnDamage = true,
		Prompt = prompt,
		TargetKey = fireTeam,
		Action = "Pour",
		Position = function()
			return camp.FirePos
		end,
		CanContinue = function()
			if not ctx.MatchService.IsNight() then
				return false, "Dawn broke — the fire can't be put out now."
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
		for _, mate in ctx.Util.TeamPlayers(fireTeam) do
			Net.FireClient("MatchEvent", mate, "FireUnderAttack", { By = myTeam, Pos = camp.FirePos })
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
