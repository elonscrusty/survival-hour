-- (f) Simulated checkout (success / cancel / fail) through the Shop UI and Commerce remote,
-- redeem codes through the Codes UI, buy + use a Gold Egg boost and let it expire.
H.boot()
local a = H.join("Alice")
Lib.waitSnap(a)
local Store = Lib.store(a)
local events = {}
a:run(function()
	Store.OnEvent("*", function(name, data)
		table.insert(events, { name = name, data = data, t = H.now() })
	end)
end)
local function eventsNamed(n)
	local out = {}
	for _, e in events do
		if e.name == n then
			table.insert(out, e)
		end
	end
	return out
end
local function commerceCount()
	local st = H.M.netStats.Commerce
	return st and st.messages or 0
end
local function cardButton(panel, title)
	for _, d in panel:GetDescendants() do
		if d:IsA("TextLabel") and d.Text == title and a:isShown(d) then
			local card = d.Parent
			for _, x in card:GetDescendants() do
				if x:IsA("TextButton") and x.Name == "Button" then
					return x
				end
			end
		end
	end
	return nil
end
local function visibleTexts(root)
	local t = {}
	for _, d in root:GetDescendants() do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and a:isShown(d) then
			t[d.Text] = true
		end
	end
	return t
end

H.section("codes before the tutorial")
local early = Lib.request(a, { type = "redeemCode", text = "EGGFARM" })
H.check("a code before finishing the tutorial is refused", early.code == "tutorial", early)
Lib.dev(a, "tutorial")

H.section("simulated checkout through the Shop")
a:click(Lib.hud(a, "Shop"))
H.wait(0.2)
local shop = Lib.panel(a, "Shop")
a:click(shop:FindFirstChild("Tabs", true):FindFirstChild("Passes", true))
H.wait(0.2)
local passBtn = cardButton(shop, "x2 Cash")
H.check("Passes tab shows the x2 Cash card with a Robux button", passBtn ~= nil and string.find(passBtn.Label.Text, "R%$") ~= nil, passBtn and passBtn.Label.Text)
local c0 = commerceCount()
a:click(passBtn)
a:click(passBtn)
H.wait(1)
local s = Lib.state(a)
local receiptIds = {}
for id in s.receipts do
	table.insert(receiptIds, id)
