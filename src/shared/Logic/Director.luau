--!strict
-- Match Director: reads a snapshot of how the match is going and shapes pacing through the
-- existing event system (tested by tests/Director.spec.luau). It never spawns threats on
-- players, never touches damage, never favours anyone; it only decides WHEN the next event
-- comes, WHICH kinds are more likely, and WHERE an opportunity (a cache) should pull people.

local Director = {}

export type Snapshot = {
	MatchAge: number, -- seconds since Day 1
	Night: boolean,
	Remaining: number, -- standing clans
	Started: number,
	Spread: number, -- average distance between living players / map size (0..~1)
	QuietFor: number, -- seconds since the last PvP hit, raid, snuff or elimination
	SinceWildlifeFight: number,
	RecentEvents: number, -- world events started in the last 10 minutes
	PoisExplored: number, -- 0..1 share of POIs somebody has visited
}

export type Plan = {
	GapMult: number, -- scales the quiet gap before the next roll
	Weights: { [string]: number }, -- multipliers on event weights
	CacheFocus: string?, -- "Between" (among spread-out players) | "Centre" | nil (anywhere)
	Opportunity: boolean, -- queue an extra free supply drop (contested pickup)
	Reason: string, -- for logs / dev panel
}

function Director.Plan(s: Snapshot): Plan
	local plan: Plan = { GapMult = 1, Weights = {}, CacheFocus = nil, Opportunity = false, Reason = "steady" }
	local late = s.Started >= 3 and s.Remaining <= 3

	-- a lot has happened recently: let the match breathe
	if s.RecentEvents >= 2 or s.QuietFor < 60 then
		plan.GapMult = 1.4
		plan.Reason = "busy: breathing room"
	end

	-- long quiet stretch: bring the next event forward and make it a reason to move
	if s.QuietFor > 240 then
		plan.GapMult = 0.5
		plan.Weights.SurvivorCache = 2
		plan.Weights.Migration = 1.5
		plan.Reason = "quiet: something to go after"
		if s.Spread > 0.45 then
			-- everyone is far apart: put the prize between them
			plan.CacheFocus = "Between"
			plan.Reason = "quiet and spread out: cache between players"
		end
	end

	-- late game with players hiding: pull them out with loot, never by revealing them
	if late and s.QuietFor > 200 then
		plan.GapMult = math.min(plan.GapMult, 0.5)
		plan.Weights.SurvivorCache = 3
		plan.CacheFocus = "Centre"
		plan.Opportunity = not s.Night
		plan.Reason = "late game standoff: loot at the centre"
	end

	-- predators just had their moment: don't stack another surge on top
	if s.SinceWildlifeFight < 90 then
		plan.Weights.PredatorSurge = 0.3
	end

	-- most of the map already picked over: caches keep exploring worthwhile
	if s.PoisExplored > 0.7 then
		plan.Weights.SurvivorCache = math.max(plan.Weights.SurvivorCache or 1, 1.8)
	end
	return plan
end

-- Average pairwise distance between points, over the map's width (for Snapshot.Spread).
function Director.Spread(points: { any }, mapSize: number): number
	local n = #points
	if n < 2 or mapSize <= 0 then
		return 0
	end
	local sum, pairs = 0, 0
	for i = 1, n do
		for j = i + 1, n do
			local dx, dz = points[i].X - points[j].X, points[i].Z - points[j].Z
			sum += math.sqrt(dx * dx + dz * dz)
			pairs += 1
		end
	end
	return (sum / pairs) / mapSize
end

-- Merges the plan's multipliers onto a condition's (both optional).
function Director.Weight(kind: string, plan: Plan?): number
	return (plan and plan.Weights[kind]) or 1
end

return Director
