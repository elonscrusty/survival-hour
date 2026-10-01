--!strict
-- Rounded progress bar with an outlined track, gradient fill and centred caption.

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local ProgressBar = {}

export type Handle = {
	Instance: Frame,
	Fill: Frame,
	Label: TextLabel,
	Set: (Handle, number, string?) -> (),
	SetColor: (Handle, Color3) -> (),
}

function ProgressBar.new(o: {
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	color: Color3?,
	textSize: number?,
	order: number?,
	parent: Instance?,
}): Handle
	local track = Instance.new("Frame")
	track.Name = "ProgressBar"
	track.BackgroundColor3 = Color3.fromRGB(70, 56, 46)
	track.Size = o.size or UDim2.new(1, 0, 0, 28)
	track.Position = o.position or UDim2.new()
	track.AnchorPoint = o.anchor or Vector2.zero
	track.LayoutOrder = o.order or 0
	Util.Corner(track, nil, 0.5)
	Util.Stroke(track, 3, Theme.Color.Ink, true)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = o.color or Theme.Color.Green
	fill.Size = UDim2.fromScale(0, 1)
	Util.Corner(fill, nil, 0.5)
	Util.Gradient(fill, Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190))
	fill.Parent = track

	local label = Util.Text({
		text = "",
		size = UDim2.new(1, -12, 1, 0),
		position = UDim2.fromOffset(6, 0),
		textSize = o.textSize or Theme.Text.S,
		font = Theme.Font.Title,
		outline = true,
		z = 3,
		parent = track,
	})

	local h: any = { Instance = track, Fill = fill, Label = label }
	local last = -1
	function h.Set(self: Handle, frac: number, caption: string?)
		if frac ~= frac then
			frac = 0
		end
		frac = math.clamp(frac, 0, 1)
		if math.abs(frac - last) > 1e-4 then
			last = frac
			Util.Tween(self.Fill, Theme.Tween.Med, { Size = UDim2.fromScale(frac, 1) })
			self.Fill.Visible = frac > 0.001
		end
		if caption then
			self.Label.Text = caption
		end
	end
	function h.SetColor(self: Handle, c: Color3)
		self.Fill.BackgroundColor3 = c
	end
	track.Parent = o.parent
	return h :: Handle
end

return ProgressBar
