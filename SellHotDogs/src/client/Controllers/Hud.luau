--!strict
-- Always-on HUD: wallet (top), business name, toasts, right-side progression buttons,
-- contextual bottom bar, save warning and the guide beam to the next purchase.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local BigNum = require(Shared.Logic.BigNum)
local Format = require(Shared.Logic.Format)
local Kit = require(script.Parent.Parent.UI.Kit)
local Bus = require(script.Parent.Bus)
local State = require(script.Parent.State)

local C = Kit.C
local new = Kit.new

local Hud = {}

local root: Frame
local walletText: TextLabel
local rateText: TextLabel
local nameText: TextLabel
local toastHolder: Frame
local banner: TextLabel
local right: Frame
local rightButtons: { [string]: Kit.Button } = {}
local bottomButtons: { [string]: Kit.Button } = {}
local bulkButton: Kit.Button

-- wallet count-up animation (display only)
local shownCash = 0.0
local targetCash: BigNum.Big = BigNum.zero

local function toast(text: string, kind: string?)
	local color = if kind == "error" then C.red elseif kind == "good" then C.green elseif kind == "cash" then C.gold else C.blue
	local t = new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = color, Parent = toastHolder }, { Kit.corner(12), Kit.stroke(C.shadow, 3) })
	Kit.label({ Text = text, Size = UDim2.new(1, -16, 1, -6), Position = UDim2.fromOffset(8, 3), Parent = t, MaxText = 24 })
	task.delay(2.6, function()
		Kit.tween(t, 0.3, { BackgroundTransparency = 1 })
		task.wait(0.3)
		t:Destroy()
	end)
	-- keep at most four toasts
	local kids = {}
	for _, k in toastHolder:GetChildren() do
		if k:IsA("Frame") then
			table.insert(kids, k)
		end
	end
	if #kids > 4 then
		kids[1]:Destroy()
	end
end
Hud.toast = toast

local function sideButton(id: string, text: string, color: Color3, dark: Color3, order: number, onClick: () -> ())
	local b = Kit.button({ text = text, color = color, dark = dark, size = UDim2.fromOffset(150, 62), parent = right, onClick = onClick, textSize = 22 })
	b.frame.LayoutOrder = order
	b.frame.Visible = false
	rightButtons[id] = b
end

local function bottomButton(id: string, text: string, color: Color3, dark: Color3, order: number, onClick: () -> ()): Kit.Button
	local b = Kit.button({ text = text, color = color, dark = dark, size = UDim2.fromOffset(118, 68), onClick = onClick, textSize = 24 })
	b.frame.LayoutOrder = order
	bottomButtons[id] = b
	return b
end

