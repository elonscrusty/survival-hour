--!nonstrict
-- Mesh-first forest decoration. Each layout decoration kind maps to asset-pack
-- meshes (one MeshPart each, far cheaper than a procedural model) with a
-- procedural Flora fallback when the pack isn't loaded.
--
-- Solid kinds (logs, boulders, snags) get ONE simple invisible box collider
-- (spec: visual and collision need not match; tiny roots/rocks never snag players).
-- Everything else is non-colliding, non-queryable decor.

local Skins = require("./Skins")
local Flora = require("./Flora")
local Build = require("./Build")

local Decor = {}

-- kind -> pack meshes (variant picked by position so every client agrees)
Decor.Meshes = {
	Fern = { "SM_Fern01", "SM_Fern02" },
	TallGrass = { "SM_Grass_Clump01", "SM_Grass_Clump02", "SM_Grass_Clump03" },
	Bush = { "SM_Bush01", "SM_Bush02", "SM_Bush03_Berry" },
	FallenLog = { "SM_FallenLog01", "SM_FallenLog02_Hollow" },
	Boulder = { "SM_Boulder01", "SM_Boulder02", "SM_Boulder03" },
	Stump = { "SM_Stump_Old01", "SM_Stump_Old02" },
	DeadSnag = { "SM_Tree_Dead_Large01" },
	LeafLitter = { "SM_LeafLitter01" },
	Mushrooms = { "SM_Mushrooms01", "SM_Mushrooms02_Glow" },
	MossPatch = { "SM_MossPatch01" },
	Pebbles = { "SM_Rock_Small01", "SM_Rock_Small02", "SM_Rock_Small03", "SM_Pinecones01" },
	Twigs = { "SM_Sticks_Loose01", "SM_Branch01", "SM_Branch02" },
	Roots = { "SM_Roots01", "SM_Roots02" },
	FlowerPatch = { "SM_Flowers01", "SM_Flowers02" },
	Sapling = { "SM_Sapling01" },
	Spruce = { "SM_Tree_Spruce01", "SM_Tree_Spruce02", "SM_Tree_Pine_Medium02" },
	Aspen = { "SM_Tree_Aspen01", "SM_Tree_Birch_Medium01" },
	GiantTree = { "SM_Tree_Oak_Large01" },
	Cliff = { "SM_Cliff_Face01", "SM_Cliff_Face02" },
	Riverbank = { "SM_Riverbank_Straight" },
}

-- Target size for mesh variants: kind -> approx height (studs) at scale 1.
Decor.Height = {
	Fern = 1.6, TallGrass = 1.8, Bush = 3.2, FallenLog = 2.2, Boulder = 3.6, Stump = 2.2, DeadSnag = 18,
	Sapling = 5, Spruce = 20, Aspen = 18, GiantTree = 34, FlowerPatch = 0.9, Roots = 1.2, Cliff = 26,
}

-- Kinds that block movement: collider box as a fraction of the mesh bounds.
Decor.Solid = { FallenLog = 0.8, Boulder = 0.8, DeadSnag = 0.25, Stump = 0.8, Spruce = 0.12, Aspen = 0.1, GiantTree = 0.12 }

-- Flora fallbacks: name -> { builder, takesScale }
local FALLBACK = {
	Fern = { "Fern", false }, TallGrass = { "TallGrass", false }, Bush = { "Bush", true }, FallenLog = { "FallenLog", true },
	Boulder = { "Boulder", true }, Stump = { "Stump", true }, DeadSnag = { "DeadSnag", true }, LeafLitter = { "LeafLitter", false },
	Mushrooms = { "Mushrooms", false }, MossPatch = { "MossPatch", false }, Pebbles = { "Pebbles", false }, Twigs = { "Twigs", false },
	Roots = { "Roots", false }, FlowerPatch = { "FlowerPatch", false }, Sapling = { "Sapling", true },
	Spruce = { "Spruce", true }, Aspen = { "Aspen", true }, GiantTree = { "GiantTree", true },
}

local function firstAvailable(list: { string }, cf: CFrame): string?
	local avail = {}
	for _, n in list do
		if Skins.Has(n) then
			table.insert(avail, n)
		end
	end
	if #avail == 0 then
		return nil
	end
	return Skins.Pick(avail, cf)
end

-- Places one decoration. Returns the Instance (Model) or nil.
function Decor.Place(kind: string, cf: CFrame, rng: Random, scale: number?, parent: Instance?): Instance?
	local s = scale or 1
	local list = Decor.Meshes[kind]
	local name = list and Skins.Enabled() and firstAvailable(list, cf)
	if name then
		local v = Skins.Visual(name)
		if v then
			local h = Decor.Height[kind]
			local k = s * (if h then h / math.max(0.2, Skins.Height(name)) else 1)
			if math.abs(k - 1) > 1e-3 then
				v:ScaleTo(k)
			end
			v:PivotTo(cf)
			v.Name = kind
			v:SetAttribute("Decor", kind)
			local solidFrac = Decor.Solid[kind]
			if solidFrac then
				local bcf, size = v:GetBoundingBox()
				local csize = Vector3.new(size.X * solidFrac, size.Y * math.max(0.5, solidFrac), size.Z * solidFrac)
				if kind == "Spruce" or kind == "Aspen" or kind == "GiantTree" or kind == "DeadSnag" then
					-- trunk only
					csize = Vector3.new(math.max(1, size.X * solidFrac), size.Y * 0.6, math.max(1, size.Z * solidFrac))
					bcf = cf * CFrame.new(0, csize.Y / 2, 0)
				end
				Build.Part({ Name = "Collider", Size = csize, CFrame = bcf, Transparency = 1, Parent = v, CanQuery = true })
			end
			v.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			v.Parent = parent
			return v
		end
	end
	local fb = FALLBACK[kind]
	local f = fb and (Flora :: any)[fb[1]]
	if f then
		local m = if fb[2] then f(cf, rng, s, parent) else f(cf, rng, parent)
		m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		return m
	end
	return nil
end

return Decor
