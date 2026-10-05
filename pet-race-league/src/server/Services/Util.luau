-- Small server helpers: rate-limited remote handlers, part building, notifications.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)

local Util = {}

local last: { [Player]: { [string]: number } } = {}

-- Connects a RemoteEvent with a per-player cooldown and pcall so one bad call
-- can't break the server.
function Util.Connect(name: string, cooldown: number, fn: (Player, ...any) -> ())
	Net.Event(name).OnServerEvent:Connect(function(player, ...)
		local t = os.clock()
		local per = last[player]
		if not per then
			per = {}
			last[player] = per
		end
		if per[name] and t - per[name] < cooldown then
			return
		end
		per[name] = t
		local ok, err = pcall(fn, player, ...)
		if not ok then
			warn("[" .. name .. "] " .. tostring(err))
		end
	end)
end

function Util.Invoke(name: string, cooldown: number, fn: (Player, ...any) -> ...any)
	Net.Function(name).OnServerInvoke = function(player, ...)
		local t = os.clock()
		local per = last[player]
		if not per then
			per = {}
			last[player] = per
		end
		if per[name] and t - per[name] < cooldown then
			return false, "Slow down!"
		end
		per[name] = t
		local result = table.pack(pcall(fn, player, ...))
		if not result[1] then
			warn("[" .. name .. "] " .. tostring(result[2]))
			return false, "Something went wrong."
		end
		return table.unpack(result, 2, result.n)
	end
end

function Util.Init()
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		last[p] = nil
	end)
end

function Util.Notify(player: Player, text: string, kind: string?)
	Net.Event("Notify"):FireClient(player, text, kind or "Info")
end

function Util.NotifyAll(text: string, kind: string?)
	Net.Event("Notify"):FireAllClients(text, kind or "Info")
end

function Util.Rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

export type PartProps = {
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3?,
	Material: Enum.Material?,
	Transparency: number?,
	CanCollide: boolean?,
	Anchored: boolean?,
	Shape: Enum.PartType?,
	Name: string?,
}

function Util.Part(props: PartProps, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Size = props.Size
	p.CFrame = props.CFrame
	p.Color = props.Color or Color3.new(1, 1, 1)
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Transparency = props.Transparency or 0
	p.CanCollide = if props.CanCollide == nil then true else props.CanCollide
	p.Anchored = if props.Anchored == nil then true else props.Anchored
	if props.Shape then
		p.Shape = props.Shape
	end
	p.Name = props.Name or "Part"
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function Util.Label(parent: BasePart, text: string, size: number, color: Color3?): BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(size * 2, size * 0.5)
	bb.StudsOffset = Vector3.new(0, parent.Size.Y / 2 + size * 0.4, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 150
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.2
	t.Name = "Text"
	t.Parent = bb
	bb.Parent = parent
	return bb
end

function Util.Root(player: Player): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Util.Humanoid(player: Player): Humanoid?
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

return Util
