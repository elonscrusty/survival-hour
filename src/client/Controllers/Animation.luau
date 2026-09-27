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
}

local rigs: { [Model]: Rig } = {}
local localSwingAt = 0
local localSwingItem = "Fists"
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
	}
end

-- Returns target offsets for right arm, left arm, waist, neck.
local function pose(rig: Rig, t: number): (CFrame, CFrame, CFrame, CFrame)
	local char = rig.Char
	local action = char:GetAttribute("Action") :: string?
	local at = (char:GetAttribute("ActionAt") :: number?) or 0
	local item = (char:GetAttribute("ActionItem") :: string?) or (char:GetAttribute("HeldId") :: string?) or "Fists"
	local elapsed = workspace:GetServerTimeNow() - at
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
	if isLocal and os.clock() - localSwingAt < 0.4 then
		action = "Attack"
		item = localSwingItem
		elapsed = os.clock() - localSwingAt
	end

	if (isLocal and localDraw) then
		r = raise(80, 1) * CFrame.Angles(0, rad(-20), 0)
		l = raise(90, -1)
		w = CFrame.Angles(0, rad(-25), 0)
		return r, l, w, n
	end

	if char:GetAttribute("Blocking") then
		r = raise(75, 1) * CFrame.Angles(0, rad(35), 0)
		w = CFrame.Angles(0, rad(10), 0)
	end

	if action == "Attack" and elapsed < 0.45 then
		local k = math.clamp(elapsed / 0.35, 0, 1)
		if item == "Spear" or item == "CrudeSpear" then
			-- thrust
			local ext = math.sin(k * math.pi)
			r = raise(70 + 20 * ext, 1)
			w = CFrame.Angles(0, rad(-15 * ext), 0)
		elseif item == "Bow" then
			r = raise(80 * (1 - k), 1)
			l = raise(90, -1)
		elseif item == "Pistol" or item == "Rifle" then
			local kick = math.max(0, 1 - k * 3)
			r = raise(90 + 15 * kick, 1)
			l = if item == "Rifle" then raise(80, -1) else ID
		elseif string.find(item, "Axe$") or string.find(item, "Pickaxe$") or item == "RepairHammer" then
			-- overhead chop
			local a = if k < 0.3 then 150 * (k / 0.3) else 150 - 190 * ((k - 0.3) / 0.7)
			r = raise(a, 1)
			w = CFrame.Angles(rad(-10 * math.sin(k * math.pi)), 0, 0)
		else
			-- horizontal slash (sword, fists, shield bash)
			local a = if k < 0.25 then -60 * (k / 0.25) else -60 + 140 * ((k - 0.25) / 0.75)
			r = raise(80, 1) * CFrame.Angles(0, rad(a), 0)
			w = CFrame.Angles(0, rad(-a * 0.3), 0)
		end
	elseif action == "Chop" then
		local k = (phase % 3) / 3
		r = raise(if k < 0.4 then 140 * (k / 0.4) else 140 - 180 * ((k - 0.4) / 0.6), 1)
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
		r = raise(60, 1) * CFrame.Angles(0, rad(40 + 15 * math.sin(phase * 2)), 0)
		l = raise(60, -1) * CFrame.Angles(0, rad(-40 - 15 * math.sin(phase * 2)), 0)
		n = CFrame.Angles(rad(-20), 0, 0)
	elseif action == "Open" or action == "Steal" then
		w = CFrame.Angles(rad(-30), 0, 0)
		r = raise(55 + 30 * math.sin(phase * 2), 1)
		l = raise(55 + 30 * math.sin(phase * 2 + 1.5), -1)
	elseif action == "Ability" and elapsed < 0.6 then
		local k = math.sin(math.clamp(elapsed / 0.6, 0, 1) * math.pi)
		r = raise(150 * k, 1)
		l = raise(150 * k, -1)
		n = CFrame.Angles(rad(15 * k), 0, 0)
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
		if a.Kind == "Attack" or a.Kind == "Release" then
			localSwingAt = os.clock()
			localSwingItem = a.Item
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