local function build()
	local _, r = Kit.canvas("Hud", 5)
	root = r
	-- wallet
	local wallet = Kit.panel({ size = UDim2.fromOffset(340, 66), pos = UDim2.new(0.5, 0, 0, 8), anchor = Vector2.new(0.5, 0), parent = root, color = C.green })
	wallet.Name = "Wallet"
	walletText = Kit.label({ Text = "$0.00", Size = UDim2.new(1, -20, 0, 46), Position = UDim2.fromOffset(10, 2), Parent = wallet, MaxText = 42 })
	rateText = Kit.label({ Text = "", Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, 45), Parent = wallet, MaxText = 16 })
	-- business name pill (tap to rename)
	local namePill = new("TextButton", { Size = UDim2.fromOffset(300, 32), Position = UDim2.new(0.5, 0, 0, 80), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = C.mustard, AutoButtonColor = true, Text = "", Parent = root }, { Kit.corner(16), Kit.stroke(C.shadow, 3) })
	nameText = Kit.label({ Text = "", Size = UDim2.new(1, -16, 1, -4), Position = UDim2.fromOffset(8, 2), Parent = namePill, TextColor3 = C.ink, MaxText = 20 })
	namePill.Activated:Connect(function()
		Bus.open("name")
	end)
	-- toasts
	toastHolder = new("Frame", { Size = UDim2.fromOffset(420, 200), Position = UDim2.new(0.5, 0, 0, 120), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = root }, {
		new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
	-- warning banner (save problems)
	banner = Kit.label({ Text = "", Size = UDim2.fromOffset(560, 30), Position = UDim2.new(0.5, 0, 0, 116), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 0, BackgroundColor3 = C.red, Visible = false, Parent = root, MaxText = 18 })
	Kit.corner(10).Parent = banner
	-- right-side progression controls (kept above the mobile jump button area)
	right = new("Frame", { Size = UDim2.fromOffset(150, 330), Position = UDim2.new(1, -12, 0.42, 0), AnchorPoint = Vector2.new(1, 0.5), BackgroundTransparency = 1, Parent = root }, {
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }),
	})
	sideButton("investors", "👽 Investors", C.green, C.greenDark, 1, function()
		Bus.open("investors")
	end)
	sideButton("evolve", "🌀 Evolution", C.violet, Color3.fromRGB(90, 50, 160), 2, function()
		Bus.open("evolve")
	end)
	sideButton("ascend", "✨ Ascension", C.gold, C.goldDark, 3, function()
		Bus.open("ascend")
	end)
	sideButton("forever", "♾️ Forever", C.teal, Color3.fromRGB(20, 120, 140), 4, function()
		Bus.open("forever")
	end)
	sideButton("dash", "🏁 DogDash", C.ketchup, C.redDark, 5, function()
		Bus.open("dash")
	end)
	-- bottom bar
	local bar = new("Frame", { Size = UDim2.fromOffset(620, 72), Position = UDim2.new(0.5, 0, 1, -10), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Parent = root }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	bottomButton("manage", "📋 Manage", C.blue, C.blueDark, 1, function()
		Bus.open("panel", "Manage")
	end).frame.Parent = bar
	bottomButton("powers", "⚡ Powers", C.violet, Color3.fromRGB(90, 50, 160), 2, function()
		Bus.open("panel", "Powers")
	end).frame.Parent = bar
	bottomButton("shop", "🛒 Shop", C.gold, C.goldDark, 3, function()
		Bus.open("panel", "Shop")
	end).frame.Parent = bar
	bottomButton("buyNext", "📡 Buy Next", C.green, C.greenDark, 4, function()
		State.send("buyNext")
	end).frame.Parent = bar
	bulkButton = bottomButton("bulk", "x1", C.gold, C.goldDark, 5, function()
		local d = State.data
		if not d then
			return
		end
		local opts = d.bulk
		local idx = table.find(opts, Bus.bulk) or 1
		Bus.setBulk(opts[idx % #opts + 1])
	end)
	bulkButton.frame.Parent = bar
end

local function refresh(d: any)
	targetCash = Bus.big(d.cash)
	local rate = Bus.big(d.rate)
	rateText.Text = if rate.m > 0 then "+" .. Format.cash(rate) .. "/s" else "Click your stand to sell!"
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
	rightButtons.investors.frame.Visible = offered.m > 0 or investors.m > 0 or d.credits > 0
	rightButtons.evolve.frame.Visible = investors.m > 0 or d.evo.n > 0
	rightButtons.ascend.frame.Visible = d.asc.n > 0 or d.asc.owned >= d.asc.total * 0.6
	rightButtons.forever.frame.Visible = d.tokens > 0
	rightButtons.forever.setText("♾️ Forever x" .. d.tokens)
	rightButtons.dash.frame.Visible = d.dash == true
	bottomButtons.buyNext.frame.Visible = d.powers.remoteBuy.tier > 0
	bottomButtons.buyNext.setEnabled(d.nextPad ~= nil)
	local opts = d.bulk
	bulkButton.frame.Visible = #opts > 1
	if not table.find(opts, Bus.bulk) then
		Bus.setBulk(1)
	end
	bulkButton.setText(if Bus.bulk == "max" then "MAX" else "x" .. tostring(Bus.bulk))
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
