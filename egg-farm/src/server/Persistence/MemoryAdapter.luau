--!nonstrict
-- Test-place persistence: wraps MemoryStore with the ProfileStoreAdapter contract. Saves live in
-- server memory only (they survive leaving and rejoining the same running server, which is how the
-- test place exercises reconnects). Never touches DataStores, so test progress and simulated
-- purchases can't reach real profiles. Fault injection: adapter.store.failLoads / failSaves.

local MemoryStore = require(script.Parent:WaitForChild("MemoryStore"))

local Adapter = {}
Adapter.__index = Adapter
Adapter.Kind = "memory"

function Adapter.new(template: () -> { [string]: any }, sessionId: string)
	local self = setmetatable({}, Adapter)
	self.store = MemoryStore.new(template, os.clock)
	self.store.stealAfter = 30
	self.session = sessionId
	return self
end

function Adapter:Load(key: string, cancel: () -> boolean)
	local r = self.store:Load(key, self.session)
	if not r.ok then
		return { ok = false, reason = r.reason }
	end
	return { ok = true, isNew = r.isNew, handle = r.handle }
end

function Adapter:SetData(handle, data)
	handle.data = data
end

function Adapter:IsActive(handle): boolean
	return handle.active
end

function Adapter:Save(handle): (boolean, string?)
	return self.store:Save(handle)
end

function Adapter:WaitForSave(handle, check: (any) -> boolean, timeout: number): boolean
	local ok = self.store:Save(handle)
	return ok and check(handle.data)
end

function Adapter:OnSessionEnd(handle, fn: () -> ()) end

function Adapter:Release(handle): (boolean, string?)
	-- retry an interrupted final save a few times before giving up the lock
	for _ = 1, 3 do
		if not handle.active then
			return true, nil
		end
		local ok, err = self.store:Release(handle)
		if ok then
			return true, nil
		end
		if err == "session lost" then
			return false, err
		end
		handle.active = true -- MemoryStore marks it inactive; retry
	end
	return false, "save failed"
end

return Adapter
