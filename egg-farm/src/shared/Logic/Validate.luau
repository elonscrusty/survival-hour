--!strict
-- Guards for anything that arrives from a client. Every remote argument passes through here
-- before it reaches game logic: wrong types, NaN, infinity, negatives and oversized strings fail.

local Validate = {}

function Validate.Finite(v: any): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

-- Whole number in [lo, hi].
function Validate.Int(v: any, lo: number, hi: number): boolean
	return Validate.Finite(v) and v == math.floor(v) and v >= lo and v <= hi
end

-- Short identifier: letters, digits, underscore, dash. Rejects anything that is not a plain string.
function Validate.Id(v: any, maxLen: number?): boolean
	if type(v) ~= "string" then
		return false
	end
	local n = #v
	return n > 0 and n <= (maxLen or 48) and string.find(v, "^[%w_%-]+$") ~= nil
end

-- Free text (codes, names): printable ASCII only, bounded length.
function Validate.Text(v: any, maxLen: number): boolean
	if type(v) ~= "string" then
		return false
	end
	return #v > 0 and #v <= maxLen and string.find(v, "^[%w _%-!%.]+$") ~= nil
end

function Validate.Bool(v: any): boolean
	return type(v) == "boolean"
end

-- Exact membership in a list of allowed string values.
function Validate.OneOf(v: any, allowed: { string }): boolean
	if type(v) ~= "string" then
		return false
	end
	return table.find(allowed, v) ~= nil
end

return Validate
