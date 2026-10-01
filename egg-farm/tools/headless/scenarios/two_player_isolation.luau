-- (b) Two players on one server: separate plots, rings only work on your own plot, one player's
-- actions never touch the other's farm, client-local UI/visuals stay separate.
H.boot()
local a = H.join("Alice")
local b = H.join("Bob")
Lib.waitSnap(a)
Lib.waitSnap(b)
local pa, ia = Lib.plotOf(a)
local pb, ib = Lib.plotOf(b)
H.check("players got different plots", pa ~= nil and pb ~= nil and ia ~= ib, { alice = ia, bob = ib })
H.check("plot owners are set per player", pa:GetAttribute("OwnerUserId") == a.player.UserId and pb:GetAttribute("OwnerUserId") == b.player.UserId)
local dA = (a:root().Position - pa.Spawn.Position).Magnitude
local dB = (b:root().Position - pb.Spawn.Position).Magnitude
H.check("each character spawned on its own plot", dA < 8 and dB < 8, string.format("Alice %.1f, Bob %.1f studs", dA, dB))

H.section("Bob builds up eggs; Alice stands in Bob's rings")
for i = 1, 25 do
	Lib.request(b, { type = "spawn" })
end
H.wait(15)
local sb = Lib.state(b)
local bobEggs = sb.housing[1].eggs
H.check("Bob's House1 has eggs", bobEggs > 0, bobEggs)
local bobCollected = sb.stats.collected or 0
a:walkTo(pb.Houses.House1.CollectRing.Position)
H.wait(3)
local sa = Lib.state(a)
sb = Lib.state(b)
H.check("Alice standing in Bob's CollectRing collects nothing", sa.carried == 0 and (sb.stats.collected or 0) == bobCollected, { aliceCarried = sa.carried, bobCollected = sb.stats.collected or 0, bobHouse1 = sb.housing[1].eggs })
H.check("Bob's House1 eggs were not taken (only grew)", sb.housing[1].eggs >= bobEggs, { before = bobEggs, after = sb.housing[1].eggs })

-- Alice gets eggs from her own house, then stands in Bob's deposit ring
for i = 1, 25 do
	Lib.request(a, { type = "spawn" })
end
H.wait(15)
a:walkTo(pa.Houses.House1.CollectRing.Position)
H.wait(1)
local carried = Lib.state(a).carried
H.check("Alice collects at her own ring", carried > 0, carried)
local bobWarehouseBefore = Lib.state(b).warehouse
local bobDepBefore = Lib.state(b).stats.deposited or 0
a:walkTo(pb.Warehouse.DepositRing.Position)
carried = Lib.state(a).carried
H.wait(3)
H.check("Alice standing in Bob's DepositRing deposits nothing", Lib.state(a).carried == carried and (Lib.state(b).stats.deposited or 0) == bobDepBefore, { aliceCarried = Lib.state(a).carried, bobDeposited = Lib.state(b).stats.deposited or 0, bobWarehouse = { bobWarehouseBefore, Lib.state(b).warehouse } })

H.section("Alice's actions never change Bob's state")
local function bobKey()
	local s = Lib.state(b)
	local houses, vehicles = {}, {}
	for i, h in s.housing do
		houses[i] = h.tier
	end
	for i, v in s.vehicles do
		vehicles[i] = v.tier
	end
	return H.json({ pop = s.population, cash = s.cash, gold = s.gold, carried = s.carried, egg = s.egg, houses = houses, vehicles = vehicles, spawned = s.stats.spawned, codes = s.codes, settings = s.settings, boosts = s.boosts, tut = s.tutorial })
end
local before = bobKey()
Lib.dev(a, "cash")
Lib.dev(a, "gold")
Lib.dev(a, "tutorial")
for _, act in {
	{ type = "spawn" }, { type = "upgradeHouse", slot = 1 }, { type = "buyHouse", slot = 2 },
	{ type = "upgradeVehicle", slot = 1 }, { type = "buyCommon", id = "spawnPerTap" }, { type = "setSetting", id = "flock", value = "low" },
	{ type = "redeemCode", text = "EGGFARM" }, { type = "setAutoSpawn", value = true }, { type = "claimDaily" },
} do
	Lib.request(a, act)
	H.wait(0.1)
