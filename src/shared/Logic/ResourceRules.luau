--!strict
-- Pure resource-node state machine (tested by tests/ResourceRules.spec.luau).
--
-- Trees:   Healthy -> Damaged -> Felled (FellTime) -> Stump -> Respawning (GrowTime) -> Healthy
-- Harvest: Healthy -> Damaged -> Exhausted -> Respawning (GrowTime) -> Healthy
-- The respawn clock starts when the node is felled/exhausted. A respawn that
-- finds its spot occupied retries after RetryDelay instead of spawning inside
-- a player or structure.

local Resources = require("../Resources")
local Rng = require("./Rng")

export type State = {
	Health: number,
	Max: number,
	State: string, -- "Healthy" | "Damaged" | "Felled" | "Stump" | "Exhausted" | "Respawning"
	Until: number, -- end of the current timed state (Felled / Respawning)
	RespawnAt: number,
}

export type HitResult = {
	Ok: boolean,
	Reason: string?, -- "Unavailable" | "NeedTool"
	Dealt: number,
	Items: { [string]: number },
	Finished: boolean,
}

local ResourceRules = {}

ResourceRules.RetryDelay = 8

function ResourceRules.New(def: Resources.Def): State
	return { Health = def.Health, Max = def.Health, State = "Healthy", Until = 0, RespawnAt = 0 }
end

-- Can this node be hit/gathered right now?
function ResourceRules.Available(s: State): boolean
	return s.State == "Healthy" or s.State == "Damaged"
end

-- Tool check. `toolType` is the equipped item's ToolType ("Axe") or nil for bare hands;
-- `tier` its ToolTier (1 Crude … 4 Steel).
function ResourceRules.ToolOk(def: Resources.Def, toolType: string?, tier: number?): boolean
	if def.RequiredTool == "Hand" then
		return true
	end
	return toolType == def.RequiredTool and (tier or 1) >= (def.MinTier or 1)
end

-- Items for damage going from `before` to `after` health: the exact Yield is spread
-- by cumulative damage, so the total is exact whatever the tool power.
function ResourceRules.YieldFor(def: Resources.Def, maxHealth: number, before: number, after: number): { [string]: number }
	local out = {}
	local y = def.Yield
	if not y then
		for id, n in def.PerHit do
			out[id] = n
		end
		return out
	end
	local d0, d1 = maxHealth - before, maxHealth - after
	for id, total in y do
		local n = math.floor(total * d1 / maxHealth + 1e-9) - math.floor(total * d0 / maxHealth + 1e-9)
		if n > 0 then
			out[id] = n
		end
	end
	return out
end

function ResourceRules.RollDrops(def: Resources.Def, rng: Rng.Rng, into: { [string]: number }?): { [string]: number }
	local out = into or {}
	for _, d in def.Drops do
		if d.Chance == nil or rng:Next() < d.Chance then
			local n = rng:Int(d.Min, d.Max)
			if n > 0 then
				out[d.Item] = (out[d.Item] or 0) + n
			end
		end
	end
	return out
end

-- One hit (tool swing or completed hand gather). `power` is the damage dealt:
-- the tool's ToolPower for trees, Resources.HandPower (1) for hand nodes.
function ResourceRules.Hit(def: Resources.Def, s: State, toolType: string?, power: number, now: number, rng: Rng.Rng, tier: number?): HitResult
	local res: HitResult = { Ok = false, Reason = nil, Dealt = 0, Items = {}, Finished = false }
	if not ResourceRules.Available(s) then
		res.Reason = "Unavailable"
		return res
	end
	if not ResourceRules.ToolOk(def, toolType, tier) then
		res.Reason = if toolType == def.RequiredTool then "NeedTier" else "NeedTool"
		return res
	end
	local dealt = math.min(s.Health, math.max(0, power))
	if dealt <= 0 then
		res.Reason = "NoDamage"
		return res
	end
	local before = s.Health
	s.Health -= dealt
	res.Ok = true
	res.Dealt = dealt
	for id, n in ResourceRules.YieldFor(def, s.Max, before, s.Health) do
		res.Items[id] = (res.Items[id] or 0) + n
	end
	if s.Health <= 0 then
		s.Health = 0
		res.Finished = true
		ResourceRules.RollDrops(def, rng, res.Items)
		s.RespawnAt = now + def.RespawnTime
		if def.Kind == "Tree" then
			s.State = "Felled"
			s.Until = now + def.FellTime
		else
			s.State = "Exhausted"
			s.Until = 0
		end
	else
		s.State = "Damaged"
	end
	return res
end

-- Advances timers. `spotClear` reports whether the node's spot is free of
-- characters/structures (only consulted when a respawn is due). Returns the
-- name of the state it entered, or nil if nothing changed.
function ResourceRules.Advance(def: Resources.Def, s: State, now: number, spotClear: (() -> boolean)?): string?
	if s.State == "Felled" and now >= s.Until then
		s.State = "Stump"
		return "Stump"
	elseif (s.State == "Stump" or s.State == "Exhausted") and now >= s.RespawnAt then
		if spotClear and not spotClear() then
			s.RespawnAt = now + ResourceRules.RetryDelay
			return nil
		end
		s.State = "Respawning"
		s.Until = now + def.GrowTime
		return "Respawning"
	elseif s.State == "Respawning" and now >= s.Until then
		s.State = "Healthy"
		s.Health = s.Max
		return "Healthy"
	end
	return nil
end

-- 0..1 health fraction (for damage visuals).
function ResourceRules.Fraction(s: State): number
	return if s.Max > 0 then s.Health / s.Max else 0
end

-- Hits needed to finish a node with a given power (UI hint + tests).
function ResourceRules.HitsToFinish(def: Resources.Def, power: number): number
	return math.ceil(def.Health / math.max(power, 1e-6))
end

return ResourceRules
