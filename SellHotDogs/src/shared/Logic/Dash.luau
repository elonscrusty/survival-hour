--!strict
-- DogDash the Game: four hot dogs race; the player bets on one and can press Cheer to push it.
-- Shape from secondary guides (four runners, bet, cheer); payout/timing are placeholders.
-- The server simulates the race; the client only animates the positions it is sent.
local BigNum = require("./BigNum")
local Economy = require("./Economy")
type Big = BigNum.Big

local Dash = {}
local C = Economy.Catalog.dash

export type Race = {
	pick: number,
	bet: Big,
	pos: { number }, -- 0..1 per runner
	speed: { number }, -- base speed per runner (track lengths per second)
	t: number,
	cheers: number,
	cheerWindow: number, -- cheers counted in the current second
	windowStart: number,
	winner: number?,
}

Dash.MAX_CHEERS_PER_SEC = 6

function Dash.betAmount(cash: Big, fractionIndex: number): Big?
	local f = C.betFractions.value[fractionIndex]
	if not f then
		return nil
	end
	return BigNum.roundCents(BigNum.mulN(cash, f))
end

function Dash.new(pick: number, bet: Big, rng: () -> number): Race?
	if pick < 1 or pick > C.runners.value or pick ~= math.floor(pick) then
		return nil
	end
	local base = 1 / C.raceSeconds.value
	local speed = {}
	local pos = {}
	for i = 1, C.runners.value do
		speed[i] = base * (0.9 + 0.2 * rng())
		pos[i] = 0
	end
	return { pick = pick, bet = bet, pos = pos, speed = speed, t = 0, cheers = 0, cheerWindow = 0, windowStart = 0, winner = nil }
end

-- Count a cheer if under the per-second cap. Returns whether it counted.
function Dash.cheer(r: Race): boolean
	if r.winner then
		return false
	end
	if r.t - r.windowStart >= 1 then
		r.windowStart = r.t
		r.cheerWindow = 0
	end
	if r.cheerWindow >= Dash.MAX_CHEERS_PER_SEC then
		return false
	end
	r.cheerWindow += 1
	r.cheers += 1
	return true
end

-- Advance the race. Each runner jitters a little; cheers add speed to the picked runner.
function Dash.step(r: Race, dt: number, rng: () -> number): number?
	if r.winner then
		return r.winner
	end
	r.t += dt
	local best, bestPos = nil, -1
	for i = 1, #r.pos do
		local s = r.speed[i] * (0.75 + 0.5 * rng())
		if i == r.pick then
			-- only the last second of cheering counts, so the boost is capped
			s += r.speed[i] * r.cheerWindow * C.cheerBoost.value
		end
		r.pos[i] = math.min(1, r.pos[i] + s * dt)
		if r.pos[i] > bestPos then
			best, bestPos = i, r.pos[i]
		end
	end
	if bestPos >= 1 then
		r.winner = best
	end
	return r.winner
end

-- Cash to pay back on a finished race (bet already deducted at start).
function Dash.payout(r: Race): Big
	if r.winner == r.pick then
		return BigNum.roundCents(BigNum.mulN(r.bet, C.winPays.value))
	end
	return BigNum.zero
end

return Dash
