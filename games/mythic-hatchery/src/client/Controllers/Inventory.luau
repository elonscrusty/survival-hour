--!strict
-- Pets inventory: grid sorted by power (equipped first) with filters, a
-- details panel (power, level/xp, variant, shiny) with Equip, Lock, Delete
-- and Craft, plus Equip Best, Unequip All and a multi-delete mode.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))

local State = require("../Core/State")
local Remote = require("../Core/Remote")
local PetInfo = require("../Core/PetInfo")
local Format = require("../Core/Format")
local Sounds = require("../Core/Sounds")
local Theme = require("../UI/Theme")
local Kit = require("../UI/Kit")
local Windows = require("../UI/Windows")
local Viewport = require("../UI/Viewport")
local PetCard = require("../UI/PetCard")
local Toasts = require("../UI/Toasts")

type PetInstance = Types.PetInstance

local Inventory = {}

local FILTERS = { "All", "Equipped", "Golden", "Rainbow", "Shiny", "Locked" }

local win: Windows.Window
local grid: ScrollingFrame
local countLabel: TextLabel
local equipLabel: TextLabel
local filterBtn: TextButton
local deleteModeBtn: TextButton
local deleteBtn: TextButton
local details: Frame
local detailPic: Frame
local detailName: TextLabel
local detailInfo: TextLabel
local setXp: (number, string?) -> ()
local btnEquip: TextButton
local btnLock: TextButton
local btnDelete: TextButton
local btnCraft: TextButton
local emptyNote: TextLabel

local filter = "All"
local selected: string? = nil
local deleteMode = false
local marked: { [string]: boolean } = {}
type CardEntry = { Card: TextButton, Sig: string }
local cards: { [string]: CardEntry } = {}

local function sigOf(p: PetInstance): string
	-- the power on a gem pet's card depends on the player's highest island
	local species = PetInfo.Species(p.Id)
	local scale = if species and species.Source == "Gem" then tostring(PetInfo.ScaleArea()) else ""
	return p.Id .. p.Variant .. tostring(p.Shiny) .. tostring(p.Level) .. scale
end

local function passes(p: PetInstance, equipped: boolean): boolean
	if filter == "Equipped" then
		return equipped
	elseif filter == "Golden" then
		return p.Variant == "Golden"
	elseif filter == "Rainbow" then
		return p.Variant == "Rainbow"
	elseif filter == "Shiny" then
		return p.Shiny
	elseif filter == "Locked" then
		return p.Locked
	end
	return true
end

-- Pets that could be crafted together with `p` (same species, variant and
-- shininess, not locked and not away on an expedition).
function Inventory.CraftGroup(p: PetInstance): { PetInstance }
	local d = State.Data
	local out: { PetInstance } = {}
	if not d then
		return out
	end
	local busy = State.BusyUids()
	local trading = State.TradeUids()
	local key = PetInfo.CraftKey(p)
	for _, q in d.Pets do
		if PetInfo.CraftKey(q) == key and not q.Locked and not busy[q.Uid] and not trading[q.Uid] then
			table.insert(out, q)
		end
	end
	return out
end

