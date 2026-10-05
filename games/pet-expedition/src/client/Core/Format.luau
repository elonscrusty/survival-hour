--!strict
-- Number and time formatting for the UI.

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 999 -> "999", 1234 -> "1.2K", 3400000 -> "3.4M", 5.6e9 -> "5.6B", 7.8e12 -> "7.8T", 1e15 -> "1Qa".
function Format.num(n: number?): string
	local v = n or 0
	if v ~= v then
		return "0"
	end
	local neg = v < 0
	v = math.abs(v)
	if v < 1000 then
		local s = tostring(math.floor(v))
		return if neg then "-" .. s else s
	end
	local tier = math.min(math.floor(math.log10(v) / 3), #SUFFIXES - 1)
	local scaled = v / 10 ^ (tier * 3)
	local s: string
	if scaled >= 100 then
		s = tostring(math.floor(scaled))
	else
		-- one decimal, dropped when it is .0 ("1K" rather than "1.0K")
		local t = math.floor(scaled * 10) / 10
		if t == math.floor(t) then
			s = tostring(math.floor(t))
		else
			s = string.format("%.1f", t)
		end
	end
	s ..= SUFFIXES[tier + 1]
	return if neg then "-" .. s else s
end

-- Full number with thousands separators: 1234567 -> "1,234,567".
function Format.commas(n: number): string
	local s = tostring(math.floor(n))
	local formatted = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
	if string.sub(formatted, 1, 1) == "," then
		formatted = string.sub(formatted, 2)
	end
	formatted = string.gsub(formatted, "^%-,", "-")
	return formatted
end

-- Countdown: "45s", "3:07", "1:02:03", "2d 4h".
function Format.time(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	if s >= 86400 then
		return string.format("%dd %dh", s // 86400, (s % 86400) // 3600)
	elseif s >= 3600 then
		return string.format("%d:%02d:%02d", s // 3600, (s % 3600) // 60, s % 60)
	elseif s >= 60 then
		return string.format("%d:%02d", s // 60, s % 60)
	end
	return tostring(s) .. "s"
end

-- Duration words: 300 -> "5 min", 7200 -> "2 h".
function Format.duration(seconds: number): string
	if seconds >= 3600 then
		local h = seconds / 3600
		return (if h == math.floor(h) then tostring(math.floor(h)) else string.format("%.1f", h)) .. " h"
	end
	return tostring(math.floor(seconds / 60)) .. " min"
end

function Format.percent(p: number): string
	-- p is 0..100
	if p >= 10 then
		return string.format("%.1f%%", p)
	elseif p >= 0.01 then
		return string.format("%.2f%%", p)
	elseif p > 0 then
		return string.format("%.3f%%", p)
	end
	return "0%"
end

return Format
