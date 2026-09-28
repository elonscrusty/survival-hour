--!strict
-- Central tuning values for Survival Hour. Every gameplay number that designers
-- are expected to tweak lives here or in the data modules next to this file
-- (Items, Recipes, Loot, Products) and in Classes / Perks / Cosmetics / Progression. See docs/TUNING.md.

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

-- Survival Wars launches solo: every player is a "team" of one with their own camp
-- (SPEC_AUDIT conflict 2). Raise MaxPerTeam to bring teams back.
Config.Match = {
	TeamCount = 4, -- camps on the map (LayoutGen places 4)
	MaxPerTeam = 1,
	MaxPlayers = 4,
	MinPlayers = 4,
	DayLength = 120,
	NightLength = 120,
	IntroLength = 12, -- countdown before the first day starts (players can look around)
	ArrivalTimeout = 60, -- seconds a reserved server waits for manifest players
	EndScreenLength = 15, -- seconds before players are returned to the lobby
	WinDiamonds = 2, -- spec: a win awards EXACTLY 2 Diamonds
	-- At each sunrise (from Day 2) players alive at that moment are invincible for this
	-- long and cannot deal damage.
	SunriseProtection = 15,
}

Config.Lives = {
	-- Unlimited respawns while your fire burns (math.huge). The paid-revive path is
	-- kept in code but off: with unlimited respawns the revive window never opens.
	FreeRespawns = math.huge,
	RespawnDelays = { 8, 12, 16, 20 }, -- 1st, 2nd, 3rd death, then capped at the last
	RespawnDelay = 8, -- legacy single value (first entry of RespawnDelays)
	ReviveWindow = 20, -- seconds a player may be paid-revived after running out of free respawns
	PurchaseLockTime = 30, -- one in-flight revive purchase per target
	MaxReviveTier = 4,
	SpawnProtection = 3, -- seconds of damage immunity after (re)spawning; protected players can't deal damage
}

Config.Player = {
	MaxHealth = 100,
	WalkSpeed = 16,
	FireHealRadius = 24,
	FireHealPerSecond = 0.5, -- spec: no fast passive regen (slow warmth at your own fire only)
	FireHealDelayAfterDamage = 5,
	FallDamageMinVelocity = 75,
}

-- Spec: Stamina 100. Sprinting drains it; melee and blocking spend it (Phase 4).
Config.Stamina = {
	Max = 100,
	SprintMult = 1.4, -- walk speed while sprinting
	SprintDrain = 12, -- per second
	Regen = 14, -- per second after RegenDelay
	RegenDelay = 1.2,
	MinToSprint = 20, -- after emptying the bar, sprint again at this much
	ExhaustedMult = 0.9, -- slight slow while exhausted
}

-- (armour pieces: Items.luau ARMOR_TIERS)
Config.Inventory = {
	PackSlots = 6, -- spec: ~6 starting slots; backpacks give 10/16/24/32/40
	BandageMax = 3,
	AmmoMax = { Arrow = 30, Bullet = 24, Bolt = 20 },
	DropDespawn = 180,
	SupplyBagDespawn = 180,
	PickupRange = 10,
}