end
H.check("checkout success grants the pass once (double tap -> one Commerce call)", s.passes.x2cash == true and commerceCount() - c0 == 1 and #receiptIds == 1, { pass = s.passes.x2cash, commerceCalls = commerceCount() - c0, receipts = receiptIds })
H.check("purchase id is a TEST- id", #receiptIds == 1 and string.sub(receiptIds[1], 1, 5) == "TEST-", receiptIds[1])
H.check("button now shows OWNED", passBtn.Label.Text == "OWNED", passBtn.Label.Text)
local c1 = commerceCount()
a:click(passBtn)
H.wait(0.5)
H.check("tapping an owned pass sends nothing", commerceCount() == c1)
local direct = a:run(function()
	return game:GetService("ReplicatedStorage").Remotes.Commerce:InvokeServer({ productId = "x2cash" })
end)
H.check("server refuses to sell an owned pass again", direct.code == "owned", direct)

a:click(shop:FindFirstChild("Tabs", true):FindFirstChild("Gold", true))
H.wait(0.2)
local goldBtn = cardButton(shop, "Handful of Gold Eggs")
local g0 = Lib.state(a).gold
Lib.dev(a, "checkout", "cancel")
a:click(goldBtn)
H.wait(1)
H.check("checkout cancel grants nothing", Lib.state(a).gold == g0, { gold = Lib.state(a).gold })
H.wait(1.2)
Lib.dev(a, "checkout", "fail")
local res = a:run(function()
	return game:GetService("ReplicatedStorage").Remotes.Commerce:InvokeServer({ productId = "gold_small" })
end)
H.check("checkout fail grants nothing and says nothing was charged", res.code == "failed" and Lib.state(a).gold == g0, res)
H.wait(2.1)
Lib.dev(a, "checkout", "success")
local gs = a:run(function()
	return game:GetService("ReplicatedStorage").Remotes.Commerce:InvokeServer({ productId = "gold_small" })
end)
H.check("checkout success grants 50 Gold Eggs", gs.ok and Lib.state(a).gold == g0 + 50, { res = gs, gold = Lib.state(a).gold })
local bogus = a:run(function()
	return game:GetService("ReplicatedStorage").Remotes.Commerce:InvokeServer({ productId = "buy_earn3" })
end)
H.check("Commerce refuses Gold-Egg items (not Robux)", bogus.ok == false and bogus.code == "invalid", bogus)
H.check("no real MarketplaceService prompt was ever opened", #H.M.marketPrompts == 0, #H.M.marketPrompts)
a:click(shop:FindFirstChild("Close", true))
H.wait(0.2)

H.section("codes through the Codes menu")
H.wait(10)
a:click(Lib.hud(a, "Shop"))
H.wait(0.2)
local codesBtn
for _, d in shop:GetDescendants() do
	if d:IsA("TextButton") and d:FindFirstChild("Label") and d.Label.Text == "Codes" then
		codesBtn = d
	end
end
a:click(codesBtn)
H.wait(0.2)
local codes = Lib.panel(a, "Codes")
local box = codes:FindFirstChild("CodeBox", true)
local redeemBtn
for _, d in codes:GetDescendants() do
	if d:IsA("TextButton") and d:FindFirstChild("Label") and d.Label.Text == "Redeem" then
		redeemBtn = d
	end
end
H.check("Codes panel has a CodeBox and a Redeem button", box ~= nil and redeemBtn ~= nil)
local Contract = H.serverRequire("ReplicatedStorage.Shared.Contract")
local function redeem(text)
	a:run(function()
		box.Text = text
	end)
	local gold0 = Lib.state(a).gold
	a:click(redeemBtn)
	H.wait(0.6)
	return visibleTexts(codes), Lib.state(a).gold - gold0
end
local t1, dg1 = redeem("eggfarm")
H.check("EGGFARM (typed lowercase) redeems: +25 Gold Eggs, success text", t1[Contract.Messages.code_ok] and dg1 == 25, { gold = dg1, ok = t1[Contract.Messages.code_ok] })
local t2, dg2 = redeem("EGGFARM")
H.check("EGGFARM again -> already redeemed", t2[Contract.Messages.code_used] and dg2 == 0)
local t3 = redeem("NOPE")
H.check("NOPE -> doesn't exist", t3[Contract.Messages.code_invalid] == true)
local t4 = redeem("TESTEXPIRED")
H.check("TESTEXPIRED -> expired", t4[Contract.Messages.code_expired] == true)
local t5 = redeem("   ")
H.check("blank -> 'Type a code first.' without a request", t5["Type a code first."] == true)
a:run(function()
	local h = nil
end)
a:click(codes:FindFirstChild("Close", true))
H.wait(0.2)

H.section("buy a Gold Egg boost, use it, let it expire")
a:click(Lib.hud(a, "Boosts"))
H.wait(0.2)
local boosts = Lib.panel(a, "Boosts")
a:click(boosts:FindFirstChild("Tabs", true):FindFirstChild("SHOP", true))
H.wait(0.2)
local buyBtn, lbl = Lib.rowButton(a, "Cash x3 Boost", boosts)
H.check("Boosts SHOP lists Cash x3 Boost", buyBtn ~= nil, lbl and lbl.Text or lbl)
local gold0 = Lib.state(a).gold
a:click(buyBtn)
H.wait(0.3)
local modalRoot = a:playerGui():FindFirstChild("EggFarmModal")
local yes
for _, d in modalRoot:GetDescendants() do
	if d:IsA("TextButton") and a:isShown(d) and d:FindFirstChild("Label") and d.Label.Text == "Buy" then
		yes = d
	end
end
H.check("Gold Egg spend asks to confirm", yes ~= nil)
a:click(yes)
H.wait(0.6)
local st = Lib.state(a)
H.check("bought: -20 Gold Eggs, earn3 in inventory", st.gold == gold0 - 20 and (st.boosts.inventory.earn3 or 0) >= 1, { goldSpent = gold0 - st.gold, inventory = st.boosts.inventory })
a:click(boosts:FindFirstChild("Tabs", true):FindFirstChild("BOOSTS", true))
H.wait(0.2)
local useBtn, ul = Lib.rowButton(a, "Cash x3", boosts)
local usedAt = H.now()
a:click(useBtn)
H.wait(0.6)
st = Lib.state(a)
local active = st.boosts.active[1]
local snap = Lib.snap(a)
H.check("using the boost starts it on the server clock (20 min)", active ~= nil and active.id == "earn3" and math.abs((active.endsAt - H.M.serverNow()) - 1200) < 2, active and { id = active.id, remaining = active.endsAt - H.M.serverNow() })
H.check("BoostUsed event reached the client", #eventsNamed("BoostUsed") == 1)
H.note("snapshot mods while active", snap.mods)
a:click(boosts:FindFirstChild("Close", true))
H.wait(19 * 60)
H.check("boost still active at 19 min", #Lib.state(a).boosts.active == 1)
H.wait(70)
st = Lib.state(a)
H.check("boost expired after 20 min (server clock)", #st.boosts.active == 0, st.boosts.active)
H.check("BoostEnded event reached the client", #eventsNamed("BoostEnded") == 1, #eventsNamed("BoostEnded"))
H.note("FarmEvents seen by the client", (function()
	local c = {}
	for _, e in events do
		c[e.name] = (c[e.name] or 0) + 1
	end
	return c
end)())
