--!strict
-- Business name rules checked before Roblox text filtering (the server also filters with
-- TextService and fails closed if filtering errors).
local Economy = require("./Economy")

local Names = {}
local C = Economy.Catalog.names

Names.MAX = C.maxLength.value
Names.MIN = C.minLength.value

-- Returns the cleaned name, or nil and a player-facing reason.
function Names.clean(raw: any): (string?, string?)
	if type(raw) ~= "string" then
		return nil, "Type a name"
	end
	if #raw > 200 then
		return nil, "That name is too long"
	end
	-- letters, digits, spaces and a little punctuation; collapse runs of spaces
	local s = raw:gsub("[%c]", ""):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
	if s:find("[^%w %'%&%-%.%!]") then
		return nil, "Use letters, numbers and ' & - . ! only"
	end
	if utf8.len(s) == nil then
		return nil, "That name has odd characters"
	end
	local n = #s
	if n < Names.MIN then
		return nil, "At least " .. Names.MIN .. " characters"
	end
	if n > Names.MAX then
		return nil, "At most " .. Names.MAX .. " characters"
	end
	return s, nil
end

function Names.default(displayName: string): string
	local base = displayName:sub(1, Names.MAX - 12)
	return base .. "'s Hot Dogs"
end

return Names
