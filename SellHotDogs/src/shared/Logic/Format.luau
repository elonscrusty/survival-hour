--!strict
-- Player-facing number text. Display only: never feed these strings back into arithmetic.
-- Style follows the reference HUD: "$3.24", "$4,772", "$296.102 trillion".
local BigNum = require("./BigNum")
type Big = BigNum.Big

local Format = {}

local UNITS = { "", "un", "duo", "tre", "quattuor", "quin", "sex", "septen", "octo", "novem" }
local SMALL = { "m", "b", "tr", "quadr", "quint", "sext", "sept", "oct", "non" }
local TENS = { "dec", "vigint", "trigint", "quadragint", "quinquagint", "sexagint", "septuagint", "octogint", "nonagint" }

-- Name of 10^(3n+3), n >= 1: 1 = million, 2 = billion, 10 = decillion, 26 = sexvigintillion.
function Format.illion(n: number): string?
	if n < 1 then
		return nil
	end
	if n < 10 then
		return SMALL[n] .. "illion"
	end
	if n == 100 then
		return "centillion"
	end
	if n > 100 then
		return nil
	end
	local u, t = n % 10, n // 10
	return UNITS[u + 1] .. TENS[t] .. "illion"
end

local function commas(int: number): string
	local s = string.format("%d", int)
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return out
end

local function trim(s: string): string
	if s:find("%.") then
		s = s:gsub("0+$", ""):gsub("%.$", "")
	end
	return s
end

-- Plain amount without a currency sign.
function Format.amount(v: Big | number, decimalsUnder1000: number?): string
	local a: Big = if type(v) == "number" then BigNum.new(v) else v
	if a.m < 0 then
		return "-" .. Format.amount(BigNum.neg(a), decimalsUnder1000)
	end
	if a.m == 0 then
		return decimalsUnder1000 == 0 and "0" or "0.00"
	end
	if a.e < 3 then
		local n = a.m * 10 ^ a.e
		local d = decimalsUnder1000 or 2
		local s = string.format("%." .. d .. "f", n)
		-- rounding can carry into the thousands
		if (tonumber(s) :: number) < 1000 then
			return s
		end
		return commas(1000)
	end
	if a.e < 6 then
		return commas(math.floor(a.m * 10 ^ a.e + 1e-6))
	end
	local group = a.e // 3 -- 2 = millions
	local name = Format.illion(group - 1)
	if not name then
		return trim(string.format("%.2f", a.m)) .. "e" .. tostring(a.e)
	end
	local lead = a.m * 10 ^ (a.e - group * 3)
	return trim(string.format("%.3f", lead)) .. " " .. name
end

function Format.cash(v: Big | number): string
	return "$" .. Format.amount(v)
end

-- Compact form for tight spots (buttons, pads): "$1.1M", "$296.1T", "$2.85e276".
local SHORT = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
function Format.short(v: Big | number): string
	local a: Big = if type(v) == "number" then BigNum.new(v) else v
	if a.m == 0 then
		return "$0"
	end
	if a.e < 3 then
		return Format.cash(a)
	end
	local group = a.e // 3
	local lead = a.m * 10 ^ (a.e - group * 3)
	local suffix = SHORT[group]
	if not suffix then
		return "$" .. trim(string.format("%.2f", a.m)) .. "e" .. tostring(a.e)
	end
	return "$" .. trim(string.format("%.2f", lead)) .. suffix
end

-- Seconds shown on the production bar: "1s", "0.8s", "12s", "3m 20s".
function Format.timer(sec: number): string
	if sec < 0 then
		sec = 0
	end
	if sec < 10 then
		local s = string.format("%.1f", sec)
		s = trim(s)
		return s .. "s"
	end
	if sec < 60 then
		return string.format("%ds", math.floor(sec))
	end
	if sec < 3600 then
		return string.format("%dm %ds", sec // 60, math.floor(sec % 60))
	end
	return string.format("%dh %dm", sec // 3600, math.floor(sec % 3600) // 60)
end

function Format.duration(sec: number): string
	sec = math.max(0, math.floor(sec))
	if sec < 60 then
		return sec .. " seconds"
	end
	local d, h, m = sec // 86400, (sec % 86400) // 3600, (sec % 3600) // 60
	local parts = {}
	if d > 0 then
		table.insert(parts, d .. "d")
	end
	if h > 0 then
		table.insert(parts, h .. "h")
	end
	if m > 0 and d == 0 then
		table.insert(parts, m .. "m")
	end
	return table.concat(parts, " ")
end

function Format.mult(n: number): string
	return "x" .. trim(string.format("%.2f", n))
end

return Format
