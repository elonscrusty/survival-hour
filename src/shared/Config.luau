--!strict
-- Central tuning values for Survival Hour. Every gameplay number that designers
-- are expected to tweak lives here or in the data modules next to this file
-- (Items, Recipes, Powerups, Loot, Products). See docs/TUNING.md.

local Config = {}

Config.Version = "1.0.0"

-- Development / Studio switches. None of these apply in live servers except
-- where noted; `IsStudioLocal` is resolved at runtime by the server.
Config.Dev = {
	-- In Studio the lobby server hosts matches in-process (see DECISIONS D2).
	StudioLocalMatches = true,
	-- Minimum ready players for a Studio local match (production uses Match.MinPlayers).
	StudioMinPlayers = 1,
	-- Seconds a Studio local queue waits after the first party readies, so other
	-- test clients (Test > Clients and Servers) can ready up too.
	StudioFillWait = 6,
	-- In Studio, a match with only one populated team does not end immediately.
	StudioAllowSingleTeam = true,
	-- Persist data when running in Studio (requires "Enable Studio Access to API Services").
	SaveInStudio = false,
	-- Enables the /sh chat-free dev panel + simulated purchases. NEVER active in live servers.
	DevPanelInStudio = true,
	-- Faster day/night for quick tests (Studio only). nil = use normal lengths.
	StudioPhaseLength = nil :: number?,
}

Config.Match = {
	TeamCount = 4,
	MaxPerTeam = 4,
	MaxPlayers = 16,
	MinPlayers = 8,
	DayLength = 120,
	NightLength = 120,
	IntroLength = 12, -- countdown before the first day starts (players can look around)
	ArrivalTimeout = 60, -- seconds a reserved server waits for manifest players
	EndScreenLength = 15, -- seconds before players are returned to the lobby
	WinDiamonds = 10,
}

Config.Lives = {
	FreeRespawns = 3,
	RespawnDelay = 5,
	ReviveWindow = 20, -- seconds a player may be paid-revived after running out of free respawns
	PurchaseLockTime = 30, -- one in-flight revive purchase per target
	MaxReviveTier = 4,
	SpawnProtection = 3, -- seconds of damage immunity after (re)spawning
}

Config.Player = {
	MaxHealth = 100,
	WalkSpeed = 16,
	FireHealRadius = 24,
	FireHealPerSecond = 2,
	FireHealDelayAfterDamage = 5,
	FallDamageMinVelocity = 75,
}

Config.Inventory = {
	ResourceCapacity = 30,
	BandageMax = 3,
	AmmoMax = { Arrow = 30, Bullet = 24 },
	DropDespawn = 180,
	SupplyBagDespawn = 180,
	PickupRange = 10,
}

Config.Fire = {
	LightRadius = 45, -- animals avoid this radius around burning fires
	PourDuration = 10,
	PourRange = 12,
	RevealRadius = 80, -- enemy camps are revealed to your team inside this range
	AlertCooldown = 6,
}

Config.Build = {
	ZoneRadius = 55,
	FireClearance = 9,
	WorkbenchClearance = 7,
	SpawnClearance = 6,
	MaxPlaceDistance = 28, -- from the builder's character
	MaxSlope = 0.35, -- (1 - normal.Y) tolerated on terrain
	Limits = { Wall = 40, Spikes = 12, Watchtower = 2, Storage = 2 },
	-- "Wall" limit counts WoodWall, ReinforcedWall and Gate together.
	RotateStep = 15,
	GridSnap = 0.5,
}

Config.Storage = {
	Capacity = 200,
	StealDuration = 3,
	StealAmount = 10,
	InteractRange = 10,
}

Config.Gather = {
	HandGatherTime = 0.9, -- seconds per hand-gather action
	AxeCooldown = 0.7,
	Range = 11,
	Respawn = { Tree = 90, Plant = 60, Rock = 75, Twigs = 60 },
	RespawnClearance = 5, -- studs kept clear of characters/structures before regrowing
}

Config.Canteen = {
	FillTime = 1,
	FillRange = 8, -- studs from a stream water point
}

Config.Bandage = {
	UseTime = 3,
	Heal = 45,
}

Config.CarePackage = {
	FreeDropDelayMin = 20,
	FreeDropDelayMax = 40,
	FallTime = 12,
	OpenTime = 4,
	OpenRange = 10,
	QueueSpacing = 25,
	Despawn = 240, -- unopened package lifetime after landing
	LootScatter = 5,
}