Config.Fire = {
	LightRadius = 45, -- animals avoid this radius around burning fires
	PourDuration = 10, -- legacy; snuff time now comes from SnuffTimes by fire level
	-- Fuel (0..1 of a full fire). 0 puts the fire out permanently, even on Nights 1-2.
	StartFuel = 0.5,
	FullFuelSeconds = { 480, 540, 600, 660, 720 }, -- L1..L5: a full fire lasts 8..12 min
	FuelPerWood = 0.02, -- 1 Wood = +2% of a full fire
	FuelWarning = 0.15, -- owner warned below this
	-- Snuffing (hold, interrupted by damage/moving/release)
	SnuffTimes = { 8, 10, 12, 15, 20 },
	ProtectedNights = 2, -- no snuffing during Nights 1-2; from Night 3 fires are vulnerable day and night
	-- Levels. Materials are contributed a bit at a time (a pack can't hold a full upgrade).
	MaxLevel = 5,
	Upgrades = {
		[2] = { Wood = 32, Stone = 18 },
		[3] = { Wood = 64, Stone = 36, Scrap = 15 },
		[4] = { Wood = 128, Stone = 72, Scrap = 40, Iron = 12 },
		[5] = { Wood = 256, Stone = 144, Scrap = 80, Iron = 32, RareComponent = 1 },
	} :: { [number]: { [string]: number } },
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
	Limits = { Wall = 40, Spikes = 12, Watchtower = 2, Storage = 2, Floor = 30, Trap = 6 },
	-- "Wall" limit counts every wall/door/gate together.
	-- Spec caps by Workbench tier I..V (override Limits for these keys):
	TierLimits = {
		Storage = { 1, 2, 3, 4, 5 },
		Trap = { 2, 3, 4, 5, 6 },
	} :: { [string]: { number } },
	RotateStep = 15,
	GridSnap = 0.5,
}

Config.Storage = {
	Capacity = 12, -- fallback stack slots (each storage item sets Items[id].Stacks)
	StealDuration = 3, -- legacy
	StealAmount = 10, -- legacy
	InteractRange = 10,
	-- Breaching unlocks (never deletes). Seconds with a normal tool (axe/pickaxe) by storage tier.
	BreachTimes = { 14, 24, 36, 50 },
	BreachToolMult = { Crowbar = 0.6, Sledgehammer = 0.4 },
	-- Minimum breaching tool by tier (nil = any axe/pickaxe/breaching tool)
	BreachNeeds = { [3] = "Crowbar", [4] = "Sledgehammer" } :: { [number]: string },
	ChargeTime = 5, -- Breaching Charge: any tier
	ChargeDamage = 60, -- to players within ChargeRadius (not the raider's structures)
	ChargeRadius = 10,
	NoiseRadius = 180, -- everyone this close hears the breach alert (raids are loud)
	ResecureTime = 4,
	ResecureCost = { Wood = { Wood = 4 }, Scrap = { Scrap = 3 }, Iron = { Iron = 2 } } :: { [string]: { [string]: number } },
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

-- Spec healing: Bandage ~20, First Aid ~50, Medkit ~100. Timed, interrupted by damage.
Config.Bandage = {
	UseTime = 3,
	Heal = 20,
}
Config.Healing = {
	Bandage = { Heal = 20, UseTime = 3 },
	FirstAid = { Heal = 50, UseTime = 5 },
	Medkit = { Heal = 100, UseTime = 8 },
	MoveSlow = 0.6, -- walk speed multiplier while applying
}

-- Crafting is a short channel: BaseTime + PerTier * recipe tier (Craftsman shortens it).
Config.Craft = {
	BaseTime = 1,
	PerTier = 0.5,
}

-- World events and match conditions (Logic/MatchEvents, EventService). Events are occasional:
-- the first can't start before FirstDelay, at most one runs at a time, and each is followed by a
-- quiet gap. Conditions are small per-match twists announced at the start; they never change rules.
Config.Events = {
	FirstDelay = 150, -- seconds into Day 1 before any event can start
	GapMin = 150, -- quiet time between the end of one event and the next roll
	GapMax = 300,
	Chance = 0.65, -- chance an event starts when the gap ends (else wait another gap)
	Weights = { Thunderstorm = 3, Fog = 3, PredatorSurge = 2, SurvivorCache = 3, Migration = 2 },
	Duration = {
		Thunderstorm = { 120, 180 },
		Fog = { 150, 240 },
		PredatorSurge = { 100, 140 },
		SurvivorCache = { 420, 420 }, -- how long the cache waits to be found
		Migration = { 90, 120 },
	},
	NotOnDay1 = { Thunderstorm = true, PredatorSurge = true },
	SurgeWolves = 3, -- extra wolves allowed above the species cap during a surge
	SurgeRadius = 45,
	MigrationHerd = { 4, 6 },
	CacheTrail = 4, -- dropped-supply clues leading to the cache
	CacheTier = "Uncommon", -- loot table; one bonus roll from Rare on top
	ConditionChance = 0.7, -- chance a match gets a condition at all
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
	MaxTotal = 20,
	MaxPerSpecies = { Wolf = 9, Bear = 2, Boar = 4, Deer = 6, Rabbit = 6, Bat = 0 }, -- bats aren't in the spec
	-- Predators (wolf/bear/boar) alive at once: base on Night 1, +2 per night, capped (Logic/WildlifeRules)
	PredatorBase = 6,
	PredatorPerNight = 2,
	PredatorMax = 14,
	SpawnInterval = 6,
	SpawnMinPlayerDist = 60,
	SpawnMaxPlayerDist = 170,
	DespawnDistance = 260,
	AggroRange = { Wolf = 60, Bear = 45, Boar = 14, Bat = 50 }, -- × night AggroMult
	FleeRange = { Deer = 38, Rabbit = 22 },
	Territory = 32, -- bears defend this radius around where they spawned
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
	-- Melee (spec: Light / Heavy / Block; stamina and guard break matter)
	LightStamina = 6,
	HeavyStamina = 18,
	HeavyMult = 1.8, -- damage
	HeavyCooldownMult = 1.6,
	HeavyWindup = 0.45, -- seconds held before a heavy can release (server enforces spacing)
	HeavyGuardDrain = 20, -- extra stamina a heavy hit drains from a blocker
	BlockReduction = 0.45, -- melee weapons/tools; the Shield uses its own (0.7)
	BlockDrainPerHp = 1.0, -- stamina per point blocked (Shield: ShieldDrainPerHp)
	ShieldDrainPerHp = 0.6,
	GuardBreakTime = 1.5, -- seconds you can't block after your guard breaks
	HeadshotMult = 1.75,
	ArmorCap = 0.5,
}

Config.Camera = {
	MaxZoom = 24,
	MinZoom = 6,
	AimFov = 55,
	DefaultFov = 70,
	SprintFovBonus = 6, -- subtle widen while sprinting
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

-- Lighting presets. Each match day runs Dawn -> Day -> Sunset (the last
-- SunsetAt fraction of the day), then a moonlit Night. The lobby sits in a
-- warm golden hour. Atmosphere / colour-grade values ride along per preset.
Config.Lighting = {
	Dawn = {
		ClockTime = 6.6,
		Brightness = 1.9,
		Ambient = Color3.fromRGB(96, 88, 92),
		OutdoorAmbient = Color3.fromRGB(150, 130, 128),
		FogColor = Color3.fromRGB(214, 190, 176),
		FogStart = 60,
		FogEnd = 520,
		ColorShift = Color3.fromRGB(255, 200, 160),
		Density = 0.4,
		AtmoColor = Color3.fromRGB(230, 200, 180),
		Decay = Color3.fromRGB(150, 120, 110),
		Haze = 1.4,
		Saturation = 0.04,
		Contrast = 0.04,
		Tint = Color3.fromRGB(255, 240, 228),
	},
	Day = {
		ClockTime = 13.5,
		Brightness = 2.4,
		Ambient = Color3.fromRGB(95, 96, 100),
		OutdoorAmbient = Color3.fromRGB(135, 138, 130),
		FogColor = Color3.fromRGB(190, 205, 200),
		FogStart = 150,
		FogEnd = 900,
		ColorShift = Color3.fromRGB(255, 240, 215),
		Density = 0.3,
		AtmoColor = Color3.fromRGB(199, 214, 210),
		Decay = Color3.fromRGB(120, 130, 110),
		Haze = 0.8,
		Saturation = 0.08,
		Contrast = 0.05,
		Tint = Color3.fromRGB(255, 250, 240),
	},
	Afternoon = {
		-- warmer, longer shadows: the day visibly turning
		ClockTime = 15.8,
		Brightness = 2.2,
		Ambient = Color3.fromRGB(100, 94, 92),
		OutdoorAmbient = Color3.fromRGB(145, 132, 118),
		FogColor = Color3.fromRGB(205, 190, 170),
		FogStart = 130,
		FogEnd = 800,
		ColorShift = Color3.fromRGB(255, 220, 180),
		Density = 0.32,
		AtmoColor = Color3.fromRGB(215, 200, 180),
		Decay = Color3.fromRGB(140, 120, 100),
		Haze = 1,
		Saturation = 0.1,
		Contrast = 0.06,
		Tint = Color3.fromRGB(255, 244, 230),
	},
	Sunset = {
		ClockTime = 17.7,
		Brightness = 1.8,
		Ambient = Color3.fromRGB(104, 86, 80),
		OutdoorAmbient = Color3.fromRGB(160, 120, 100),
		FogColor = Color3.fromRGB(220, 150, 110),
		FogStart = 90,
		FogEnd = 620,
		ColorShift = Color3.fromRGB(255, 170, 110),
		Density = 0.38,
		AtmoColor = Color3.fromRGB(240, 170, 130),
		Decay = Color3.fromRGB(170, 90, 80),
		Haze = 1.6,
		Saturation = 0.12,
		Contrast = 0.07,
		Tint = Color3.fromRGB(255, 232, 210),
	},
	Night = {
		-- moonlit: cool, readable silhouettes, deep fog in the distance
		ClockTime = 0.3,
		Brightness = 0.9,
		Ambient = Color3.fromRGB(62, 70, 98),
		OutdoorAmbient = Color3.fromRGB(84, 96, 136),
		FogColor = Color3.fromRGB(28, 34, 52),
		FogStart = 50,
		FogEnd = 400,
		ColorShift = Color3.fromRGB(150, 170, 230),
		Density = 0.4,
		AtmoColor = Color3.fromRGB(70, 84, 120),
		Decay = Color3.fromRGB(40, 44, 70),
		Haze = 1.2,
		Saturation = -0.15,
		Contrast = 0.08,
		Tint = Color3.fromRGB(220, 228, 255),
	},
	Lobby = {
		ClockTime = 17.2,
		Brightness = 2,
		Ambient = Color3.fromRGB(104, 92, 84),
		OutdoorAmbient = Color3.fromRGB(160, 132, 110),
		FogColor = Color3.fromRGB(214, 170, 130),
		FogStart = 120,
		FogEnd = 700,
		ColorShift = Color3.fromRGB(255, 190, 130),
		Density = 0.34,
		AtmoColor = Color3.fromRGB(236, 190, 150),
		Decay = Color3.fromRGB(160, 110, 90),
		Haze = 1.3,
		Saturation = 0.1,
		Contrast = 0.06,
		Tint = Color3.fromRGB(255, 238, 220),
	},
	RainChance = 0.2, -- chance a phase (after Day 1) brings a rain shower; purely visual
	AfternoonAt = 0.42, -- fraction of the day when light turns to afternoon
	SunsetAt = 0.72, -- fraction of the day after which the sun sets
	DawnTime = 12, -- seconds of dawn light at the start of each day
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
