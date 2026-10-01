--!strict
-- Modal dialogs: Alien Investors / Rebirth, Void Evolution, Ascension, Forever Purchase
-- target selection, welcome-back offline income, business name editing, and confirmations.
-- Every confirm only sends a request; results come back from the server.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local BigNum = require(Shared.Logic.BigNum)
local Economy = require(Shared.Logic.Economy)
local Format = require(Shared.Logic.Format)
local Names = require(Shared.Logic.Names)
local Kit = require(script.Parent.Parent.UI.Kit)
local Bus = require(script.Parent.Bus)
local State = require(script.Parent.State)

local C = Kit.C
local new = Kit.new

local Dialogs = {}

local gui: ScreenGui
local root: Frame
local box: Frame
local body: Frame
local titleLabel: TextLabel
local openKind: string? = nil
local selecting = false
local selectBanner: Frame

local function close()
	gui.Enabled = false
	openKind = nil
end
Dialogs.close = close

local function clearBody()
	for _, c in body:GetChildren() do
		c:Destroy()
	end
end

local function show(kind: string, title: string, height: number)
	openKind = kind
	gui.Enabled = true
	titleLabel.Text = title
	box.Size = UDim2.fromOffset(520, height)
	clearBody()
end

local function text(s: string, y: number, h: number, color: Color3?, font: Enum.Font?, maxText: number?): TextLabel
	return Kit.label({ Text = s, Size = UDim2.new(1, 0, 0, h), Position = UDim2.fromOffset(0, y), Parent = body, TextColor3 = color or C.ink, Font = font or Kit.FONT, TextWrapped = true, MaxText = maxText or 24 })
end

local function buttons(specs: { { text: string, color: Color3, dark: Color3, enabled: boolean?, onClick: () -> () } })
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 58), Position = UDim2.new(0, 0, 1, -58), BackgroundTransparency = 1, Parent = body }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
	for i, s in specs do
		local b = Kit.button({ text = s.text, color = s.color, dark = s.dark, size = UDim2.fromOffset(150, 56), parent = row, textSize = 22, onClick = s.onClick })
		b.frame.LayoutOrder = i
		if s.enabled == false then
			b.setEnabled(false)
		end
	end
end

local function progressBar(y: number, p: number, color: Color3, label: string)
	local back, fill = Kit.bar(body, UDim2.new(1, -20, 0, 30), UDim2.fromOffset(10, y), color)
	fill.Size = UDim2.fromScale(math.clamp(p, 0, 1), 1)
	Kit.label({ Text = label, Size = UDim2.new(1, -10, 1, -4), Position = UDim2.fromOffset(5, 2), Parent = back, ZIndex = 2, MaxText = 20 })
end

-- second step for every reset: what goes, what stays
local function confirm(title: string, lines: string, yes: string, action: string)
	show("confirm", title, 340)
	text(lines, 0, 200, C.ink, Kit.FONT_BODY, 18)
	buttons({
		{ text = yes, color = C.red, dark = C.redDark, onClick = function()
			State.send(action)
			close()
		end },
		{ text = "Cancel", color = C.grey, dark = Color3.fromRGB(120, 115, 110), onClick = close },
	})
end

