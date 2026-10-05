--!strict
-- STUB (replaced by the model pass). Builds the whole map under workspace.World
-- and returns positions the server needs. See docs/CONTRACTS.md for tags.

local Areas = require("../Areas")

export type Zone = { Center: Vector3, Size: Vector3 }
export type WorldInfo = {
	Spawns: { [string]: CFrame },
	Zones: { [string]: { Zone } },
	Bounds: { [string]: { Min: Vector3, Max: Vector3 } },
}

local World = {}

World.IslandSpacing = 260

function World.Build(): WorldInfo
	local folder = Instance.new("Folder")
	folder.Name = "World"
	local info: WorldInfo = { Spawns = {}, Zones = {}, Bounds = {} }
	for i, a in Areas.List do
		local x = (i - 1) * World.IslandSpacing
		local ground = Instance.new("Part")
		ground.Name = a.Id .. "Ground"
		ground.Anchored = true
		ground.Size = Vector3.new(200, 4, 200)
		ground.CFrame = CFrame.new(x, -2, 0)
		ground.Parent = folder
		info.Spawns[a.Id] = CFrame.new(x, 4, 60)
		info.Zones[a.Id] = { { Center = Vector3.new(x, 0, -30), Size = Vector3.new(120, 0, 80) } }
		info.Bounds[a.Id] = { Min = Vector3.new(x - 130, -50, -130), Max = Vector3.new(x + 130, 200, 130) }
	end
	folder.Parent = workspace
	return info
end

return World
