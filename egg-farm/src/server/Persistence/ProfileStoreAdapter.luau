--!nonstrict
-- Production persistence: ProfileStore (vendored, pinned; see LICENSES.md) with session locking.
-- Same contract as MemoryStore: Load / Save / Release / WaitForSave. A load that fails, is
-- cancelled, or loses a session conflict returns ok = false and NO data, so the caller can never
-- fall back to a default profile that would overwrite real progress.

local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService:WaitForChild("Vendor"):WaitForChild("ProfileStore"))

local Adapter = {}
Adapter.__index = Adapter
Adapter.Kind = "profilestore"

-- template: a FarmState with createdAt = 0 (marks "never saved").
function Adapter.new(storeName: string, template: { [string]: any })
	local self = setmetatable({}, Adapter)
	self.store = ProfileStore.New(storeName, template)
	return self
end

-- cancel(): return true to abandon the load (player left).
function Adapter:Load(key: string, cancel: () -> boolean)
	local ok, profileOrErr = pcall(function()
		return self.store:StartSessionAsync(key, { Cancel = cancel })
	end)
	if not ok then
		return { ok = false, reason = "error", detail = tostring(profileOrErr) }
	end
	local profile = profileOrErr
	if profile == nil then
		return { ok = false, reason = if cancel() then "cancelled" else "error" }
	end
	local handle = { key = key, profile = profile, active = true, data = profile.Data }
	return { ok = true, isNew = profile.Data.createdAt == 0, handle = handle }
end

-- Replace the saved table (after migration). Only valid while the session is active.
function Adapter:SetData(handle, data)
	handle.profile.Data = data
	handle.data = data
end

function Adapter:IsActive(handle): boolean
	return handle.active and handle.profile:IsActive()
end

-- Requests a save (ProfileStore saves asynchronously; it also autosaves on its own).
function Adapter:Save(handle): (boolean, string?)
	if not self:IsActive(handle) then
		return false, "session lost"
	end
	handle.profile:Save()
	return true, nil
end

-- Yields until a save that includes `check(lastSavedData)` lands, or timeout. Used by receipts.
function Adapter:WaitForSave(handle, check: (any) -> boolean, timeout: number): boolean
	if not self:IsActive(handle) then
		return false
	end
	local done = false
	local conn = handle.profile.OnAfterSave:Connect(function(lastSaved)
		if check(lastSaved) then
			done = true
		end
	end)
	handle.profile:Save()
	local t0 = os.clock()
	while not done and os.clock() - t0 < timeout and self:IsActive(handle) do
		task.wait(0.25)
	end
	conn:Disconnect()
	return done
end

function Adapter:OnSessionEnd(handle, fn: () -> ())
	handle.profile.OnSessionEnd:Connect(fn)
end

function Adapter:Release(handle): (boolean, string?)
	if handle.active then
		handle.active = false
		handle.profile:EndSession() -- final save happens inside ProfileStore (with retries)
	end
	return true, nil
end

return Adapter