---------------------------------------------------------------- Investors / Rebirth
local function investors()
	local d = State.data
	if not d then
		return
	end
	local held = Bus.big(d.investors)
	local offered = Bus.big(d.offered)
	show("investors", "👽 Alien Hot Dog Investors", 430)
	text(string.format("You have %s investors", Format.amount(held, 0)), 0, 34)
	text(string.format("Each investor gives +%s%% cash  (now x%s)", tostring(d.bonusPer * 100), Format.amount(BigNum.add(BigNum.new(1), BigNum.mulN(held, d.bonusPer)))), 36, 26, C.greenDark, Kit.FONT_BODY, 18)
	text(if offered.m > 0 then string.format("Rebirth now to gain %s investors%s", Format.amount(offered, 0), if d.x2 then "  (x2!)" else "") else "Earn more cash this run to attract investors.", 72, 52, C.violet, nil, 24)
	if not d.x2 then
		Kit.button({ text = "x2 Investors", color = C.gold, dark = C.goldDark, size = UDim2.fromOffset(200, 44), pos = UDim2.new(0.5, 0, 0, 132), anchor = Vector2.new(0.5, 0), parent = body, textSize = 20, onClick = function()
			Bus.open("panel", "Shop")
		end })
	end
	if d.credits > 0 then
		Kit.button({ text = string.format("Collect without reset (%d)", d.credits), color = C.teal, dark = Color3.fromRGB(20, 120, 140), size = UDim2.fromOffset(300, 44), pos = UDim2.new(0.5, 0, 0, 184), anchor = Vector2.new(0.5, 0), parent = body, textSize = 20, onClick = function()
			State.send("rebirthNoReset")
			close()
		end }).setEnabled(offered.m > 0)
	end
	buttons({
		{ text = "Rebirth", color = C.green, dark = C.greenDark, enabled = offered.m > 0, onClick = function()
			confirm("Rebirth?", string.format("You'll gain %s investors.\n\nResets: cash, businesses and upgrades.\nKeeps: investors, powers, evolutions, Robux purchases, Forever Purchases and your business name.", Format.amount(offered, 0)), "Rebirth", "rebirth")
		end },
		{ text = "Close", color = C.grey, dark = Color3.fromRGB(120, 115, 110), onClick = close },
	})
end

---------------------------------------------------------------- Evolution
local function evolve()
	local d = State.data
	if not d then
		return
	end
	show("evolve", "🌀 Void Evolution", 400)
	text(string.format("Each evolution gives x%d income speed", d.evo.mult), 0, 30)
	text(string.format("%s Dogs  →  %s Dogs", d.evo.recipe, d.evo.nextRecipe), 36, 34, C.violet)
	progressBar(84, d.evo.progress, C.violet, string.format("%d%%", math.floor(d.evo.progress * 100)))
	text(string.format("Needs %s investors (you have %s)", Format.amount(Bus.big(d.evo.need), 0), Format.amount(Bus.big(d.investors), 0)), 122, 40, C.inkSoft, Kit.FONT_BODY, 17)
	buttons({
		{ text = "Evolve", color = C.violet, dark = Color3.fromRGB(90, 50, 160), enabled = d.evo.can, onClick = function()
			confirm("Evolve?", "Most progress resets, including investors and investor powers.\n\nKeeps: evolutions, ascensions, Robux purchases, Forever Purchases and your business name.", "Evolve", "evolve")
		end },
		{ text = "Close", color = C.grey, dark = Color3.fromRGB(120, 115, 110), onClick = close },
	})
end

---------------------------------------------------------------- Ascension
local function ascend()
	local d = State.data
	if not d then
		return
	end
	show("ascend", "✨ Ascension", 410)
	text(string.format("Climb the staircase: x%s cash, but prices x%s", tostring(d.asc.cash), tostring(d.asc.price)), 0, 50, C.ink, nil, 22)
	text("+1 Forever Purchase", 52, 28, C.teal)
	progressBar(90, d.asc.owned / math.max(1, d.asc.total), C.gold, string.format("%d / %d upgrades owned", d.asc.owned, d.asc.total))
	text(if d.asc.can then "Everything is built. You can ascend!" else "Buy every upgrade on your plot to ascend.", 128, 40, C.inkSoft, Kit.FONT_BODY, 17)
	buttons({
		{ text = "Ascend", color = C.gold, dark = C.goldDark, enabled = d.asc.can, onClick = function()
			confirm("Ascend?", "EVERYTHING resets: cash, businesses, investors, powers and evolutions.\n\nKeeps: ascensions, Robux purchases, Forever Purchases and your business name.", "Ascend", "ascend")
		end },
		{ text = "Close", color = C.grey, dark = Color3.fromRGB(120, 115, 110), onClick = close },
	})
end

