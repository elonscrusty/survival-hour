--!strict
-- Which player owns which plot. Pure bookkeeping so ownership rules are unit-tested:
-- one plot per player, one player per plot, released plots are reusable, and an action on a
-- plot is allowed only for its owner.

export type Registry = {
	count: number,
	owner: { [number]: number }, -- plot -> userId
	plotOf: { [number]: number }, -- userId -> plot
}

local PlotRegistry = {}

function PlotRegistry.new(count: number): Registry
	return { count = count, owner = {}, plotOf = {} }
end

-- Returns the plot index, or nil when the server is full.
function PlotRegistry.Claim(r: Registry, userId: number): number?
	if r.plotOf[userId] then
		return r.plotOf[userId]
	end
	for i = 1, r.count do
		if r.owner[i] == nil then
			r.owner[i] = userId
			r.plotOf[userId] = i
			return i
		end
	end
	return nil
end

function PlotRegistry.Release(r: Registry, userId: number): number?
	local i = r.plotOf[userId]
	if i then
		r.plotOf[userId] = nil
		r.owner[i] = nil
	end
	return i
end

function PlotRegistry.Owns(r: Registry, userId: number, plot: number): boolean
	return r.owner[plot] == userId
end

return PlotRegistry