function Inventory.Craft(p: PetInstance)
	local nextVariant = PetInfo.NextVariant(p.Variant)
	if not nextVariant then
		Toasts.Show("Rainbow is the best variant already!", "info")
		return
	end
	local group = Inventory.CraftGroup(p)
	if #group < Config.CraftCost then
		Toasts.Show("Need " .. Config.CraftCost .. " matching unlocked pets (you have " .. #group .. ").", "bad")
		return
	end
	Windows.Confirm(
		"Craft " .. nextVariant .. " " .. PetInfo.Name(p.Id) .. "?",
		"Uses " .. Config.CraftCost .. " " .. PetInfo.FullName(p) .. " to make 1 " .. nextVariant .. " pet ("
			.. string.format("%gx", (Config.VariantPower[nextVariant] or 1) / (Config.VariantPower[p.Variant] or 1)) .. " power).",
		Theme.Icons.Craft .. " Craft",
		"Purple",
		function()
			local res = Remote.CallOnce("CraftPet", p.Uid)
			if res then
				Sounds.Play("Reward")
				local made = res.pet
				if type(made) == "table" and type(made.Id) == "string" then
					Toasts.Show("Crafted <b>" .. PetInfo.FullName(made :: PetInstance) .. "</b>!", "gold", {
						PetId = made.Id,
						Variant = made.Variant,
						Shiny = made.Shiny,
					})
					selected = made.Uid
				else
					Toasts.Show("Crafted a " .. nextVariant .. " pet!", "gold")
				end
			end
		end
	)
end

local function deletePets(uids: { string })
	if #uids == 0 then
		return
	end
	Windows.Confirm(
		"Delete " .. #uids .. " pet" .. (if #uids == 1 then "" else "s") .. "?",
		"Deleted pets are gone forever. You get a few coins back.",
		"Delete",
		"Red",
		function()
			local res = Remote.CallOnce("DeletePets", uids)
			if res then
				Toasts.Show("Deleted " .. #uids .. " pet" .. (if #uids == 1 then "" else "s") .. (if type(res.coins) == "number" and res.coins > 0 then "  +" .. Theme.Icons.Coins .. Format.num(res.coins) else ""), "good")
				for _, uid in uids do
					marked[uid] = nil
					if selected == uid then
						selected = nil
					end
				end
			end
		end
	)
end

local function renderDetails()
	local d = State.Data
	local p = if selected then State.PetByUid(selected) else nil
	if not d or not p then
		details.Visible = false
		return
	end
	local pet = p :: PetInstance
	details.Visible = true
	local key = sigOf(pet)
	if detailPic:GetAttribute("Sig") ~= key then
		detailPic:SetAttribute("Sig", key)
		Kit.clear(detailPic)
		Viewport.Pet(pet.Id, pet.Variant, pet.Shiny, { Size = UDim2.fromScale(1, 1), Spin = true, Parent = detailPic })
	end
	local rarity = PetInfo.Rarity(pet.Id)
	local rc = Theme.RarityColor(rarity)
	detailName.Text = PetInfo.FullName(pet)
	local stroke = detailName:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Theme.Darken(rc, 0.45)
	end
	local busy = State.BusyUids()[pet.Uid] == true
	local inTrade = State.TradeUids()[pet.Uid] == true
	local equipped = State.IsEquipped(pet.Uid)
	detailInfo.Text = string.format(
		"<font color=\"#%s\"><b>%s</b></font>   %s %s\n%s Power <b>%s</b>%s",
		rc:ToHex(),
		rarity,
		pet.Variant,
		if pet.Shiny then Theme.Icons.Shiny .. "Shiny" else "",
		Theme.Icons.Boost,
		Format.num(PetInfo.Power(pet)),
		if busy then "\n" .. Theme.Icons.Expeditions .. " On an expedition" elseif inTrade then "\n" .. Theme.Icons.Trade .. " In a trade" else ""
	)
	local level = pet.Level or 1
	if level >= Config.PetMaxLevel then
		setXp(1, "Lv " .. level .. "  MAX")
	else
		local need = Config.PetXpForLevel(level)
		setXp((pet.Xp or 0) / math.max(1, need), "Lv " .. level .. "   " .. Format.num(pet.Xp or 0) .. "/" .. Format.num(need) .. " XP")
	end
	Kit.setButton(btnEquip, {
		Text = if equipped then "Unequip" else "Equip",
		Tone = if equipped then "Yellow" else "Green",
		Enabled = not busy,
	})
	Kit.setButton(btnLock, { Text = if pet.Locked then Theme.Icons.Lock .. " Unlock" else Theme.Icons.Lock .. " Lock", Tone = "Blue" })
	Kit.setButton(btnDelete, { Enabled = not pet.Locked and not busy and not equipped and not inTrade })
	local nextVariant = PetInfo.NextVariant(pet.Variant)
	local group = #Inventory.CraftGroup(pet)
	if nextVariant then
		Kit.setButton(btnCraft, {
			Text = Theme.Icons.Craft .. " " .. math.min(group, Config.CraftCost) .. "/" .. Config.CraftCost,
			Enabled = group >= Config.CraftCost and not pet.Locked and not inTrade,
		})
	else
		Kit.setButton(btnCraft, { Text = "Max", Enabled = false })
	end
end

local function onCard(uid: string)
	local d = State.Data
	if not d then
		return
	end
	if deleteMode then
		local p = State.PetByUid(uid)
		if not p then
			return
		end
		if p.Locked then
			Toasts.Show("That pet is locked.", "info")
			return
		end
		if State.IsEquipped(uid) or State.BusyUids()[uid] or State.TradeUids()[uid] then
			Toasts.Show("Unequip it first (or wait for its expedition or trade).", "info")
			return
		end
		if marked[uid] then
			marked[uid] = nil
		else
			marked[uid] = true
		end
		Inventory.Render()
		return
	end
	selected = uid
	Inventory.Render()
end

function Inventory.Render()
	if not win or not win.IsOpen then
		return
	end
	local d = State.Data
	if not d then
		return
	end
	local list = table.clone(d.Pets)
	PetInfo.Sort(list, d.Equipped)
	local busy = State.BusyUids()
	local eqSet: { [string]: boolean } = {}
	for _, uid in d.Equipped do
		eqSet[uid] = true
	end
	local alive: { [string]: boolean } = {}
	local shownCount = 0
	for i, p in list do
		local equipped = eqSet[p.Uid] == true
		local show = passes(p, equipped)
		local entry: CardEntry? = cards[p.Uid]
		local sig = sigOf(p)
		if entry and entry.Sig ~= sig then
			entry.Card:Destroy()
			entry = nil
		end
		if not entry then
			local uid = p.Uid
			local card = PetCard.new(p, Vector2.new(96, 112), function()
				onCard(uid)
			end)
			card.Parent = grid
			entry = { Card = card, Sig = sig }
			cards[p.Uid] = entry
		end
		local e = entry :: CardEntry
		alive[p.Uid] = true
		e.Card.LayoutOrder = i
		e.Card.Visible = show
		if show then
			shownCount += 1
		end
		PetCard.SetFlags(e.Card, {
			Equipped = equipped,
			Locked = p.Locked,
			Busy = busy[p.Uid] == true,
			Selected = not deleteMode and selected == p.Uid,
			Marked = deleteMode and marked[p.Uid] == true,
		})
	end
	for uid, entry in cards do
		if not alive[uid] then
			entry.Card:Destroy()
			cards[uid] = nil
			marked[uid] = nil
		end
	end
	if selected and not alive[selected] then
		selected = nil
	end
	emptyNote.Visible = shownCount == 0
	emptyNote.Text = if #d.Pets == 0 then "No pets yet! Hatch an egg at an egg stand." else "No pets match this filter."
	countLabel.Text = Theme.Icons.Pets .. " " .. #d.Pets .. "/" .. d.MaxStorage
	countLabel.TextColor3 = if #d.Pets >= d.MaxStorage then Theme.Colors.Bad else Theme.Colors.Text
	equipLabel.Text = Theme.Icons.Equipped .. " " .. #d.Equipped .. "/" .. d.MaxEquip
	Kit.setButton(filterBtn, { Text = "Filter: " .. filter })
	local nMarked = 0
	for _ in marked do
		nMarked += 1
	end
	Kit.setButton(deleteModeBtn, { Text = if deleteMode then "Done" else "Multi-delete", Tone = if deleteMode then "Blue" else "Red" })
	deleteBtn.Visible = deleteMode
	Kit.setButton(deleteBtn, { Text = "Delete " .. nMarked, Enabled = nMarked > 0 })
	renderDetails()
end

function Inventory.Init()
	win = Windows.Create("Pets", { Title = "Pets", Icon = Theme.Icons.Pets, Color = Theme.Tones.Yellow.Rim })
	local body = win.Body
	-- top bar
	local top = Kit.box({ Size = UDim2.new(1, 0, 0, 52), Parent = body })
	countLabel = Kit.fitLabel("", 26, { Size = UDim2.fromOffset(150, 46), Position = UDim2.fromOffset(4, 3), Align = "Left", Parent = top })
	equipLabel = Kit.fitLabel("", 26, { Size = UDim2.fromOffset(120, 46), Position = UDim2.fromOffset(150, 3), Align = "Left", Parent = top })
	filterBtn = Kit.button("Filter: All", "White", {
		Size = UDim2.fromOffset(200, 50),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -300, 0, 0),
		TextSize = 20,
		Parent = top,
	}, function()
		local i = table.find(FILTERS, filter) or 1
		filter = FILTERS[i % #FILTERS + 1]
		Inventory.Render()
	end)

	-- grid
	grid = Kit.scroll({
		Size = UDim2.new(1, -300, 1, -122),
		Position = UDim2.fromOffset(0, 58),
		Parent = body,
	}, { Kit.grid(Vector2.new(96, 112), 8), Kit.pad(8, 6, 8, 6) })
	emptyNote = Kit.fitLabel("", 22, {
		Size = UDim2.new(1, -300, 0, 60),
		Position = UDim2.fromOffset(0, 140),
		Color = Theme.Colors.TextDim,
		Visible = false,
		Parent = body,
	})

	-- details
	details = Kit.panel({
		Size = UDim2.new(0, 290, 1, -58),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = Theme.Colors.PanelAlt,
		Visible = false,
		Parent = body,
	})
	detailPic = Kit.box({ Size = UDim2.new(1, -20, 0, 150), Position = UDim2.fromOffset(10, 6), Parent = details })
	detailName = Kit.fitLabel("", 24, {
		Size = UDim2.new(1, -16, 0, 30),
		Position = UDim2.fromOffset(8, 156),
		Outline = true,
		Parent = details,
	})
	detailInfo = Kit.fitLabel("", 16, {
		Size = UDim2.new(1, -16, 0, 54),
		Position = UDim2.fromOffset(8, 186),
		Font = Theme.FontBody,
		Rich = true,
		Parent = details,
	})
	local xpBar, xpSet = Kit.bar({ Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromOffset(12, 244) }, Theme.Colors.Info)
	xpBar.Parent = details
	setXp = xpSet
	local actions = Kit.box({
		Size = UDim2.new(1, -16, 0, 124),
		Position = UDim2.fromOffset(8, 274),
		Parent = details,
	}, { Kit.grid(Vector2.new(132, 56), 8) })
	btnEquip = Kit.button("Equip", "Green", { LayoutOrder = 1, Parent = actions }, function()
		local uid = selected
		if not uid then
			return
		end
		Remote.CallOnce("EquipPet", uid, not State.IsEquipped(uid))
	end)
	btnLock = Kit.button("Lock", "Blue", { LayoutOrder = 2, Parent = actions }, function()
		local p = if selected then State.PetByUid(selected) else nil
		if p then
			Remote.CallOnce("LockPet", p.Uid, not p.Locked)
		end
	end)
	btnDelete = Kit.button("Delete", "Red", { LayoutOrder = 3, Parent = actions }, function()
		if selected then
			deletePets({ selected })
		end
	end)
	btnCraft = Kit.button("Craft", "Purple", { LayoutOrder = 4, Parent = actions }, function()
		local p = if selected then State.PetByUid(selected) else nil
		if p then
			Inventory.Craft(p)
		end
	end)

	-- bottom bar
	local bottom = Kit.box({
		Size = UDim2.new(1, -300, 0, 58),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Parent = body,
	}, { Kit.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	Kit.button("Equip Best", "Green", { Size = UDim2.fromOffset(140, 54), LayoutOrder = 1, Parent = bottom, TextSize = 20 }, function()
		Remote.CallOnce("EquipBest")
	end)
	Kit.button("Unequip All", "Yellow", { Size = UDim2.fromOffset(140, 54), LayoutOrder = 2, Parent = bottom, TextSize = 20 }, function()
		Remote.CallOnce("UnequipAll")
	end)
	deleteModeBtn = Kit.button("Multi-delete", "Red", { Size = UDim2.fromOffset(110, 54), LayoutOrder = 3, Parent = bottom, TextSize = 18 }, function()
		deleteMode = not deleteMode
		table.clear(marked)
		Inventory.Render()
	end)
	deleteBtn = Kit.button("Delete 0", "Red", { Size = UDim2.fromOffset(100, 54), LayoutOrder = 4, Parent = bottom, TextSize = 18 }, function()
		local uids = {}
		for uid in marked do
			table.insert(uids, uid)
		end
		deletePets(uids)
	end)
	deleteBtn.Visible = false

	win.Opened:Connect(function()
		Inventory.Render()
	end)
	win.Closed:Connect(function()
		deleteMode = false
		table.clear(marked)
	end)
	State.Changed:Connect(function()
		Inventory.Render()
	end)
end

return Inventory
