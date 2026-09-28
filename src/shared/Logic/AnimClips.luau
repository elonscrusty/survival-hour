--!strict
-- Which uploaded animation clip (AnimationIds) plays for a character or animal
-- state. Pure so the mapping is tested (tests/AnimClips.spec.luau). Each result
-- lists candidates in order of preference; the first one with an uploaded id
-- plays, and with none the procedural animation stays in charge.

local AnimClips = {}

export type Pick = { Clips: { string }, OneShot: boolean, Hold: boolean }

export type PlayerState = {
	Action: string?,
	Item: string, -- the action's item (or the held item)
	Held: string,
	Heavy: boolean,
	Elapsed: number, -- seconds since the action started
	Blocking: boolean,
	Drawing: boolean,
	DrawAge: number, -- seconds since the bow / crossbow draw started
}

export type AnimalState = {
	Species: string,
	Tele: string?, -- telegraph (Lunge, Roar, Swipe, Swoop, Strike, Dead)
	TeleAge: number,
	Speed: number, -- ground speed, studs/s
}

-- Clip lists for every name the owner can upload (the ChatGPT animation prompt).
AnimClips.PlayerClips = {
	"SwingLight", "SwingHeavy", "SpearThrust", "BowDraw", "BowHold", "CrossbowAim", "Block",
	"Chop", "Breach", "Mine", "Gather", "Fill", "Pour", "Bandage", "Craft", "Build", "Feed", "Eat", "Search",
	"EmoteWave", "EmoteFlex", "EmoteWarmHands", "VictoryTorch", "VictoryAxe", "VictoryThrone",
}
AnimClips.AnimalClips = {
	"WolfWalk", "WolfRun", "WolfLunge", "WolfDeath",
	"BearWalk", "BearRun", "BearRoar", "BearSwipe", "BearDeath",
	"QuadWalk", "QuadRun",
}

AnimClips.RunSpeed = 8 -- animals above this ground speed use the Run clip
AnimClips.WalkSpeed = 1

local NONE: Pick = { Clips = {}, OneShot = false, Hold = false }

local function pick(clips: { string }, oneShot: boolean?, hold: boolean?): Pick
	return { Clips = clips, OneShot = oneShot == true, Hold = hold == true }
end

local function isBow(item: string): boolean
	return item == "Bow" or item == "CrudeBow" or item == "HuntingBow"
end

local function isChopper(item: string): boolean
	return string.find(item, "Axe$") ~= nil or string.find(item, "Pickaxe$") ~= nil or item == "RepairHammer" or item == "Sledgehammer" or item == "Crowbar"
end

-- Timed one-shot actions: action -> (clip, how long the action pose lasts).
local TIMED: { [string]: { Clip: string, For: number } } = {
	Build = { Clip = "Build", For = 0.9 },
	Feed = { Clip = "Feed", For = 0.7 },
	Eat = { Clip = "Eat", For = 0.9 },
}

-- Channelled (looping) actions -> candidate clips.
local LOOPS: { [string]: { string } } = {
	Chop = { "Chop" },
	Breach = { "Breach", "Chop" },
	Mine = { "Mine" },
	Gather = { "Gather" },
	Fill = { "Fill", "Gather" },
	Pour = { "Pour" },
	Bandage = { "Bandage" },
	Craft = { "Craft" },
	Open = { "Search" },
	Steal = { "Search" },
}

local EMOTES = { EmoteWave = "EmoteWave", EmoteFlex = "EmoteFlex", EmoteCampfire = "EmoteWarmHands" }
local POSES = { PoseTorch = "VictoryTorch", PoseAxe = "VictoryAxe", PoseThrone = "VictoryThrone" }

function AnimClips.Player(s: PlayerState): Pick
	if s.Drawing then
		if s.Held == "Crossbow" then
			return pick({ "CrossbowAim" })
		elseif isBow(s.Held) then
			return if s.DrawAge < 0.8 then pick({ "BowDraw", "BowHold" }, true) else pick({ "BowHold" })
		end
	end
	if s.Blocking then
		return pick({ "Block" })
	end
	local a = s.Action
	if a == "Attack" then
		local len = (if s.Heavy then 0.62 else 0.38) + 0.08
		if s.Elapsed >= len or isBow(s.Item) or s.Item == "Crossbow" or s.Item == "Pistol" or s.Item == "Rifle" then
			return NONE
		elseif s.Item == "Spear" or s.Item == "CrudeSpear" then
			return pick({ "SpearThrust" }, true)
		elseif s.Heavy or isChopper(s.Item) then
			return pick({ "SwingHeavy", "SwingLight" }, true)
		end
		return pick({ "SwingLight" }, true)
	end
	local timed = a and TIMED[a]
	if timed then
		return if s.Elapsed < timed.For then pick({ timed.Clip }, true) else NONE
	end
	local loop = a and LOOPS[a]
	if loop then
		return pick(loop)
	end
	if a == "Emote" and s.Elapsed < 2 then
		local clip = EMOTES[s.Item]
		return if clip then pick({ clip }, true) else NONE
	end
	if a == "Victory" and s.Elapsed < 12 then
		return pick({ POSES[s.Item] or "VictoryTorch" })
	end
	return NONE
end

local PREFIX = { Wolf = "Wolf", Bear = "Bear", Boar = "Quad", Fox = "Quad", Deer = "Quad", Rabbit = "Quad" }

function AnimClips.Animal(s: AnimalState): Pick
	local prefix = PREFIX[s.Species]
	if not prefix then
		return NONE
	end
	if s.Tele == "Dead" then
		return pick({ prefix .. "Death" }, true, true)
	end
	if s.Tele and s.Tele ~= "Strike" and s.TeleAge < 1.2 then
		return pick({ prefix .. s.Tele }, true)
	end
	if s.Speed > AnimClips.RunSpeed then
		return pick({ prefix .. "Run", prefix .. "Walk" })
	elseif s.Speed > AnimClips.WalkSpeed then
		return pick({ prefix .. "Walk" })
	end
	return NONE
end

-- First candidate with an uploaded id: (name, id), or nil.
function AnimClips.First(p: Pick, ids: { [string]: number }): (string?, number?)
	for _, name in p.Clips do
		local id = ids[name]
		if type(id) == "number" and id > 0 then
			return name, id
		end
	end
	return nil, nil
end

return AnimClips
