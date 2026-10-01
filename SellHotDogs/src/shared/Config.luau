--!strict
-- Runtime switches (not economy numbers; those live in catalog/economy.json).
local Config = {
	-- Storage: "mock" keeps saves in server memory only (safe for local Studio tests).
	-- Switch to "datastore" only after the new experience is published and Studio API access
	-- is deliberately enabled for THAT experience (see docs/LIVE_SETUP.md).
	Storage = "mock",
	DataStoreName = "SellHotDogs_Profiles_v1",
	AutosaveSeconds = 60,
	LoadRetries = 3,

	-- Robux: product IDs live in Products.luau. While MockPurchases is on (Studio only),
	-- the shop shows "Test" buttons that run the real receipt handler with fake receipts.
	MockPurchases = true,

	Plots = 4,
	StepSeconds = 0.1, -- production step
	SyncSeconds = 0.2, -- state snapshot rate to the owner
	InteractRange = 40, -- studs from a business to click/upgrade without Manage
	PadRange = 14, -- studs from a pad for a prompt purchase without Remote Buy
	BaseWalkSpeed = 16,

	-- Extra yaw (degrees) applied to every uploaded mesh, in case the importer faces them
	-- backwards. Check one model in Studio after the first upload and set 0 or 180.
	MeshYaw = 0,
}
return Config
