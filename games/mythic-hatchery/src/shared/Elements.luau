--!strict
-- The five elements. Beats forms a cycle (each beats exactly one other and
-- loses to exactly one other): Fire > Nature > Storm > Shadow > Ice > Fire.
-- Colours are RGB triples (no Color3, so CLI tests can load this module).

export type Element = {
	Id: string,
	Name: string,
	Beats: string,
	Color: { number },
	Glow: { number },
	Area: string, -- the island whose eggs favour this element
}

local Elements = {}

Elements.List = {
	{ Id = "Fire", Name = "Fire", Beats = "Nature", Color = { 255, 110, 50 }, Glow = { 255, 190, 60 }, Area = "Volcano" },
	{ Id = "Ice", Name = "Ice", Beats = "Fire", Color = { 120, 200, 255 }, Glow = { 210, 245, 255 }, Area = "Frost" },
	{ Id = "Storm", Name = "Storm", Beats = "Shadow", Color = { 250, 225, 70 }, Glow = { 170, 140, 255 }, Area = "Storm" },
	{ Id = "Nature", Name = "Nature", Beats = "Storm", Color = { 100, 210, 90 }, Glow = { 200, 255, 140 }, Area = "Meadow" },
	{ Id = "Shadow", Name = "Shadow", Beats = "Ice", Color = { 120, 70, 190 }, Glow = { 220, 90, 255 }, Area = "Shadow" },
} :: { Element }

Elements.ById = {} :: { [string]: Element }
for _, e in Elements.List do
	Elements.ById[e.Id] = e
end

-- True when attacker's element has the edge over defender's.
function Elements.HasEdge(attacker: string, defender: string): boolean
	local e = Elements.ById[attacker]
	return e ~= nil and e.Beats == defender
end

return Elements
