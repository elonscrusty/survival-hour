-- Procedural pet animation (tested by tests/PetAnim.spec.luau; mirrored in
-- blender/build.py for the preview video). Pure numbers: for each joint it returns
-- a small offset {rx, ry, rz, x, y, z} (radians / studs, Roblox axes, pet faces -Z)
-- that the client applies on top of the joint's rest pose:
--   part-built pets: Weld.C0 = rest * CFrame.new(x, y, z) * CFrame.Angles(rx, ry, rz)
--   mesh pets:       Bone.Transform = the same CFrame (axes fixed up by BoneAxis)
-- Joints form a tree: Body (everything hangs off it), Head, EarL/EarR (on Head),
-- Tail, WingL/WingR, LegFL/LegFR/LegBL/LegBR. Missing joints are simply skipped.
local PetAnim = {}

PetAnim.Joints = { "Body", "Head", "EarL", "EarR", "Tail", "WingL", "WingR", "LegFL", "LegFR", "LegBL", "LegBR" }

export type Offset = { rx: number, ry: number, rz: number, x: number, y: number, z: number }
export type State = {
	Run: number, -- 0 idle .. 1 full gallop
	Air: number, -- 0 grounded .. 1 mid-jump
	Land: number, -- landing squash impulse, 1 on touchdown, decays to 0
	Happy: number, -- 0..1: excited hopping (hatch reveal, level up, win)
	Look: number, -- idle head turn, radians
	Size: number, -- pet height in studs (scales bob distances)
}
export type Pose = { [string]: Offset }

local sin, abs = math.sin, math.abs

local function off(): Offset
	return { rx = 0, ry = 0, rz = 0, x = 0, y = 0, z = 0 }
end

-- How fast the run cycle turns (radians per second) at a given run amount.
function PetAnim.CycleSpeed(run: number): number
	return 4 + 9 * math.clamp(run, 0, 1)
end

-- t: seconds (idle motions); phase: run cycle angle (advance it by CycleSpeed * dt).
function PetAnim.Sample(s: State, t: number, phase: number): Pose
	local run = math.clamp(s.Run, 0, 1)
	local air = math.clamp(s.Air, 0, 1)
	local land = math.clamp(s.Land, 0, 1)
	local happy = math.clamp(s.Happy, 0, 1)
	local ground = 1 - air
	local idle = (1 - run) * ground
	local k = math.max(s.Size, 1) / 4 -- bob distances were tuned on a 4-stud-tall pet
	local p: Pose = {}
	for _, j in PetAnim.Joints do
		p[j] = off()
	end

	-- Body: breathe when idle, bounce and rock when running, stretch in the air,
	-- squash on landing, hop when happy.
	local b = p.Body
	b.y = (0.05 * sin(t * 2.2) * idle + 0.32 * abs(sin(phase)) * run * ground - 0.3 * land + 0.7 * abs(sin(t * 9)) * happy) * k
	b.rx = 0.07 * sin(phase * 2) * run * ground - 0.16 * air + 0.12 * land
	b.rz = 0.05 * sin(phase) * run * ground + 0.06 * sin(t * 9) * happy
	b.z = -0.08 * run * k

	-- Head: looks around when idle, counters the body when running, tilts when happy.
	local h = p.Head
	h.ry = s.Look * idle
	h.rx = 0.06 * sin(t * 2.2 + 0.7) * idle - 0.1 * sin(phase * 2 + 0.6) * run * ground + 0.12 * air - 0.15 * land
	h.rz = 0.18 * sin(t * 4.5) * happy + 0.05 * sin(t * 0.9) * idle

	-- Ears: twitch when idle, sweep back when running fast, flop on landing.
	for i, j in { "EarL", "EarR" } do
		local side = if i == 1 then 1 else -1
		local e = p[j]
		local twitch = math.max(0, sin(t * 1.3 + i * 2.1)) ^ 12
		e.rz = side * (0.12 * twitch * idle + 0.1 * sin(phase * 2) * run + 0.25 * land + 0.2 * sin(t * 9 + i) * happy)
		e.rx = 0.45 * run + 0.25 * air - 0.2 * land
	end

	-- Tail: wags (fast when happy), lifts while running.
	local tl = p.Tail
	tl.ry = 0.35 * sin(t * 4) * idle + 0.25 * sin(phase) * run + 0.6 * sin(t * 15) * happy
	tl.rx = -0.35 * run - 0.2 * air + 0.1 * sin(t * 2.2) * idle

	-- Wings: slow fold-breathe idle, flap with the stride, spread wide in the air.
	for i, j in { "WingL", "WingR" } do
		local side = if i == 1 then 1 else -1
		local w = p[j]
		w.rz = side * (0.08 * sin(t * 1.8) * idle + 0.55 * sin(phase * 2) * run * ground + (0.75 + 0.45 * sin(t * 14)) * air + 0.5 * sin(t * 12) * happy)
		w.ry = side * 0.15 * run
	end

	-- Legs: diagonal pairs swing opposite (a trot), tuck in the air, splay on landing.
	local legs = { LegFL = 0, LegBR = 0, LegFR = math.pi, LegBL = math.pi }
	for j, ph in legs do
		local front = string.sub(j, 4, 4) == "F"
		local l = p[j]
		local swing = sin(phase + ph)
		l.rx = 0.85 * swing * run * ground + (if front then -0.75 else 0.65) * air + 0.15 * sin(t * 9 + ph) * happy
		l.y = math.max(0, -sin(phase + ph)) * 0.22 * run * ground * k -- lift the foot on the way forward
		l.rz = (if string.sub(j, 5, 5) == "L" then 1 else -1) * 0.12 * land
	end
	return p
end

-- Eye openness 0..1: a quick blink every few seconds (seeded so pets don't sync).
function PetAnim.Blink(t: number, seed: number): number
	local period = 3.2 + (seed % 7) * 0.35
	local x = (t + seed * 0.37) % period
	if x < 0.12 then
		return 1 - math.sin(x / 0.12 * math.pi)
	end
	return 1
end

return PetAnim
