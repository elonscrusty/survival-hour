--!strict
-- Phone offers: a buyer texts a cash offer; the player can Accept, Raise or Decline.
-- Raising can bring a better offer, a final offer, or the buyer walking away.
-- All odds/amounts are catalog placeholders (the reference's rules are unknown).
local BigNum = require("./BigNum")
local Economy = require("./Economy")
type Big = BigNum.Big

local Phone = {}
local C = Economy.Catalog.phone

export type Offer = {
	id: number,
	buyer: string,
	amount: Big,
	round: number,
	final: boolean,
	expires: number,
	state: string, -- "open" | "accepted" | "declined" | "walked" | "expired"
}

Phone.BUYERS = {
	"Big Sal from the Ballpark",
	"Mayor Mustard",
	"Coach Relish",
	"Food Truck Fran",
	"Ziggy (from space)",
	"Grandma Bun",
	"Captain Ketchup",
}

-- rng(): number in [0, 1)
function Phone.newOffer(id: number, incomeRate: Big, now: number, rng: () -> number): Offer?
	if incomeRate.m <= 0 then
		return nil
	end
	local lo, hi = C.offerSeconds.value[1], C.offerSeconds.value[2]
	local secs = lo + (hi - lo) * rng()
	local amount = BigNum.roundCents(BigNum.max(BigNum.mulN(incomeRate, secs), BigNum.new(1)))
	return {
		id = id,
		buyer = Phone.BUYERS[1 + math.floor(rng() * #Phone.BUYERS) % #Phone.BUYERS],
		amount = amount,
		round = 1,
		final = false,
		expires = now + C.expires.value,
		state = "open",
	}
end

-- action: "accept" | "raise" | "decline". Returns outcome and (for accept) the cash to grant.
function Phone.respond(o: Offer, action: string, now: number, rng: () -> number): (string, Big?)
	if o.state ~= "open" then
		return "closed", nil
	end
	if now > o.expires then
		o.state = "expired"
		return "expired", nil
	end
	if action == "accept" then
		o.state = "accepted"
		return "accepted", o.amount
	elseif action == "decline" then
		o.state = "declined"
		return "declined", nil
	elseif action == "raise" then
		if o.final then
			o.state = "walked" -- pushing past a final offer ends the deal
			return "walked", nil
		end
		local odds = C.raiseOdds.value
		local r = rng()
		if r < odds.walk then
			o.state = "walked"
			return "walked", nil
		end
		o.amount = BigNum.roundCents(BigNum.mulN(o.amount, C.raiseStep.value))
		o.round += 1
		o.expires = now + C.expires.value
		if r < odds.walk + odds.final then
			o.final = true
			return "final", nil
		end
		return "better", nil
	end
	return "invalid", nil
end

return Phone
