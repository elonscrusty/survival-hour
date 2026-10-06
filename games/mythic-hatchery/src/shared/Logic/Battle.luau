--!strict
-- Pure battle simulation. All calls use server time and owned creature snapshots.
-- Service integration must validate ownership/busy state and journal reward claims.
local Gameplay = require("../Gameplay")
local Elements = require("../Elements")
local Moves = require("../Moves")
local Level = require("./Level")
local Tuning = Gameplay.Battle
export type Fighter = { Creature: Level.Creature, Hp: number, MaxHp: number, Shield: number, Entered: boolean, Contribution: number }
export type Side = { UserId: number, Fighters: { Fighter }, Active: number, MoveAt: number, SwapAt: number }
export type State = { Id: string, Sides: { Side }, Status: string, Winner: number?, StartedAt: number, Now: number }
export type Reward = { Coins: number, Points: number, Xp: { [string]: number } }
local Battle = {}

local function side(userId: number, creatures: { Level.Creature }, now: number): Side
	assert(#creatures == Tuning.TeamSize, "Choose three creatures")
	local seen: { [string]: boolean } = {}
	local fighters: { Fighter } = {}
	for i, c in creatures do
		assert(c.Uid ~= "" and not seen[c.Uid], "Duplicate creature")
		seen[c.Uid] = true
		Moves.For(c) -- verifies species/element before any battle is created
		local hp = Tuning.BaseHp * Level.Power(c)
		table.insert(fighters, { Creature = table.clone(c), Hp = hp, MaxHp = hp, Shield = 0, Entered = i == 1, Contribution = 0 })
	end
	return { UserId = userId, Fighters = fighters, Active = 1, MoveAt = now, SwapAt = now }
end
function Battle.New(id: string, left: number, right: number, a: { Level.Creature }, b: { Level.Creature }, now: number): State
	assert(left ~= right and Level.IsFinite(now), "Invalid battle")
	return { Id = id, Sides = { side(left, a, now), side(right, b, now) }, Status = "Running", Winner = nil, StartedAt = now, Now = now }
end
local function find(b: State, userId: number): (Side?, Side?)
	for i, s in b.Sides do
		if s.UserId == userId then return s, b.Sides[3 - i] end
	end
	return nil, nil
end
local function validTime(b: State, now: number): boolean
	return b.Status == "Running" and Level.IsFinite(now) and now >= b.Now and now - b.StartedAt < Tuning.MaxSeconds
end
local function replace(b: State, s: Side, winner: Side)
	if s.Fighters[s.Active].Hp > 0 then return end
	for i, f in s.Fighters do
		if f.Hp > 0 then s.Active = i; f.Entered = true; return end
	end
	b.Status = "Done"; b.Winner = winner.UserId
end
function Battle.Move(b: State, userId: number, moveId: string, now: number): (boolean, string?)
	if not validTime(b, now) then return false, "Battle unavailable" end
	local s, other = find(b, userId)
	if not s or not other then return false, "Not in this battle" end
	if now < s.MoveAt then return false, "Moves cooling down" end
	local attacker, defender = s.Fighters[s.Active], other.Fighters[other.Active]
	local chosen: Moves.Move? = nil
	for _, move in Moves.For(attacker.Creature) do if move.Id == moveId then chosen = move; break end end
	if not chosen then return false, "Move not unlocked" end
	local move = chosen :: Moves.Move
	local amount = Tuning.BaseDamage * Level.Power(attacker.Creature) * move.Power
	if move.Kind == "Heal" then
		amount = math.min(amount, attacker.MaxHp - attacker.Hp)
		if amount <= 0 then return false, "Already at full health" end
		attacker.Hp += amount; attacker.Contribution += amount
	elseif move.Kind == "Guard" then
		if attacker.Shield > 0 then return false, "Already guarded" end
		attacker.Shield = amount
	else
		if move.Element and Elements.HasEdge(move.Element, defender.Creature.Element) then amount *= Tuning.ElementBonus end
		local absorbed = math.min(defender.Shield, amount)
		defender.Shield -= absorbed; amount -= absorbed
		defender.Contribution += absorbed
		amount = math.min(defender.Hp, amount)
		defender.Hp -= amount; attacker.Contribution += amount
	end
	attacker.Entered = true
	s.MoveAt = now + Tuning.MoveCooldown
	b.Now = now
	replace(b, other, s)
	return true, nil
end
function Battle.Swap(b: State, userId: number, index: number, now: number): (boolean, string?)
	if not validTime(b, now) or not Level.IsFinite(index) or index % 1 ~= 0 then return false, "Invalid swap" end
	local s = find(b, userId)
	if not s then return false, "Not in this battle" end
	if now < s.SwapAt then return false, "Swap cooling down" end
	local f = s.Fighters[index]
	if not f or f.Hp <= 0 or s.Active == index then return false, "Choose a living reserve" end
	s.Active = index; f.Entered = true; s.SwapAt = now + Tuning.SwapCooldown; b.Now = now
	return true, nil
end
function Battle.Forfeit(b: State, userId: number, now: number): boolean
	if b.Status ~= "Running" or not Level.IsFinite(now) or now < b.Now then return false end
	local s, opponent = find(b, userId)
	if not s or not opponent then return false end
	b.Status = "Done"; b.Winner = opponent.UserId; b.Now = now
	return true
end
-- Time limit prevents healing loops; remaining health fractions determine winner.
-- A tie is a draw: participation coins/XP, no arena-point change.
function Battle.Timeout(b: State, now: number): boolean
	if b.Status ~= "Running" or not Level.IsFinite(now) or now < b.Now or now - b.StartedAt < Tuning.MaxSeconds then return false end
	local totals = { 0, 0 }
	for i, s in b.Sides do for _, f in s.Fighters do totals[i] += f.Hp / f.MaxHp end end
	b.Status = "Done"; b.Now = now
	if math.abs(totals[1] - totals[2]) > 1e-8 then b.Winner = b.Sides[if totals[1] > totals[2] then 1 else 2].UserId end
	return true
end
-- Calculation only, never grants currency. Services must dedupe by battle Id.
function Battle.Reward(b: State, userId: number): Reward?
	if b.Status ~= "Done" then return nil end
	local s = find(b, userId)
	if not s then return nil end
	local won = b.Winner == userId
	local budget = if won then Tuning.WinXp else Tuning.LoseXp
	local participants: { Fighter } = {}
	local weights, total = {}, 0
	for _, f in s.Fighters do
		if f.Entered then
			table.insert(participants, f)
			local weight = 1 + f.Contribution
			table.insert(weights, weight); total += weight
		end
	end
	local xp: { [string]: number } = {}
	local fractions: { { Uid: string, Fraction: number, Order: number } } = {}
	local allocated = 0
	for i, f in participants do
		local share = budget * weights[i] / total
		local whole = math.floor(share)
		xp[f.Creature.Uid] = whole; allocated += whole
		table.insert(fractions, { Uid = f.Creature.Uid, Fraction = share - whole, Order = i })
	end
	table.sort(fractions, function(a: { Uid: string, Fraction: number, Order: number }, c: { Uid: string, Fraction: number, Order: number }) return if a.Fraction == c.Fraction then a.Order < c.Order else a.Fraction > c.Fraction end)
	for i = 1, budget - allocated do
		local uid = fractions[i].Uid; xp[uid] += 1
	end
	return {
		Coins = if won then Tuning.WinCoins else Tuning.LoseCoins,
		Points = if b.Winner == nil then 0 elseif won then Tuning.WinPoints else -Tuning.LosePoints,
		Xp = xp,
	}
end
function Battle.TeamStrength(team: { Level.Creature }): number
	local power = 0
	for _, c in team do power += Level.Power(c) end
	return power
end
function Battle.CanMatch(a: { Level.Creature }, b: { Level.Creature }): boolean
	if #a ~= Tuning.TeamSize or #b ~= Tuning.TeamSize then return false end
	local left, right = Battle.TeamStrength(a), Battle.TeamStrength(b)
	return math.max(left, right) / math.min(left, right) <= Tuning.MatchStrengthRatio
end
return Battle
