-- Pets in the world: hatching, equipping, riding, following, dashing and the
-- speed every rider gets. All movement numbers are set here, on the server.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Pets = require(Shared.Pets)
local Eggs = require(Shared.Eggs)
local Cosmetics = require(Shared.Cosmetics)
local Net = require(Shared.Net)
local PetModel = require(Shared.PetModel)
local Hatch = require(Shared.Logic.Hatch)
local PetStats = require(Shared.Logic.PetStats)
local Profile = require(Shared.Logic.Profile)

local PetService = {}

type State = {
	Built: PetModel.Built?,
	Uid: string?,
	Riding: boolean,
	WantRide: boolean,
	DefaultHip: number?,
	Charges: number,
	DashUntil: number,
	ZoneMult: number, -- set by races: mud/boost
	Frozen: boolean, -- set by races: countdown, respawn penalty
	Locked: boolean, -- in a race: can't change pet or dismount
	Recharging: boolean,
}

local states: { [Player]: State } = {}
local ctx: any
local Util: any
local Data: any
local rng = Random.new()
local folder: Folder

local function state(p: Player): State
	local s = states[p]
	if not s then
		s = {
			Riding = false,
			WantRide = true,
			Charges = 0,
			DashUntil = 0,
			ZoneMult = 1,
			Frozen = false,
			Locked = false,
			Recharging = false,
		}
		states[p] = s
	end
	return s
end

-- The rider sits (sit animation) instead of standing, so the hips go lower than a
-- standing hip height: this share of the normal hip height stays above the back.
local SEAT = 0.3

local function rideHip(s: State): number
	return (s.DefaultHip :: number) * SEAT + (s.Built :: PetModel.Built).Height
end

local function equippedPet(p: Player): PetStats.Pet?
	local d = Data.Get(p)
	return d and Profile.EquippedPet(d)
end

