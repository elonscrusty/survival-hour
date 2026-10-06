--!strict
-- ViewportFrame pictures of pets and eggs (clones of Models.*). Pets face -Z,
-- so the camera sits on the -Z side, slightly above and to the side.

local RunService = game:GetService("RunService")

local ModelCache = require("../Core/ModelCache")
local Kit = require("./Kit")

local Viewport = {}

export type Options = {
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Parent: any,
	ZIndex: number?,
	LayoutOrder: number?,
	Silhouette: boolean?,
	Spin: boolean?,
	Angle: number?, -- yaw in degrees (default 25: three-quarter view)
	Name: string?,
}

local spinning: { [ViewportFrame]: Model } = {}

-- Frames the camera on the model (call after the model changes size).
function Viewport.Frame(vp: ViewportFrame, model: Model, angle: number?)
	local cam = vp.CurrentCamera
	if not cam then
		local c = Instance.new("Camera")
		c.FieldOfView = 30
		c.Parent = vp
		vp.CurrentCamera = c
		cam = c
	end
	local camera = cam :: Camera
	local cf, size = model:GetBoundingBox()
	local radius = math.max(size.X, size.Y, size.Z) * 0.5
	local dist = radius / math.tan(math.rad(camera.FieldOfView / 2)) * 1.08
	local yaw = math.rad(angle or 25)
	local dir = Vector3.new(math.sin(yaw), 0.32, -math.cos(yaw)).Unit
	local target = cf.Position
	camera.CFrame = CFrame.lookAt(target + dir * (dist + radius * 0.3), target)
end

local function make(model: Model, opts: Options?): ViewportFrame
	local o: Options = opts or {}
	local vp: ViewportFrame = Kit.new("ViewportFrame", {
		Name = o.Name or "Picture",
		BackgroundTransparency = 1,
		Size = o.Size or UDim2.fromScale(1, 1),
		Position = o.Position or UDim2.new(),
		AnchorPoint = o.AnchorPoint or Vector2.zero,
		ZIndex = o.ZIndex or 1,
		LayoutOrder = o.LayoutOrder or 0,
		Ambient = Color3.fromRGB(190, 190, 200),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-0.4, -1, 0.7),
	})
	if o.Silhouette then
		vp.ImageColor3 = Color3.fromRGB(30, 34, 52)
		vp.Ambient = Color3.new(0, 0, 0)
		vp.LightColor = Color3.new(0, 0, 0)
	end
	-- particles don't render in viewports; strip them to save memory
	for _, d in model:GetDescendants() do
		if d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	model:PivotTo(CFrame.new())
	model.Parent = vp
	Viewport.Frame(vp, model, o.Angle)
	if o.Spin then
		spinning[vp] = model
		vp.Destroying:Connect(function()
			spinning[vp] = nil
		end)
	end
	if o.Parent then
		vp.Parent = o.Parent
	end
	return vp
end

function Viewport.Pet(petId: string, variant: string?, shiny: boolean?, opts: Options?): ViewportFrame
	return make(ModelCache.Pet(petId, variant or "Normal", shiny == true), opts)
end

function Viewport.Egg(eggId: string, opts: Options?): ViewportFrame
	return make(ModelCache.Egg(eggId), opts)
end

-- Gets the model inside a viewport made here.
function Viewport.ModelOf(vp: ViewportFrame): Model?
	return vp:FindFirstChildOfClass("Model")
end

RunService.RenderStepped:Connect(function(dt: number)
	for vp, model in spinning do
		if vp.Parent == nil then
			spinning[vp] = nil
		elseif vp.Visible then
			model:PivotTo(model:GetPivot() * CFrame.Angles(0, dt * 0.9, 0))
		end
	end
end)

return Viewport
