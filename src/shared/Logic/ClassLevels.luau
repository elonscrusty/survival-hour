--!strict
-- Class levels (owner decision: small perk upgrades, earned only by playing).
-- Each class has one task counted in matches played as that class; reaching the
-- goals unlocks Level 2 and 3, which strengthen the class's own percentage
-- effects a little (x1.25, x1.5). Flags and whole-number effects (extra slots,
-- sense radius) don't grow. Never sold, no skips. Pure for tests
-- (tests/ClassLevels.spec.luau).

local ClassLevels = {}

export type Task = { Stat: string, Label: string, Need: { number } } -- Need[1] = Level 2, Need[2] = Level 3

ClassLevels.Max = 3
ClassLevels.Mult = { 1, 1.25, 1.5 } -- by level

-- Per-match stat (PowerupService st.Stats) counted while playing the class.
local TASKS: { [string]: Task } = {
	Survivor = { Stat = "Nights", Label = "Survive nights", Need = { 10, 30 } },
	Lumberjack = { Stat = "Chopped", Label = "Chop wood", Need = { 300, 1000 } },
	Miner = { Stat = "Mined", Label = "Mine stone and ore", Need = { 200, 700 } },
	Hunter = { Stat = "Animals", Label = "Hunt animals", Need = { 25, 80 } },
	Scavenger = { Stat = "Chests", Label = "Search containers", Need = { 30, 100 } },
	Raider = { Stat = "Breaches", Label = "Breach storages", Need = { 10, 35 } },
	Tracker = { Stat = "Kills", Label = "Take down players", Need = { 10, 40 } },
}
ClassLevels.Tasks = TASKS

-- Profile stat key holding a class's task progress.
function ClassLevels.Key(classId: string): string
	return "ClassTask_" .. classId
end

function ClassLevels.Progress(stats: { [string]: number }, classId: string): number
	return stats[ClassLevels.Key(classId)] or 0
end

function ClassLevels.LevelFor(classId: string, progress: number): number
	local task = ClassLevels.Tasks[classId]
	if not task then
		return 1
	end
	local level = 1
	for i, need in task.Need do
		if progress >= need then
			level = i + 1
		end
	end
	return level
end

function ClassLevels.Level(stats: { [string]: number }, classId: string): number
	return ClassLevels.LevelFor(classId, ClassLevels.Progress(stats, classId))
end

-- Adds a finished match's task count (matchStats = PowerupService st.Stats) to the profile.
-- Returns the new level if it went up, else nil.
function ClassLevels.Commit(stats: { [string]: number }, classId: string, matchStats: { [string]: number }): number?
	local task = ClassLevels.Tasks[classId]
	local n = task and matchStats[task.Stat] or 0
	if not task or n <= 0 then
		return nil
	end
	local before = ClassLevels.Level(stats, classId)
	local key = ClassLevels.Key(classId)
	stats[key] = (stats[key] or 0) + math.floor(n)
	local after = ClassLevels.Level(stats, classId)
	return if after > before then after else nil
end

local function grows(v: number): boolean
	return v ~= 0 and math.abs(v) < 1 -- fractions (percentages) only
end

-- The class's effects at `level`.
function ClassLevels.Effects(effects: { [string]: number }, level: number): { [string]: number }
	local mult = ClassLevels.Mult[math.clamp(level, 1, ClassLevels.Max)]
	local out = {}
	for k, v in effects do
		out[k] = if grows(v) then v * mult else v
	end
	return out
end

-- Client view: { Level, Progress, Need (next goal or nil at max), Label, Next = { "22% ..." } }.
function ClassLevels.View(stats: { [string]: number }, classId: string): { [string]: any }?
	local task = ClassLevels.Tasks[classId]
	if not task then
		return nil
	end
	local progress = ClassLevels.Progress(stats, classId)
	local level = ClassLevels.LevelFor(classId, progress)
	return {
		Level = level,
		Progress = progress,
		Need = task.Need[level], -- nil at max level
		Label = task.Label,
	}
end

-- "+15%" -> "+19%" preview lines for the next level's effects (percent effects only).
function ClassLevels.Boosts(effects: { [string]: number }, level: number): { { Key: string, From: number, To: number } }
	local out = {}
	if level >= ClassLevels.Max then
		return out
	end
	local now = ClassLevels.Effects(effects, level)
	local nxt = ClassLevels.Effects(effects, level + 1)
	for k, v in effects do
		if grows(v) then
			table.insert(out, { Key = k, From = math.floor(math.abs(now[k]) * 100 + 0.5), To = math.floor(math.abs(nxt[k]) * 100 + 0.5) })
		end
	end
	table.sort(out, function(a, b)
		return a.Key < b.Key
	end)
	return out
end

return ClassLevels
