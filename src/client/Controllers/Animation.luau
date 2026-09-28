--!nonstrict
-- Procedural character animation layered over the default Roblox animations.
--
-- No KeyframeSequence assets were uploaded for this project (DECISIONS D34),
-- so actions are expressed by pre-multiplying each joint's `Transform` right
-- after the Animator writes it (PreSimulation). That equals offsetting C0, but
-- also works for AnimationConstraint joints (avatar joint upgrade), whose C0
-- doesn't exist. The server replicates `Action`, `ActionAt`, `ActionItem`,
-- `Blocking` and `HeldId` attributes; every client animates every nearby
-- character from them. The local player also gets instant predicted swings.
--
-- Supports R15 (RightShoulder/LeftShoulder/Waist/Neck) and R6 joints, as
-- Motor6D or AnimationConstraint.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local State = require("../State")
local Input = require("./Input")

local Animation = {}

local player = Players.LocalPlayer

-- Motor6D or AnimationConstraint; both expose a writable `Transform`.
type Joint = any

type Rig = {
	Char: Model,
	R: Joint?,
	L: Joint?,
	Waist: Joint?,
	Neck: Joint?,
	R15: boolean,
	Cur: { r: CFrame, l: CFrame, w: CFrame, n: CFrame },
	-- Per joint: the animated Transform we offset last frame, and what we wrote.
	-- If the Animator leaves a joint alone, Transform still holds our write, so
	-- we reuse the stored base instead of stacking offsets.
	Base: { [Joint]: CFrame },
	Wrote: { [Joint]: CFrame },
	-- reaction bookkeeping (client-side only)
	Held: string?,
	EquipAt: number,
	WasAir: boolean,
	LandAt: number,
}

local rigs: { [Model]: Rig } = {}
local localSwingAt = 0
local localSwingItem = "Fists"
local localSwingHeavy = false
local localDraw = false

local ID = CFrame.identity
local rad = math.rad

local function findRig(char: Model): Rig?
	local r15 = char:FindFirstChild("UpperTorso") ~= nil
	local R, L, W, N
	if r15 then
		local rua = char:FindFirstChild("RightUpperArm")
		local lua = char:FindFirstChild("LeftUpperArm")
		local ut = char:FindFirstChild("UpperTorso")
		local head = char:FindFirstChild("Head")
		R = rua and rua:FindFirstChild("RightShoulder")
		L = lua and lua:FindFirstChild("LeftShoulder")
		W = ut and ut:FindFirstChild("Waist")
		N = head and head:FindFirstChild("Neck")
	else
		local torso = char:FindFirstChild("Torso")
		if torso then
			R = torso:FindFirstChild("Right Shoulder")
			L = torso:FindFirstChild("Left Shoulder")
			N = torso:FindFirstChild("Neck")
		end
	end
	if not R or not L then
		return nil
	end
	return {
		Char = char,
		R = R,
		L = L,
		Waist = W,
		Neck = N,
		R15 = r15,
		Cur = { r = ID, l = ID, w = ID, n = ID },
		Base = {},
		Wrote = {},
		Held = char:GetAttribute("HeldId"),
		EquipAt = 0,
		WasAir = false,
		LandAt = 0,
	}
end

local function remoteDraw(owner: Player?, isLocal: boolean, held: string): boolean
	return not isLocal and owner ~= nil and owner:GetAttribute("Drawing") == true and (held == "Bow" or held == "CrudeBow" or held == "HuntingBow" or held == "Crossbow")
end

local function isBow(item: string): boolean
	return item == "Bow" or item == "CrudeBow" or item == "HuntingBow"
end

local function isChopper(item: string): boolean
	return string.find(item, "Axe$") ~= nil or string.find(item, "Pickaxe$") ~= nil or item == "RepairHammer" or item == "Sledgehammer" or item == "Crowbar"
end