---------------------------------------------------------------- Forever Purchase
local function foreverConfirm(padId: string)
	local pad = Economy.padById[padId]
	show("foreverConfirm", "♾️ Forever Purchase", 300)
	text(string.format("Keep %s forever?", pad.name), 0, 60)
	text("It stays owned through every rebirth, evolution and ascension. Uses 1 Forever Purchase.", 64, 60, C.inkSoft, Kit.FONT_BODY, 17)
	buttons({
		{ text = "Yes", color = C.green, dark = C.greenDark, onClick = function()
			State.send("forever", padId)
			selecting = false
			selectBanner.Visible = false
			close()
		end },
		{ text = "nvm", color = C.grey, dark = Color3.fromRGB(120, 115, 110), onClick = function()
			Dialogs.forever()
		end },
	})
end

function Dialogs.forever()
	local d = State.data
	if not d or d.tokens < 1 then
		return
	end
	selecting = true
	selectBanner.Visible = true
	show("forever", "♾️ Pick an upgrade to keep", 520)
	local list = new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -66), BackgroundTransparency = 1, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollBarThickness = 8, Parent = body }, {
		new("UIGridLayout", { CellSize = UDim2.fromOffset(150, 64), CellPadding = UDim2.fromOffset(8, 8) }),
	})
	for _, pad in Economy.pads do
		local ps = d.pads[pad.id]
		if pad.kind ~= "unlock" and ps and ps.s ~= 3 then
			Kit.button({ text = pad.name, color = if ps.s == 2 then C.blue else C.teal, dark = C.blueDark, size = UDim2.fromOffset(150, 64), parent = list, textSize = 16, onClick = function()
				foreverConfirm(pad.id)
			end })
		end
	end
	buttons({
		{ text = "Cancel", color = C.red, dark = C.redDark, onClick = function()
			selecting = false
			selectBanner.Visible = false
			close()
		end },
	})
end

---------------------------------------------------------------- Offline / name / errors
local function offline(amount: any)
	show("offline", "👋 Welcome back!", 300)
	text("While you were away your businesses earned", 0, 50, C.ink, Kit.FONT_BODY, 20)
	text(Format.cash(Bus.big(amount)), 54, 56, C.greenDark, nil, 44)
	buttons({
		{ text = "Collect", color = C.green, dark = C.greenDark, onClick = function()
			State.send("claimOffline")
			close()
		end },
	})
end

