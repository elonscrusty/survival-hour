--!strict
-- What a purchase / claim button shows. PURE (no Roblox APIs) so it is unit-tested
-- (tests/PurchaseState.spec). The UI recomputes this on every snapshot and timer tick, so
-- affordability is never stale.
--
-- Input:
--   price        number? : the cost (from Logic/Prices), or nil when it can't be bought
--   reason       string? : the reason code when price is nil (Prices codes: "max_level", "locked",
--                          "slot_locked", "slot_taken", "invalid", ...; plus "owned", "claimed",
--                          "not_ready", "tutorial")
--   balance      number  : what the player has in the matching currency
--   currency     string? : "cash" (default) | "gold" | "robux" | "free"
--   owned        boolean?: a one-time thing already owned (passes)
--   busy         boolean?: a request for this button is in flight
--   lastRejectAt number? : when the server (or a local check) last rejected this button
--   now          number  : clock used for lastRejectAt (any monotonic clock, seconds)
--
-- Output: { state, canRequest, code? }
--   state      : "loading" | "rejected" | "owned" | "max" | "locked" | "unavailable"
--                | "affordable" | "unaffordable"
--   canRequest : true only when a tap should contact the server
--   code       : Contract.Messages key explaining why a tap does nothing (for a toast)

export type Input = {
	price: number?,
	reason: string?,
	balance: number,
	currency: string?,
	owned: boolean?,
	busy: boolean?,
	lastRejectAt: number?,
	now: number,
}

export type Output = { state: string, canRequest: boolean, code: string? }

local PurchaseState = {}

PurchaseState.REJECT_SHOW = 1.2 -- seconds the red "rejected" look stays before the live state returns

local LOCKED = {
	locked = true,
	slot_locked = true,
	tutorial = true,
	not_last_egg = true,
	skip_too_early = true,
	not_requirement = true,
}

function PurchaseState.Compute(i: Input): Output
	if i.busy then
		return { state = "loading", canRequest = false, code = nil }
	end
	if i.lastRejectAt and i.now >= i.lastRejectAt and i.now - i.lastRejectAt < PurchaseState.REJECT_SHOW then
		return { state = "rejected", canRequest = false, code = nil }
	end
	if i.owned or i.reason == "owned" or i.reason == "slot_taken" or i.reason == "claimed" or i.reason == "already" then
		return { state = "owned", canRequest = false, code = "already" }
	end
	local price = i.price
	if price == nil then
		local reason = i.reason or "invalid"
		if reason == "max_level" then
			return { state = "max", canRequest = false, code = "max_level" }
		elseif LOCKED[reason] then
			return { state = "locked", canRequest = false, code = reason }
		end
		return { state = "unavailable", canRequest = false, code = reason }
	end
	-- Robux prices are paid through Roblox's own prompt: the balance isn't known here.
	if i.currency == "robux" or i.currency == "free" or price <= 0 then
		return { state = "affordable", canRequest = true, code = nil }
	end
	if i.balance >= price then
		return { state = "affordable", canRequest = true, code = nil }
	end
	return {
		state = "unaffordable",
		canRequest = false,
		code = if i.currency == "gold" then "cant_afford_gold" else "cant_afford",
	}
end

-- Short button caption for states that replace the price text (nil = show the price).
function PurchaseState.Caption(state: string): string?
	if state == "loading" then
		return "..."
	elseif state == "owned" then
		return "OWNED"
	elseif state == "max" then
		return "MAX"
	elseif state == "locked" then
		return "LOCKED"
	elseif state == "unavailable" then
		return "N/A"
	end
	return nil
end

-- Whether a rejection should be remembered (all failures except our own dedupe).
function PurchaseState.IsRejection(result: { ok: boolean, code: string }?): boolean
	return result ~= nil and not result.ok and result.code ~= "busy"
end

return PurchaseState
