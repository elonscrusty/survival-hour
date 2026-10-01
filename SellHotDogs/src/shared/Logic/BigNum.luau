--!strict
-- Serializable big numbers for cash and investors: value = m * 10^e with 1 <= |m| < 10
-- (or m = 0, e = 0). Plain tables so they save to a DataStore and cross remotes as-is.
-- Ordinary doubles overflow near 1e308; reference footage shows wallets near 10^564.

export type Big = { m: number, e: number }

local BigNum = {}

local ZERO_EXP_GAP = 17 -- beyond this many orders of magnitude the smaller term is invisible

local function norm(m: number, e: number): Big
	if m ~= m or m == math.huge or m == -math.huge then
		error("BigNum: non-finite mantissa")
	end
	if m == 0 then
		return { m = 0, e = 0 }
	end
	local shift = math.floor(math.log10(math.abs(m)))
	m = m / 10 ^ shift
	e = e + shift
	-- guard float drift (e.g. 9.9999999 or 10.0000001)
	if math.abs(m) >= 10 then
		m /= 10
		e += 1
	elseif math.abs(m) < 1 then
		m *= 10
		e -= 1
	end
	return { m = m, e = e }
end

function BigNum.new(n: number): Big
	return norm(n, 0)
end

function BigNum.fromParts(m: number, e: number): Big
	return norm(m, e)
end

BigNum.zero = table.freeze({ m = 0, e = 0 })

-- Accepts saved/remote data; returns nil if it is not a valid finite big number.
function BigNum.sanitize(v: any): Big?
	if type(v) == "number" then
		if v ~= v or math.abs(v) == math.huge then
			return nil
		end
		return norm(v, 0)
	end
	if type(v) ~= "table" or type(v.m) ~= "number" or type(v.e) ~= "number" then
		return nil
	end
	if v.m ~= v.m or math.abs(v.m) == math.huge or v.e ~= v.e or math.abs(v.e) == math.huge then
		return nil
	end
	return norm(v.m, math.floor(v.e))
end

function BigNum.copy(a: Big): Big
	return { m = a.m, e = a.e }
end

function BigNum.isZero(a: Big): boolean
	return a.m == 0
end

function BigNum.add(a: Big, b: Big): Big
	if a.m == 0 then
		return BigNum.copy(b)
	end
	if b.m == 0 then
		return BigNum.copy(a)
	end
	if a.e < b.e then
		a, b = b, a
	end
	local gap = a.e - b.e
	if gap > ZERO_EXP_GAP then
		return BigNum.copy(a)
	end
	return norm(a.m + b.m / 10 ^ gap, a.e)
end

function BigNum.neg(a: Big): Big
	return { m = -a.m, e = a.e }
end

function BigNum.sub(a: Big, b: Big): Big
	return BigNum.add(a, BigNum.neg(b))
end

function BigNum.mul(a: Big, b: Big): Big
	if a.m == 0 or b.m == 0 then
		return { m = 0, e = 0 }
	end
	return norm(a.m * b.m, a.e + b.e)
end

function BigNum.mulN(a: Big, n: number): Big
	return BigNum.mul(a, norm(n, 0))
end

function BigNum.div(a: Big, b: Big): Big
	if b.m == 0 then
		error("BigNum: divide by zero")
	end
	if a.m == 0 then
		return { m = 0, e = 0 }
	end
	return norm(a.m / b.m, a.e - b.e)
end

-- x^p for a plain number power (used for multiplier stacks like 42^evolutions).
function BigNum.powN(base: number, p: number): Big
	if base <= 0 then
		return p == 0 and norm(1, 0) or { m = 0, e = 0 }
	end
	local l = math.log10(base) * p
	local e = math.floor(l)
	return norm(10 ^ (l - e), e)
end

function BigNum.cmp(a: Big, b: Big): number
	local sa = a.m > 0 and 1 or (a.m < 0 and -1 or 0)
	local sb = b.m > 0 and 1 or (b.m < 0 and -1 or 0)
	if sa ~= sb then
		return sa < sb and -1 or 1
	end
	if sa == 0 then
		return 0
	end
	if a.e ~= b.e then
		local r = a.e < b.e and -1 or 1
		return sa > 0 and r or -r
	end
	if a.m == b.m then
		return 0
	end
	return a.m < b.m and -1 or 1
end

function BigNum.lt(a: Big, b: Big): boolean
	return BigNum.cmp(a, b) < 0
end
function BigNum.gte(a: Big, b: Big): boolean
	return BigNum.cmp(a, b) >= 0
end
function BigNum.eq(a: Big, b: Big): boolean
	return BigNum.cmp(a, b) == 0
end

function BigNum.max(a: Big, b: Big): Big
	return BigNum.cmp(a, b) >= 0 and a or b
end

-- Plain number (may be math.huge for very large values). For ratios and display only.
function BigNum.toNumber(a: Big): number
	if a.e > 308 then
		return a.m > 0 and math.huge or -math.huge
	end
	if a.e < -320 then
		return 0
	end
	return a.m * 10 ^ a.e
end

-- log10 as a plain number; -inf for zero. Safe for any exponent.
function BigNum.log10(a: Big): number
	if a.m <= 0 then
		return -math.huge
	end
	return a.e + math.log10(a.m)
end

function BigNum.floor(a: Big): Big
	if a.e >= 15 or a.m == 0 then
		return BigNum.copy(a)
	end
	if a.e < 0 then
		return { m = 0, e = 0 }
	end
	return norm(math.floor(a.m * 10 ^ a.e + 1e-9), 0)
end

-- Round to whole cents. Settled cash stays cent-exact while it is small.
function BigNum.roundCents(a: Big): Big
	if a.e >= 13 or a.m == 0 then
		return BigNum.copy(a)
	end
	local v = a.m * 10 ^ a.e
	return norm(math.floor(v * 100 + 0.5) / 100, 0)
end

-- Square root (used by placeholder investor award rule).
function BigNum.sqrt(a: Big): Big
	if a.m <= 0 then
		return { m = 0, e = 0 }
	end
	local l = BigNum.log10(a) / 2
	local e = math.floor(l)
	return norm(10 ^ (l - e), e)
end

return BigNum
