-- Lobby training: ride through the Speed Ring gates, jump the hurdles, run on the
-- treadmill. Positions are polled on the server, so there's nothing to fake.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Profile = require(Shared.Logic.Profile)
local PetStats = require(Shared.Logic.PetStats)

local TrainingService = {}

type Track = {
	Gate: number?, -- last gate passed
	Dir: number?, -- +1 or -1 once two gates are passed
	GateCount: number,
	GateAt: number,
	LastZ: number?,
	HurdleAt: { [number]: number },
	PadTime: number,
}

local tracks: { [Player]: Track } = {}
local ctx: any

local function award(p: Player, stat: string, xp: number)
	local d = ctx.DataService.Get(p)
	local pet = d and Profile.EquippedPet(d)
	if not pet then
		return
	end
	local before = PetStats.Ride(pet)
	local gained = PetStats.AddXp(pet, stat, xp)
	ctx.DataService.Changed(p)
	ctx.Util.Notify(p, "+" .. xp .. " " .. stat, "Xp")
	if gained > 0 then
		ctx.Util.Notify(p, stat .. " level " .. pet.Levels[stat] .. "!", "Level")
		local after = PetStats.Ride(pet)
		if after.DashCharges ~= before.DashCharges then
			ctx.PetService.ResetCharges(p)
		end
		ctx.PetService.Apply(p)
	end
end

local function tick(p: Player, dt: number)
	local root = ctx.Util.Root(p)
	if not root or not ctx.PetService.IsRiding(p) or p:GetAttribute("InRace") then
		tracks[p] = nil
		return
	end
	local t = tracks[p]
	if not t then
		t = { GateCount = 0, GateAt = 0, HurdleAt = {}, PadTime = 0 }
		tracks[p] = t
	end
	local pos = root.Position
	local now = os.clock()
	local W = ctx.WorldService
	local T = Config.Training

	-- Speed ring
	local gates = W.SpeedGates
	local n = #gates
	for i, g in gates do
		local flat = Vector3.new(pos.X - g.X, 0, pos.Z - g.Z)
		if flat.Magnitude < 8 and i ~= t.Gate and now - t.GateAt >= T.GateMinGap then
			local ok = false
			if t.Gate == nil then
				ok = true
			else
				local fwd = (t.Gate % n) + 1
				local back = ((t.Gate - 2) % n) + 1
				if t.Dir == nil and (i == fwd or i == back) then
					t.Dir = if i == fwd then 1 else -1
					ok = true
				elseif (t.Dir == 1 and i == fwd) or (t.Dir == -1 and i == back) then
					ok = true
				end
			end
			if ok then
				t.Gate = i
				t.GateAt = now
				t.GateCount += 1
				award(p, "Speed", T.GateXp)
				if t.GateCount % n == 0 then
					award(p, "Speed", T.LapBonusXp)
					ctx.Util.Notify(p, "Lap bonus!", "Level")
				end
			else
				-- skipped a gate: start a fresh sequence from here
				t.Gate = i
				t.Dir = nil
				t.GateAt = now
				t.GateCount = 0
			end
			break
		end
	end

	-- Hurdles: crossing a hurdle line inside the lane means you jumped it.
	if t.LastZ then
		for i, h in W.Hurdles do
			if pos.X >= h.X0 and pos.X <= h.X1 and (t.LastZ - h.Z) * (pos.Z - h.Z) < 0 then
				if now - (t.HurdleAt[i] or 0) > 1.5 then
					t.HurdleAt[i] = now
					award(p, "Jump", math.max(2, math.floor(T.GateXp * h.H / 4 + 0.5)))
				end
			end
		end
	end
	t.LastZ = pos.Z

	-- Treadmill
	local tm = W.Treadmill
	if W.InBox(pos, tm.Center, tm.Size) then
		t.PadTime += dt
		if t.PadTime >= T.PadTick then
			t.PadTime -= T.PadTick
			award(p, "Stamina", T.PadXp)
		end
	else
		t.PadTime = 0
	end
end

function TrainingService.Init(c)
	ctx = c
end

function TrainingService.Start()
	Players.PlayerRemoving:Connect(function(p)
		tracks[p] = nil
	end)
	local step = 0.1
	while true do
		task.wait(step)
		for _, p in Players:GetPlayers() do
			local ok, err = pcall(tick, p, step)
			if not ok then
				warn("[Training] " .. tostring(err))
			end
		end
	end
end

return TrainingService
