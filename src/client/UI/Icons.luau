--!nonstrict
-- Swaps a drawn glyph for an uploaded icon image (Shared/IconIds) when one exists.
-- Decal ids are resolved to their image by the server (ImageService -> ReplicatedStorage
-- .ImageMap); images update when that arrives. Nothing is hidden until an image has
-- actually loaded, so a missing or blocked image leaves the drawn look in place.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IconIds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("IconIds"))

local Icons = {}

local function idOf(key: string?): number?
	local id = if key then IconIds[key] else nil
	return if type(id) == "number" and id > 0 then id else nil
end

local function map(): Instance?
	return ReplicatedStorage:FindFirstChild("ImageMap")
end

-- Best image url for `key` right now, or nil when no image is listed.
function Icons.Image(key: string?): string?
	local id = idOf(key)
	if not id then
		return nil
	end
	local m = map()
	local resolved = m and m:GetAttribute(tostring(id))
	return if type(resolved) == "string" then resolved else "rbxassetid://" .. tostring(id)
end

-- Keeps `il.Image` on the best url for `key` (updates when the server resolves a Decal),
-- and calls `onLoaded` once the image has loaded.
function Icons.Bind(il: ImageLabel, key: string, onLoaded: (() -> ())?)
	il.Image = Icons.Image(key) or ""
	local id = idOf(key)
	task.spawn(function()
		local m = map() or ReplicatedStorage:WaitForChild("ImageMap", 10)
		if m and id then
			m:GetAttributeChangedSignal(tostring(id)):Connect(function()
				il.Image = Icons.Image(key) or ""
			end)
			il.Image = Icons.Image(key) or ""
		end
	end)
	if onLoaded then
		if il.IsLoaded then
			onLoaded()
		else
			local c
			c = il:GetPropertyChangedSignal("IsLoaded"):Connect(function()
				if il.IsLoaded then
					c:Disconnect()
					onLoaded()
				end
			end)
		end
	end
end

-- Puts `key`'s image over `glyph` (a symbol label, button or swatch frame); the symbol
-- is hidden only once the image loads. Returns true when an image is listed.
function Icons.Apply(glyph: GuiObject?, key: string?): boolean
	if not glyph or not idOf(key) then
		return false
	end
	local il = Instance.new("ImageLabel")
	il.Name = "IconImage"
	il.BackgroundTransparency = 1
	il.AnchorPoint = Vector2.new(0.5, 0.5)
	il.Position = UDim2.fromScale(0.5, 0.5)
	il.Size = UDim2.fromScale(1, 1)
	il.ScaleType = Enum.ScaleType.Fit
	il.ZIndex = glyph.ZIndex + 1
	il.Parent = glyph
	Icons.Bind(il, key :: string, function()
		if glyph:IsA("TextLabel") or glyph:IsA("TextButton") then
			(glyph :: any).TextTransparency = 1
		end
	end)
	return true
end

return Icons
