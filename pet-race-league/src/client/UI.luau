-- Tiny UI kit: everything is built in code with big, phone-friendly buttons.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UI = {}

UI.Colors = {
	Panel = Color3.fromRGB(34, 36, 56),
	PanelLight = Color3.fromRGB(52, 55, 84),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(180, 185, 210),
	Gold = Color3.fromRGB(255, 205, 60),
	Green = Color3.fromRGB(80, 200, 110),
	Red = Color3.fromRGB(235, 80, 80),
	Blue = Color3.fromRGB(70, 150, 255),
	Pink = Color3.fromRGB(255, 90, 170),
	Purple = Color3.fromRGB(150, 90, 255),
}

UI.Font = Enum.Font.FredokaOne
UI.Body = Enum.Font.GothamBold

local screen: ScreenGui? = nil

-- Set by the Sound controller: plays a click on every button press.
UI.OnClick = nil :: (() -> ())?

function UI.Screen(): ScreenGui
	if screen then
		return screen
	end
	local g = Instance.new("ScreenGui")
	g.Name = "PetRaceUI"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = false
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screen = g
	return g
end

function UI.Corner(parent: Instance, r: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 12)
	c.Parent = parent
end

function UI.Stroke(parent: Instance, color: Color3?, thick: number?)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.new(0, 0, 0)
	s.Thickness = thick or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

function UI.Pad(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.Parent = parent
end

function UI.Frame(props: { [string]: any }, parent: Instance?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = UI.Colors.Panel
	f.BorderSizePixel = 0
	for k, v in props do
		(f :: any)[k] = v
	end
	f.Parent = parent
	return f
end

function UI.Text(props: { [string]: any }, parent: Instance?): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = UI.Font
	t.TextColor3 = UI.Colors.Text
	t.TextScaled = true
	t.BorderSizePixel = 0
	for k, v in props do
		(t :: any)[k] = v
	end
	t.Parent = parent
	return t
end

function UI.Button(props: { [string]: any }, parent: Instance?, onClick: (() -> ())?): TextButton
	local b = Instance.new("TextButton")
	b.Font = UI.Font
	b.TextColor3 = UI.Colors.Text
	b.TextScaled = true
	b.AutoButtonColor = true
	b.BackgroundColor3 = UI.Colors.Blue
	b.BorderSizePixel = 0
	for k, v in props do
		(b :: any)[k] = v
	end
	UI.Corner(b, 10)
	UI.Stroke(b, Color3.fromRGB(20, 20, 30), 2)
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = 30
	c.Parent = b
	b.Parent = parent
	if onClick then
		b.Activated:Connect(function()
			local s = b.Size
			local t = TweenService:Create(b, TweenInfo.new(0.06), { Size = UDim2.new(s.X.Scale * 0.94, s.X.Offset * 0.94, s.Y.Scale * 0.94, s.Y.Offset * 0.94) })
			t:Play()
			t.Completed:Once(function()
				TweenService:Create(b, TweenInfo.new(0.08), { Size = s }):Play()
			end)
			if UI.OnClick then
				UI.OnClick()
			end
			onClick()
		end)
	end
	return b
end

-- A centered modal panel with a title and a close button. Returns panel, body.
function UI.Modal(title: string, size: UDim2, onClose: (() -> ())?): (Frame, Frame)
	local panel = UI.Frame({
		Name = title .. "Modal",
		Size = size,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Visible = false,
		ZIndex = 10,
	}, UI.Screen())
	UI.Corner(panel, 18)
	UI.Stroke(panel, Color3.fromRGB(15, 15, 25), 3)
	local ar = Instance.new("UISizeConstraint")
	ar.MaxSize = Vector2.new(760, 560)
	ar.Parent = panel
	UI.Text({ Text = title, Size = UDim2.new(1, -80, 0, 44), Position = UDim2.fromOffset(16, 8), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11 }, panel)
	UI.Button({ Text = "X", Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, -54, 0, 8), BackgroundColor3 = UI.Colors.Red, ZIndex = 11 }, panel, function()
		panel.Visible = false
		if onClose then
			onClose()
		end
	end)
	local body = UI.Frame({ Size = UDim2.new(1, -24, 1, -68), Position = UDim2.fromOffset(12, 58), BackgroundTransparency = 1, ZIndex = 11 }, panel)
	return panel, body
end

function UI.Rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- Spinning 3D preview of a model inside a ViewportFrame.
function UI.Viewport(parent: Instance, model: Model, props: { [string]: any }?): ViewportFrame
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromScale(1, 1)
	vp.Ambient = Color3.fromRGB(200, 200, 200)
	vp.LightColor = Color3.fromRGB(255, 255, 255)
	if props then
		for k, v in props do
			(vp :: any)[k] = v
		end
	end
	local world = Instance.new("WorldModel")
	world.Parent = vp
	model.Parent = world
	local cam = Instance.new("Camera")
	local _, size = model:GetBoundingBox()
	local dist = size.Magnitude * 1.1
	local center = Vector3.new(0, size.Y / 2, 0)
	cam.CFrame = CFrame.lookAt(center + Vector3.new(-dist * 0.75, dist * 0.35, -dist * 0.75), center)
	cam.FieldOfView = 40
	cam.Parent = vp
	vp.CurrentCamera = cam
	vp.Parent = parent
	return vp
end

return UI
