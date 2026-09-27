--!strict
-- Token-bucket rate limiter keyed by (player, bucket). Pure; time is injected.

export type Limiter = {
	Buckets: { [any]: { [string]: { Tokens: number, Last: number } } },
	Rules: { [string]: { number } },
}

local RateLimiter = {}

function RateLimiter.New(rules: { [string]: { number } }): Limiter
	return { Buckets = {}, Rules = rules }
end

-- Returns true if the action is allowed (and consumes a token).
function RateLimiter.Allow(lim: Limiter, key: any, bucket: string, now: number): boolean
	local rule = lim.Rules[bucket] or lim.Rules.Default
	local rate, burst = rule[1], rule[2]
	local perKey = lim.Buckets[key]
	if perKey == nil then
		perKey = {}
		lim.Buckets[key] = perKey
	end
	local b = perKey[bucket]
	if b == nil then
		b = { Tokens = burst, Last = now }
		perKey[bucket] = b
	end
	b.Tokens = math.min(burst, b.Tokens + (now - b.Last) * rate)
	b.Last = now
	if b.Tokens >= 1 then
		b.Tokens -= 1
		return true
	end
	return false
end

function RateLimiter.Forget(lim: Limiter, key: any)
	lim.Buckets[key] = nil
end

return RateLimiter
