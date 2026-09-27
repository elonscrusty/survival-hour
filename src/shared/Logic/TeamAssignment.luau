--!strict
-- Party → team packing for matchmaking. Pure Luau (no Roblox APIs) so it is
-- covered by the CLI test-suite (tests/TeamAssignment.spec.luau).
--
-- Rules (from the brief):
--   * exactly `teamCount` teams, every team non-empty, each team <= `teamCap`
--   * parties are never split
--   * teams are filled as evenly as possible (minimise largest - smallest)
--   * older queue entries get priority; if a composition is impossible the
--     affected parties simply stay queued

export type Party = { Id: string, Size: number, Members: { any }? }
export type Packing = { Teams: { { Party } }, Sizes: { number }, Total: number }

local TeamAssignment = {}

local NODE_BUDGET = 60000

-- Packs `parties` into `teamCount` bins. Returns nil when impossible.
function TeamAssignment.Pack(parties: { Party }, teamCount: number, teamCap: number): Packing?
	if #parties < teamCount then
		return nil
	end
	local total = 0
	for _, p in parties do
		if p.Size < 1 or p.Size > teamCap then
			return nil
		end
		total += p.Size
	end
	if total > teamCount * teamCap then
		return nil
	end

	-- Largest first makes the search prune quickly.
	local order = table.clone(parties)
	table.sort(order, function(a, b)
		if a.Size ~= b.Size then
			return a.Size > b.Size
		end
		return a.Id < b.Id
	end)

	local sizes = table.create(teamCount, 0)
	local assign = table.create(#order, 0)
	local bestAssign: { number }? = nil
	local bestSpread = math.huge
	local idealSpread = if total % teamCount == 0 then 0 else 1
	local nodes = 0

	-- remaining[i] = players in order[i..n]
	local remaining = table.create(#order + 1, 0)
	for i = #order, 1, -1 do
		remaining[i] = remaining[i + 1] + order[i].Size
	end

	local function dfs(i: number)
		nodes += 1
		if nodes > NODE_BUDGET or bestSpread <= idealSpread then
			return
		end
		if i > #order then
			local lo, hi = math.huge, -math.huge
			for _, s in sizes do
				lo = math.min(lo, s)
				hi = math.max(hi, s)
			end
			if lo >= 1 and hi - lo < bestSpread then
				bestSpread = hi - lo
				bestAssign = table.clone(assign)
			end
			return
		end
		-- Prune: empty teams must still be fillable by the remaining parties.
		local empty = 0
		for _, s in sizes do
			if s == 0 then
				empty += 1
			end
		end
		if empty > #order - i + 1 then
			return
		end
		local size = order[i].Size
		local triedEmpty = false
		for t = 1, teamCount do
			local s = sizes[t]
			if s + size <= teamCap then
				if s == 0 then
					-- All empty teams are equivalent; only try one of them.
					if triedEmpty then
						continue
					end
					triedEmpty = true
				end
				sizes[t] = s + size
				assign[i] = t
				dfs(i + 1)
				sizes[t] = s
			end
		end
	end

	dfs(1)

	local chosen = bestAssign
	if chosen == nil then
		return nil
	end
	local teams: { { Party } } = {}
	local outSizes = table.create(teamCount, 0)
	for t = 1, teamCount do
		teams[t] = {}
	end
	for i, p in order do
		local t = chosen[i]
		table.insert(teams[t], p)
		outSizes[t] += p.Size
	end
	return { Teams = teams, Sizes = outSizes, Total = total }
end

-- Chooses which queued parties (oldest first) go into the next match.
-- Prefers the largest valid player count, then the oldest parties.
-- Returns the packing, or nil if no valid match can be formed yet.
function TeamAssignment.Select(queue: { Party }, teamCount: number, teamCap: number, minPlayers: number, maxScan: number?): Packing?
	local maxPlayers = teamCount * teamCap
	local scan = math.min(#queue, maxScan or 40)
	local best: Packing? = nil
	local bestTotal = 0
	local nodes = 0

	local chosen: { Party } = {}
	local suffix = table.create(scan + 1, 0)
	for i = scan, 1, -1 do
		suffix[i] = suffix[i + 1] + math.min(queue[i].Size, teamCap)
	end

	local function consider()
		local total = 0
		for _, p in chosen do
			total += p.Size
		end
		if total < minPlayers or total <= bestTotal or #chosen < teamCount then
			return
		end
		local packing = TeamAssignment.Pack(chosen, teamCount, teamCap)
		if packing then
			best = packing
			bestTotal = total
		end
	end

	-- Include-first DFS so older parties win ties.
	local function dfs(i: number, total: number)
		nodes += 1
		if nodes > NODE_BUDGET or bestTotal == maxPlayers then
			return
		end
		if total + suffix[i] <= bestTotal then
			return
		end
		if i > scan then
			consider()
			return
		end
		local p = queue[i]
		if p.Size >= 1 and p.Size <= teamCap and total + p.Size <= maxPlayers then
			table.insert(chosen, p)
			dfs(i + 1, total + p.Size)
			table.remove(chosen)
		end
		dfs(i + 1, total)
	end

	dfs(1, 0)
	return best
end

-- Used by a match server whose arrivals differ from the manifest (leavers
-- during teleport). Moves whole parties from overfull teams into empty ones.
-- `teams` is a list of party lists; returns a new list.
function TeamAssignment.Rebalance(teams: { { Party } }, teamCap: number): { { Party } }
	local all: { Party } = {}
	for _, list in teams do
		for _, p in list do
			if p.Size > 0 then
				table.insert(all, p)
			end
		end
	end
	local packing = TeamAssignment.Pack(all, #teams, teamCap)
	if packing then
		return packing.Teams
	end
	-- Cannot make every team non-empty: keep the original arrangement minus empty parties.
	local out = {}
	for t, list in teams do
		out[t] = {}
		for _, p in list do
			if p.Size > 0 then
				table.insert(out[t], p)
			end
		end
	end
	return out
end

return TeamAssignment
