--!strict
-- Number and time formatting shared by the HUD, menus and server messages.
-- Values up to 1e303 get a short suffix; anything larger falls back to scientific notation.

local Format = {}

local SUFFIXES = {
	"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No",
	"Dc", "UDc", "DDc", "TDc", "QaDc", "QiDc", "SxDc", "SpDc", "OcDc", "NoDc",
	"Vg", "UVg", "DVg", "TVg", "QaVg", "QiVg", "SxVg", "SpVg", "OcVg", "NoVg",
	"Tg", "UTg", "DTg", "TTg", "QaTg", "QiTg", "SxTg", "SpTg", "OcTg", "NoTg",
	"Qd", "UQd", "DQd", "TQd", "QaQd", "QiQd", "SxQd", "SpQd", "OcQd", "NoQd",
	"Qq", "UQq", "DQq", "TQq", "QaQq", "QiQq", "SxQq", "SpQq", "OcQq", "NoQq",
	"Sg", "USg", "DSg", "TSg", "QaSg", "QiSg", "SxSg", "SpSg", "OcSg", "NoSg",
	"St", "USt", "DSt", "TSt", "QaSt", "QiSt", "SxSt", "SpSt", "OcSt", "NoSt",
	"Og", "UOg", "DOg", "TOg", "QaOg", "QiOg", "SxOg", "SpOg", "OcOg", "NoOg",
	"Nn", "UNn", "DNn", "TNn", "QaNn", "QiNn", "SxNn", "SpNn", "OcNn", "NoNn",
	"Ce",
}

local function isBad(n: number): boolean
	return n ~= n or n == math.huge or n == -math.huge
end

-- Group digits: 1234567 -> "1,234,567" (integers below 1e15 only).
function Format.Commas(n: number): string
	if isBad(n) then
		return "0"
	end
	local neg = n < 0
	local s = string.format("%d", math.floor(math.abs(n)))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return (neg and "-" or "") .. out
end

-- Short form: 999 -> "999", 1234 -> "1.23K", 5.6e9 -> "5.6B". At most 3 significant digits, truncated.
function Format.Short(n: number): string
	if isBad(n) then
		return n ~= n and "0" or (n > 0 and "∞" or "-∞")
	end
	local neg = n < 0
	local a = math.abs(n)
	local sign = neg and "-" or ""
	if a < 1000 then
		if a == math.floor(a) then
			return sign .. string.format("%d", a)
		end
		return sign .. (string.format("%.2f", a):gsub("%.?0+$", ""))
	end
	local exp = math.floor(math.log10(a) / 3)
	-- digits are truncated (never rounded up), so a shown balance is never more than the real one
	local scaled = a / 10 ^ (exp * 3)
	if scaled < 1 then -- float error in log10 just below a power of 1000
		exp -= 1
		scaled = a / 10 ^ (exp * 3)
	elseif scaled >= 1000 then
		exp += 1
		scaled = a / 10 ^ (exp * 3)
	end
	local suffix = SUFFIXES[exp + 1]
	if not suffix then
		return sign .. (string.format("%.2e", a):gsub("e%+?", "e"))
	end
	local digits
	if scaled >= 100 then
		digits = string.format("%d", math.floor(scaled))
	elseif scaled >= 10 then
		digits = (string.format("%.1f", math.floor(scaled * 10) / 10):gsub("%.0$", ""))
	else
		digits = (string.format("%.2f", math.floor(scaled * 100) / 100):gsub("%.?0+$", ""))
	end
	return sign .. digits .. suffix
end

function Format.Cash(n: number): string
	return "$" .. Format.Short(n)
end

-- "1h 02m", "4m 05s", "12s"
function Format.Duration(seconds: number): string
	if isBad(seconds) or seconds < 0 then
		seconds = 0
	end
	local s = math.floor(seconds)
	local d = s // 86400
	local h = (s % 86400) // 3600
	local m = (s % 3600) // 60
	local sec = s % 60
	if d > 0 then
		return string.format("%dd %02dh", d, h)
	elseif h > 0 then
		return string.format("%dh %02dm", h, m)
	elseif m > 0 then
		return string.format("%dm %02ds", m, sec)
	end
	return string.format("%ds", sec)
end

-- Rate per second, e.g. "12.5K/s"
function Format.Rate(n: number): string
	return Format.Short(n) .. "/s"
end

-- Multiplier, e.g. "x2.5"
function Format.Mult(n: number): string
	return "x" .. Format.Short(n)
end

return Format
