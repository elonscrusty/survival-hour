--!strict
-- Save storage behind one interface. "mock" = in-memory (default; nothing leaves the server),
-- "datastore" = Roblox DataStore with retries and a simple session lock.
-- Failure injection for tests (Studio): workspace attributes
--   SHD_FailLoads = n   next n loads fail
--   SHD_FailSaves = n   next n saves fail
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Store = {}

local mock: { [string]: string } = {} -- JSON per key, like a real store
local store: GlobalDataStore? = nil
local JOB = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)
local LOCK_SECONDS = 1800

Store.mode = Config.Storage

local function injected(attr: string): boolean
	local n = workspace:GetAttribute(attr)
	if type(n) == "number" and n > 0 then
		workspace:SetAttribute(attr, n - 1)
		return true
	end
	return false
end

function Store.init()
	if Store.mode == "datastore" then
		local ok, res = pcall(function()
			return DataStoreService:GetDataStore(Config.DataStoreName)
		end)
		if ok then
			store = res
		else
			warn("[Store] DataStore unavailable, falling back to mock storage:", res)
			Store.mode = "mock"
		end
	end
	print("[Store] mode =", Store.mode)
end

local function key(userId: number): string
	return "u_" .. tostring(userId)
end

-- Returns ok, data (nil data = no save yet). ok=false means "could not read": never treat as new.
function Store.load(userId: number): (boolean, any)
	for attempt = 1, Config.LoadRetries do
		if injected("SHD_FailLoads") then
			warn(string.format("[Store] load attempt %d failed (injected)", attempt))
			task.wait(0.2 * attempt)
			continue
		end
		if Store.mode == "mock" then
			local raw = mock[key(userId)]
			if raw == nil then
				return true, nil
			end
			return true, HttpService:JSONDecode(raw).data
		end
		local ds = store :: GlobalDataStore
		local result: any = nil
		local locked = false
		local ok, err = pcall(function()
			ds:UpdateAsync(key(userId), function(old)
				old = old or {}
				local lock = old.lock
				if type(lock) == "table" and lock.job ~= JOB and os.time() - (lock.t or 0) < LOCK_SECONDS then
					locked = true
					return nil -- cancel: another server still holds this profile
				end
				old.lock = { job = JOB, t = os.time() }
				result = old.data
				return old
			end)
		end)
		if ok and not locked then
			return true, result
		end
		warn(string.format("[Store] load attempt %d failed: %s", attempt, if locked then "session locked by another server" else tostring(err)))
		task.wait(2 ^ attempt)
	end
	return false, nil
end

-- release = true on leave/shutdown (drops the session lock).
function Store.save(userId: number, data: any, release: boolean): boolean
	if injected("SHD_FailSaves") then
		warn("[Store] save failed (injected)")
		return false
	end
	if Store.mode == "mock" then
		mock[key(userId)] = HttpService:JSONEncode({ data = data })
		return true
	end
	local ds = store :: GlobalDataStore
	for attempt = 1, 3 do
		local blocked = false
		local ok, err = pcall(function()
			ds:UpdateAsync(key(userId), function(old)
				old = old or {}
				if type(old.lock) == "table" and old.lock.job ~= JOB and os.time() - (old.lock.t or 0) < LOCK_SECONDS then
					blocked = true
					return nil -- someone else owns it now; do not clobber
				end
				old.data = data
				old.lock = if release then nil else { job = JOB, t = os.time() }
				return old
			end)
		end)
		if ok and blocked then
			warn("[Store] save skipped: profile is locked by another server")
			return false
		end
		if ok then
			return true
		end
		warn(string.format("[Store] save attempt %d failed: %s", attempt, tostring(err)))
		task.wait(attempt)
	end
	return false
end

-- Test helpers (mock mode only).
function Store._mockRaw(userId: number): string?
	return mock[key(userId)]
end
function Store._mockPut(userId: number, json: string)
	mock[key(userId)] = json
end

return Store
