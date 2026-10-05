-- Hatch reveal: the egg wobbles, cracks with a flash, and the new pet spins in.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Pets = require(Shared.Pets)
local Eggs = require(Shared.Eggs)
local Net = require(Shared.Net)
local PetModel = require(Shared.PetModel)
local UI = require(script.Parent.Parent.UI)
local Notify = require(script.Parent.Notify)

local HatchView = {}

local overlay: Frame
local busy = false

local function show(species: string, eggId: string, uid: string)
	busy = true
	overlay:ClearAllChildren()
	overlay.Visible = true
	overlay.BackgroundTransparency = 0.35
	local egg = Eggs.ById[eggId]
	local s = Pets.ById[species]
	local rar = Pets.Rarities[s.Rarity]

	local eggFrame = UI.Frame({
		Size = UDim2.fromOffset(160, 210),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		BackgroundColor3 = if egg then UI.Rgb(egg.Color) else Color3.new(1, 1, 1),
		ZIndex = 41,
	}, overlay)
	UI.Corner(eggFrame, 80)
	UI.Stroke(eggFrame, Color3.fromRGB(255, 255, 255), 4)
	for i = 1, 3 do
		local t = TweenService:Create(eggFrame, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true), { Rotation = if i % 2 == 0 then -14 - i * 4 else 14 + i * 4 })
		t:Play()
		t.Completed:Wait()
		task.wait(0.25)
	end
	local flash = UI.Frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 45 }, overlay)
	eggFrame:Destroy()
	TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()

	local holder = UI.Frame({ Size = UDim2.fromOffset(320, 320), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), BackgroundTransparency = 1, ZIndex = 41 }, overlay)
	local rays = UI.Frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = UI.Rgb(rar.Color), BackgroundTransparency = 0.6, ZIndex = 41 }, holder)
	UI.Corner(rays, 160)
	local built = PetModel.Build(species, 1)
	for _, d in built.Model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	UI.Viewport(holder, built.Model, { ZIndex = 42 })
	local spin = 0
	local conn = RunService.RenderStepped:Connect(function(dt)
		spin += dt * 1.5
		built.Model:PivotTo(CFrame.Angles(0, spin, 0))
	end)
	UI.Text({ Text = s.Name, Size = UDim2.fromOffset(400, 56), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.42, 165), ZIndex = 42, TextStrokeTransparency = 0 }, overlay)
	UI.Text({ Text = string.upper(s.Rarity), Size = UDim2.fromOffset(300, 34), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.42, 220), TextColor3 = UI.Rgb(rar.Color), ZIndex = 42, TextStrokeTransparency = 0 }, overlay)

	local function close()
		conn:Disconnect()
		overlay.Visible = false
		overlay:ClearAllChildren()
		busy = false
	end
	local bar = UI.Frame({ Size = UDim2.fromOffset(420, 56), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20), BackgroundTransparency = 1, ZIndex = 42 }, overlay)
	UI.Button({ Text = "Ride it!", Size = UDim2.new(1 / 3, -6, 1, 0), BackgroundColor3 = UI.Colors.Green, ZIndex = 43 }, bar, function()
		Net.Event("Equip"):FireServer(uid)
		close()
	end)
	UI.Button({ Text = "OK", Size = UDim2.new(1 / 3, -6, 1, 0), Position = UDim2.new(1 / 3, 3, 0, 0), ZIndex = 43 }, bar, close)
	UI.Button({ Text = "Again", Size = UDim2.new(1 / 3, -6, 1, 0), Position = UDim2.new(2 / 3, 6, 0, 0), BackgroundColor3 = UI.Colors.Gold, ZIndex = 43 }, bar, function()
		close()
		local ok, res = Net.Function("Hatch"):InvokeServer(eggId)
		if not ok then
			Notify.Show(res or "Can't hatch right now.", "Error")
		end
	end)
end

function HatchView.Start()
	overlay = UI.Frame({ Name = "Hatch", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), Visible = false, ZIndex = 40 }, UI.Screen())
	local queue = {}
	Net.Event("Hatched").OnClientEvent:Connect(function(species, eggId, uid)
		table.insert(queue, { species, eggId, uid })
		if busy then
			return
		end
		while #queue > 0 do
			local q = table.remove(queue, 1)
			show(q[1], q[2], q[3])
			while busy do
				task.wait(0.1)
			end
		end
	end)
end

return HatchView
