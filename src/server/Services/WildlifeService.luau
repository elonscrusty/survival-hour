--!nonstrict
-- Wildlife (spec): deer flee, rabbits are fast and passive, boars charge when
-- provoked, wolves hunt aggressively in packs at night, bears are uncommon,
-- territorial and dangerous (bats are kept in code but no longer spawn).
--
-- Night escalation (Logic/WildlifeRules) raises predator pressure, aggression,
-- pack size and roaming each night; it never inflates health. Animals spawn away
-- from players and outside burning campfire light, never enter fire light;
-- night-only hunters leave at dawn. Every animal drops leather when killed.
-- Movement is cheap steering (Humanoid:MoveTo / AlignPosition), not pathfinding,
-- with stuck detection, jumps, sidesteps and a give-up despawn.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Models = Shared:WaitForChild("Models")
local AnimalModels = require(Models:WaitForChild("Animals"))
local WildlifeRules = require(Shared:WaitForChild("Logic"):WaitForChild("WildlifeRules"))

local WildlifeService = {}

-- Role: "Prey" flees; "Pack" hunts (wolves); "Territorial" defends a home area
-- (bears); "Charger" charges when provoked (boars); "Flyer" (bats, disabled).
WildlifeService.Species = {
	Wolf = { Role = "Pack", NightOnly = true, Health = 60, Damage = 12, Speed = 21, Reach = 6.5, Cooldown = 1.6, Telegraph = 0.45, Leather = 1, Pack = { 2, 3 }, Sound = "WolfGrowl" },
	Bear = { Role = "Territorial", Health = 220, Damage = 30, Speed = 13, ChargeSpeed = 25, Reach = 8, Cooldown = 2.4, Telegraph = 0.8, Leather = 4, Pack = { 1, 1 }, Sound = "BearRoar" },
	Boar = { Role = "Charger", Health = 110, Damage = 18, Speed = 14, ChargeSpeed = 27, Reach = 6, Cooldown = 2.2, Telegraph = 0.6, Leather = 2, Pack = { 1, 2 }, Sound = "BearRoar" },
	Deer = { Role = "Prey", Health = 70, Damage = 0, Speed = 12, FleeSpeed = 26, Reach = 0, Cooldown = 1, Telegraph = 0, Leather = 2, Pack = { 1, 3 }, Sound = "AnimalHit" },
	Rabbit = { Role = "Prey", Health = 15, Damage = 0, Speed = 10, FleeSpeed = 30, Reach = 0, Cooldown = 1, Telegraph = 0, Leather = 1, Pack = { 1, 2 }, Sound = "AnimalHit" },
	Bat = { Role = "Flyer", NightOnly = true, Health = 25, Damage = 6, Speed = 24, Reach = 5, Cooldown = 1.3, Telegraph = 0.35, Leather = 1, Pack = { 3, 4 }, Sound = "BatScreech" },
}

type Animal = {
	Id: number,
	Species: string,
	Model: Model,
	Hum: Humanoid,
	Root: BasePart,
	State: string,
	Target: Player?,
	Waypoint: Vector3?,
	LastPos: Vector3,
	StillTime: number,
	StuckTotal: number,
	NextAttack: number,
	BusyUntil: number,
	ChargeUntil: number,
	ChargeDir: Vector3?,
	Damage: { [Player]: number },
	Dead: boolean,
	Leaving: boolean,
	SpawnedAt: number,
	Home: Vector3, -- territorial animals defend around here
	FleeUntil: number,
	FleeFrom: Vector3?,
	MigrateTo: Vector3?, -- migrating herd (EventService): walks toward this, then roams
}

local ctx: any
local animals: { [number]: Animal } = {}
local byModel: { [Model]: Animal } = {}
local nextId = 0
local folder: Folder? = nil
local rng = Random.new()

function WildlifeService.Init(c)
	ctx = c
	ctx.MatchService.On("MatchStarting", function(map)
		folder = Instance.new("Folder")
		folder.Name = "Wildlife"
		folder.Parent = map.Folder
	end)
	ctx.MatchService.On("PhaseChanged", function(phase: string)
		if phase == "Night" then
			WildlifeService._denSpawns()
		end
		if phase == "Day" then
			for _, a in animals do
				if WildlifeService.Species[a.Species].NightOnly then
					a.Leaving = true
				end
			end
		end
	end)
	ctx.MatchService.On("MatchCleanup", function()
		for _, a in animals do
			a.Model:Destroy()
		end
		animals = {}
		byModel = {}
		folder = nil
	end)
