--!strict
-- Pure life/respawn/revive rules. The server's LivesService owns the actual
-- state and timers; this module decides what happens so it can be unit-tested.
--
-- Player life states:
--   "Alive"          – in the world
--   "Respawning"     – dead, a free respawn was spent, waiting RespawnDelay
--   "AwaitingRevive" – dead, no free respawns left, fire burning, revive window open
--   "Eliminated"     – out for the rest of the match (spectating)
--   "Left"           – disconnected

export type LifeState = "Alive" | "Respawning" | "AwaitingRevive" | "Eliminated" | "Left"

export type Life = {
	State: LifeState,
	FreeRespawns: number, -- math.huge = unlimited while the fire burns
	Deaths: number, -- deaths this match (drives the respawn delay)
	PaidRevives: number, -- paid revives RECEIVED this match (drives the price tier)
	WindowEndsAt: number?,
	PurchaseLockUntil: number?,
	PurchaseLockBy: number?,
}

local LivesRules = {}

function LivesRules.New(freeRespawns: number): Life
	return { State = "Alive", FreeRespawns = freeRespawns, Deaths = 0, PaidRevives = 0 }
end

-- Decides the outcome of a death. Every death while the fire burns spends a
-- free respawn, whatever the cause (DECISIONS D5).
-- Returns the action: "Respawn" | "ReviveWindow" | "Eliminate"
function LivesRules.OnDeath(life: Life, fireBurning: boolean, now: number, reviveWindow: number): string
	if life.State ~= "Alive" then
		return "Ignore"
	end
	life.Deaths += 1
	if not fireBurning then
		life.State = "Eliminated"
		return "Eliminate"
	end
	if life.FreeRespawns > 0 then
		life.FreeRespawns -= 1
		life.State = "Respawning"
		return "Respawn"
	end
	life.State = "AwaitingRevive"
	life.WindowEndsAt = now + reviveWindow
	life.PurchaseLockUntil = nil
	life.PurchaseLockBy = nil
	return "ReviveWindow"
end

-- Respawn delay for the death just recorded: delays[1] for the first death, then
-- delays[2], ... capped at the last entry (spec: 8, 12, 16, then 20 s).
function LivesRules.RespawnDelay(life: Life, delays: { number }): number
	return delays[math.clamp(life.Deaths, 1, #delays)]
end

function LivesRules.Unlimited(life: Life): boolean
	return life.FreeRespawns == math.huge
end

-- The fire just went out: nobody who is waiting may come back.
-- Returns true if the life changed to Eliminated.
function LivesRules.OnFireOut(life: Life): boolean
	if life.State == "Respawning" or life.State == "AwaitingRevive" then
		life.State = "Eliminated"
		life.WindowEndsAt = nil
		return true
	end
	return false
end

-- Revive window expiry check. Returns true if the player was eliminated.
function LivesRules.Tick(life: Life, now: number): boolean
	if life.State == "AwaitingRevive" and life.WindowEndsAt and now >= life.WindowEndsAt then
		life.State = "Eliminated"
		life.WindowEndsAt = nil
		return true
	end
	return false
end

function LivesRules.ReviveTier(life: Life, maxTier: number): number
	return math.min(life.PaidRevives + 1, maxTier)
end

-- Can a revive purchase be started right now for this target?
-- Returns ok, reason.
function LivesRules.CanStartRevive(life: Life, fireBurning: boolean, now: number, payerId: number): (boolean, string?)
	if life.State ~= "AwaitingRevive" then
		return false, "Not awaiting revive"
	end
	if not fireBurning then
		return false, "Fire is out"
	end
	if life.WindowEndsAt == nil or now >= life.WindowEndsAt then
		return false, "Revive window closed"
	end
	if life.PurchaseLockUntil and now < life.PurchaseLockUntil and life.PurchaseLockBy ~= payerId then
		return false, "Another teammate is already paying"
	end
	return true, nil
end

function LivesRules.Lock(life: Life, payerId: number, now: number, lockTime: number)
	life.PurchaseLockBy = payerId
	life.PurchaseLockUntil = now + lockTime
end

function LivesRules.Unlock(life: Life, payerId: number)
	if life.PurchaseLockBy == payerId then
		life.PurchaseLockBy = nil
		life.PurchaseLockUntil = nil
	end
end

-- Applies a revive paid at `tier`. The paid tier must cover the current tier.
-- Returns true on success (caller then respawns the player). A failed apply
-- means the caller must convert the payment into a deferred credit (D8).
function LivesRules.ApplyRevive(life: Life, tier: number, fireBurning: boolean, now: number, maxTier: number): boolean
	if life.State ~= "AwaitingRevive" or not fireBurning then
		return false
	end
	if life.WindowEndsAt == nil or now >= life.WindowEndsAt then
		return false
	end
	if tier < LivesRules.ReviveTier(life, maxTier) then
		return false
	end
	life.PaidRevives += 1
	life.State = "Respawning"
	life.WindowEndsAt = nil
	life.PurchaseLockBy = nil
	life.PurchaseLockUntil = nil
	return true
end

-- Credits are stored as { [tierString] = count }. Returns the lowest usable
-- tier >= needed, or nil.
function LivesRules.FindCredit(credits: { [string]: number }, needed: number, maxTier: number): number?
	for t = needed, maxTier do
		local c = credits[tostring(t)]
		if c and c > 0 then
			return t
		end
	end
	return nil
end

-- A team is still in the match while any member can act now or will act
-- again without further input (Alive / Respawning), or is inside a bounded
-- revive window. Pending purchases never extend the window.
function LivesRules.TeamStanding(lives: { Life }): boolean
	for _, life in lives do
		if life.State == "Alive" or life.State == "Respawning" or life.State == "AwaitingRevive" then
			return true
		end
	end
	return false
end

-- Given team standing flags (index = team), returns: "Continue" | "Winner", teamIndex | "NoTeams"
-- `startedTeams` lists teams that had players when the match began.
function LivesRules.Outcome(standing: { [number]: boolean }, startedTeams: { number }, allowSingleTeam: boolean): (string, number?)
	local alive = {}
	for _, t in startedTeams do
		if standing[t] then
			table.insert(alive, t)
		end
	end
	if #alive == 0 then
		return "NoTeams", nil
	end
	if #alive == 1 then
		if allowSingleTeam and #startedTeams == 1 then
			return "Continue", nil
		end
		return "Winner", alive[1]
	end
	return "Continue", nil
end

return LivesRules
