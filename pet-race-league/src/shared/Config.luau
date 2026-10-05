-- All tuning numbers for Pet Race League live here.
local Config = {}

Config.StartCoins = 250
Config.ProfileVersion = 1

Config.Slots = {
	Base = 24, -- pet storage for everyone
	BonusPass = 36, -- extra slots from the "Big Barn" game pass
}

-- Pet stats: Speed, Jump and Stamina each level from 1 to MaxLevel.
Config.Stats = {
	Names = { "Speed", "Jump", "Stamina" },
	MaxLevel = 50,
	XpBase = 20, -- xp needed for level 1 -> 2
	XpGrowth = 1.09, -- each level needs this much more
}

-- Riding numbers. Rarity adds a small bonus on top (see Pets.Rarities), so training
-- matters far more than luck.
Config.Ride = {
	OnFootSpeed = 16,
	OnFootJump = 42,
	BaseSpeed = 20,
	SpeedPerLevel = 0.5,
	BaseJump = 46,
	JumpPerLevel = 0.5,
	DashBoost = 1.6, -- WalkSpeed multiplier while dashing
	DashTime = 1.2,
	DashChargesBase = 1,
	DashChargesEvery = 15, -- +1 charge per this many Stamina levels
	DashChargesMax = 4,
	DashRechargeBase = 6,
	DashRechargePerLevel = 0.06,
	DashRechargeMin = 3,
	SizeBase = 1,
	SizePerLevel = 0.01, -- pets grow as they level (cosmetic only)
}

Config.Training = {
	GateXp = 5, -- per gate passed in order
	GateMinGap = 0.5, -- seconds between gates (anti-spam)
	LapBonusXp = 15,
	PadXp = 3, -- treadmill xp per tick
	PadTick = 1.5,
}

Config.Hatch = {
	PityEvery = 10, -- every 10th hatch of an egg is Rare or better
	RarePlus = 3, -- rarity rank that counts as "Rare or better"
}

Config.Race = {
	QueueTime = 20, -- seconds the portal waits for more racers
	MinPlayers = 1, -- solo races are allowed (race the medal times)
	MaxPlayers = 8,
	Countdown = 3,
	TimeLimit = 150,
	ResultsTime = 6,
	FallDepth = 30, -- studs below the track that count as a fall
	FallPenalty = 1.5, -- seconds of freeze after respawning at a checkpoint
	BoostMult = 1.5, -- speed on boost pads
	MudMult = 0.6, -- speed in mud
	HurryTime = 30, -- after the first finisher, everyone else has this long
	PlaceCoins = { 120, 90, 70, 55, 45, 40, 35, 30 },
	FinishCoins = 25, -- for finishing at all
	DnfCoins = 10,
	MedalCoins = { Gold = 60, Silver = 35, Bronze = 15 },
	-- Trophies only go up. Multiplayer: by place, scaled by how many raced.
	PlaceTrophies = { 12, 9, 7, 5, 4, 3, 2, 2 },
	MedalTrophies = { Gold = 3, Silver = 2, Bronze = 1 },
	SoloTrophyCap = 3, -- solo races give medal trophies only
	-- Anti-cheat. Over the whole race nobody can average more than walk speed times
	-- SustainMult (boost pads and dashes included); between two checkpoints nobody can
	-- beat a full dash on a boost pad. Both allow BurstSlack studs of wiggle room.
	SustainMult = 1.45,
	BurstSlack = 8,
	-- Medal targets: average speeds (studs/s) needed over the whole track.
	MedalSpeeds = { Gold = 34, Silver = 27, Bronze = 20 },
}

Config.Leagues = {
	{ Name = "Bronze", Min = 0, Color = { 205, 127, 50 } },
	{ Name = "Silver", Min = 100, Color = { 192, 192, 200 } },
	{ Name = "Gold", Min = 300, Color = { 255, 205, 60 } },
	{ Name = "Diamond", Min = 700, Color = { 110, 220, 255 } },
	{ Name = "Champion", Min = 1500, Color = { 255, 90, 170 } },
}

Config.AutosaveEvery = 120

-- Promo codes (typed in the DAILY menu). Each works once per player. Codes are not
-- case sensitive. Add new ones for updates and remove old ones.
Config.Codes = {
	LAUNCH = { Coins = 300 },
	ZOOM = { Coins = 150 },
	PETRACE = { Coins = 200 },
}

-- Badge ids from the Creator Dashboard (Badges). nil = not created yet (skipped).
Config.Badges = {
	FirstRace = nil :: number?, -- finish your first race
	FirstWin = nil :: number?, -- win a race against other players
	GoldMedal = nil :: number?, -- get a Gold medal
	Legendary = nil :: number?, -- hatch a Legendary or Mythic pet
	Gold = nil :: number?, -- reach Gold league
	Champion = nil :: number?, -- reach Champion league
	MaxLevel = nil :: number?, -- get any pet stat to level 50
}

return Config
