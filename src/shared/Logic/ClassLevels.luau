--!strict
-- Class levels (owner decision: small perk upgrades, earned only by playing).
-- Each class has one task counted in matches played as that class; reaching the
-- goals unlocks Level 2 and 3, which strengthen the class's own percentage
-- effects a little (x1.25, x1.5). Flags and whole-number effects (extra slots,
-- sense radius) don't grow, nor does anything that helps in fights (bow draw);
-- breach speed grows less. Classes whose perks are flags get small level extras
-- instead (Hunter hides, Tracker trail delay). Goals aim for ~4 matches to
-- Level 2 and ~10-12 to Level 3. Never sold, no skips. Pure for tests
-- (tests/ClassLevels.spec.luau).

local ClassLevels = {}

export type Task = { Stat: string, Label: string, Need: { number } } -- Need[1] = Level 2, Need[2] = Level 3

ClassLevels.Max = 3
ClassLevels.Mult = { 1, 1.25, 1.5 } -- by level

-- Per-match stat (PowerupService st.Stats) counted while playing the class.
local TASKS: { [string]: Task } = {
	Survivor = { Stat = "Nights", Label = "Survive nights", Need = { 12, 36 } },
	Lumberjack = { Stat = "Chopped", Label = "Chop wood", Need = { 1000, 3000 } },
	Miner = { Stat = "Mined", Label = "Mine stone and ore", Need = { 600, 1800 } },
	Hunter = { Stat = "Animals", Label = "Hunt animals", Need = { 30, 80 } },
	Scavenger = { Stat = "Chests", Label = "Search containers", Need = { 25, 70 } },
	-- each storage counts once per match (a friend resecuring can't be farmed)
	Raider = { Stat = "RaidedStores", Label = "Breach different storages", Need = { 8, 22 } },
	-- at most 2 per victim per match (PowerupService, like kill rewards)
	Tracker = { Stat = "Takedowns", Label = "Take down players", Need = { 6, 18 } },
}
ClassLevels.Tasks = TASKS

-- Effects that never grow with level (they would help in fights), and growth caps.
local NO_GROW = { DrawSpeed = true }
local MAX_MULT = { BreachSpeed = 1.2 }

-- Level extras added on top, for classes whose own perks are flags.
local EXTRAS: { [string]: { [number]: { [string]: number } } } = {
	Hunter = { [2] = { ExtraHide = 1 }, [3] = { ExtraHide = 2 } }, -- extra leather per animal
	Tracker = { [2] = { TrailDelay = 0.2 }, [3] = { TrailDelay = 0.35 } }, -- trails show sooner (still delayed)
}

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

local function grows(k: string, v: number): boolean
	return v ~= 0 and math.abs(v) < 1 and not NO_GROW[k] -- fractions (percentages) only
end

-- The class's effects (`effects` = Classes def Effects) at `level`.
function ClassLevels.Effects(classId: string, effects: { [string]: number }, level: number): { [string]: number }
	level = math.clamp(level, 1, ClassLevels.Max)
	local mult = ClassLevels.Mult[level]
	local out = {}
	for k, v in effects do
		out[k] = if grows(k, v) then v * math.min(mult, MAX_MULT[k] or mult) else v
	end
	local byLevel = EXTRAS[classId]
	local extra: { [string]: number } = if byLevel then byLevel[level] or {} else {}
	for k, v in extra do
		out[k] = (out[k] or 0) + v
	end
	return out
end

-- Client view: { Level, Progress, Need (next goal or nil at max), Label }.
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

export type Boost = { Key: string, From: number, To: number, Percent: boolean }

-- What changes at the next level: percentages as whole percents, others as counts.
function ClassLevels.Boosts(classId: string, effects: { [string]: number }, level: number): { Boost }
	local out: { Boost } = {}
	if level >= ClassLevels.Max then
		return out
	end
	local now = ClassLevels.Effects(classId, effects, level)
	local nxt = ClassLevels.Effects(classId, effects, level + 1)
	for k, v in nxt do
		local was = now[k] or 0
		if v ~= was then
			local pct = math.abs(v) < 1
			local function f(x: number): number
				return if pct then math.floor(math.abs(x) * 100 + 0.5) else x
			end
			table.insert(out, { Key = k, From = f(was), To = f(v), Percent = pct })
		end
	end
	table.sort(out, function(a, b)
		return a.Key < b.Key
	end)
	return out
end

return ClassLevels
