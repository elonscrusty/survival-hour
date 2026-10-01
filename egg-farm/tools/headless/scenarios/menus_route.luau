-- (c) Drive every menu through the HUD buttons, tab buttons, Close/Back, and the Host API;
-- one main panel at a time; purchase double-taps send one request.
H.boot()
local host
local a = H.join("Alice", {
	beforeScripts = function(ctx)
		-- capture the client's Menus/Host instance (same module table Main.client uses)
		H.M.spawnIn(ctx, function()
			local inst = ctx.player.PlayerScripts.Client.Menus.Host
			local Host = H.M.requireIn(ctx, inst)
			local orig = Host.new
			Host.new = function(...)
				host = orig(...)
				return host
			end
		end)
	end,
})
Lib.waitSnap(a)
H.check("captured the client's menu Host", host ~= nil)
Lib.dev(a, "tutorial")
Lib.dev(a, "cash")
Lib.dev(a, "gold")
H.wait(0.5)
local errors0 = #H.M.errors

local function only(name)
	local open = Lib.openPanels(a)
	return #open == 1 and open[1] == name, open
end
local dimmer = a:findGui("Dimmer")

H.section("HUD nav buttons open each menu; tabs switch; Close closes")
local navs = { "Shop", "Eggs", "Quests", "Settings", "Daily", "Boosts", "Gifts", "Upgrades", "Farm" }
local allOk = true
for _, n in navs do
	local b = Lib.hud(a, n)
	local clicked, why = a:click(b)
	H.wait(0.2)
	local ok, open = only(n)
	local dimOn = a:isShown(dimmer)
	H.check("nav " .. n .. " opens only the " .. n .. " panel", clicked and ok and dimOn, { open = open, dimmer = dimOn, why = why })
	-- every tab via its tab button
	local panel = Lib.panel(a, n)
	local tabs = panel and panel:FindFirstChild("Tabs", true)
	if tabs then
		local list = {}
		for _, t in tabs:GetDescendants() do
			if t:IsA("TextButton") and a:isShown(t) then
				table.insert(list, t)
			end
		end
		table.sort(list, function(x, y)
			return x.LayoutOrder < y.LayoutOrder
		end)
		local seen = {}
		for _, t in list do
			a:click(t)
			H.wait(0.15)
			local cur = host.Router:GetTab(n)
			local ok2 = cur == t.Name and only(n)
			table.insert(seen, t.Name .. (if ok2 then "" else "!"))
			allOk = allOk and ok2
		end
		H.check("  " .. n .. " tabs switch via tab buttons", allOk, seen)
	end
	-- clicking another nav while open is blocked by the dimmer (it sinks taps)
	local other = Lib.hud(a, if n == "Shop" then "Eggs" else "Shop")
	local okOther, whyOther = a:click(other)
	H.check("  another HUD button can't be tapped through the open " .. n .. " panel", not okOther, whyOther)
	local close = panel:FindFirstChild("Close", true)
	a:click(close)
	H.wait(0.2)
	H.check("  Close closes " .. n, #Lib.openPanels(a) == 0 and not a:isShown(dimmer), Lib.openPanels(a))
end

H.section("Shop -> Codes -> Back returns to Shop")
a:click(Lib.hud(a, "Shop"))
H.wait(0.2)
local shop = Lib.panel(a, "Shop")
local codesBtn
for _, d in shop:GetDescendants() do
	if d:IsA("TextButton") then
		local l = d:FindFirstChild("Label")
		if l and l.Text == "Codes" then
			codesBtn = d
		end
	end
end
local okc = codesBtn and a:click(codesBtn)
H.wait(0.2)
H.check("Shop's Codes button opens only Codes", okc and only("Codes"), Lib.openPanels(a))
local back = Lib.panel(a, "Codes"):FindFirstChild("Back", true)
local okb = back and a:isShown(back) and a:click(back)
H.wait(0.2)
H.check("Codes' Back button returns to Shop", okb and only("Shop"), Lib.openPanels(a))
a:click(shop:FindFirstChild("Close", true))
H.wait(0.2)

H.section("every menu/tab through Host:Open (one panel at a time)")
local targets = {
	{ "Shop", "Featured" }, { "Shop", "Passes" }, { "Shop", "Gold" }, { "Shop", "Cash" }, { "Codes" }, { "Eggs" }, { "Quests" },
	{ "Boosts", "BOOSTS" }, { "Boosts", "SHOP" }, { "Daily" }, { "Gifts" }, { "Settings" }, { "Upgrades", "COMMON" }, { "Upgrades", "EPIC" },
	{ "Farm", "Housing" }, { "Farm", "Shipping" }, { "Farm", "Workers" }, { "Farm", "Silos" },
}
local bad = {}
for _, t in targets do
	a:run(function()
		host:Open(t[1], t[2])
	end)
	H.wait(0.1)
	local ok, open = only(t[1])
	local tabOk = t[2] == nil or host.Router:GetTab(t[1]) == t[2]
	if t[2] then
		local tabs = Lib.panel(a, t[1]):FindFirstChild("Tabs", true)
		local tb = tabs and tabs:FindFirstChild(t[2], true)
		tabOk = tabOk and tb ~= nil and a:isShown(tb)
	end
	if not (ok and tabOk) then
		table.insert(bad, { t = t, open = open })
	end
end
H.check("all 18 menu/tab targets open alone with the right tab", #bad == 0, if #bad == 0 then "18/18" else bad)
a:run(function()
	host:Close()
end)
H.wait(0.1)
H.check("Host:Close closes everything", #Lib.openPanels(a) == 0)
local built = {}
for name in host.built do
	table.insert(built, name)
end
table.sort(built)
H.check("every menu built (lazily) without a build failure", #built == 10, built)

H.section("blocking while a menu is open")
a:click(Lib.hud(a, "Settings"))
H.wait(0.2)
local spawnN = Lib.actionCount()
a:click(Lib.hud(a, "Spawn"), { force = true })
H.wait(0.3)
local ppsOff = a:run(function()
	return game:GetService("ProximityPromptService").Enabled
end)
H.check("SPAWN does nothing while a menu is open; world prompts disabled locally", Lib.actionCount() == spawnN and ppsOff == false, { requests = Lib.actionCount() - spawnN, promptServiceEnabled = ppsOff })
H.check("server-side ProximityPromptService stays enabled", game:GetService("ProximityPromptService").Enabled == true)
a:click(Lib.panel(a, "Settings"):FindFirstChild("Close", true))
H.wait(0.2)

H.section("double tap on a purchase button sends one request")
a:click(Lib.hud(a, "Upgrades"))
H.wait(0.2)
local up = Lib.panel(a, "Upgrades")
-- first visible, affordable purchase button in the COMMON tab
local target, title
for _, d in up:GetDescendants() do
	if d:IsA("TextButton") and d.Name == "Button" and a:isShown(d) and d.Parent and d.Parent.Name == "Action" then
		target = d
		local card = d
		while card and card.Name ~= "Card" do
			card = card.Parent
		end
		local t = card and card:FindFirstChild("Text")
		title = t and t:FindFirstChildWhichIsA("TextLabel") and t:FindFirstChildWhichIsA("TextLabel").Text
		break
	end
end
H.check("found a Common upgrade purchase button", target ~= nil, title)
local function levels()
	return H.json({ common = Lib.state(a).common, epic = Lib.state(a).epic })
end
local lv0 = levels()
local n0 = Lib.actionCount()
a:click(target)
a:click(target) -- same frame
H.wait(1 / 30)
a:click(target) -- next frame, while the first request is still in flight
H.wait(1)
local sent = Lib.actionCount() - n0
local lv1 = levels()
H.check("three rapid taps -> exactly one request reaches the server", sent == 1, { requests = sent })
H.check("the upgrade was bought exactly once", lv0 ~= lv1, { before = lv0, after = lv1 })
local confirmOn = Lib.state(a).settings.confirmSpend
H.note("FINDING: Upgrades tab remembered EPIC; this Gold-Egg-priced Epic upgrade bought on tap without the 'Confirm Gold Eggs' dialog (Shop/Boosts ask)", { item = title, confirmSpend = confirmOn, modalShown = host.Router:Modal() })
-- a tap after the reply buys the next level (the button isn't stuck)
a:click(target)
H.wait(1)
H.check("a later tap sends a fresh request", Lib.actionCount() - n0 == 2, { requests = Lib.actionCount() - n0 })
a:click(up:FindFirstChild("Close", true))
H.wait(0.2)

H.section("modal: confirm Gold Egg spend")
-- Boosts > SHOP buys with Gold Eggs; with confirmSpend on, a confirm modal appears first
Lib.request(a, { type = "setSetting", id = "confirmSpend", value = true })
a:run(function()
	host:Open("Boosts", "SHOP")
end)
H.wait(0.3)
local bshop = Lib.panel(a, "Boosts")
local gbtn
for _, d in bshop:GetDescendants() do
	if d:IsA("TextButton") and d.Name == "Button" and a:isShown(d) then
		gbtn = d
		break
	end
end
local g0 = Lib.state(a).gold
local m0 = Lib.actionCount()
if gbtn then
	a:click(gbtn)
	H.wait(0.3)
end
local modalOpen = host.Router:Modal()
H.check("a Gold Egg purchase asks for confirmation first (no request yet)", gbtn ~= nil and modalOpen ~= nil and Lib.actionCount() == m0, { modal = modalOpen, requests = Lib.actionCount() - m0 })
local modalRoot = a:playerGui():FindFirstChild("EggFarmModal")
local yes
for _, d in modalRoot:GetDescendants() do
	if d:IsA("TextButton") and a:isShown(d) then
		local l = d:FindFirstChild("Label")
		if l and l.Text ~= "" and l.Text ~= "Cancel" and l.Text ~= "CANCEL" then
			yes = d
		end
	end
end
if yes then
	a:click(yes)
	a:click(yes)
end
H.wait(1)
H.check("confirming spends Gold Eggs once and closes the modal", yes ~= nil and Lib.state(a).gold < g0 and host.Router:Modal() == nil and Lib.actionCount() - m0 == 1, { goldBefore = g0, goldAfter = Lib.state(a).gold, requests = Lib.actionCount() - m0 })
a:run(function()
	host:Close()
end)
H.wait(0.2)

H.section("keyboard back closes the open menu")
a:run(function()
	host:Open("Eggs")
end)
H.wait(0.1)
a:key(Enum.KeyCode.Backspace, Enum.UserInputState.Begin)
H.wait(0.1)
H.check("Backspace (EggFarmBack action) closes the menu", #Lib.openPanels(a) == 0, Lib.openPanels(a))

local newErrors = #H.M.errors - errors0
local buildWarn = 0
for _, w in H.M.warnings do
	if string.find(w.msg, "failed") then
		buildWarn += 1
	end
end
H.check("no Lua errors or build/start failures while routing menus", newErrors == 0 and buildWarn == 0, { errors = newErrors, failWarnings = buildWarn })
