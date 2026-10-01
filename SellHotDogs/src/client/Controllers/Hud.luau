--!strict
-- Always-on HUD: compact wallet + business name (top), next-unlock progress bar, toasts,
-- milestone banners, right-side progression buttons, contextual bottom bar, save warning and
-- the guide beam to the next purchase. Everything animates in; nothing here changes numbers.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local BigNum = require(Shared.Logic.BigNum)
local Economy = require(Shared.Logic.Economy)
local Format = require(Shared.Logic.Format)
local Kit = require(script.Parent.Parent.UI.Kit)
local Bus = require(script.Parent.Bus)
local State = require(script.Parent.State)

local C = Kit.C
local new = Kit.new

local Hud = {}

local root: Frame
local wallet: Frame
local walletText: TextLabel
local rateText: TextLabel
local nameText: TextLabel
local toastHolder: Frame
local banner: TextLabel
local right: Frame
local nextBar: Frame
local nextFill: Frame
local nextText: TextLabel
local nextIcon: GuiObject? = nil
local nextIconKey = ""
local bannerHolder: Frame
local rightButtons: { [string]: Kit.Button } = {}
local bottomButtons: { [string]: Kit.Button } = {}
local bulkButton: Kit.Button
local wasVisible: { [string]: boolean } = {}

-- wallet count-up animation (display only)
local shownCash = 0.0
local targetCash: BigNum.Big = BigNum.zero
local lastCash: BigNum.Big = BigNum.zero

local function toast(text: string, kind: string?)
	local color = if kind == "error" then C.red elseif kind == "good" then C.green elseif kind == "cash" then C.gold else C.blue
	local t = new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = color, Parent = toastHolder }, { Kit.corner(10), Kit.stroke(C.shadow, 2) })
	Kit.label({ Text = text, Size = UDim2.new(1, -12, 1, -4), Position = UDim2.fromOffset(6, 2), Parent = t, MaxText = 18 })
	Kit.popIn(t)
	task.delay(2.4, function()
		Kit.tween(t, 0.3, { BackgroundTransparency = 1 })
		for _, d in t:GetDescendants() do
			if d:IsA("TextLabel") then
				Kit.tween(d, 0.3, { TextTransparency = 1 })
			elseif d:IsA("UIStroke") then
				Kit.tween(d, 0.3, { Transparency = 1 })
			end
		end
		task.wait(0.3)
		t:Destroy()
	end)
	local kids = {}
	for _, k in toastHolder:GetChildren() do
		if k:IsA("Frame") then
			table.insert(kids, k)
		end
	end
	if #kids > 3 then
		kids[1]:Destroy()
	end
end
Hud.toast = toast

