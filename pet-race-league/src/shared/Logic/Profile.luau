-- Player save data: defaults, cleaning up loaded data, and pet inventory rules.
local Config = require("../Config")
local Pets = require("../Pets")
local Cosmetics = require("../Cosmetics")
local PetStats = require("./PetStats")

local Profile = {}

export type Data = {
	Version: number,
	Coins: number,
	Trophies: number,
	Pets: { PetStats.Pet },
	Equipped: string?, -- pet uid
	NextUid: number,
	Owned: { [string]: boolean }, -- cosmetics
	Pity: { [string]: number }, -- hatches per egg
	BestTimes: { [string]: number }, -- per track
	Stats: { [string]: number }, -- lifetime: Races, Wins, Hatches, Golds
	BigBarn: boolean,
	Receipts: { string }, -- recent purchase ids (duplicate guard)
	Tutorial: boolean,
}

function Profile.Default(): Data
	local d: Data = {
		Version = Config.ProfileVersion,
		Coins = Config.StartCoins,
		Trophies = 0,
		Pets = {},
		Equipped = nil,
		NextUid = 1,
		Owned = {},
		Pity = {},
		BestTimes = {},
		Stats = { Races = 0, Wins = 0, Hatches = 0, Golds = 0 },
		BigBarn = false,
		Receipts = {},
		Tutorial = false,
	}
	-- Everyone starts with a Pup so they can ride and race straight away.
	local pup = Profile.AddPet(d, "Pup")
	d.Equipped = pup and pup.Uid
	return d
end

local function num(v: any, default: number, lo: number, hi: number): number
	if type(v) ~= "number" or v ~= v then
		return default
	end
	return math.clamp(v, lo, hi)
end

-- Repairs anything missing or broken in loaded data (old versions, bad values).
function Profile.Sanitize(raw: any): Data
	if type(raw) ~= "table" then
		return Profile.Default()
	end
	local d = Profile.Default()
	d.Pets = {}
	d.Equipped = nil
	d.Coins = math.floor(num(raw.Coins, Config.StartCoins, 0, 1e12))
	d.Trophies = math.floor(num(raw.Trophies, 0, 0, 1e9))
	d.NextUid = math.floor(num(raw.NextUid, 1, 1, 1e12))
	d.BigBarn = raw.BigBarn == true
	d.Tutorial = raw.Tutorial == true
	if type(raw.Pets) == "table" then
		local seen = {}
		for _, p in raw.Pets do
			if type(p) == "table" and type(p.Uid) == "string" and Pets.ById[p.Species] and not seen[p.Uid] then
				seen[p.Uid] = true
				local pet = PetStats.New(p.Uid, p.Species)
				for _, s in Config.Stats.Names do
					pet.Levels[s] = math.floor(num(p.Levels and p.Levels[s], 1, 1, Config.Stats.MaxLevel))
					pet.Xp[s] = num(p.Xp and p.Xp[s], 0, 0, 1e9)
				end
				if type(p.Paint) == "string" and Cosmetics.ById[p.Paint] then
					pet.Paint = p.Paint
				end
				if type(p.Trail) == "string" and Cosmetics.ById[p.Trail] then
					pet.Trail = p.Trail
				end
				if type(p.Nick) == "string" then
					pet.Nick = string.sub(p.Nick, 1, 20)
				end
				table.insert(d.Pets, pet)
			end
		end
	end
	if type(raw.Owned) == "table" then
		for id, v in raw.Owned do
			if v == true and Cosmetics.ById[id] then
				d.Owned[id] = true
			end
		end
	end
	for _, key in { "Pity", "BestTimes", "Stats" } do
		local src = raw[key]
		if type(src) == "table" then
			for k, v in src do
				if type(k) == "string" and type(v) == "number" and v == v and v >= 0 then
					(d :: any)[key][k] = v
				end
			end
		end
	end
	if type(raw.Receipts) == "table" then
		for _, r in raw.Receipts do
			if type(r) == "string" then
				table.insert(d.Receipts, r)
			end
		end
	end
	if #d.Pets == 0 then
		local pup = Profile.AddPet(d, "Pup")
		d.Equipped = pup and pup.Uid
	elseif Profile.FindPet(d, raw.Equipped) then
		d.Equipped = raw.Equipped
	else
		d.Equipped = d.Pets[1].Uid
	end
	return d
end

function Profile.Capacity(d: Data): number
	return Config.Slots.Base + (if d.BigBarn then Config.Slots.BonusPass else 0)
end

function Profile.FindPet(d: Data, uid: any): PetStats.Pet?
	if type(uid) ~= "string" then
		return nil
	end
	for _, p in d.Pets do
		if p.Uid == uid then
			return p
		end
	end
	return nil
end

function Profile.EquippedPet(d: Data): PetStats.Pet?
	return Profile.FindPet(d, d.Equipped)
end

-- Adds a new pet. Returns nil if storage is full.
function Profile.AddPet(d: Data, species: string): PetStats.Pet?
	if #d.Pets >= Profile.Capacity(d) or not Pets.ById[species] then
		return nil
	end
	local pet = PetStats.New("p" .. d.NextUid, species)
	d.NextUid += 1
	table.insert(d.Pets, pet)
	return pet
end

-- Removes a pet. You can't release your ridden pet or your last pet.
function Profile.Release(d: Data, uid: string): (boolean, string?)
	if #d.Pets <= 1 then
		return false, "You can't release your last pet."
	end
	if d.Equipped == uid then
		return false, "Pick another pet before releasing this one."
	end
	for i, p in d.Pets do
		if p.Uid == uid then
			table.remove(d.Pets, i)
			return true, p.Species
		end
	end
	return false, "Pet not found."
end

-- Records a purchase id. Returns false if it was already handled.
function Profile.TakeReceipt(d: Data, id: string): boolean
	if table.find(d.Receipts, id) then
		return false
	end
	table.insert(d.Receipts, id)
	while #d.Receipts > 50 do
		table.remove(d.Receipts, 1)
	end
	return true
end

return Profile
