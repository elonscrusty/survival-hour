--!nonstrict
-- Plays uploaded animation clips (Shared/AnimationIds) on characters and
-- animals, chosen by Logic/AnimClips. Client-side only, like the procedural
-- animation it replaces clip by clip: when nothing is uploaded for a state,
-- Set() returns false and the caller keeps animating procedurally.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationIds = require(ReplicatedStorage.Shared.AnimationIds)
local AnimClips = require(ReplicatedStorage.Shared.Logic.AnimClips)

local AnimTracks = {}

type Slot = {
	Animator: Animator?,
	Tracks: { [string]: AnimationTrack },
	Name: string?,
	Key: any,
	Hold: boolean,
	PlayedAt: number,
}

local FADE = 0.12

local LOAD_TIMEOUT = 4 -- a clip still empty after this is treated as missing (bad id / not owned)

local slots: { [Model]: Slot } = setmetatable({}, { __mode = "k" }) :: any
local usable: { [string]: number } = table.clone(AnimationIds)

-- True once at least one clip id has been filled in (skips all work otherwise).
AnimTracks.Enabled = next(AnimationIds) ~= nil

local function animatorOf(model: Model): Animator?
	local host = model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildOfClass("AnimationController")
	if not host then
		return nil
	end
	local a = host:FindFirstChildOfClass("Animator")
	if not a then
		-- Server-built animals may have none; a client-made Animator plays locally.
		a = Instance.new("Animator")
		a.Parent = host
	end
	return a
end

local function slotOf(model: Model): Slot
	local s = slots[model]
	if not s then
		s = { Animator = nil, Tracks = {}, Name = nil, Key = nil, Hold = false, PlayedAt = 0 }
		slots[model] = s
	end
	if not s.Animator or not s.Animator.Parent then
		s.Animator = animatorOf(model)
		s.Tracks = {}
	end
	return s
end

local function stop(s: Slot)
	local cur = s.Name and s.Tracks[s.Name]
	if cur then
		cur:Stop(FADE)
	end
	s.Name = nil
	s.Key = nil
end

-- Plays the first uploaded clip of `pick` on `model`. One-shot picks restart when
-- `key` (e.g. the action's start time) changes; Hold picks freeze on the last frame.
-- Returns true while a loaded clip is in charge of the model (false while it is
-- still loading, so the procedural pose covers the gap).
function AnimTracks.Set(model: Model, pick: AnimClips.Pick, key: any): boolean
	if not AnimTracks.Enabled then
		return false
	end
	local name, id = AnimClips.First(pick, usable)
	local s = slots[model]
	if not name then
		if s and s.Name then
			stop(s)
		end
		return false
	end
	s = slotOf(model)
	if not s.Animator then
		return false
	end
	local k = if pick.OneShot then key else nil
	if s.Name == name and s.Key == k then
		local track = s.Tracks[name]
		if not track then
			return false
		end
		if track.Length <= 0 then
			if os.clock() - s.PlayedAt > LOAD_TIMEOUT then
				warn("[AnimTracks] clip " .. name .. " didn't load; using the procedural animation")
				usable[name] = nil
				stop(s)
			end
			return false
		end
		if s.Hold and track.Length > 0 and track.TimePosition >= track.Length - 0.05 then
			track:AdjustSpeed(0)
		end
		return true
	end
	stop(s)
	local track = s.Tracks[name]
	if not track then
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://" .. tostring(id)
		local ok, t = pcall(function()
			return (s.Animator :: Animator):LoadAnimation(anim)
		end)
		if not ok then
			return false
		end
		track = t
		track.Priority = Enum.AnimationPriority.Action
		s.Tracks[name] = track
	end
	track:Play(FADE)
	track:AdjustSpeed(1)
	s.Name = name
	s.Key = k
	s.Hold = pick.Hold
	s.PlayedAt = os.clock()
	return track.Length > 0
end

return AnimTracks
