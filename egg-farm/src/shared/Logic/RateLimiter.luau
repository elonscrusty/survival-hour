--!strict
-- Token bucket per key. The server owns the clock (`now` is always passed in by the caller),
-- so a client can never speed up its own refill.

export type Bucket = { tokens: number, last: number }
export type Limiter = {
	capacity: number,
	refillPerSecond: number,
	buckets: { [any]: Bucket },
	Allow: (self: Limiter, key: any, now: number, cost: number?) -> boolean,
	Forget: (self: Limiter, key: any) -> (),
}

local RateLimiter = {}

local function allow(self: Limiter, key: any, now: number, cost: number?): boolean
	local c = cost or 1
	local b = self.buckets[key]
	if not b then
		b = { tokens = self.capacity, last = now }
		self.buckets[key] = b
	end
	local dt = now - b.last
	if dt > 0 then
		b.tokens = math.min(self.capacity, b.tokens + dt * self.refillPerSecond)
		b.last = now
	end
	if b.tokens >= c then
		b.tokens -= c
		return true
	end
	return false
end

local function forget(self: Limiter, key: any)
	self.buckets[key] = nil
end

function RateLimiter.new(capacity: number, refillPerSecond: number): Limiter
	return {
		capacity = capacity,
		refillPerSecond = refillPerSecond,
		buckets = {},
		Allow = allow,
		Forget = forget,
	}
end

return RateLimiter