end
-- a forged action naming Bob's slot/plot has no way to address Bob: actions carry no player/plot id
Lib.request(a, { type = "upgradeHouse", slot = 1, plot = ib, userId = b.player.UserId })
H.wait(1)
local after = bobKey()
H.check("Bob's farm unchanged by Alice's dev commands and actions", before == after, if before == after then "identical" else { before = before, after = after })
H.check("Alice's own farm did change", Lib.state(a).housing[1].tier >= 2 and Lib.state(a).cash > 0, { aliceHouse1 = Lib.state(a).housing[1].tier, aliceCash = Lib.state(a).cash })
H.check("Bob's plot attributes unaffected", pb:GetAttribute("OwnerUserId") == b.player.UserId and pb:GetAttribute("HouseTiers") == "1,0,0,0", pb:GetAttribute("HouseTiers"))
H.check("Alice's plot attributes reflect her upgrades", pa:GetAttribute("HouseTiers") ~= "1,0,0,0", pa:GetAttribute("HouseTiers"))

H.section("prompts and the fox are owner-only")
local bobBoard
for _, d in pb.Boards:GetDescendants() do
	if d:IsA("ProximityPrompt") and d:GetAttribute("Menu") == "Housing" then
		bobBoard = d
		break
	end
end
a:walkTo(bobBoard.Parent.Position)
local ok, why = a:triggerPrompt(bobBoard)
H.check("Bob's board prompt is disabled on Alice's client", not ok, why)
H.check("Bob's board prompt stays enabled on the server/Bob", bobBoard.Enabled == true)
local okForce = H.M.enqueue(function()
	H.M.SignalApi.FireFor(H.M.getSignal(game:GetService("ProximityPromptService"), "PromptTriggered"), function(c)
		return c == a.ctx
	end, bobBoard, a.player)
end)
H.wait(0.3)
H.check("even a forced trigger of Bob's board opens no menu for Alice", #Lib.openPanels(a) == 0, Lib.openPanels(a))
Lib.dev(b, "tutorial")
Lib.dev(b, "fox")
H.wait(0.2)
local fox = pb:FindFirstChild("LuckyFox")
H.check("Bob's Lucky Fox spawned on Bob's plot", fox ~= nil)
if fox then
	local prompt = fox:FindFirstChildWhichIsA("ProximityPrompt", true)
	local bobCash = Lib.state(b).cash
	local aliceCash = Lib.state(a).cash
	a:teleport(fox:GetPivot().Position + Vector3.new(2, 0, 0))
	local okA, whyA = a:triggerPrompt(prompt)
	H.check("Bob's fox prompt is disabled on Alice's client", not okA, whyA)
	local forced = a:triggerPrompt(prompt, { force = true })
	H.wait(0.3)
	H.check("a forced trigger by Alice is refused by the server (no catch, no pay)", forced and pb:FindFirstChild("LuckyFox") ~= nil and Lib.state(a).cash == aliceCash and Lib.state(b).cash == bobCash, { forced = forced, foxStillThere = pb:FindFirstChild("LuckyFox") ~= nil })
	b:teleport(fox:GetPivot().Position + Vector3.new(-2, 0, 0))
	local okB = b:triggerPrompt(prompt)
	H.wait(0.3)
	H.check("Bob catches his own fox and is paid", okB and pb:FindFirstChild("LuckyFox") == nil and Lib.state(b).cash > bobCash, { before = bobCash, after = Lib.state(b).cash })
end

H.section("client-local instances stay separate")
local seenByA = 0
a:run(function()
	for _, ch in b.player:FindFirstChild("PlayerGui"):GetChildren() do
		seenByA += 1
	end
end)
H.check("Alice's client can't see Bob's PlayerGui contents", seenByA == 0, seenByA)
local fvA = a:run(function()
	local n = 0
	for _, ch in workspace:GetChildren() do
		if ch.Name == "FarmVisuals" then
			n += 1
		end
	end
	return n
end)
local fvServer = H.asServer(function()
	return workspace:FindFirstChild("FarmVisuals") == nil
end)
H.check("each client has exactly one own FarmVisuals; the server sees none", fvA == 1 and fvServer, { aliceSees = fvA, serverSeesNone = fvServer })
