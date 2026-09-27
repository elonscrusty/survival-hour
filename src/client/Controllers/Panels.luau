--!nonstrict
-- Modal panel manager. Only one large panel is open at a time; each has a
-- title bar with a large close button (touch friendly). Panels scale to the
-- screen and scroll when content is taller than the viewport.

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local UI = require("../UI/UI")
local Theme = require("../UI/Theme")
local State = require("../State")

local Panels = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local panels: { [string]: { Frame: Frame, Body: ScrollingFrame, OnOpen: (() -> ())?, OnClose: (() -> ())? } } = {}
Panels.Current = nil :: string?

function Panels.Start()
	gui = UI.new("ScreenGui", { Name = "Panels", ResetOnSpawn = false, DisplayOrder = 10, IgnoreGuiInset = false, Parent = player:WaitForChild("PlayerGui") })
	local scale = UI.new("UIScale", { Parent = gui })
	local function rescale()
		local vp = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.clamp(math.min(vp.X / 900, vp.Y / 560), 0.6, 1.15)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()
	UserInputService.InputBegan:Connect(function(io, processed)
		if io.KeyCode == Enum.KeyCode.Backspace and not processed and Panels.Current then
			Panels.Close()
		end
	end)
	State.On("OpenPanel", function(name)
		Panels.Open(name)
	end)
	player:GetAttributeChangedSignal("InMatch"):Connect(function()
		Panels.Close()
	end)
end

-- Creates (once) and returns the scrolling body of a panel.
function Panels.Create(name: string, title: string, size: Vector2, onOpen: (() -> ())?, onClose: (() -> ())?): ScrollingFrame
	while not gui do
		task.wait()
	end
	local frame = UI.panel({ Name = name, Size = UDim2.fromOffset(size.X, size.Y), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Visible = false, Parent = gui })
	UI.new("UISizeConstraint", { MaxSize = Vector2.new(size.X, size.Y), Parent = frame })
	local header = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = Theme.Colors.PanelLight, BorderSizePixel = 0, Parent = frame }, { UI.corner() })
	UI.text(title, { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -80, 1, 0), TextSize = 22, Font = Theme.FontBlack, TextColor3 = Theme.Colors.Accent, Parent = header })
	UI.button("✖", { Size = UDim2.fromOffset(44, 40), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), TextSize = 22, BackgroundColor3 = Color3.fromRGB(90, 40, 36), Parent = header }, function()
		Panels.Close()
	end)
	local body = UI.new("ScrollingFrame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 1, -56),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = frame,
	}, { UI.padding(10) })
	panels[name] = { Frame = frame, Body = body, OnOpen = onOpen, OnClose = onClose }
	return body
end

function Panels.Open(name: string)
	local p = panels[name]
	if not p then
		return
	end
	if Panels.Current and Panels.Current ~= name then
		Panels.Close()
	end
	Panels.Current = name
	p.Frame.Visible = true
	if p.OnOpen then
		p.OnOpen()
	end
	GuiService.SelectedObject = nil
end

function Panels.Close()
	local name = Panels.Current
	if not name then
		return
	end
	local p = panels[name]
	Panels.Current = nil
	if p then
		p.Frame.Visible = false
		if p.OnClose then
			p.OnClose()
		end
	end
end

function Panels.Toggle(name: string)
	if Panels.Current == name then
		Panels.Close()
	else
		Panels.Open(name)
	end
end

function Panels.IsOpen(name: string): boolean
	return Panels.Current == name
end

return Panels