local nameStatus: TextLabel? = nil
local function nameEditor()
	local d = State.data
	show("name", "✏️ Name your business", 330)
	local tb = new("TextBox", {
		Size = UDim2.new(1, -20, 0, 56),
		Position = UDim2.fromOffset(10, 0),
		BackgroundColor3 = C.white,
		Font = Kit.FONT,
		TextScaled = true,
		TextColor3 = C.ink,
		PlaceholderText = "Carter's Hot Dogs",
		Text = if d then d.name else "",
		ClearTextOnFocus = false,
		Parent = body,
	}, { Kit.corner(10), Kit.stroke(C.inkSoft, 2), new("UITextSizeConstraint", { MaxTextSize = 30 }) })
	local count = text("", 62, 22, C.inkSoft, Kit.FONT_BODY, 16)
	nameStatus = text("", 90, 50, C.redDark, Kit.FONT_BODY, 17)
	local function upd()
		count.Text = string.format("%d / %d", #tb.Text, Names.MAX)
		count.TextColor3 = if #tb.Text > Names.MAX then C.red else C.inkSoft
	end
	tb:GetPropertyChangedSignal("Text"):Connect(upd)
	upd()
	buttons({
		{ text = "Save", color = C.green, dark = C.greenDark, onClick = function()
			local clean, why = Names.clean(tb.Text)
			if not clean then
				(nameStatus :: TextLabel).Text = why or ""
				return
			end
			(nameStatus :: TextLabel).TextColor3 = C.inkSoft;
			(nameStatus :: TextLabel).Text = "Checking…"
			State.send("setName", clean)
		end },
		{ text = "Cancel", color = C.grey, dark = Color3.fromRGB(120, 115, 110), onClick = close },
	})
end

function Dialogs.init()
	local g, r = Kit.canvas("Dialogs", 30)
	gui, root = g, r
	gui.Enabled = false
	new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, Text = "", AutoButtonColor = false, Parent = root })
	box = Kit.panel({ size = UDim2.fromOffset(520, 400), pos = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), parent = root })
	new("UISizeConstraint", { MaxSize = Vector2.new(560, 580), Parent = box })
	titleLabel = Kit.label({ Text = "", Size = UDim2.new(1, -90, 0, 44), Position = UDim2.fromOffset(16, 12), Parent = box, TextColor3 = C.ink, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 30 })
	Kit.button({ text = "✕", color = C.red, dark = C.redDark, size = UDim2.fromOffset(48, 48), pos = UDim2.new(1, -12, 0, 10), anchor = Vector2.new(1, 0), parent = box, textSize = 26, onClick = function()
		if selecting then
			selecting = false
			selectBanner.Visible = false
		end
		close()
	end })
	body = new("Frame", { Size = UDim2.new(1, -32, 1, -84), Position = UDim2.fromOffset(16, 68), BackgroundTransparency = 1, Parent = box })
	-- selection-mode banner (top of the screen, above the HUD) with its own Cancel
	local _, hudRoot = Kit.canvas("ForeverBanner", 31)
	selectBanner = Kit.panel({ size = UDim2.fromOffset(460, 54), pos = UDim2.new(0.5, 0, 0, 120), anchor = Vector2.new(0.5, 0), parent = hudRoot, color = C.teal })
	selectBanner.Visible = false
	Kit.label({ Text = "Choose an upgrade to keep forever", Size = UDim2.new(1, -130, 1, -10), Position = UDim2.fromOffset(10, 5), Parent = selectBanner, MaxText = 20 })
	Kit.button({ text = "Cancel", color = C.red, dark = C.redDark, size = UDim2.fromOffset(100, 42), pos = UDim2.new(1, -8, 0.5, 0), anchor = Vector2.new(1, 0.5), parent = selectBanner, textSize = 18, onClick = function()
		selecting = false
		selectBanner.Visible = false
		close()
	end })

	Bus.Opened:Connect(function(what, arg)
		if what == "investors" then
			investors()
		elseif what == "evolve" then
			evolve()
		elseif what == "ascend" then
			ascend()
		elseif what == "forever" then
			Dialogs.forever()
		elseif what == "name" then
			nameEditor()
		elseif what == "panel" and gui.Enabled and not selecting then
			close()
		end
	end)
	State.Notify:Connect(function(kind, data)
		if kind == "open" then
			Bus.open(data)
		elseif kind == "offline" then
			offline(data.amount)
		elseif kind == "nameResult" then
			if openKind == "name" and nameStatus then
				nameStatus.TextColor3 = if data.ok then C.greenDark else C.redDark
				nameStatus.Text = data.msg
				if data.ok then
					task.delay(0.8, function()
						if openKind == "name" then
							close()
						end
					end)
				end
			end
		elseif kind == "prestige" then
			local msg = if data.kind == "rebirth" or data.kind == "rebirthNoReset" then "👽 " .. Format.amount(Bus.big(data.amount), 0) .. " investors joined!" elseif data.kind == "evolve" then "🌀 Evolved: " .. data.recipe .. " Dogs!" else "✨ Ascended!"
			show("done", msg, 220)
			buttons({ { text = "Awesome!", color = C.green, dark = C.greenDark, onClick = close } })
		end
	end)
	-- keep an open info dialog fresh (not confirmations or the name editor)
	local lastRefresh = 0
	State.Changed:Connect(function()
		if os.clock() - lastRefresh < 1 then
			return
		end
		lastRefresh = os.clock()
		if openKind == "investors" then
			investors()
		elseif openKind == "evolve" then
			evolve()
		elseif openKind == "ascend" then
			ascend()
		end
	end)
end

return Dialogs