end

function WildlifeService.Start()
	local spawnAcc = 0
	while true do
		local dt = task.wait(Config.Wildlife.ThinkRate)
		if ctx.MatchService.Active and folder then
			spawnAcc += dt
			local pressure = WildlifeService.Pressure()
			if spawnAcc >= Config.Wildlife.SpawnInterval * pressure.IntervalMult * ctx.EventService.WildlifeIntervalMult() then
				spawnAcc = 0
				local phase = ctx.MatchService.Phase
				if phase == "Day" or phase == "Night" then
					WildlifeService._trySpawn(pressure)
				end
			end
			for _, a in animals do
				if not a.Dead then
					local ok, err = pcall(WildlifeService._think, a, dt)
					if not ok then
						warn("[Wildlife] think error:", err)
						WildlifeService._despawn(a)
					end
				end
			end
		end
	end
end

function WildlifeService.FromPart(part: Instance): Animal?
	local m = part:FindFirstAncestorOfClass("Model")
	while m do
		local a = byModel[m]
		if a then
			return if a.Dead then nil else a
		end
		m = m:FindFirstAncestorOfClass("Model")
	end
	return nil
end

function WildlifeService.List(): { Animal }
	local out = {}
	for _, a in animals do
		if not a.Dead then
			table.insert(out, a)
		end
	end
	return out
end

-- Current escalation (Logic/WildlifeRules).
function WildlifeService.Pressure(): WildlifeRules.Pressure
	local night = WildlifeRules.NightNumber(ctx.MatchService.Phase, ctx.MatchService.Day)
	local p = WildlifeRules.Pressure(night, Config.Wildlife)
	if night > 0 then
		p.AggroMult *= ctx.EventService.PredatorAggroMult()
	end
	return p
end

-- Spawning --------------------------------------------------------------------------------

local function count(species: string?): number
	local n = 0
	for _, a in animals do
		if not a.Dead and (species == nil or a.Species == species) then
			n += 1
		end
	end
	return n
end

local function nearestPlayerDist(pos: Vector3): number
	local best = math.huge
	for _, p in ctx.Util.MatchPlayers() do
		local r = ctx.Util.Root(p)
		if r then
			best = math.min(best, (r.Position - pos).Magnitude)
		end
	end
	return best
end

local function predatorCount(): number
	local n = 0
	for _, a in animals do
		if not a.Dead and WildlifeRules.Predators[a.Species] then
			n += 1
		end
	end
	return n
end

-- Medium caves hold a wolf den and large caves a bear at night (spec: predators).
function WildlifeService._denSpawns()
	local map = ctx.MatchService.Map
	if not map or not map.Caves then
		return
	end
	for _, cave in map.Caves do
		local species = if cave.Size == "Large" then "Bear" elseif cave.Size == "Medium" then "Wolf" else nil
		if species and count(species) < (Config.Wildlife.MaxPerSpecies[species] or 0) then
			local inside = (cave.CF * CFrame.new(0, 1, cave.Length * 0.7)).Position
			local occupied = false
			for _, a in animals do
				if not a.Dead and (a.Root.Position - inside).Magnitude < 25 then
					occupied = true
				end
			end
			if not occupied then
				for i = 1, if species == "Wolf" then 2 else 1 do
					local a = WildlifeService._spawn(species, inside + Vector3.new(i * 2, 0, 0))
					if a then
						a.Home = inside
					end
				end
			end
		end
	end
end

-- Event spawns (EventService): a group placed around `center`, allowed `extra` above the
-- species cap. Returns how many spawned. `migrate` sends a herd walking toward that point.
function WildlifeService.SpawnGroup(species: string, center: Vector3, n: number, radius: number, extra: number, migrate: Vector3?): number
	if not folder or not WildlifeService.Species[species] then
		return 0
	end
	local cap = (Config.Wildlife.MaxPerSpecies[species] or 0) + extra
	local made = 0
	for i = 1, n do
		if count(species) >= cap then
			break
		end
		local a = rng:NextNumber() * math.pi * 2
		local d = rng:NextNumber(0, radius)
		local x, z = center.X + math.cos(a) * d, center.Z + math.sin(a) * d
		local pos = Vector3.new(x, ctx.WorldService.GroundY(x, z), z)
		if not ctx.CampService.InFireLight(pos, 20) then
			local an = WildlifeService._spawn(species, pos)
			if an then
				an.MigrateTo = migrate and (migrate + Vector3.new((i % 3 - 1) * 6, 0, (i % 2) * 6)) or nil
				made += 1
			end
		end
	end
	return made
