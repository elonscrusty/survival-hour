--!strict
-- Builds each pet/egg model once (Models builds them from primitives, which
-- costs a little) and hands out clones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Models = require(Shared:WaitForChild("Models"))

local ModelCache = {}

local templates: { [string]: Model } = {}

local function fallback(name: string): Model
	-- used only if the model builder errors, so the UI never breaks
	local m = Instance.new("Model")
	m.Name = name
	local p = Instance.new("Part")
	p.Name = "Root"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(2.5, 2.5, 2.5)
	p.Color = Color3.fromRGB(240, 200, 120)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CFrame = CFrame.new(0, 1.25, 0)
	p.Parent = m
	p.PivotOffset = CFrame.new(0, -1.25, 0) -- pivot at the bottom centre, like Models
	m.PrimaryPart = p
	return m
end

local function prepare(m: Model)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		end
	end
end

function ModelCache.PetKey(petId: string, variant: string, shiny: boolean): string
	return petId .. "|" .. variant .. "|" .. (if shiny then "1" else "0")
end

function ModelCache.Pet(petId: string, variant: string, shiny: boolean): Model
	local key = "P:" .. ModelCache.PetKey(petId, variant, shiny)
	local t = templates[key]
	if not t then
		local ok, res = pcall(Models.Pet, petId, variant, shiny)
		local m = if ok and typeof(res) == "Instance" and res:IsA("Model") then res else fallback(petId)
		if not ok then
			warn("[ModelCache] Models.Pet failed for " .. petId .. ": " .. tostring(res))
		end
		prepare(m)
		templates[key] = m
		t = m
	end
	return (t :: Model):Clone()
end

function ModelCache.Egg(eggId: string): Model
	local key = "E:" .. eggId
	local t = templates[key]
	if not t then
		local ok, res = pcall(Models.Egg, eggId)
		local m = if ok and typeof(res) == "Instance" and res:IsA("Model") then res else fallback(eggId)
		if not ok then
			warn("[ModelCache] Models.Egg failed for " .. eggId .. ": " .. tostring(res))
		end
		prepare(m)
		templates[key] = m
		t = m
	end
	return (t :: Model):Clone()
end

return ModelCache
