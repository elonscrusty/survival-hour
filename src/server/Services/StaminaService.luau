--!nonstrict
-- Stamina (spec: 100). Sprinting drains it, and melee/blocking spend it
-- (CombatService calls Spend). It regenerates after a short pause. Movement speed
-- is still applied by PowerupService's movement loop, which multiplies in SpeedMult.
--
-- Replicated player attributes: Stamina (0..MaxStamina), MaxStamina, Sprinting, Exhausted.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local StaminaService = {}

type St = { Value: number, Want: boolean, Sprinting: boolean, Exhausted: boolean, LastSpend: number, Pushed: number, LastNoise: number? }

local ctx: any
local states: { [Player]: St } = {}
local S = Config.Stamina

local function max(p: Player): number
	return S.Max * ctx.PowerupService.StaminaMaxMult(p)
end

local function get(p: Player): St
	local st = states[p]
	if not st then
		st = { Value = S.Max, Want = false, Sprinting = false, Exhausted = false, LastSpend = 0, Pushed = -1 }
		states[p] = st
	end
	return st
end

function StaminaService.Init(c)
	ctx = c
	ctx.Util.Connect("Sprint", "Default", function(p: Player, want: any)
		get(p).Want = want == true
	end)
	ctx.Util.OnPlayerRemoving(function(p)
		states[p] = nil
	end)
end

function StaminaService.Start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		local step = acc
		acc = 0
		local t = os.clock()
		for p, st in states do
			local hum = ctx.Util.Humanoid(p)
			if not hum or hum.Health <= 0 or not p:GetAttribute("InMatch") then
				st.Sprinting = false
				continue
			end
			local m = max(p)
			local moving = hum.MoveDirection.Magnitude > 0.1
			st.Sprinting = st.Want and moving and not st.Exhausted and st.Value > 0
			if st.Sprinting then
				-- running is noisy (wildlife hears it; once a second)
				if t - (st.LastNoise or 0) >= 1 then
					st.LastNoise = t
					local root = ctx.Util.Root(p)
					if root then
						ctx.WildlifeService.Noise(root.Position, Config.Noise.Sprint)
					end
				end
				st.Value = math.max(0, st.Value - S.SprintDrain * step)
				st.LastSpend = t
				if st.Value <= 0 then
					st.Exhausted = true
				end
			elseif t - st.LastSpend >= S.RegenDelay then
				st.Value = math.min(m, st.Value + S.Regen * ctx.PowerupService.StaminaRegenMult(p) * step)
			end
			if st.Exhausted and st.Value >= S.MinToSprint then
				st.Exhausted = false
			end
			local shown = math.floor(st.Value + 0.5)
			if shown ~= st.Pushed then
				st.Pushed = shown
				p:SetAttribute("Stamina", shown)
				p:SetAttribute("MaxStamina", math.floor(m + 0.5))
			end
			if p:GetAttribute("Sprinting") ~= st.Sprinting then
				p:SetAttribute("Sprinting", st.Sprinting)
			end
			if p:GetAttribute("Exhausted") ~= st.Exhausted then
				p:SetAttribute("Exhausted", st.Exhausted)
			end
		end
	end)
end

-- Movement speed multiplier (sprint, exhaustion).
function StaminaService.SpeedMult(p: Player): number
	local st = states[p]
	if not st then
		return 1
	end
	if st.Sprinting then
		return S.SprintMult * ctx.PowerupService.SprintMult(p)
	end
	return if st.Exhausted then S.ExhaustedMult else 1
end

function StaminaService.Get(p: Player): number
	return get(p).Value
end

-- Spends stamina for an action. Returns false (nothing spent) if there isn't enough.
function StaminaService.Spend(p: Player, amount: number): boolean
	local st = get(p)
	if st.Value < amount then
		return false
	end
	st.Value -= amount
	st.LastSpend = os.clock()
	return true
end

-- Drains up to `amount` (used by blocking); returns what was drained.
function StaminaService.Drain(p: Player, amount: number): number
	local st = get(p)
	local d = math.min(st.Value, amount)
	st.Value -= d
	st.LastSpend = os.clock()
	if st.Value <= 0 then
		st.Exhausted = true
	end
	return d
end

-- Fresh bar on (re)spawn.
function StaminaService.OnSpawn(p: Player)
	local st = get(p)
	st.Value = max(p)
	st.Exhausted = false
	st.Pushed = -1
end

-- Short boost (Second Wind).
function StaminaService.Refill(p: Player, amount: number)
	local st = get(p)
	st.Value = math.min(max(p), st.Value + amount)
	st.Exhausted = false
end

return StaminaService
