--!strict
-- Index (collection book): every species grouped by island, undiscovered ones
-- as dark silhouettes with "???", and the tier rewards for discovering a
-- fraction of all species.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Pets = require(Shared:WaitForChild("Pets"))
local Areas = require(Shared:WaitForChild("Areas"))

local State = require("../Core/State")
local Remote = require("../Core/Remote")
local Sounds = require("../Core/Sounds")
local Theme = require("../UI/Theme")
local Kit = require("../UI/Kit")
local Windows = require("../UI/Windows")
local PetCard = require("../UI/PetCard")
local Toasts = require("../UI/Toasts")
local RewardText = require("../UI/RewardText")

local IndexMenu = {}

local win: Windows.Window
local content: ScrollingFrame
local renderedSig = ""

local function sections(): { { Title: string, Ids: { string } } }
	local out: { { Title: string, Ids: { string } } } = {}
	local byTitle: { [string]: { Title: string, Ids: { string } } } = {}
	local function add(title: string, id: string)
		local s = byTitle[title]
		if not s then
			s = { Title = title, Ids = {} }
			byTitle[title] = s
			table.insert(out, s :: any)
		end
		table.insert((s :: any).Ids, id)
	end
	for _, a in Areas.List do
		for _, p in Pets.List do
			if p.Area == a.Id and p.Source ~= "Gem" then
				add(a.Name, p.Id)
			end
		end
	end
	for _, p in Pets.List do
		if p.Source == "Gem" then
			add("Prism Egg", p.Id)
		end
	end
	return out
end

local function render(force: boolean?)
	if not win.IsOpen then
		return
	end
	local d = State.Data
	if not d then
		return
	end
	local found = 0
	local sig = ""
	for _, p in Pets.List do
		if d.Index[p.Id] then
			found += 1
			sig ..= p.Id
		end
	end
	for k in d.IndexClaimed do
		sig ..= "#" .. k
	end
	if sig == renderedSig and not force then
		return
	end
	renderedSig = sig
	Kit.clear(content)
	local total = #Pets.List
	local frac = if total > 0 then found / total else 0

	-- progress + tiers
	local top = Kit.panel({ Size = UDim2.new(1, -10, 0, 190), LayoutOrder = 1, BackgroundColor3 = Theme.Colors.PanelAlt, Parent = content })
	local bar, set = Kit.bar({ Size = UDim2.new(1, -30, 0, 34), Position = UDim2.fromOffset(15, 12) }, Theme.Rarity.Legendary)
	bar.Parent = top
	set(frac, Theme.Icons.Index .. " " .. found .. " / " .. total .. " discovered")
	local tiers = Kit.box({ Size = UDim2.new(1, -20, 0, 128), Position = UDim2.fromOffset(10, 54), Parent = top }, {
		Kit.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center),
	})
	for tier, r in Config.IndexRewards do
		local need = math.ceil((r.Fraction or 1) * total)
		local claimedTier = d.IndexClaimed[tostring(tier)] == true
		local reached = found >= need
		local t = Kit.panel({
			Size = UDim2.fromOffset(190, 124),
			LayoutOrder = tier,
			BackgroundColor3 = if claimedTier then Theme.Colors.PanelDark elseif reached then Theme.Lighten(Theme.Colors.Good, 0.6) else Theme.Colors.Panel,
			Parent = tiers,
		})
		Kit.fitLabel(need .. " pets", 20, { Size = UDim2.new(1, -10, 0, 26), Position = UDim2.fromOffset(5, 4), Parent = t })
		Kit.fitLabel(RewardText(r :: any), 15, { Size = UDim2.new(1, -10, 0, 34), Position = UDim2.fromOffset(5, 30), Font = Theme.FontBody, Parent = t })
		local b = Kit.button(if claimedTier then Theme.Icons.Equipped .. " Claimed" elseif reached then "Claim" else Theme.Icons.Lock .. " " .. found .. "/" .. need, if reached and not claimedTier then "Green" else "Grey", {
			Size = UDim2.new(1, -16, 0, 46),
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			TextSize = 18,
			Parent = t,
		}, function()
			local res = Remote.CallOnce("ClaimIndex", tier)
			if res then
				Sounds.Play("Reward")
				Toasts.Show(Theme.Icons.Index .. " Index reward! " .. RewardText(if type(res.reward) == "table" then res.reward else r :: any), "gold")
			end
		end)
		if claimedTier or not reached then
			Kit.setButton(b, { Enabled = false })
		end
	end

	-- species
	for i, s in sections() do
		local count = 0
		for _, id in s.Ids do
			if d.Index[id] then
				count += 1
			end
		end
		Kit.fitLabel(s.Title .. "  (" .. count .. "/" .. #s.Ids .. ")", 26, {
			Size = UDim2.new(1, -10, 0, 34),
			LayoutOrder = 10 + i * 2,
			Align = "Left",
			Parent = content,
		})
		local grid = Kit.box({
			Size = UDim2.new(1, -10, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 11 + i * 2,
			Parent = content,
		}, { Kit.grid(Vector2.new(104, 122), 8) })
		for j, id in s.Ids do
			local discovered = d.Index[id] == true
			local card = PetCard.Species(id, discovered, Vector2.new(104, 122))
			card.LayoutOrder = j
			card.Parent = grid
			local species = Pets.ById[id]
			if species and species.Source == "Expedition" then
				Kit.fitLabel(Theme.Icons.Expeditions, 20, {
					Size = UDim2.fromOffset(26, 26),
					Position = UDim2.fromOffset(4, 4),
					ZIndex = 4,
					Parent = card,
				})
			end
		end
	end
end

function IndexMenu.Init()
	win = Windows.Create("Index", { Title = "Pet Index", Icon = Theme.Icons.Index, Color = Theme.Tones.Cyan.Rim })
	content = Kit.scroll({ Size = UDim2.fromScale(1, 1), Parent = win.Body }, {
		Kit.list(Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Left),
		Kit.pad(4, 8, 8, 4),
	})
	win.Opened:Connect(function()
		render(true)
	end)
	State.Changed:Connect(function()
		render()
	end)
end

return IndexMenu