Config.Crates = {
	PerSector = 3,
	Center = 3,
	OpenTime = 1.5,
	OpenRange = 8,
}

Config.Wildlife = {
	MaxTotal = 14,
	MaxPerSpecies = { Wolf = 7, Bear = 3, Bat = 8 },
	SpawnInterval = 6,
	SpawnMinPlayerDist = 60,
	SpawnMaxPlayerDist = 170,
	DespawnDistance = 260,
	AggroRange = { Wolf = 60, Bear = 45, Bat = 50 },
	StuckTime = 3,
	StuckGiveUp = 12,
	ThinkRate = 0.2, -- seconds between AI decisions
}

Config.Combat = {
	MeleeTolerance = 3, -- extra studs of reach allowed for latency
	AimAssistAngle = 6, -- degrees (touch only)
	ArrowSpeed = 190,
	ArrowGravity = 35,
	ArrowMaxTime = 3,
	HitMarkerTime = 0.25,
	StructureDamageScale = 1,
}

Config.Camera = {
	MaxZoom = 24,
	MinZoom = 6,
	AimFov = 55,
	DefaultFov = 70,
}

Config.RateLimits = {
	-- tokens per second, burst
	Default = { 10, 20 },
	Attack = { 8, 10 },
	Interact = { 6, 12 },
	Build = { 3, 6 },
	Craft = { 4, 8 },
	Lobby = { 4, 10 },
	Purchase = { 1, 3 },
}

Config.Lighting = {
	Day = {
		ClockTime = 13.5,
		Brightness = 2.4,
		Ambient = Color3.fromRGB(95, 96, 100),
		OutdoorAmbient = Color3.fromRGB(135, 138, 130),
		FogColor = Color3.fromRGB(190, 205, 200),
		FogStart = 150,
		FogEnd = 900,
		ColorShift = Color3.fromRGB(255, 240, 215),
	},
	Night = {
		ClockTime = 0.3,
		Brightness = 0.8,
		Ambient = Color3.fromRGB(62, 70, 98),
		OutdoorAmbient = Color3.fromRGB(78, 88, 126),
		FogColor = Color3.fromRGB(28, 34, 52),
		FogStart = 60,
		FogEnd = 420,
		ColorShift = Color3.fromRGB(150, 170, 230),
	},
	TransitionTime = 8,
}

Config.Map = {
	TileSize = 200,
	Grid = 5,
	CampDistance = 400,
	BaseHeight = 8,
	HillAmplitude = 7,
	PathWidth = 14,
	TreesPerTile = 34,
	-- The match map is built at this offset so a Studio local match can coexist with the lobby.
	MatchOrigin = Vector3.new(0, 0, 0),
	LobbyOrigin = Vector3.new(0, 400, 1400),
}

Config.Teams = {
	{ Name = "Fox", Color = Color3.fromRGB(232, 116, 59), Symbol = "▲", Motif = "Cedar" },
	{ Name = "Owl", Color = Color3.fromRGB(59, 139, 232), Symbol = "●", Motif = "Slate" },
	{ Name = "Stag", Color = Color3.fromRGB(155, 89, 208), Symbol = "◆", Motif = "Antler" },
	{ Name = "Hare", Color = Color3.fromRGB(232, 198, 59), Symbol = "■", Motif = "Thatch" },
}

Config.Data = {
	StoreName = "SurvivalHourProfiles_v1",
	AutosaveInterval = 90,
	SessionLockTimeout = 150, -- seconds after which a stale lock may be stolen
	LoadRetries = 6,
	ProcessedReceiptMemory = 200, -- purchase ids remembered per profile
	RewardedMatchMemory = 40,
}

Config.Matchmaking = {
	QueueMapName = "SH_Queue_v1",
	AssignMapName = "SH_Assign_v1",
	ManifestMapName = "SH_Manifest_v1",
	LockKey = "SH_MatchmakerLock_v1",
	PollInterval = 3,
	EntryTtl = 120, -- queue entries must be refreshed by their lobby server
	FillWait = 25, -- seconds to wait for a full 16 before launching with >= MinPlayers
	PriorityBoost = 1000, -- seconds of age granted to players bounced from a failed match
}

return Config
