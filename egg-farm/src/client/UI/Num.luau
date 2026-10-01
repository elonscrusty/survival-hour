--!strict
-- Number display that honours the player's notation setting ("short" = 1.23M, "scientific" =
-- 1.23e6). Everything on screen formats numbers through here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Format"))

local Num = {}

local notation = "short"

function Num.SetNotation(n: string?)
	notation = if n == "scientific" then "scientific" else "short"
end

function Num.Short(n: number): string
	if notation == "scientific" and n == n and math.abs(n) >= 1000 and math.abs(n) ~= math.huge then
		-- 1.23e+06 -> 1.23e6
		return (string.format("%.2e", n):gsub("e%+?(%-?)0*(%d)", "e%1%2"))
	end
	return Format.Short(n)
end

function Num.Cash(n: number): string
	return "$" .. Num.Short(n)
end

function Num.Rate(n: number): string
	return Num.Short(n) .. "/s"
end

function Num.Duration(s: number): string
	return Format.Duration(s)
end

return Num
