--!strict
-- One-line description of a reward spec/result: "🪙 500  💎 10  ⚡ 2x Luck".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local Theme = require("./Theme")
local Format = require("../Core/Format")

return function(r: { [string]: any }?): string
	if type(r) ~= "table" then
		return ""
	end
	local parts: { string } = {}
	if type(r.Coins) == "number" and r.Coins > 0 then
		table.insert(parts, Theme.Icons.Coins .. " " .. Format.num(r.Coins))
	end
	if type(r.Gems) == "number" and r.Gems > 0 then
		table.insert(parts, Theme.Icons.Gems .. " " .. Format.num(r.Gems))
	end
	if type(r.Boost) == "string" then
		local def = Config.Boosts[r.Boost]
		table.insert(parts, Theme.Icons.Boost .. " " .. (if def then def.Name else r.Boost))
	end
	if type(r.Equip) == "number" and r.Equip > 0 then
		table.insert(parts, Theme.Icons.Pets .. " +" .. r.Equip .. " equip")
	end
	if type(r.Storage) == "number" and r.Storage > 0 then
		table.insert(parts, "🎒 +" .. r.Storage .. " storage")
	end
	if type(r.Pets) == "table" and #r.Pets > 0 then
		table.insert(parts, Theme.Icons.Pets .. " " .. #r.Pets .. " pet" .. (if #r.Pets == 1 then "" else "s"))
	end
	return table.concat(parts, "   ")
end