-- Cartoon outline around a pet in the world (Highlights don't show in viewports).
local function outline(built: PetModel.Built)
	local hl = Instance.new("Highlight")
	hl.FillTransparency = 1
	hl.OutlineColor = Color3.fromRGB(30, 22, 45)
	hl.OutlineTransparency = 0.15
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = built.Model
end

local function destroyModel(s: State)
	if s.Built then
		s.Built.Model:Destroy()
		s.Built = nil
	end
	s.Uid = nil
end

-- Applies WalkSpeed/JumpPower/HipHeight for the player's current state.
function PetService.Apply(p: Player)
	local hum = Util.Humanoid(p)
	if not hum then
		return
	end
	local s = state(p)
	local pet = equippedPet(p)
	hum.UseJumpPower = true
	if s.DefaultHip == nil then
		s.DefaultHip = hum.HipHeight
	end
	local speed, jump
	if s.Riding and pet and s.Built then
		local ride = PetStats.Ride(pet)
		speed, jump = ride.WalkSpeed, ride.JumpPower
		hum.HipHeight = rideHip(s)
		if os.clock() < s.DashUntil then
			speed *= Config.Ride.DashBoost
		end
	else
		speed, jump = Config.Ride.OnFootSpeed, Config.Ride.OnFootJump
		hum.HipHeight = s.DefaultHip :: number
	end
	speed *= s.ZoneMult
	if s.Frozen then
		speed, jump = 0, 0
	end
	hum.WalkSpeed = speed
	hum.JumpPower = jump
	p:SetAttribute("Riding", s.Riding)
end

local function mount(p: Player)
	local s = state(p)
	local pet = equippedPet(p)
	local char = p.Character
	local root = Util.Root(p)
	local hum = Util.Humanoid(p)
	if not pet or not char or not root or not hum or hum.Health <= 0 then
		return
	end
	local wasRiding = s.Riding and s.Built ~= nil
	destroyModel(s)
	local ride = PetStats.Ride(pet)
	local built = PetModel.Build(pet.Species, ride.Size, pet.Paint)
	PetModel.SetTrail(built, pet.Trail)
	outline(built)
	if s.DefaultHip == nil then
		s.DefaultHip = hum.HipHeight
	end
	s.Built = built
	-- Rider sits on the pet's back, a little behind the middle (the big head is in
	-- front). A Weld (not WeldConstraint) so clients can bob the pet as it runs.
	local feetY = -(rideHip(s) + root.Size.Y / 2)
	local seat = CFrame.new(0, feetY, -built.Footprint.Y * 0.12)
	built.Model:PivotTo(root.CFrame * seat)
	local weld = Instance.new("Weld")
	weld.Name = "RideWeld"
	weld.Part0 = root
	weld.Part1 = built.Root
	weld.C0 = root.CFrame:ToObjectSpace(built.Root.CFrame)
	weld.C1 = CFrame.new()
	weld.Parent = built.Root
	-- Invisible box around the pet's body that collides with the world, so hurdles,
	-- steps and pillars block the pet (the visible parts don't collide). It starts
	-- 1 stud up so it never drags on floors or ramps.
	local fp = built.Footprint
	local boxH = math.max(0.5, built.Height - 1)
	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Size = Vector3.new(fp.X * 0.9, boxH, fp.Y * 0.9)
	hitbox.CFrame = built.Model:GetPivot() * CFrame.new(0, 1 + boxH / 2, 0)
	hitbox.Transparency = 1
	hitbox.CanCollide = true
	hitbox.CanQuery = false
	hitbox.CanTouch = false
	hitbox.Massless = true
	hitbox.Parent = built.Model
	local hw = Instance.new("WeldConstraint")
	hw.Part0 = built.Root
	hw.Part1 = hitbox
	hw.Parent = hitbox
	built.Model.Name = "RiddenPet"
	built.Model.Parent = char
	s.Built = built
	s.Uid = pet.Uid
	s.Riding = true
	-- Lift the character so the pet doesn't sink into the floor (only when getting on,
	-- so swapping pets or cosmetics can't be spammed as a lift).
	if not wasRiding then
		root.CFrame += Vector3.new(0, built.Height, 0)
	end
	PetService.Apply(p)
end

local function spawnFollower(p: Player)
	local s = state(p)
	local pet = equippedPet(p)
	destroyModel(s)
	s.Riding = false
	PetService.Apply(p)
	local root = Util.Root(p)
	if not pet or not root then
		return
	end
	local ride = PetStats.Ride(pet)
	local built = PetModel.Build(pet.Species, ride.Size * 0.8, pet.Paint)
	PetModel.SetTrail(built, pet.Trail)
	outline(built)
	-- Only the root is anchored (the server moves it); everything else hangs off it on
	-- joints, so clients can animate the follower too.
	built.Root.Anchored = true
	built.Model:SetAttribute("Owner", p.UserId)
	built.Model.Name = p.Name .. "Pet"
	built.Model:PivotTo(root.CFrame * CFrame.new(4, -3, 3))
	built.Model.Parent = folder
	s.Built = built
	s.Uid = pet.Uid
end

-- Ride or walk. force=true ignores the race lock (used by RaceService).
function PetService.SetRiding(p: Player, on: boolean, force: boolean?)
	local s = state(p)
	if s.Locked and not force then
		return
	end
	s.WantRide = on
	if on then
		mount(p)
	else
		spawnFollower(p)
	end
end

function PetService.Refresh(p: Player)
	local s = state(p)
	if s.WantRide then
		mount(p)
	else
		spawnFollower(p)
	end
end

function PetService.SetZone(p: Player, mult: number)
	local s = state(p)
	if s.ZoneMult ~= mult then
		s.ZoneMult = mult
		PetService.Apply(p)
	end
end

function PetService.SetFrozen(p: Player, frozen: boolean)
	state(p).Frozen = frozen
	PetService.Apply(p)
end

function PetService.SetLocked(p: Player, locked: boolean)
	state(p).Locked = locked
end

function PetService.IsRiding(p: Player): boolean
	return state(p).Riding
end

function PetService.ResetCharges(p: Player)
	local s = state(p)
	local pet = equippedPet(p)
	local max = if pet then PetStats.Ride(pet).DashCharges else 0
	s.Charges = max
	s.DashUntil = 0
	p:SetAttribute("DashCharges", max)
	p:SetAttribute("DashMax", max)
end

local function recharge(p: Player)
	local s = state(p)
	if s.Recharging then
		return
	end
	s.Recharging = true
	task.spawn(function()
		while p.Parent do
			local pet = equippedPet(p)
			if not pet then
				break
			end
			local ride = PetStats.Ride(pet)
			if s.Charges >= ride.DashCharges then
				break
			end
			task.wait(ride.DashRecharge)
			s.Charges = math.min(ride.DashCharges, s.Charges + 1)
			p:SetAttribute("DashCharges", s.Charges)
		end
		s.Recharging = false
	end)
end

local function dash(p: Player)
	local s = state(p)
	if not s.Riding or s.Frozen or s.Charges <= 0 or os.clock() < s.DashUntil then
		return
	end
	s.Charges -= 1
	s.DashUntil = os.clock() + Config.Ride.DashTime
	p:SetAttribute("DashCharges", s.Charges)
	PetService.Apply(p)
	task.delay(Config.Ride.DashTime + 0.05, function()
		if p.Parent then
			PetService.Apply(p)
		end
	end)
	recharge(p)
end

-- Hatches an egg. Returns ok, species or error text.
function PetService.Hatch(p: Player, eggId: any): (boolean, string)
	local egg = type(eggId) == "string" and Eggs.ById[eggId]
	local d = Data.Get(p)
	if not egg or not d then
		return false, "That egg doesn't exist."
	end
	if state(p).Locked then
		return false, "Finish your race first!"
	end
	local root = Util.Root(p)
	local stand = ctx.WorldService.EggStands[egg.Id]
	if not root or not stand or (root.Position - stand).Magnitude > 30 then
		return false, "Get closer to the egg."
	end
	if d.Coins < egg.Price then
		return false, "You need " .. (egg.Price - d.Coins) .. " more coins."
	end
	if #d.Pets >= Profile.Capacity(d) then
		return false, "Your barn is full! Release a pet first."
	end
	local count = (d.Pity[egg.Id] or 0) + 1
	local species = Hatch.Roll(egg, rng:NextNumber(), Hatch.IsPity(count))
	local pet = Profile.AddPet(d, species)
	if not pet then
		return false, "Your barn is full!"
	end
	d.Coins -= egg.Price
	d.Pity[egg.Id] = count
	Profile.Bump(d, "Hatches")
	Data.Changed(p)
	Net.Event("Hatched"):FireClient(p, species, egg.Id, pet.Uid)
	local rank = Pets.Rank(species)
	if rank >= 5 then
		ctx.DailyService.Badge(p, "Legendary")
		Util.NotifyAll(p.DisplayName .. " hatched a " .. Pets.RarityOf(species) .. " " .. Pets.ById[species].Name .. "!", "Rare")
	end
	return true, species
end

function PetService.Equip(p: Player, uid: any)
	local d = Data.Get(p)
	local s = state(p)
	if not d or s.Locked or not Profile.FindPet(d, uid) then
		return
	end
	d.Equipped = uid
	Data.Changed(p)
	PetService.ResetCharges(p)
	PetService.Refresh(p)
end

function PetService.Init(c)
	ctx = c
	Util = c.Util
	Data = c.DataService
	folder = Instance.new("Folder")
	folder.Name = "Pets"
	folder.Parent = workspace
end

function PetService.Start()
	Data.OnLoaded(function(p: Player, d)
		PetService.ResetCharges(p)
		if p.Character then
			PetService.Refresh(p)
		end
		local _ = d
	end)
	local function onChar(p: Player, char: Model)
		local s = state(p)
		s.DefaultHip = nil
		destroyModel(s) -- a follower lives outside the character, so clear it too
		s.Riding = false
		p:SetAttribute("Riding", false) -- no sit pose until the new pet is mounted
		local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
		char:WaitForChild("HumanoidRootPart", 10)
		if not hum or not Data.Get(p) then
			return
		end
		task.wait(0.2)
		if p.Character == char then
			PetService.ResetCharges(p)
			PetService.Refresh(p)
		end
	end
	Players.PlayerAdded:Connect(function(p)
		p.CharacterAdded:Connect(function(c)
			onChar(p, c)
		end)
	end)
	for _, p in Players:GetPlayers() do
		p.CharacterAdded:Connect(function(c)
			onChar(p, c)
		end)
		if p.Character then
			task.spawn(onChar, p, p.Character)
		end
	end
	Players.PlayerRemoving:Connect(function(p)
		local s = states[p]
		if s then
			destroyModel(s)
		end
		states[p] = nil
	end)

	-- Hatch from the egg prompts.
	for _, d in workspace:WaitForChild("Lobby"):GetDescendants() do
		if d:IsA("ProximityPrompt") and d.Name == "HatchPrompt" then
			d.Triggered:Connect(function(p)
				local ok, err = PetService.Hatch(p, d:GetAttribute("Egg"))
				if not ok then
					Util.Notify(p, err, "Error")
				end
			end)
		end
	end
	Util.Invoke("Hatch", 0.6, function(p, eggId)
		return PetService.Hatch(p, eggId)
	end)

	Util.Connect("Equip", 0.4, PetService.Equip)
	Util.Connect("Ride", 0.4, function(p, on)
		PetService.SetRiding(p, on == true)
	end)
	Util.Connect("Dash", 0.15, dash)
	Util.Connect("Release", 0.3, function(p, uid)
		local d = Data.Get(p)
		if not d or type(uid) ~= "string" then
			return
		end
		local ok, res = Profile.Release(d, uid)
		if not ok then
			Util.Notify(p, res or "Can't release that pet.", "Error")
			return
		end
		local refund = Pets.Rarities[Pets.RarityOf(res :: string)].Refund
		d.Coins += refund
		Data.Changed(p)
		Util.Notify(p, "Released! +" .. refund .. " coins", "Coins")
	end)
	Util.Connect("SetCosmetic", 0.4, function(p, kind, id)
		local d = Data.Get(p)
		local pet = d and Profile.EquippedPet(d)
		if not d or not pet or state(p).Locked or (kind ~= "Trail" and kind ~= "Paint") then
			return
		end
		if id ~= nil then
			local def = type(id) == "string" and Cosmetics.ById[id]
			if not def or def.Kind ~= kind or not d.Owned[id] then
				return
			end
		end
		if kind == "Trail" then
			pet.Trail = id
		else
			pet.Paint = id
		end
		Data.Changed(p)
		PetService.Refresh(p)
	end)
	Util.Connect("Rename", 2, function(p, uid, name)
		local d = Data.Get(p)
		local pet = d and Profile.FindPet(d, uid)
		if not pet or type(name) ~= "string" then
			return
		end
		name = string.sub(string.gsub(name, "[%c]", ""), 1, 20)
		if name == "" then
			pet.Nick = nil
		else
			local ok, filtered = pcall(function()
				return TextService:FilterStringAsync(name, p.UserId):GetNonChatStringForBroadcastAsync()
			end)
			if not ok then
				Util.Notify(p, "Couldn't check that name, try again.", "Error")
				return
			end
			pet.Nick = filtered
		end
		Data.Changed(p)
	end)

	-- Followers trot after their owner.
	RunService.Heartbeat:Connect(function(dt)
		for p, s in states do
			local built = s.Built
			if built and not s.Riding then
				local root = Util.Root(p)
				if root then
					local target = root.CFrame * CFrame.new(4, 0, 4)
					local hum = Util.Humanoid(p)
					local ground = target.Position.Y - ((hum and hum.HipHeight or 2) + root.Size.Y / 2)
					local goal = CFrame.new(target.Position.X, ground, target.Position.Z) * root.CFrame.Rotation
					local cur = built.Model:GetPivot()
					local alpha = math.min(1, dt * 8)
					if (cur.Position - goal.Position).Magnitude > 60 then
						alpha = 1
					end
					-- move only the anchored root; the rest hangs off it on joints
					built.Root.CFrame = cur:Lerp(goal, alpha) * built.Root.PivotOffset:Inverse()
				end
			end
		end
	end)
end

return PetService
