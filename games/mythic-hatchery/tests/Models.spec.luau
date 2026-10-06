-- Model data integrity: every pet, egg and breakable (kind x area) has
-- generated primitive data, part counts stay within budget and no row has
-- NaN or non-positive sizes. Data comes from models/gen_models.py.
local ModelData = require("../src/shared/Models/ModelData")
local WorldData = require("../src/shared/Models/WorldData")
local Species = require("../src/shared/Species")
local Cosmetics = require("../src/shared/Cosmetics")
local Eggs = require("../src/shared/Eggs")
local Areas = require("../src/shared/Areas")

local MAX_PET_PARTS = 100
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
		for _, p in Species.List do
			checkEntry(t, ModelData.Species[p.Id], "pet " .. p.Id, MAX_PET_PARTS)
		end
	end,
    ["creatures are ride sized and have distinct authored geometry"] = function(t)
        local signatures = {}
        for _, species in Species.List do
            local entry = ModelData.Species[species.Id]
            t.ok(entry.B[2] >= 5, species.Id .. " ride size")
            local signature = tostring(#entry.P) .. ":" .. tostring(entry.B[1]) .. ":" .. tostring(entry.B[2]) .. ":" .. tostring(entry.B[3])
            t.ok(not signatures[signature], species.Id .. " unique silhouette")
            signatures[signature] = true
        end
        for _, cosmetic in Cosmetics.List do
            checkEntry(t, ModelData.Cosmetics[cosmetic.Id], cosmetic.Id, 30)
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
			if e.Kind ~= "Fused" then t.ok(stands[e.Id], "stand for " .. e.Id) end
		end
		for _, a in Areas.List do
			if a.GateCost > 0 then
				t.ok(gates[a.Id], "gate for " .. a.Id)
			end
		end
		for _, k in { "Hatchery", "FusionAltar", "CosmeticShop", "BattleArena", "HabitatPlot", "SpawnLocation" } do
			t.ok(kinds[k], "world has " .. k)
		end
	end,
    ["regional seams leave exactly one gate passage"] = function(t)
        local gates = {}
        for _, it in WorldData.Interact do
            if it.Kind == "Gate" then
                t.eq(it.Yaw,90,"gate faces travel along X")
                gates[it.Area] = it
                local barrier
                for _, row in ModelData.Props[it.Prop].P do
                    if row[13] == "Barrier" then barrier=row end
                end
                t.ok(barrier ~= nil,"gate has barrier")
                t.eq(barrier[2],18,"rotated barrier spans passage")
                t.eq(barrier[4],1,"barrier depth")
            end
        end
        for index,area in Areas.List do
            local rows=WorldData.Parts[area.Id]
            local sides={}
            local shores=0
            local lintel=false
            for _,r in rows do
                if r[13]=="BorderRidge" then
                    shores+=1
                    t.eq(r[2],WorldData.IslandSpacing,"shore covers region width")
                    t.ok(r[3]>=80,"shore blocks region flight height")
                elseif r[13]=="RegionRidge" then
                    t.eq(r[5],gates[area.Id].P[1],"ridge aligns with gate")
                    local near=math.abs(r[7])-r[4]/2
                    local far=math.abs(r[7])+r[4]/2
                    t.eq(near,9,"ridge starts at passage edge")
                    t.eq(far,150,"ridge reaches closed shore")
                    sides[if r[7]<0 then "north" else "south"]=true
                elseif r[13]=="GateLintel" then lintel=true end
            end
            t.eq(shores,2,"both shore borders exist")
            if index>1 then
                t.ok(sides.north and sides.south,"seam closed around gate")
                t.ok(lintel,"overhead passage closed")
            end
        end
    end,
    ["all eight habitat plots are accessible in the starter meadow"] = function(t)
        local indices={}
        local count=0
        local bounds=WorldData.Bounds.Meadow
        for _,it in WorldData.Interact do
            if it.Kind=="HabitatPlot" then
                count+=1
                t.eq(it.Area,"Meadow","habitat accessible before any gate")
                local index=tonumber(it.A.PlotIndex)
                t.ok(index and index>=1 and index<=8 and not indices[index],"unique plot index")
                indices[index]=true
                t.ok(it.P[1]-21>bounds.Min[1] and it.P[1]+21<bounds.Max[1],"plot footprint inside meadow X")
                t.ok(it.P[3]-25>bounds.Min[3] and it.P[3]+25<bounds.Max[3],"plot footprint inside meadow Z")
            end
        end
        t.eq(count,8,"eight accessible plots")
        local slots=0
        for _,r in WorldData.Parts.Meadow do
            if r[13]=="HabitatSlot" then slots+=1 end
        end
        t.eq(slots,64,"eight visible slots per plot")
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
