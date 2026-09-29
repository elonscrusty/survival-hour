--!nonstrict
-- Swaps a drawn glyph for an uploaded icon image (Shared/IconIds) when one exists.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IconIds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("IconIds"))

local Icons = {}

-- "rbxassetid://…" for `key`, or nil when no image is uploaded.
function Icons.Image(key: string?): string?
	local id = if key then IconIds[key] else nil
	return if type(id) == "number" and id > 0 then "rbxassetid://" .. tostring(id) else nil
end

-- Puts `key`'s image over `glyph` (a TextLabel/TextButton showing a symbol) and hides
-- the symbol. Returns true when an image was used.
function Icons.Apply(glyph: GuiObject?, key: string?): boolean
	local img = Icons.Image(key)
	if not img or not glyph then
		return false
	end
	if glyph:IsA("TextLabel") or glyph:IsA("TextButton") then
		(glyph :: any).TextTransparency = 1
	end
	local il = Instance.new("ImageLabel")
	il.Name = "IconImage"
	il.BackgroundTransparency = 1
	il.AnchorPoint = Vector2.new(0.5, 0.5)
	il.Position = UDim2.fromScale(0.5, 0.5)
	il.Size = UDim2.fromScale(1, 1)
	il.ScaleType = Enum.ScaleType.Fit
	il.Image = img
	il.ZIndex = glyph.ZIndex + 1
	il.Parent = glyph
	return true
end

return Icons
