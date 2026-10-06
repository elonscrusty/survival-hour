-- Model data integrity: every pet, egg and breakable (kind x area) has
-- generated primitive data, part counts stay within budget and no row has
-- NaN or non-positive sizes. Data comes from models/gen_models.py.
local ModelData = require("../src/shared/Models/ModelData")
local WorldData = require("../src/shared/Models/WorldData")
local Pets = require("../src/shared/Pets")
local Eggs = require("../src/shared/Eggs")
local Areas = require("../src/shared/Areas")

local MAX_PET_PARTS = 45
local MAX_EGG_PARTS = 48
local MAX_BREAKABLE_PARTS = 45
local MAX_WORLD_PARTS = 8000
local SHAPES = { B = true, S = true, C = true, W = true }
local KINDS = { "CoinPile", "Crate", "Chest", "GemRock", "BigChest" }

local function finite(x)
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

local function checkRows(t, rows, label)
	t.ok(type(rows) == "table" and #rows > 0, label .. " has parts")
	for i, r in rows do
		local where = label .. " row " .. i
		t.ok(SHAPES[r[1]], where .. " shape " .. tostring(r[1]))
		for k = 2, 10 do
			t.ok(finite(r[k]), where .. " field " .. k .. " is a finite number")
		end
		for k = 2, 4 do
			t.ok(r[k] > 0, where .. " size > 0")
		end
		t.ok(type(r[11]) == "number" and r[11] >= 0 and r[11] <= 0xFFFFFF, where .. " colour")
		t.ok(type(r[12]) == "string", where .. " material")
		if r[14] ~= nil then
			t.ok(finite(r[14]) and r[14] >= 0 and r[14] <= 1, where .. " transparency")
		end
	end
end

local function checkEntry(t, entry, label, maxParts)
	t.ok(entry ~= nil, label .. " has model data")
	if not entry then
		return
	end
	t.ok(#entry.B == 3 and finite(entry.B[1]) and finite(entry.B[2]) and finite(entry.B[3]), label .. " bounds")
	checkRows(t, entry.P, label)
	t.ok(#entry.P <= maxParts, string.format("%s has %d parts (limit %d)", label, #entry.P, maxParts))
end

return {
	["every pet has model data within the part budget"] = function(t)
		for _, p in Pets.List do
			checkEntry(t, ModelData.Pets[p.Id], "pet " .. p.Id, MAX_PET_PARTS)
		end
	end,
	["pets are 2.5 to 4.5 studs tall and grow with rarity"] = function(t)
		local order = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6 }
		for _, a in Pets.List do
			local ha = ModelData.Pets[a.Id].B[2]
			t.ok(ha >= 2.4 and ha <= 4.6, a.Id .. " height " .. ha)
			for _, b in Pets.List do
				if order[a.Rarity] < order[b.Rarity] then
					t.ok(ha < ModelData.Pets[b.Id].B[2], a.Id .. " shorter than " .. b.Id)
				end
			end
		end
	end,
	["every egg has model data about 3 studs tall"] = function(t)
		for _, e in Eggs.List do
			local entry = ModelData.Eggs[e.Id]
			checkEntry(t, entry, "egg " .. e.Id, MAX_EGG_PARTS)
			t.ok(entry and math.abs(entry.B[2] - 3) < 0.05, e.Id .. " height")
		end
	end,
	["every breakable kind exists for every area"] = function(t)
		for _, a in Areas.List do
			local byArea = ModelData.Breakables[a.Id]
			t.ok(byArea ~= nil, a.Id .. " has breakables")
			for _, kind in KINDS do
				checkEntry(t, byArea and byArea[kind], a.Id .. " " .. kind, MAX_BREAKABLE_PARTS)
			end
			for _, b in a.Breakables do
				t.ok(byArea[b.Kind] ~= nil, a.Id .. " lists unknown kind " .. b.Kind)
			end
		end
	end,
	["props referenced by the world exist and are valid"] = function(t)
		for name, entry in ModelData.Props do
			checkEntry(t, entry, "prop " .. name, 200)
			t.ok(type(entry.C) == "boolean", name .. " collide flag")
		end
		for _, pl in WorldData.Place do
			t.ok(ModelData.Props[pl[1]] ~= nil, "placed prop " .. tostring(pl[1]))
		end
		for _, it in WorldData.Interact do
			t.ok(ModelData.Props[it.Prop] ~= nil, "interactable prop " .. tostring(it.Prop))
		end
	end,
	["world covers every area with spawns, zones and bounds"] = function(t)
		for _, a in Areas.List do
			local b = WorldData.Bounds[a.Id]
			t.ok(b and WorldData.Spawns[a.Id], a.Id .. " has bounds and spawn")
			local zones = WorldData.Zones[a.Id]
			t.ok(zones and #zones > 0, a.Id .. " has zones")
			for _, z in zones do
				for k = 1, 3 do
					t.ok(z.C[k] - z.S[k] / 2 >= b.Min[k] and z.C[k] + z.S[k] / 2 <= b.Max[k], a.Id .. " zone inside bounds")
				end
				t.eq(z.C[2], 0, a.Id .. " zone sits on the ground")
			end
		end
	end,
	["every egg has a stand and every locked area a gate"] = function(t)
		local stands, gates, kinds = {}, {}, {}
		for _, it in WorldData.Interact do
			kinds[it.Kind] = true
			if it.Kind == "EggStand" then
				stands[it.A.EggId] = true
			elseif it.Kind == "Gate" then
				gates[it.A.AreaId] = true
			end
		end
		for _, e in Eggs.List do
			t.ok(stands[e.Id], "stand for " .. e.Id)
		end
		for _, a in Areas.List do
			if a.GateCost > 0 then
				t.ok(gates[a.Id], "gate for " .. a.Id)
			end
		end
		for _, k in { "ExpeditionBoard", "CraftMachine", "RebirthStatue", "IndexBook", "SpawnLocation" } do
			t.ok(kinds[k], "world has " .. k)
		end
	end,
	["world stays within the part budget"] = function(t)
		local n = 0
		for _, rows in WorldData.Parts do
			n += #rows
		end
		for _, pl in WorldData.Place do
			n += #ModelData.Props[pl[1]].P
		end
		for _, it in WorldData.Interact do
			n += #ModelData.Props[it.Prop].P
			if it.Kind == "EggStand" then
				n += #ModelData.Eggs[it.A.EggId].P
			end
		end
		t.ok(n < MAX_WORLD_PARTS, "world parts " .. n)
	end,
}
