--!nonstrict
-- Night wildlife: wolves (fast packs, telegraphed lunge), bears (roar → charge,
-- heavy swipe), bats (erratic flying swarms that swoop).
--
-- Rules: animals spawn only at night, away from players' view distance and
-- outside burning campfire light, never enter burning fire light, flee and
-- despawn at dawn, and drop leather only when killed at night. Movement is
-- cheap steering (Humanoid:MoveTo / AlignPosition), not pathfinding, with
-- stuck detection, jumps, sidesteps and a give-up despawn.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Models = Shared:WaitForChild("Models")
local AnimalModels = require(Models:WaitForChild("Animals"))

local WildlifeService = {}

WildlifeService.Species = {
	Wolf = { Health = 60, Damage = 12, Speed = 21, Reach = 6.5, Cooldown = 1.6, Telegraph = 0.45, Leather = 1, Pack = { 2, 3 }, Weight = 5, Sound = "WolfGrowl" },
	Bear = { Health = 220, Damage = 30, Speed = 13, ChargeSpeed = 25, Reach = 8, Cooldown = 2.4, Telegraph = 0.8, Leather = 3, Pack = { 1, 1 }, Weight = 2, Sound = "BearRoar" },
	Bat = { Health = 25, Damage = 6, Speed = 24, Reach = 5, Cooldown = 1.3, Telegraph = 0.35, Leather = 1, Pack = { 3, 4 }, Weight = 3, Sound = "BatScreech" },
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
		if phase == "Day" then
			for _, a in animals do
				a.Leaving = true
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
			if spawnAcc >= Config.Wildlife.SpawnInterval then
				spawnAcc = 0
				if ctx.MatchService.IsNight() then
					WildlifeService._trySpawn()
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

function WildlifeService._trySpawn()
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
	-- Weighted species choice respecting per-species caps
	local pool, total = {}, 0
	for name, sp in WildlifeService.Species do
		if count(name) < Config.Wildlife.MaxPerSpecies[name] then
			table.insert(pool, name)
			total += sp.Weight
		end
	end
	if #pool == 0 then
		return
	end
	table.sort(pool)
	local pick = rng:NextNumber() * total
	local species = pool[1]
	for _, name in pool do
		pick -= WildlifeService.Species[name].Weight
		if pick <= 0 then
			species = name
			break
		end
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
			local n = rng:NextInteger(sp.Pack[1], sp.Pack[2])
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
	local model = if species == "Wolf" then AnimalModels.Wolf() elseif species == "Bear" then AnimalModels.Bear() else AnimalModels.Bat()
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

local function pickTarget(a: Animal): Player?
	local range = Config.Wildlife.AggroRange[a.Species]
	local best, bestD = nil, range
	for _, p in ctx.Util.MatchPlayers() do
		local r = ctx.Util.Root(p)
		if r and ctx.Util.IsAlive(p) and not ctx.CampService.InFireLight(r.Position) then
			local d = (r.Position - a.Root.Position).Magnitude
			if d < bestD then
				best, bestD = p, d
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
		ctx.CombatService.DamagePlayer(target, sp.Damage, { Kind = "Animal", Name = a.Species, Pos = a.Root.Position })
		a.Model:SetAttribute("Telegraph", "Strike")
		a.Model:SetAttribute("TelegraphAt", workspace:GetServerTimeNow())
	end
end

function WildlifeService._think(a: Animal, dt: number)
	local now = os.clock()
	local pos = a.Root.Position
	local sp = WildlifeService.Species[a.Species]

	-- Dawn: run away from the nearest player and despawn.
	if a.Leaving or not ctx.MatchService.IsNight() then
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

	-- Target selection
	if not a.Target or not ctx.Util.IsAlive(a.Target) or (ctx.Util.Root(a.Target) and ctx.CampService.InFireLight((ctx.Util.Root(a.Target) :: BasePart).Position)) then
		a.Target = pickTarget(a)
	end
	local target = a.Target
	local troot = target and ctx.Util.Root(target)

	if not target or not troot then
		-- Roam around
		a.State = "Roam"
		a.Hum.WalkSpeed = sp.Speed * 0.5
		if not a.Waypoint or flatDist(pos, a.Waypoint) < 5 then
			local wp = pos + Vector3.new(rng:NextNumber(-40, 40), 0, rng:NextNumber(-40, 40))
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
		elseif a.Species == "Bear" then
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
			elseif dist < 32 and dist > 12 and now >= a.NextAttack then
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

	-- Stuck detection (ground animals)
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
		-- Being hit draws aggro to the attacker (unless they're in fire light).
		a.Target = attacker
		Net.FireClient("HitFeedback", attacker, "Animal", math.floor(amount + 0.5), a.Root.Position)
	end
	ctx.Util.PlaySound("AnimalHit", a.Root)
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
	if night then
		local sp = WildlifeService.Species[a.Species]
		local ground = ctx.WorldService.GroundY(pos.X, pos.Z)
		ctx.InventoryService.SpawnPickup("Leather", sp.Leather, Vector3.new(pos.X, ground + 1, pos.Z))
		if killer then
			ctx.PowerupService.OnAnimalKilled(killer, a.Id)
		end
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