-- Big celebration banner across the top-middle with confetti.
local function celebrate(title: string, sub: string, color: Color3)
	local b = Kit.panel({ size = UDim2.fromOffset(420, 84), pos = UDim2.new(0.5, 0, 0, 0), anchor = Vector2.new(0.5, 0), parent = bannerHolder, color = color })
	Kit.label({ Text = title, Size = UDim2.new(1, -20, 0, 46), Position = UDim2.fromOffset(10, 6), Parent = b, MaxText = 38 })
	Kit.label({ Text = sub, Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 52), Parent = b, MaxText = 20 })
	Kit.popIn(b)
	-- confetti: little coloured squares falling from the banner
	local cols = { C.ketchup, C.mustard, C.green, C.blue, C.violet }
	for i = 1, 26 do
		local c = new("Frame", { Size = UDim2.fromOffset(8, 12), Position = UDim2.new(0.5, math.random(-200, 200), 0, 40), BackgroundColor3 = cols[i % #cols + 1], BorderSizePixel = 0, Rotation = math.random(0, 360), Parent = bannerHolder })
		Kit.tween(c, 1.4 + math.random() * 0.6, { Position = UDim2.new(0.5, math.random(-320, 320), 0, math.random(260, 420)), Rotation = math.random(-360, 360), BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
		task.delay(2.2, function()
			c:Destroy()
		end)
	end
	task.delay(2.6, function()
		Kit.tween(b, 0.35, { Position = UDim2.new(0.5, 0, 0, -120) }, Enum.EasingStyle.Back)
		task.wait(0.4)
		b:Destroy()
	end)
end
Hud.celebrate = celebrate

local function sideButton(id: string, text: string, icon: string, color: Color3, dark: Color3, order: number, onClick: () -> ())
	local b = Kit.button({ text = text, icon = icon, color = color, dark = dark, size = UDim2.fromOffset(150, 58), parent = right, onClick = onClick, textSize = 20 })
	b.frame.LayoutOrder = order
	b.frame.Visible = false
	rightButtons[id] = b
end

local function bottomButton(id: string, text: string, icon: string?, color: Color3, dark: Color3, order: number, onClick: () -> ()): Kit.Button
	local b = Kit.button({ text = text, icon = icon, color = color, dark = dark, size = UDim2.fromOffset(if icon then 128 else 84, 64), onClick = onClick, textSize = 20 })
	b.frame.LayoutOrder = order
	bottomButtons[id] = b
	return b
end

local function build()
	local _, r = Kit.canvas("Hud", 5)
	root = r
	-- compact wallet (about a third of the old area) so the world stays visible
	wallet = Kit.panel({ size = UDim2.fromOffset(200, 42), pos = UDim2.new(0.5, 0, 0, 6), anchor = Vector2.new(0.5, 0), parent = root, color = C.green })
	wallet.Name = "Wallet"
	walletText = Kit.label({ Text = "$0.00", Size = UDim2.new(1, -14, 0, 28), Position = UDim2.fromOffset(7, 1), Parent = wallet, MaxText = 26 })
	rateText = Kit.label({ Text = "", Size = UDim2.new(1, -14, 0, 12), Position = UDim2.fromOffset(7, 28), Parent = wallet, MaxText = 11 })
	-- business name pill (tap to rename)
	local namePill = new("TextButton", { Size = UDim2.fromOffset(180, 22), Position = UDim2.new(0.5, 0, 0, 52), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = C.mustard, AutoButtonColor = true, Text = "", Parent = root }, { Kit.corner(11), Kit.stroke(C.shadow, 2) })
	nameText = Kit.label({ Text = "", Size = UDim2.new(1, -12, 1, -4), Position = UDim2.fromOffset(6, 2), Parent = namePill, TextColor3 = C.ink, MaxText = 14 })
	namePill.Activated:Connect(function()
		Kit.pulse(namePill)
		Bus.open("name")
	end)
	-- next-unlock progress (top-left, under the Roblox menu buttons)
	nextBar = Kit.panel({ size = UDim2.fromOffset(230, 46), pos = UDim2.fromOffset(12, 8), parent = root, color = C.panel })
	nextBar.Name = "NextUnlock"
	local back, fill = Kit.bar(nextBar, UDim2.new(1, -56, 0, 14), UDim2.fromOffset(50, 26), C.green)
	nextFill = fill
	nextText = Kit.label({ Text = "", Size = UDim2.new(1, -56, 0, 18), Position = UDim2.fromOffset(50, 5), Parent = nextBar, TextColor3 = C.ink, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 14 })
	local _ = back
	-- toasts and banners
	toastHolder = new("Frame", { Size = UDim2.fromOffset(360, 140), Position = UDim2.new(0.5, 0, 0, 80), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = root }, {
		new("UIListLayout", { Padding = UDim.new(0, 5), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
	bannerHolder = new("Frame", { Size = UDim2.new(1, 0, 0, 100), Position = UDim2.fromOffset(0, 90), BackgroundTransparency = 1, Parent = root })
	-- warning banner (save problems)
	banner = Kit.label({ Text = "", Size = UDim2.fromOffset(520, 26), Position = UDim2.new(0.5, 0, 0, 80), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 0, BackgroundColor3 = C.red, Visible = false, Parent = root, MaxText = 16 })
	Kit.corner(10).Parent = banner
	-- right-side progression controls (kept above the mobile jump button area)
	right = new("Frame", { Size = UDim2.fromOffset(150, 330), Position = UDim2.new(1, -12, 0.42, 0), AnchorPoint = Vector2.new(1, 0.5), BackgroundTransparency = 1, Parent = root }, {
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }),
	})
	sideButton("investors", "Investors", "investors", C.green, C.greenDark, 1, function()
		Bus.open("investors")
	end)
	sideButton("evolve", "Evolution", "evolve", C.violet, Color3.fromRGB(90, 50, 160), 2, function()
		Bus.open("evolve")
	end)
	sideButton("ascend", "Ascension", "ascend", C.gold, C.goldDark, 3, function()
		Bus.open("ascend")
	end)
	sideButton("forever", "Forever", "forever", C.teal, Color3.fromRGB(20, 120, 140), 4, function()
		Bus.open("forever")
	end)
	sideButton("dash", "DogDash", "dashgame", C.ketchup, C.redDark, 5, function()
		Bus.open("dash")
	end)
	-- bottom bar
	local bar = new("Frame", { Size = UDim2.fromOffset(700, 66), Position = UDim2.new(0.5, 0, 1, -10), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Parent = root }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	bottomButton("manage", "Manage", "manage", C.blue, C.blueDark, 1, function()
		Bus.open("panel", "Manage")
	end).frame.Parent = bar
	bottomButton("powers", "Powers", "powers", C.violet, Color3.fromRGB(90, 50, 160), 2, function()
		Bus.open("panel", "Powers")
	end).frame.Parent = bar
	bottomButton("decor", "Decor", "decorShop", C.green, C.greenDark, 3, function()
		Bus.open("panel", "Decor")
	end).frame.Parent = bar
	bottomButton("shop", "Shop", "shop", C.gold, C.goldDark, 4, function()
		Bus.open("panel", "Shop")
	end).frame.Parent = bar
	bottomButton("buyNext", "Buy Next", "remoteBuy", C.green, C.greenDark, 5, function()
		State.send("buyNext")
	end).frame.Parent = bar
	bulkButton = bottomButton("bulk", "x1", nil, C.gold, C.goldDark, 6, function()
		local d = State.data
		if not d then
			return
		end
		local opts = d.bulk
		local idx = table.find(opts, Bus.bulk) or 1
		Bus.setBulk(opts[idx % #opts + 1])
		Kit.pulse(bulkButton.frame)
	end)
	bulkButton.frame.Parent = bar
	-- entrance: everything pops in, staggered
	Kit.popIn(wallet, 0.1)
	Kit.popIn(namePill, 0.2)
	Kit.popIn(nextBar, 0.25)
	for i, b in { "manage", "powers", "decor", "shop", "buyNext", "bulk" } do
		Kit.popIn(bottomButtons[b].frame, 0.3 + i * 0.06)
	end
end

local function setSide(id: string, on: boolean)
	local b = rightButtons[id]
	if on and not wasVisible[id] then
		b.frame.Visible = true
		Kit.popIn(b.frame)
		Kit.wiggle(b.frame)
	elseif not on then
		b.frame.Visible = false
	end
	wasVisible[id] = on
end

local function refresh(d: any)
	targetCash = Bus.big(d.cash)
	if BigNum.lt(lastCash, targetCash) and not BigNum.isZero(lastCash) then
		Kit.pulse(wallet, 0.06)
	end
	lastCash = targetCash
	local rate = Bus.big(d.rate)
	rateText.Text = if rate.m > 0 then "+" .. Format.short(rate) .. "/s" else "Click your stand to sell!"
	nameText.Text = d.name .. "  ✏️"
	if d.loadError then
		banner.Text = "⚠ " .. d.loadError
		banner.Visible = true
	elseif not d.canSave then
		banner.Text = "⚠ Saving is off for this visit"
		banner.Visible = true
	else
		banner.Visible = false
	end
	local offered = Bus.big(d.offered)
	local investors = Bus.big(d.investors)
	setSide("investors", offered.m > 0 or investors.m > 0 or d.credits > 0)
	setSide("evolve", investors.m > 0 or d.evo.n > 0)
	setSide("ascend", d.asc.n > 0 or d.asc.owned >= d.asc.total * 0.6)
	setSide("forever", d.tokens > 0)
	rightButtons.forever.setText("Forever x" .. d.tokens)
	setSide("dash", d.dash == true)
	bottomButtons.buyNext.frame.Visible = d.powers.remoteBuy.tier > 0
	bottomButtons.buyNext.setEnabled(d.nextPad ~= nil)
	local opts = d.bulk
	bulkButton.frame.Visible = #opts > 1
	if not table.find(opts, Bus.bulk) then
		Bus.setBulk(1)
	end
	bulkButton.setText(if Bus.bulk == "max" then "MAX" else "x" .. tostring(Bus.bulk))
	-- next unlock: name, % of its price you have, its icon
	local np = d.nextPad and Economy.padById[d.nextPad]
	if np and d.pads[np.id] and d.pads[np.id].c then
		local cost = Bus.big(d.pads[np.id].c)
		local frac = math.clamp(BigNum.toNumber(BigNum.div(targetCash, cost)), 0, 1)
		nextBar.Visible = true
		nextText.Text = string.format("Next: %s  %s", np.name, if frac >= 1 then "READY!" else Format.short(cost))
		Kit.tween(nextFill, 0.25, { Size = UDim2.fromScale(frac, 1) })
		nextFill.BackgroundColor3 = if frac >= 1 then C.gold else C.green
		local key = if np.kind == "unlock" then np.bizId else (np.model or "")
		if key ~= nextIconKey then
			nextIconKey = key
			if nextIcon then
				nextIcon:Destroy()
			end
			local icon = Kit.icon(if np.kind == "unlock" then np.bizId else (np.model or "cash"), 40, nextBar, UDim2.fromOffset(4, 3))
			nextIcon = icon
			Kit.popIn(icon)
		end
	else
		nextBar.Visible = false
	end
end

-- guide beam from the player to the next affordable purchase
local beam: Beam? = nil
local a0: Attachment? = nil
local a1: Attachment? = nil
local function guide()
	local d = State.data
	local ch = Players.LocalPlayer.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	local plotIdx = Players.LocalPlayer:GetAttribute("Plot")
	local plots = workspace:FindFirstChild("Plots")
	local plot = plots and plotIdx and plots:FindFirstChild("Plot" .. tostring(plotIdx))
	local target: BasePart? = nil
	if d and d.nextPad and plot then
		local pad = d.pads[d.nextPad]
		if pad and pad.c and BigNum.gte(Bus.big(d.cash), Bus.big(pad.c)) then
			target = plot:FindFirstChild(d.nextPad) :: BasePart?
		end
	end
	if not root or not target then
		if beam then
			beam.Enabled = false
		end
		return
	end
	if not beam then
		local b = Instance.new("Beam")
		b.Width0, b.Width1 = 0.6, 0.6
		b.FaceCamera = true
		b.Color = ColorSequence.new(C.mustard)
		b.Transparency = NumberSequence.new(0.35)
		b.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		b.TextureSpeed = 2
		b.TextureLength = 2
		b.LightEmission = 0.6
		beam = b
		a1 = Instance.new("Attachment")
	end
	local bm = beam :: Beam
	if not a0 or a0.Parent ~= root then
		a0 = Instance.new("Attachment")
		;(a0 :: Attachment).Position = Vector3.new(0, -2, 0)
		;(a0 :: Attachment).Parent = root
	end
	local att1 = a1 :: Attachment
	if att1.Parent ~= target then
		att1.Parent = target
	end
	bm.Attachment0 = a0
	bm.Attachment1 = att1
	bm.Parent = root
	bm.Enabled = (root.Position - target.Position).Magnitude > 10
end

function Hud.init()
	build()
	State.Changed:Connect(refresh)
	Bus.BulkChanged:Connect(function()
		if State.data then
			refresh(State.data)
		end
	end)
	State.Notify:Connect(function(kind, data)
		if kind == "toast" then
			toast(data.text, data.kind)
		elseif kind == "bought" then
			toast("Bought " .. data.name .. "!", "good")
		elseif kind == "cash" and data.source ~= "pickup" then
			toast("+" .. Format.cash(Bus.big(data.amount)), "cash")
		elseif kind == "purchase" then
			toast(data.msg, "good")
		elseif kind == "decor" then
			toast(data.msg, "good")
		elseif kind == "milestone" then
			if data.kind == "cash" then
				celebrate("🎉 " .. Format.cash(Bus.big(data.amount)) .. " earned!", "Your hot dog empire is growing", C.gold)
			elseif data.kind == "unlock" then
				celebrate("🏪 " .. data.name .. " is open!", "A new business joins your plot", C.green)
			elseif data.kind == "level" then
				local biz = Economy.bizById[data.bizId]
				celebrate("⭐ " .. biz.name .. " level " .. data.level .. "!", "Your plot got busier", C.blue)
			end
		end
	end)
	local acc = 0
	RunService.RenderStepped:Connect(function(dt: number)
		-- smooth count-up for small values; large values snap (no float precision there)
		local target = BigNum.toNumber(targetCash)
		if targetCash.e < 14 and target > shownCash and target - shownCash < 1e13 then
			shownCash += (target - shownCash) * math.min(1, dt * 10)
			if target - shownCash < 0.005 then
				shownCash = target
			end
			walletText.Text = Format.cash(BigNum.roundCents(BigNum.new(shownCash)))
		else
			shownCash = if target == math.huge then 0 else target
			walletText.Text = Format.cash(targetCash)
		end
		acc += dt
		if acc > 0.25 then
			acc = 0
			guide()
		end
	end)
end

return Hud
