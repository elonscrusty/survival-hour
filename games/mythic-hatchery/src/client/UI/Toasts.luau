--!strict
-- Toast messages (stacked under the currency bar) and big centre banners.

local Theme = require("./Theme")
local Kit = require("./Kit")
local Windows = require("./Windows")
local Viewport = require("./Viewport")
local Sounds = require("../Core/Sounds")

local Toasts = {}

local TONES: { [string]: Color3 } = {
	good = Theme.Colors.Good,
	bad = Theme.Colors.Bad,
	info = Theme.Colors.Info,
	gold = Theme.Rarity.Legendary,
	luck = Theme.Colors.Luck,
	purple = Theme.Rarity.Epic,
}

local MAX = 4
local holder: Frame? = nil
local order = 0

local function getHolder(): Frame
	local h = holder
	if h then
		return h
	end
	local nh: Frame = Kit.box({
		Name = "Toasts",
		Size = UDim2.fromOffset(520, 400),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Parent = Windows.Gui("Toasts"),
	}, { Kit.list(Enum.FillDirection.Vertical, 8) })
	Kit.autoScale(nh, 1)
	holder = nh
	return nh
end

export type ToastOptions = {
	Icon: string?,
	PetId: string?,
	Variant: string?,
	Shiny: boolean?,
	Duration: number?,
	Silent: boolean?,
}

-- tone: good | bad | info | gold | luck | purple
function Toasts.Show(text: string, tone: string?, opts: ToastOptions?)
	local o: ToastOptions = opts or {}
	local color = TONES[tone or "info"] or Theme.Colors.Info
	local h = getHolder()
	-- drop the oldest when too many
	local items = {}
	for _, c in h:GetChildren() do
		if c:IsA("Frame") then
			table.insert(items, c)
		end
	end
	table.sort(items, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #items >= MAX do
		local first = table.remove(items, 1) :: Frame
		first:Destroy()
	end
	order += 1
	local hasPic = o.PetId ~= nil
	local f: Frame = Kit.panel({
		Name = "Toast",
		Size = UDim2.fromOffset(500, if hasPic then 70 else 54),
		BackgroundColor3 = Theme.Colors.Panel,
		StrokeColor = Theme.Darken(color, 0.25),
		Corner = 16,
		LayoutOrder = order,
		Parent = h,
	})
	Kit.new("Frame", {
		Size = UDim2.new(0, 10, 1, -12),
		Position = UDim2.fromOffset(6, 6),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = f,
	}, { Kit.corner(5) })
	local x = 24
	if hasPic then
		Viewport.Pet(o.PetId :: string, o.Variant, o.Shiny, {
			Size = UDim2.fromOffset(62, 62),
			Position = UDim2.fromOffset(20, 4),
			Parent = f,
		})
		x = 88
	elseif o.Icon then
		Kit.fitLabel(o.Icon, 30, { Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(22, 7), Parent = f })
		x = 66
	end
	Kit.fitLabel(text, 22, {
		Size = UDim2.new(1, -x - 12, 1, -8),
		Position = UDim2.fromOffset(x, 4),
		Align = "Left",
		Rich = true,
		Parent = f,
	})
	Kit.pop(f, 0.7)
	if not o.Silent then
		Sounds.Play(if tone == "bad" then "Error" else "Toast")
	end
	task.delay(o.Duration or 3.5, function()
		if f.Parent then
			local t = Kit.tween(f, 0.25, { BackgroundTransparency = 1 })
			for _, d in f:GetDescendants() do
				if d:IsA("TextLabel") then
					Kit.tween(d, 0.25, { TextTransparency = 1 })
				elseif d:IsA("UIStroke") then
					Kit.tween(d, 0.25, { Transparency = 1 })
				end
			end
			t.Completed:Wait()
			f:Destroy()
		end
	end)
end

-- Big banner across the middle-top of the screen.
function Toasts.Banner(title: string, subtitle: string?, color: Color3?, seconds: number?)
	local c = color or Theme.Colors.Header
	local gui = Windows.Gui("Toasts")
	local f: Frame = Kit.box({
		Name = "Banner",
		Size = UDim2.fromOffset(760, 120),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Parent = gui,
	})
	Kit.autoScale(f, 1)
	local t = Kit.fitLabel(title, 54, {
		Size = UDim2.new(1, 0, 0, 66),
		Outline = Theme.Darken(c, 0.5),
		Color = c,
		Parent = f,
	})
	local sub: TextLabel? = nil
	if subtitle then
		sub = Kit.fitLabel(subtitle, 26, {
			Size = UDim2.new(1, 0, 0, 36),
			Position = UDim2.fromOffset(0, 70),
			Outline = true,
			Parent = f,
		})
	end
	Kit.pop(f, 0.5)
	task.delay(seconds or 3, function()
		Kit.tween(t, 0.4, { TextTransparency = 1 })
		local ts = t:FindFirstChildOfClass("UIStroke")
		if ts then
			Kit.tween(ts, 0.4, { Transparency = 1 })
		end
		if sub then
			Kit.tween(sub, 0.4, { TextTransparency = 1 })
			local ss = sub:FindFirstChildOfClass("UIStroke")
			if ss then
				Kit.tween(ss, 0.4, { Transparency = 1 })
			end
		end
		task.wait(0.45)
		f:Destroy()
	end)
end

return Toasts
