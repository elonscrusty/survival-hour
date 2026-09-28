--!nonstrict
-- Plays uploaded animation clips (Shared/AnimationIds) on characters and
-- animals, chosen by Logic/AnimClips. When nothing is uploaded for a state,
-- Set() returns false and the caller keeps animating procedurally.
--
-- Who plays what: each client plays clips on its own character (Roblox
-- replicates those tracks to everyone) and on nearby animals (local only).
-- Other players' characters are never driven from here; Playing() tells the
-- procedural animator to stand aside while their replicated clip runs.

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
}

local FADE = 0.12
local LOAD_TIMEOUT = 4 -- a clip still empty this long after its first play is treated as missing

local slots: { [Model]: Slot } = setmetatable({}, { __mode = "k" }) :: any
local usable: { [string]: number } = table.clone(AnimationIds)
local firstPlay: { [string]: number } = {}
local ours: { [string]: boolean } = {} -- asset id digits of every clip
for _, id in AnimationIds do
	ours[tostring(id)] = true
end

-- True once at least one clip id has been filled in (skips all work otherwise).
AnimTracks.Enabled = next(AnimationIds) ~= nil

local function animatorOf(model: Model): Animator?
	local host = model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildOfClass("AnimationController")
	return host and host:FindFirstChildOfClass("Animator")
end

local function slotOf(model: Model): Slot
	local s = slots[model]
	if not s then
		s = { Animator = nil, Tracks = {}, Name = nil, Key = nil, Hold = false }
		slots[model] = s
	end
	if not s.Animator or not s.Animator.Parent then
		s.Animator = animatorOf(model)
		s.Tracks = {}
		s.Name, s.Key, s.Hold = nil, nil, false
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

-- A clip that never loads (bad id, not owned by the experience owner) is dropped.
local function loaded(name: string, track: AnimationTrack): boolean
	if track.Length > 0 then
		return true
	end
	if os.clock() - (firstPlay[name] or os.clock()) > LOAD_TIMEOUT then
		warn("[AnimTracks] clip " .. name .. " didn't load; using the procedural animation")
		usable[name] = nil
	end
	return false
end

-- Name of the clip currently playing on `model` (nil when procedural).
function AnimTracks.Current(model: Model): string?
	local s = slots[model]
	return s and s.Name
end

-- Plays the first uploaded clip of `pick` on `model`. One-shot picks restart when
-- `key` (e.g. the action's start time) changes; Hold picks freeze on the last frame.
-- Returns true while a loaded clip is in charge of the model (false while it is
-- still loading or after a one-shot finished, so the procedural pose covers it).
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
	local track = s.Tracks[name]
	if s.Name == name and s.Key == k and track then
		if not loaded(name, track) then
			if not usable[name] then
				stop(s)
			end
			return false
		end
		if not track.IsPlaying then
			if not s.Hold then
				return false -- one-shot over: procedural for the rest of the window
			end
			track:Play(0)
			track.TimePosition = math.max(0, track.Length - 0.03)
			track:AdjustSpeed(0)
		elseif s.Hold and track.TimePosition >= track.Length - 0.1 then
			track:AdjustSpeed(0)
		end
		return true
	end
	stop(s)
	if not track then
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://" .. tostring(id)
		local ok, t = pcall(function()
			return (s.Animator :: Animator):LoadAnimation(anim)
		end)
		if not ok then
			usable[name] = nil
			return false
		end
		track = t
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = not pick.OneShot and not pick.Hold
		s.Tracks[name] = track
	end
	firstPlay[name] = firstPlay[name] or os.clock()
	track:Play(FADE)
	track:AdjustSpeed(1)
	s.Name = name
	s.Key = k
	s.Hold = pick.Hold
	return loaded(name, track)
end

-- True while one of our clips plays on `model` (e.g. replicated from another
-- player's client), so procedural offsets don't stack on top of it.
function AnimTracks.Playing(model: Model): boolean
	if not AnimTracks.Enabled then
		return false
	end
	local animator = animatorOf(model)
	if not animator then
		return false
	end
	for _, track in animator:GetPlayingAnimationTracks() do
		local digits = track.Animation and string.match(track.Animation.AnimationId, "%d+$")
		if digits and ours[digits] and track.WeightCurrent > 0.5 then
			return true
		end
	end
	return false
end

return AnimTracks
