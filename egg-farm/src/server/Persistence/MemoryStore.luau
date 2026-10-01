--!strict
-- In-memory persistence adapter with the same contract as ProfileStoreAdapter.
-- Used by the unit tests and the unpublished Studio test place. It models the things that go
-- wrong with real DataStores so the save rules can be tested offline:
--   * session locks held by another server (conflicts), with an optional steal timeout
--   * load failures (the caller must NOT fall back to a default profile)
--   * save failures / interrupted saves (the last good copy stays; the next save retries)
-- Nothing here touches Roblox services. Results from this adapter are NOT DataStore validation.

export type Handle = {
	key: string,
	session: string,
	active: boolean,
	data: { [string]: any },
}

export type LoadResult = {
	ok: boolean,
	reason: string?, -- "error" | "locked" when ok is false
	handle: Handle?,
	isNew: boolean?,
}

export type Store = {
	records: { [string]: { data: any?, lock: string?, lockAt: number } },
	failLoads: number,
	failSaves: number,
	stealAfter: number?,
	clock: () -> number,
	template: () -> { [string]: any },
	saves: number,
	Load: (self: Store, key: string, session: string) -> LoadResult,
	Save: (self: Store, handle: Handle) -> (boolean, string?),
	Release: (self: Store, handle: Handle) -> (boolean, string?),
	Peek: (self: Store, key: string) -> any,
}

local function deepCopy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = deepCopy(x)
	end
	return out
end

local MemoryStore = {}
MemoryStore.DeepCopy = deepCopy

local function load(self: Store, key: string, session: string): LoadResult
	if self.failLoads > 0 then
		self.failLoads -= 1
		return { ok = false, reason = "error" }
	end
	local rec = self.records[key]
	if rec and rec.lock and rec.lock ~= session then
		local held = self.clock() - rec.lockAt
		if not self.stealAfter or held < self.stealAfter then
			return { ok = false, reason = "locked" }
		end
	end
	local isNew = rec == nil or rec.data == nil
	if not rec then
		rec = { data = nil, lock = nil, lockAt = 0 }
		self.records[key] = rec
	end
	rec.lock = session
	rec.lockAt = self.clock()
	local data = if isNew then self.template() else deepCopy(rec.data)
	return { ok = true, isNew = isNew, handle = { key = key, session = session, active = true, data = data } }
end

local function save(self: Store, handle: Handle): (boolean, string?)
	local rec = self.records[handle.key]
	if not handle.active or not rec or rec.lock ~= handle.session then
		return false, "session lost"
	end
	if self.failSaves > 0 then
		self.failSaves -= 1
		return false, "save failed"
	end
	rec.data = deepCopy(handle.data)
	rec.lockAt = self.clock()
	self.saves += 1
	return true, nil
end

local function release(self: Store, handle: Handle): (boolean, string?)
	if not handle.active then
		return true, nil
	end
	local ok, err = save(self, handle)
	local rec = self.records[handle.key]
	if rec and rec.lock == handle.session then
		rec.lock = nil
	end
	handle.active = false
	return ok, err
end

function MemoryStore.new(template: () -> { [string]: any }, clock: (() -> number)?): Store
	return {
		records = {},
		failLoads = 0,
		failSaves = 0,
		stealAfter = nil,
		clock = clock or os.clock,
		template = template,
		saves = 0,
		Load = load,
		Save = save,
		Release = release,
		Peek = function(self: Store, key: string)
			local rec = self.records[key]
			return rec and deepCopy(rec.data)
		end,
	}
end

return MemoryStore