end

function WildlifeService._trySpawn(pressure: WildlifeRules.Pressure)
	if count(nil) >= Config.Wildlife.MaxTotal then
		return
	end
	local candidates = {}
	for _, p in ctx.Util.MatchPlayers() do
		local r = ctx.Util.Root(p)
		if r and ctx.Util.IsAlive(p) and not ctx.CampService.InFireLight(r.Position, 10) then
			table.insert(candidates, r.Position)
		end
	end
	if #candidates == 0 then
		return
	end
	local focus = candidates[rng:NextInteger(1, #candidates)]
	-- Weighted species choice (by time of day / night number) respecting caps
	local allowed = {}
	local predatorsFull = predatorCount() >= pressure.PredatorCap
	for name in WildlifeService.Species do
		if count(name) < (Config.Wildlife.MaxPerSpecies[name] or 0) and not (predatorsFull and WildlifeRules.Predators[name]) then
			allowed[name] = true
		end
	end
	local species = WildlifeRules.Pick(WildlifeRules.Weights(pressure.Night), allowed, rng:NextNumber())
	if not species then
		return
	end
	local map = ctx.MatchService.Map
	local H = map.Layout.HalfSize - 12
	for _ = 1, 12 do
		local ang = rng:NextNumber() * math.pi * 2
		local dist = rng:NextNumber(Config.Wildlife.SpawnMinPlayerDist, Config.Wildlife.SpawnMaxPlayerDist)
		local x = math.clamp(focus.X + math.cos(ang) * dist, map.Origin.X - H, map.Origin.X + H)
		local z = math.clamp(focus.Z + math.sin(ang) * dist, map.Origin.Z - H, map.Origin.Z + H)
		local y = ctx.WorldService.GroundY(x, z)
		local pos = Vector3.new(x, y, z)
		if not ctx.CampService.InFireLight(pos, 25) and nearestPlayerDist(pos) >= Config.Wildlife.SpawnMinPlayerDist then
			local sp = WildlifeService.Species[species]
			local n = rng:NextInteger(sp.Pack[1], sp.Pack[2]) + (if species == "Wolf" then pressure.PackBonus else 0)
			n = math.min(n, Config.Wildlife.MaxPerSpecies[species] - count(species), Config.Wildlife.MaxTotal - count(nil))
			for i = 1, n do
				WildlifeService._spawn(species, pos + Vector3.new(i * 3, 0, (i % 2) * 3))
			end
			return
		end
	end
end

function WildlifeService._spawn(species: string, pos: Vector3): Animal?
	local sp = WildlifeService.Species[species]
	local model = AnimalModels.Build(species)
	local root = (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart) :: BasePart
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.MaxHealth = sp.Health
	hum.Health = sp.Health
	hum.WalkSpeed = sp.Speed
	local y = pos.Y + (if species == "Bat" then 12 else hum.HipHeight + root.Size.Y / 2 + 0.5)
	model:PivotTo(CFrame.new(pos.X, y, pos.Z) * CFrame.Angles(0, rng:NextNumber() * 6.28, 0))
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = "Animals"
		end
	end
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	nextId += 1
	local a: Animal = {
		Id = nextId,
		Species = species,
		Model = model,
		Hum = hum,
		Root = root,
		State = "Roam",
		Target = nil,
		Waypoint = nil,
		LastPos = root.Position,
		StillTime = 0,
		StuckTotal = 0,
		NextAttack = 0,
		BusyUntil = 0,
		ChargeUntil = 0,
		ChargeDir = nil,
		Damage = {},
		Dead = false,
		Leaving = false,
		SpawnedAt = os.clock(),
		Home = pos,
		FleeUntil = 0,
		FleeFrom = nil,
	}
	model:SetAttribute("Species", species)
	model:SetAttribute("AnimalId", a.Id)
	animals[a.Id] = a
	byModel[model] = a
	hum.Died:Connect(function()
		WildlifeService._onDied(a)
	end)
	return a
end

-- Behaviour ----------------------------------------------------------------------------------

local function flatDist(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Moves the destination out of any burning fire's light radius.
local function safeGoal(goal: Vector3): Vector3
	local fire = ctx.CampService.NearestLitFire(goal, Config.Fire.LightRadius + 4)
	if fire then
		local away = Vector3.new(goal.X - fire.X, 0, goal.Z - fire.Z)
		local dir = if away.Magnitude > 0.1 then away.Unit else Vector3.new(1, 0, 0)
		return Vector3.new(fire.X, goal.Y, fire.Z) + dir * (Config.Fire.LightRadius + 5)
	end
	return goal
end

-- Nearest valid player within `range` of `from` (default: the animal).
local function pickTarget(a: Animal, range: number?, from: Vector3?): Player?
	local origin = from or a.Root.Position
	local best, bestD = nil, range or (Config.Wildlife.AggroRange[a.Species] or 0) * WildlifeService.Pressure().AggroMult
	for _, p in ctx.Util.MatchPlayers() do
		local r = ctx.Util.Root(p)
		if r and ctx.Util.IsAlive(p) and not ctx.CampService.InFireLight(r.Position) then
			local d = (r.Position - origin).Magnitude
			if d < bestD then
				best, bestD = p, d
			end
		end
	end
	return best
end

-- Nearest player position within range (prey watch for threats, even in fire light).
local function nearestThreat(pos: Vector3, range: number): Vector3?
	local best, bestD = nil, range
	for _, p in ctx.Util.MatchPlayers() do
		local r = ctx.Util.Root(p)
		if r and ctx.Util.IsAlive(p) then
			local d = (r.Position - pos).Magnitude
			if d < bestD then
				best, bestD = r.Position, d
			end
		end
	end
	return best
end

local function moveTo(a: Animal, goal: Vector3)
	if a.Species == "Bat" then
		local mover = a.Root:FindFirstChild("Mover") :: AlignPosition?
		local facing = a.Root:FindFirstChild("Facing") :: AlignOrientation?
		if mover then
			mover.Position = goal
		end
		if facing then
			local flatDir = Vector3.new(goal.X - a.Root.Position.X, 0, goal.Z - a.Root.Position.Z)
			if flatDir.Magnitude > 0.5 then
				facing.CFrame = CFrame.lookAt(Vector3.zero, flatDir)
			end
		end
	else
		a.Hum:MoveTo(goal)
	end
end

local function telegraph(a: Animal, kind: string, duration: number)
	a.Model:SetAttribute("Telegraph", kind)
	a.Model:SetAttribute("TelegraphAt", workspace:GetServerTimeNow())
	ctx.Util.PlaySound(WildlifeService.Species[a.Species].Sound, a.Root)
	a.BusyUntil = os.clock() + duration
end

local function hitIfClose(a: Animal, target: Player, reach: number)
	local r = ctx.Util.Root(target)
	if not r or a.Dead then
		return
	end
	-- Walls and other solid cover block animal attacks.
	local los = RaycastParams.new()
	los.FilterType = Enum.RaycastFilterType.Exclude
	los.FilterDescendantsInstances = { a.Model, target.Character :: Instance }
	los.IgnoreWater = true
	local blocked = workspace:Raycast(a.Root.Position, r.Position - a.Root.Position, los)
	if blocked and blocked.Instance ~= workspace.Terrain then
		return
	end
	if (r.Position - a.Root.Position).Magnitude <= reach and not ctx.CampService.InFireLight(r.Position) then
		local sp = WildlifeService.Species[a.Species]
		ctx.CombatService.DamagePlayer(target, sp.Damage * ctx.PowerupService.WildlifeDamageMult(target), { Kind = "Animal", Name = a.Species, Pos = a.Root.Position })
		a.Model:SetAttribute("Telegraph", "Strike")
		a.Model:SetAttribute("TelegraphAt", workspace:GetServerTimeNow())
	end
end

function WildlifeService._think(a: Animal, dt: number)
	local now = os.clock()
	local pos = a.Root.Position
	local sp = WildlifeService.Species[a.Species]

	-- Dawn: run away from the nearest player and despawn.
	if a.Leaving or (sp.NightOnly and not ctx.MatchService.IsNight()) then
		a.Leaving = true
		a.Model:SetAttribute("Telegraph", nil)
		if now - a.SpawnedAt > 0 then
			a.Hum.WalkSpeed = sp.Speed * 1.2
			local away = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit
			moveTo(a, pos + away * 40 + (if a.Species == "Bat" then Vector3.new(0, 30, 0) else Vector3.zero))
		end
		if nearestPlayerDist(pos) > 90 or (a.Model:GetAttribute("LeaveStart") and now - (a.Model:GetAttribute("LeaveStart") :: number) > 6) then
			WildlifeService._despawn(a)
		elseif not a.Model:GetAttribute("LeaveStart") then
			a.Model:SetAttribute("LeaveStart", now)
		end
		return
	end

	if nearestPlayerDist(pos) > Config.Wildlife.DespawnDistance then
		WildlifeService._despawn(a)
		return
	end

	-- Prey: roam; bolt away from nearby players or after being hit.
	if sp.Role == "Prey" then
		local threat = nearestThreat(pos, (Config.Wildlife.FleeRange[a.Species] or 25) * WildlifeService.Pressure().AggroMult)
		if threat then
			if now >= a.FleeUntil then
				-- startled: head snaps up (client) as it bolts
				a.Model:SetAttribute("AlertAt", workspace:GetServerTimeNow())
			end
			a.FleeUntil = now + 3
			a.FleeFrom = threat
		end
		if now < a.FleeUntil and a.FleeFrom then
			a.State = "Flee"
			a.Hum.WalkSpeed = sp.FleeSpeed
			local away = (pos - a.FleeFrom) * Vector3.new(1, 0, 1)
			local dir = if away.Magnitude > 0.1 then away.Unit else Vector3.new(1, 0, 0)
			-- zig-zag a little so it reads as a panicked run
			local jig = CFrame.Angles(0, math.sin(now * 3 + a.Id) * 0.5, 0) * dir
			local goal = pos + jig * 24
			moveTo(a, safeGoal(Vector3.new(goal.X, ctx.WorldService.GroundY(goal.X, goal.Z), goal.Z)))
		else
			a.State = "Roam"
			a.Hum.WalkSpeed = sp.Speed * 0.5
			local mig = a.MigrateTo
			if mig and flatDist(pos, mig) < 12 then
				a.MigrateTo = nil -- arrived: back to normal grazing
				mig = nil
			end
			if mig then
				-- herd on the move: steady walk toward the far side, a little spread
				a.Hum.WalkSpeed = sp.Speed * 0.75
				if not a.Waypoint or flatDist(pos, a.Waypoint) < 5 then
					local dir = (mig - pos) * Vector3.new(1, 0, 1)
					local step = pos + dir.Unit * math.min(dir.Magnitude, 24) + Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4))
					a.Waypoint = safeGoal(Vector3.new(step.X, ctx.WorldService.GroundY(step.X, step.Z), step.Z))
				end
			elseif not a.Waypoint or flatDist(pos, a.Waypoint) < 5 then
				local wp = pos + Vector3.new(rng:NextNumber(-30, 30), 0, rng:NextNumber(-30, 30))
				a.Waypoint = safeGoal(Vector3.new(wp.X, ctx.WorldService.GroundY(wp.X, wp.Z), wp.Z))
			end
			moveTo(a, a.Waypoint :: Vector3)
		end
		WildlifeService._unstick(a, dt)
		return
	end

	-- Never linger inside fire light.
	if ctx.CampService.InFireLight(pos) then
		a.Target = nil
		a.State = "Retreat"
		moveTo(a, safeGoal(pos))
		return
	end

	if now < a.BusyUntil then
		return -- mid-telegraph / recovering
	end

	-- Target selection by role
	local pressure = WildlifeService.Pressure()
	local function lost(t: Player?): boolean
		local r = t and ctx.Util.Root(t)
		return not t or not r or not ctx.Util.IsAlive(t) or ctx.CampService.InFireLight(r.Position)
	end
	if sp.Role == "Territorial" then
		-- Bears defend a home area; they drop the chase once you leave it.
		local territory = Config.Wildlife.Territory * pressure.AggroMult
		if lost(a.Target) or flatDist((ctx.Util.Root(a.Target :: Player) :: BasePart).Position, a.Home) > territory * 1.6 then
			a.Target = pickTarget(a, territory, a.Home)
		end
	elseif sp.Role == "Charger" then
		-- Boars ignore you unless you come close (or hit them), and give up at a distance.
		if lost(a.Target) or ((ctx.Util.Root(a.Target :: Player) :: BasePart).Position - pos).Magnitude > 45 then
			a.Target = pickTarget(a)
		end
	elseif lost(a.Target) then
		a.Target = pickTarget(a)
	end
	local target = a.Target
	local troot = target and ctx.Util.Root(target)

	if not target or not troot then
		-- Roam around
		a.State = "Roam"
		a.Hum.WalkSpeed = sp.Speed * 0.5
		if not a.Waypoint or flatDist(pos, a.Waypoint) < 5 then
			local base = if sp.Role == "Territorial" then a.Home else pos
			local reach = 40 * pressure.AggroMult
			local wp = base + Vector3.new(rng:NextNumber(-reach, reach), 0, rng:NextNumber(-reach, reach))
			local map = ctx.MatchService.Map
			local H = map.Layout.HalfSize - 15
			wp = Vector3.new(math.clamp(wp.X, -H, H), ctx.WorldService.GroundY(wp.X, wp.Z) + (if a.Species == "Bat" then 14 else 0), math.clamp(wp.Z, -H, H))
			a.Waypoint = safeGoal(wp)
		end
		moveTo(a, a.Waypoint :: Vector3)
	else
		a.State = "Chase"
		local tpos = troot.Position
		local dist = (tpos - pos).Magnitude
		a.Hum.WalkSpeed = sp.Speed
		if a.Species == "Wolf" then
			if dist <= sp.Reach + 1.5 and now >= a.NextAttack then
				telegraph(a, "Lunge", sp.Telegraph)
				a.NextAttack = now + sp.Cooldown
				task.delay(sp.Telegraph, function()
					if a.Dead or not target.Parent then
						return
					end
					local r2 = ctx.Util.Root(target)
					if r2 then
						local dir = (r2.Position - a.Root.Position) * Vector3.new(1, 0, 1)
						if dir.Magnitude > 0.1 then
							a.Root.AssemblyLinearVelocity = dir.Unit * 38 + Vector3.new(0, 12, 0)
						end
						task.wait(0.15)
						hitIfClose(a, target, sp.Reach)
					end
				end)
			else
				-- Flank slightly so packs spread out
				local side = if a.Id % 2 == 0 then 1 else -1
				local offset = CFrame.lookAt(tpos, pos).RightVector * side * math.min(6, dist * 0.2)
				moveTo(a, safeGoal(tpos + offset))
			end
		elseif a.Species == "Bear" or a.Species == "Boar" then
			if now < a.ChargeUntil and a.ChargeDir then
				a.Hum.WalkSpeed = sp.ChargeSpeed :: number
				moveTo(a, safeGoal(pos + a.ChargeDir * 20))
				if dist <= sp.Reach then
					a.ChargeUntil = 0
					hitIfClose(a, target, sp.Reach)
					a.NextAttack = now + sp.Cooldown
					a.BusyUntil = now + 0.8
				end
			elseif dist <= sp.Reach and now >= a.NextAttack then
				telegraph(a, "Swipe", 0.5)
				a.NextAttack = now + sp.Cooldown
				task.delay(0.5, function()
					hitIfClose(a, target, sp.Reach + 1)
				end)
			elseif dist < (if a.Species == "Boar" then 22 else 32) and dist > (if a.Species == "Boar" then 6 else 12) and now >= a.NextAttack then
				-- Roar, then charge in a straight line
				telegraph(a, "Roar", sp.Telegraph)
				a.NextAttack = now + sp.Cooldown + 1
				local dir = (tpos - pos) * Vector3.new(1, 0, 1)
				a.ChargeDir = if dir.Magnitude > 0.1 then dir.Unit else nil
				a.ChargeUntil = now + sp.Telegraph + 2
			else
				moveTo(a, safeGoal(tpos))
			end
		else -- Bat
			local hover = tpos + Vector3.new(math.sin(now * 2.3 + a.Id) * 9, 8 + math.sin(now * 3.1 + a.Id) * 2, math.cos(now * 1.9 + a.Id) * 9)
			if dist <= 14 and now >= a.NextAttack then
				telegraph(a, "Swoop", sp.Telegraph)
				a.NextAttack = now + sp.Cooldown + rng:NextNumber(0, 0.8)
				task.delay(sp.Telegraph, function()
					if a.Dead or not target.Parent then
						return
					end
					local r2 = ctx.Util.Root(target)
					if r2 then
						moveTo(a, r2.Position + Vector3.new(0, 1.5, 0))
						task.wait(0.35)
						hitIfClose(a, target, sp.Reach)
					end
				end)
			else
				moveTo(a, safeGoal(hover))
			end
		end
	end

	WildlifeService._unstick(a, dt)
end

-- Stuck detection (ground animals): jump, sidestep, and give up if hopeless.
function WildlifeService._unstick(a: Animal, dt: number)
	local pos = a.Root.Position
	if a.Species ~= "Bat" then
		local moved = flatDist(pos, a.LastPos)
		if moved < 0.6 * dt * 5 then
			a.StillTime += dt
		else
			a.StillTime = 0
			a.StuckTotal = math.max(0, a.StuckTotal - dt)
		end
		a.LastPos = pos
		if a.StillTime > Config.Wildlife.StuckTime then
			a.StillTime = 0
			a.StuckTotal += Config.Wildlife.StuckTime
			a.Hum.Jump = true
			local side = CFrame.lookAt(pos, pos + a.Root.CFrame.LookVector).RightVector * (if rng:NextNumber() < 0.5 then -1 else 1)
			a.Waypoint = safeGoal(pos + side * 12)
			moveTo(a, a.Waypoint :: Vector3)
		end
		if a.StuckTotal > Config.Wildlife.StuckGiveUp then
			WildlifeService._despawn(a)
		end
		-- Fell out of the world / into a hole
		if pos.Y < ctx.WorldService.GroundY(pos.X, pos.Z) - 20 then
			WildlifeService._despawn(a)
		end
	end
end

-- Damage / death -----------------------------------------------------------------------------

function WildlifeService.Damage(a: Animal, amount: number, attacker: Player?): boolean
	if a.Dead or amount <= 0 then
		return false
	end
	if attacker then
		a.Damage[attacker] = (a.Damage[attacker] or 0) + amount
		-- Being hit draws aggro (predators, boars) or makes prey bolt.
		if WildlifeService.Species[a.Species].Role == "Prey" then
			local r = ctx.Util.Root(attacker)
			a.FleeFrom = if r then r.Position else a.Root.Position
			a.FleeUntil = os.clock() + 5
		else
			a.Target = attacker
		end
		Net.FireClient("HitFeedback", attacker, "Animal", math.floor(amount + 0.5), a.Root.Position)
	end
	ctx.Util.PlaySound("AnimalHit", a.Root)
	a.Model:SetAttribute("HitAt", workspace:GetServerTimeNow())
	Net.FireAll("Fx", "Impact", { Pos = a.Root.Position, Kind = "Animal" })
	a.Hum.Health = math.max(0, a.Hum.Health - amount)
	return true
end

function WildlifeService._onDied(a: Animal)
	if a.Dead then
		return
	end
	a.Dead = true
	local pos = a.Root.Position
	local night = ctx.MatchService.IsNight()
	-- Killer = biggest damage contributor (still in the match).
	local killer, best = nil, 0
	for p, d in a.Damage do
		if p.Parent and d > best then
			killer, best = p, d
		end
	end
	local sp = WildlifeService.Species[a.Species]
	local ground = ctx.WorldService.GroundY(pos.X, pos.Z)
	local leather = sp.Leather + (if killer then ctx.PowerupService.ExtraHide(killer) else 0)
	ctx.InventoryService.SpawnPickup("Leather", leather, Vector3.new(pos.X, ground + 1, pos.Z))
	if killer then
		ctx.PowerupService.OnAnimalKilled(killer, a.Id)
		ctx.PowerupService.OnWildlifeKill(killer, a.Species, night)
	end
	a.Model:SetAttribute("Telegraph", "Dead")
	for _, d in a.Model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery = false
		end
	end
	task.delay(2, function()
		WildlifeService._despawn(a)
	end)
end

function WildlifeService._despawn(a: Animal)
	a.Dead = true
	animals[a.Id] = nil
	byModel[a.Model] = nil
	if a.Model.Parent then
		a.Model:Destroy()
	end
end


return WildlifeService