-- Returns target offsets for right arm, left arm, waist, neck.
-- Base pose from the current action, then additive reaction layers (hit flinch,
-- block impact, guard break, landing, equip, sprint lean, exhausted breathing).
local function pose(rig: Rig, t: number): (CFrame, CFrame, CFrame, CFrame)
	local char = rig.Char
	local owner = Players:GetPlayerFromCharacter(char)
	local now = workspace:GetServerTimeNow()
	local action = char:GetAttribute("Action") :: string?
	local at = (char:GetAttribute("ActionAt") :: number?) or 0
	local item = (char:GetAttribute("ActionItem") :: string?) or (char:GetAttribute("HeldId") :: string?) or "Fists"
	local heavy = char:GetAttribute("ActionHeavy") == true
	local variant = (char:GetAttribute("ActionVariant") :: number?) or 0
	local elapsed = now - at
	local isLocal = char == player.Character
	local phase = t * 6
	local r, l, w, n = ID, ID, ID, ID
	-- R6 shoulders rotate around Z; convert "forward raise" to the right axis.
	local function raise(deg: number, side: number): CFrame
		if rig.R15 then
			return CFrame.Angles(rad(deg), 0, 0)
		end
		return CFrame.Angles(0, 0, rad(deg) * side)
	end

	-- Local prediction for instant feedback
	if isLocal and os.clock() - localSwingAt < 0.6 then
		action = "Attack"
		item = localSwingItem
		heavy = localSwingHeavy
		elapsed = os.clock() - localSwingAt
	end

	local held = (char:GetAttribute("HeldId") :: string?) or "Fists"
	if held ~= rig.Held then
		rig.Held = held
		rig.EquipAt = t
	end

	if isLocal and localDraw then
		-- bow draw: bow arm out, string hand back to the cheek
		r = raise(85, 1) * CFrame.Angles(0, rad(-35), 0)
		l = raise(90, -1)
		w = CFrame.Angles(0, rad(-30), 0)
		n = CFrame.Angles(0, rad(20), 0)
		return r, l, w, n
	end

	if remoteDraw(owner, isLocal, held) then
		r = raise(85, 1) * CFrame.Angles(0, rad(-35), 0)
		l = raise(90, -1)
		w = CFrame.Angles(0, rad(-30), 0)
		n = CFrame.Angles(0, rad(20), 0)
		return r, l, w, n
	end

	-- Blocking is a Player attribute (set by CombatService's BlockState handler)
	if (owner and owner:GetAttribute("Blocking")) or char:GetAttribute("Blocking") then
		-- guard: weapon across the body, off hand braced
		r = raise(78, 1) * CFrame.Angles(0, rad(40), 0)
		l = raise(55, -1) * CFrame.Angles(0, rad(-25), 0)
		w = CFrame.Angles(0, rad(12), 0)
	elseif held == "Crossbow" or held == "Rifle" or held == "Pistol" then
		-- ranged ready: weapon held low and forward
		r = raise(35, 1)
		l = if held == "Pistol" then ID else raise(30, -1)
	elseif isBow(held) then
		l = raise(25, -1)
	end

	local swingLen = if heavy then 0.62 else 0.38
	if action == "Attack" and elapsed < swingLen + 0.08 then
		local k = math.clamp(elapsed / swingLen, 0, 1)
		if item == "Spear" or item == "CrudeSpear" then
			-- thrust (heavy: longer lunge)
			local ext = math.sin(k * math.pi)
			r = raise(70 + (if heavy then 30 else 20) * ext, 1)
			l = raise(50 * ext, -1)
			w = CFrame.Angles(rad(-8 * ext), rad(-15 * ext), 0)
		elseif isBow(item) then
			r = raise(85 * (1 - k), 1)
			l = raise(90, -1)
		elseif item == "Crossbow" or item == "Pistol" or item == "Rifle" then
			local kick = math.max(0, 1 - k * 3)
			r = raise(90 + 15 * kick, 1)
			l = if item == "Pistol" then ID else raise(80, -1)
			n = CFrame.Angles(rad(-4 * kick), 0, 0)
		elseif isChopper(item) then
			-- overhead chop; heavy = bigger wind-up with a waist twist
			local wind = if heavy then 0.45 else 0.3
			local top = if heavy then 170 else 150
			local a = if k < wind then top * (k / wind) else top - (top + 40) * ((k - wind) / (1 - wind))
			r = raise(a, 1)
			l = raise(a * 0.35, -1)
			w = CFrame.Angles(rad(-12 * math.sin(k * math.pi)), rad((if heavy then 25 else 10) * (1 - k)), 0)
		else
			-- horizontal slash; alternates direction, heavy is a wide wind-up
			local dir = if variant == 0 then 1 else -1
			local wind = if heavy then 0.4 else 0.25
			local span = if heavy then 170 else 140
			local a = if k < wind then -60 * dir * (k / wind) else dir * (-60 + span * ((k - wind) / (1 - wind)))
			r = raise(if variant == 0 then 80 else 95, 1) * CFrame.Angles(0, rad(a), 0)
			l = raise(30, -1)
			w = CFrame.Angles(0, rad(-a * (if heavy then 0.45 else 0.3)), 0)
		end
	elseif action == "Chop" or action == "Breach" then
		-- repeated overhead strikes; breaching is slower and heavier
		local rate = if action == "Breach" then 2.4 else 3
		local k = (phase % rate) / rate
		local a = if k < 0.4 then 150 * (k / 0.4) else 150 - 190 * ((k - 0.4) / 0.6)
		r = raise(a, 1)
		l = raise(a * 0.4, -1)
		w = CFrame.Angles(rad(-10 * math.max(0, math.sin(k * math.pi * 2))), rad(12), 0)
	elseif action == "Mine" then
		-- pickaxe: bent over, swinging down at the rock
		local k = (phase % 2.6) / 2.6
		local a = if k < 0.45 then 135 * (k / 0.45) else 135 - 175 * ((k - 0.45) / 0.55)
		r = raise(a, 1)
		l = raise(a * 0.5, -1)
		w = CFrame.Angles(rad(-18), 0, 0)
		n = CFrame.Angles(rad(-15), 0, 0)
	elseif action == "Gather" or action == "Fill" then
		w = CFrame.Angles(rad(-35), 0, 0)
		n = CFrame.Angles(rad(-15), 0, 0)
		r = raise(40 + 25 * math.sin(phase * 1.5), 1)
		l = raise(40 + 25 * math.sin(phase * 1.5 + math.pi), -1)
	elseif action == "Pour" then
		r = raise(95, 1) * CFrame.Angles(0, 0, rad(-40 + 8 * math.sin(phase)))
		w = CFrame.Angles(rad(-12), 0, 0)
		n = CFrame.Angles(rad(-20), 0, 0)
	elseif action == "Bandage" then
		-- wrapping: both hands circle over the forearm, head down to watch
		r = raise(60, 1) * CFrame.Angles(0, rad(40 + 15 * math.sin(phase * 2)), 0)
		l = raise(60, -1) * CFrame.Angles(0, rad(-40 - 15 * math.sin(phase * 2)), 0)
		n = CFrame.Angles(rad(-25), 0, 0)
		w = CFrame.Angles(rad(-6), 0, 0)
	elseif action == "Craft" and elapsed < 1.2 then
		-- quick hammering at the bench
		local k = (phase * 1.4) % 1
		r = raise(70 + 40 * math.max(0, math.sin(k * math.pi * 2)), 1)
		l = raise(55, -1) * CFrame.Angles(0, rad(-20), 0)
		w = CFrame.Angles(rad(-15), 0, 0)
		n = CFrame.Angles(rad(-20), 0, 0)
	elseif action == "Craft" then
		-- long craft channel: hands busy at chest height
		r = raise(55 + 12 * math.sin(phase * 2.2), 1) * CFrame.Angles(0, rad(20), 0)
		l = raise(55 + 12 * math.sin(phase * 2.2 + 1.3), -1) * CFrame.Angles(0, rad(-20), 0)
		w = CFrame.Angles(rad(-12), 0, 0)
		n = CFrame.Angles(rad(-22), 0, 0)
	elseif action == "Build" and elapsed < 0.9 then
		-- two hammer taps
		local k = (elapsed / 0.45) % 1
		r = raise(if k < 0.4 then 120 * (k / 0.4) else 120 - 110 * ((k - 0.4) / 0.6), 1)
		w = CFrame.Angles(rad(-10), 0, 0)
	elseif action == "Feed" and elapsed < 0.7 then
		-- toss wood onto the fire
		local k = elapsed / 0.7
		local a = if k < 0.4 then 20 + 60 * (k / 0.4) else 80 - 40 * ((k - 0.4) / 0.6)
		r = raise(a, 1)
		l = raise(a, -1)
		w = CFrame.Angles(rad(-20 * math.sin(k * math.pi)), 0, 0)
	elseif action == "Open" or action == "Steal" then
		w = CFrame.Angles(rad(-30), 0, 0)
		r = raise(55 + 30 * math.sin(phase * 2), 1)
		l = raise(55 + 30 * math.sin(phase * 2 + 1.5), -1)
	elseif action == "Emote" and elapsed < 2 then
		local k = math.sin(math.clamp(elapsed / 2, 0, 1) * math.pi)
		if item == "EmoteWave" then
			r = raise(150 * k, 1) * CFrame.Angles(0, 0, rad(25 * math.sin(elapsed * 10)))
		elseif item == "EmoteFlex" then
			r = raise(90 * k, 1) * CFrame.Angles(rad(-60 * k), 0, 0)
			l = raise(90 * k, -1) * CFrame.Angles(rad(-60 * k), 0, 0)
		else
			r = raise(70 * k, 1)
			l = raise(70 * k, -1)
			w = CFrame.Angles(rad(-15 * k), 0, 0)
		end
	elseif action == "Victory" and elapsed < 12 then
		if item == "PoseThrone" then
			w = CFrame.Angles(rad(10), 0, 0)
			r = raise(35, 1)
			l = raise(35, -1)
		elseif item == "PoseAxe" then
			r = raise(160, 1) * CFrame.Angles(0, 0, rad(-30))
		else
			r = raise(170, 1)
			n = CFrame.Angles(rad(15), 0, 0)
		end
	end

	-- Reaction layers ---------------------------------------------------------------
	local hum = char:FindFirstChildOfClass("Humanoid")
	-- equip: the new item comes up from the hip
	local eq = t - rig.EquipAt
	if eq < 0.28 and held ~= "Fists" then
		r = raise(-35 * (1 - eq / 0.28), 1) * r
	end
	-- airborne arms lift a little; landing dips the torso
	local air = hum ~= nil and hum.FloorMaterial == Enum.Material.Air
	if air then
		l = raise(18, -1) * l
		r = raise(12, 1) * r
	elseif rig.WasAir then
		rig.LandAt = t
	end
	rig.WasAir = air
	local land = t - rig.LandAt
	if land < 0.25 then
		w = CFrame.Angles(rad(-10 * math.sin(land / 0.25 * math.pi)), 0, 0) * w
	end
	-- sprint lean / exhausted breathing
	if owner and owner:GetAttribute("Sprinting") and hum and hum.MoveDirection.Magnitude > 0.1 then
		w = CFrame.Angles(rad(-7), 0, 0) * w
	elseif owner and owner:GetAttribute("Exhausted") then
		w = CFrame.Angles(rad(-8 + 3 * math.sin(t * 5)), 0, 0) * w
		n = CFrame.Angles(rad(4 * math.sin(t * 5)), 0, 0) * n
	end
	-- guard broken: arms drop and the torso staggers
	if owner and (owner:GetAttribute("GuardBrokenUntil") or 0) > now then
		r = raise(-15, 1)
		l = raise(-15, -1)
		w = CFrame.Angles(rad(8), rad(10 * math.sin(t * 9)), 0) * w
	end
	-- block impact: the guard is knocked back
	local bh = now - ((char:GetAttribute("BlockHitAt") :: number?) or 0)
	if bh < 0.22 then
		local k = math.sin(bh / 0.22 * math.pi)
		r = raise(-18 * k, 1) * r
		w = CFrame.Angles(rad(6 * k), 0, 0) * w
	end
	-- hit flinch: head and torso snap away from the blow
	local hit = now - ((char:GetAttribute("HitAt") :: number?) or 0)
	if hit < 0.3 then
		local k = math.sin(hit / 0.3 * math.pi)
		w = CFrame.Angles(rad(10 * k), 0, rad(4 * k)) * w
		n = CFrame.Angles(rad(12 * k), 0, 0) * n
	end
	return r, l, w, n
end

-- C0 * (off * T) == (C0 * off) * T, so this matches the old C0 offset.
local function offset(rig: Rig, joint: Joint?, off: CFrame)
	if not joint then
		return
	end
	local cur = joint.Transform
	local base = if rig.Wrote[joint] == cur then rig.Base[joint] or cur else cur
	local out = off * base
	rig.Base[joint] = base
	rig.Wrote[joint] = out
	joint.Transform = out
end

local function apply(rig: Rig, dt: number, t: number)
	local r, l, w, n = pose(rig, t)
	local a = math.clamp(dt * 18, 0, 1)
	rig.Cur.r = rig.Cur.r:Lerp(r, a)
	rig.Cur.l = rig.Cur.l:Lerp(l, a)
	rig.Cur.w = rig.Cur.w:Lerp(w, a)
	rig.Cur.n = rig.Cur.n:Lerp(n, a)
	offset(rig, rig.R, rig.Cur.r)
	offset(rig, rig.L, rig.Cur.l)
	offset(rig, rig.Waist, rig.Cur.w)
	offset(rig, rig.Neck, rig.Cur.n)
end

function Animation.Start()
	State.On("LocalAction", function(a)
		if a.Kind == "Attack" or a.Kind == "Heavy" or a.Kind == "Release" then
			localSwingAt = os.clock()
			localSwingItem = a.Item
			localSwingHeavy = a.Kind == "Heavy"
			localDraw = false
		elseif a.Kind == "Draw" then
			localDraw = true
		end
	end)
	-- PreSimulation runs after the Animator has written this frame's Transforms.
	RunService.PreSimulation:Connect(function(dt)
		local cam = workspace.CurrentCamera.CFrame.Position
		local t = os.clock()
		if not Input.Down.Attack then
			localDraw = false
		end
		for _, p in Players:GetPlayers() do
			local char = p.Character
			if char and char.Parent then
				local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and (root.Position - cam).Magnitude < 150 then
					local rig = rigs[char]
					if rig == nil or not rig.R or not rig.R.Parent then
						local found = findRig(char)
						if found then
							rigs[char] = found
							rig = found
						end
					end
					if rig then
						apply(rig, dt, t)
					end
				end
			end
		end
		for char in rigs do
			if not char.Parent then
				rigs[char] = nil
			end
		end
	end)
end

return Animation
