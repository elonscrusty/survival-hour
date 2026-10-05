-- Loaded 3D models (see server AssetLoader and Models.luau). The server puts each
-- model in ReplicatedStorage.PetRaceModels as a Model whose pivot is the bottom
-- centre, so both server and client can clone them. Everything that uses a model
-- has a part-built fallback, so the game works before the models are uploaded.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = {}

local function folder(): Instance?
	return ReplicatedStorage:FindFirstChild("PetRaceModels")
end

function Assets.Has(name: string): boolean
	local f = folder()
	return f ~= nil and f:FindFirstChild(name) ~= nil
end

-- A fresh copy (pivot at the origin, unparented), or nil if it isn't loaded.
function Assets.Clone(name: string): Model?
	local f = folder()
	local src = f and f:FindFirstChild(name)
	if not src or not src:IsA("Model") then
		return nil
	end
	return src:Clone()
end

-- Clones, scales and places a model with its pivot at cf. Returns nil if not loaded.
function Assets.Place(name: string, cf: CFrame, parent: Instance, scale: number?): Model?
	local m = Assets.Clone(name)
	if not m then
		return nil
	end
	if scale and scale ~= 1 then
		m:ScaleTo(scale)
	end
	m:PivotTo(cf)
	m.Parent = parent
	return m
end

return Assets
