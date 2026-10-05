--!strict
-- Token-bucket rate limiting, per owner (a player) and per bucket name (a
-- remote). Each bucket refills `Rate` tokens per second up to `Burst`; every
-- call costs one token. Pure: the caller passes the clock.

export type Limit = { Rate: number, Burst: number }
type Bucket = { Tokens: number, At: number }
export type Limiter = { Owners: { [any]: { [string]: Bucket } } }

local RateLimiter = {}

function RateLimiter.New(): Limiter
	return { Owners = {} }
end

function RateLimiter.Allow(l: Limiter, owner: any, name: string, limit: Limit, now: number): boolean
	local buckets = l.Owners[owner]
	if not buckets then
		buckets = {}
		l.Owners[owner] = buckets
	end
	local b = buckets[name]
	if not b then
		b = { Tokens = limit.Burst, At = now }
		buckets[name] = b
	end
	local elapsed = now - b.At
	if elapsed > 0 then
		b.Tokens = math.min(limit.Burst, b.Tokens + elapsed * limit.Rate)
	end
	b.At = math.max(b.At, now)
	if b.Tokens >= 1 then
		b.Tokens -= 1
		return true
	end
	return false
end

function RateLimiter.Forget(l: Limiter, owner: any)
	l.Owners[owner] = nil
end

return RateLimiter
