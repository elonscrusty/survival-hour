--!strict
-- Versioned save data: creation, validation and migration. Pure.
-- A profile that fails validation is never "repaired" into an empty one silently: migrate()
-- returns nil plus a reason, and the caller must not save over the stored data.
local BigNum = require("./BigNum")
local Economy = require("./Economy")
type Big = BigNum.Big

export type BizState = { level: number, progress: number, running: boolean }

export type Profile = {
	v: number,
	cash: Big,
	lifetime: Big, -- earned since the last rebirth (drives investors offered)
	totalEarned: Big,
	biz: { [string]: BizState },
	pads: { [string]: boolean },
	forever: { [string]: boolean },
	foreverTokens: number,
	decor: { [string]: boolean }, -- looks-only plot decorations (never reset)
	investors: Big,
	evolutions: number,
	ascensions: number,
	powers: { [string]: number }, -- bought with investors (reset by evolution)
	robux: {
		passes: { [string]: boolean },
		tiers: { [string]: number }, -- permanent power tiers from Robux
		receipts: { string }, -- recent PurchaseIds (idempotency)
		rebirthCredits: number,
		skipSeconds: number, -- time-skip seconds waiting for income to exist
	},
	name: string?,
	lastSeen: number,
	pendingOffline: Big,
	stats: { [string]: number },
}

local Profile = {}

Profile.VERSION = 2
Profile.MAX_RECEIPTS = 200

local function freshBiz(): { [string]: BizState }
	local t = {}
	for _, b in Economy.businesses do
		t[b.id] = { level = 0, progress = 0, running = false }
	end
	return t
end

function Profile.new(now: number): Profile
	return {
		v = Profile.VERSION,
		cash = BigNum.new(Economy.Catalog.start.cash.value),
		lifetime = BigNum.zero,
		totalEarned = BigNum.zero,
		biz = freshBiz(),
		pads = {},
		forever = {},
		foreverTokens = 0,
		decor = {},
		investors = BigNum.zero,
		evolutions = 0,
		ascensions = 0,
		powers = {},
		robux = { passes = {}, tiers = {}, receipts = {}, rebirthCredits = 0, skipSeconds = 0 },
		name = nil,
		lastSeen = now,
		pendingOffline = BigNum.zero,
		stats = { rebirths = 0, clicks = 0, pickups = 0, deals = 0, races = 0 },
	}
end

Profile.freshBiz = freshBiz

local function int(v: any, lo: number, hi: number): number?
	if type(v) ~= "number" or v ~= v then
		return nil
	end
	return math.clamp(math.floor(v), lo, hi)
end

local function big(v: any): Big?
	local b = BigNum.sanitize(v)
	if b and b.m < 0 then
		return nil
	end
	return b
end

local function padSet(v: any): { [string]: boolean }
	local out = {}
	if type(v) == "table" then
		for k, on in v do
			if type(k) == "string" and on == true and Economy.padById[k] then
				out[k] = true
			end
		end
	end
	return out
end

-- Version 1 stored cash as a plain number and had no forever tokens.
local MIGRATIONS: { [number]: (any) -> any } = {
	[1] = function(d)
		d.v = 2
		if type(d.cash) == "number" then
			d.cash = BigNum.new(d.cash)
		end
		d.foreverTokens = d.foreverTokens or 0
		return d
	end,
}

-- Returns a validated profile, or nil + reason. `raw` may be any decoded DataStore value.
function Profile.migrate(raw: any, now: number): (Profile?, string?)
	if raw == nil then
		return Profile.new(now), "new"
	end
	if type(raw) ~= "table" or type(raw.v) ~= "number" then
		return nil, "unrecognised save format"
	end
	if raw.v > Profile.VERSION then
		return nil, "save is from a newer game version"
	end
	local d = raw
	while d.v < Profile.VERSION do
		local step = MIGRATIONS[d.v]
		if not step then
			return nil, "no migration from version " .. tostring(d.v)
		end
		d = step(d)
	end

	local p = Profile.new(now)
	local cash = big(d.cash)
	if not cash then
		return nil, "cash is invalid"
	end
	p.cash = cash
	p.lifetime = big(d.lifetime) or BigNum.zero
	p.totalEarned = big(d.totalEarned) or BigNum.zero
	p.investors = big(d.investors) or BigNum.zero
	p.pendingOffline = big(d.pendingOffline) or BigNum.zero
	p.pads = padSet(d.pads)
	p.forever = padSet(d.forever)
	p.foreverTokens = int(d.foreverTokens, 0, 1e6) or 0
	if type(d.decor) == "table" then
		for _, item in Economy.Catalog.decor.items do
			if d.decor[item.id] == true then
				p.decor[item.id] = true
			end
		end
	end
	p.evolutions = int(d.evolutions, 0, 1e6) or 0
	p.ascensions = int(d.ascensions, 0, 1e6) or 0
	p.lastSeen = if type(d.lastSeen) == "number" and d.lastSeen == d.lastSeen then d.lastSeen else now
	if type(d.name) == "string" and #d.name <= 64 then
		p.name = d.name
	end

	if type(d.biz) == "table" then
		for id, st in p.biz do
			local s = d.biz[id]
			if type(s) == "table" then
				st.level = int(s.level, 0, 1e7) or 0
				st.progress = if type(s.progress) == "number" and s.progress == s.progress then math.clamp(s.progress, 0, 1) else 0
				st.running = s.running == true
			end
			-- a business level without its unlock pad is inconsistent: trust the pad
			if not (p.pads["biz:" .. id] or p.forever["biz:" .. id]) then
				st.level, st.progress, st.running = 0, 0, false
			elseif st.level < 1 then
				st.level = 1
			end
		end
	end

	if type(d.powers) == "table" then
		for _, pw in Economy.Catalog.powers do
			p.powers[pw.id] = int(d.powers[pw.id], 0, pw.tiers) or nil :: any
		end
	end
	local r = d.robux
	if type(r) == "table" then
		if type(r.passes) == "table" then
			for k, v in r.passes do
				if type(k) == "string" and v == true then
					p.robux.passes[k] = true
				end
			end
		end
		if type(r.tiers) == "table" then
			for _, pw in Economy.Catalog.powers do
				p.robux.tiers[pw.id] = int(r.tiers[pw.id], 0, pw.tiers) or nil :: any
			end
		end
		if type(r.receipts) == "table" then
			for _, id in r.receipts do
				if type(id) == "string" then
					table.insert(p.robux.receipts, id)
				end
			end
		end
		p.robux.rebirthCredits = int(r.rebirthCredits, 0, 1e6) or 0
		p.robux.skipSeconds = if type(r.skipSeconds) == "number" and r.skipSeconds == r.skipSeconds then math.max(0, r.skipSeconds) else 0
	end
	if type(d.stats) == "table" then
		for k, v in d.stats do
			if type(k) == "string" and type(v) == "number" and v == v then
				p.stats[k] = v
			end
		end
	end
	return p, nil
end

-- Deep copy into plain tables (for saving / sending).
function Profile.serialize(p: Profile): any
	local function copy(v: any): any
		if type(v) ~= "table" then
			return v
		end
		local t = {}
		for k, x in v do
			t[k] = copy(x)
		end
		return t
	end
	return copy(p)
end

return Profile
