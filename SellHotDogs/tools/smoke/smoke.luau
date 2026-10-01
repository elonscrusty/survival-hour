--!nocheck
-- Headless end-to-end smoke test of the BUILT place under Lune.
--   lune run tools/smoke/smoke.luau [build/SellHotDogs.rbxlx]
-- Runs the real server and client scripts with one or two simulated players, drives the UI
-- by firing button/touch signals, and writes docs/evidence/smoke_report.md + smoke_log.txt.
-- Limits: no physics, rendering, touch input, real network, DataStores or Studio. Some setup
-- steps write to the server profile directly (marked SETUP) to reach late-game states fast.
local fs = require("@lune/fs")
local process = require("@lune/process")
local task = require("@lune/task")
local Engine = require("./engine")

local placePath = process.args[1] or "build/SellHotDogs.rbxlx"
local dm = Engine.load(placePath)
local R = require("@lune/roblox")

local results = {}
local function check(name, ok, detail)
	table.insert(results, { name = name, ok = ok and true or false, detail = detail or "" })
	print((if ok then "PASS " else "FAIL ") .. name .. (if detail and detail ~= "" then "  -- " .. detail else ""))
end

Engine.startClock()
local server = Engine.newSide(dm, "server")
local sss = dm:GetService("ServerScriptService")
local rs = dm:GetService("ReplicatedStorage")
local okBoot, bootErr = pcall(server.run, sss.Server.Main)
check("server boots", okBoot, tostring(bootErr or ""))

local BigNum = server.require(rs.Shared.Logic.BigNum)
local Format = server.require(rs.Shared.Logic.Format)
local Data = server.require(sss.Server.Services.Data)
local Store = server.require(sss.Server.Services.Store)

local plots = dm:GetService("Workspace"):FindFirstChild("Plots")
check("plots built", plots and #plots:GetChildren() == 4, plots and (#plots:GetChildren() .. " plots") or "none")

local function main()
-- player joins ---------------------------------------------------------------
local player = Engine.addPlayer(dm, "Carter", 1001)
Engine.localPlayer = player
local client
local function waitFor(cond, timeout)
	local t0 = os.clock()
	while os.clock() - t0 < (timeout or 5) do
		local ok, v = pcall(cond)
		if ok and v then
			return v
		end
		task.wait(0.05)
	end
	return nil
end
local session = waitFor(function()
	return Data.get(player)
end)
check("profile loads (mock storage)", session ~= nil and session.canSave)
local character = Engine.spawnCharacter(player)
local root = character.HumanoidRootPart
waitFor(function()
	return false
end, 0.3)

client = Engine.newSide(dm, "client")
local playerScripts = dm:GetService("StarterPlayer").StarterPlayerScripts
local okClient, clientErr = pcall(client.run, playerScripts.Client.Main)
check("client boots and builds UI", okClient, tostring(clientErr or ""))
local State = client.require(playerScripts.Client.Controllers.State)
local snap = waitFor(function()
	return State.data
end)
check("client receives state", snap ~= nil)

local function cash()
	return BigNum.toNumber(session.profile.cash)
end
local function shownCash()
	return BigNum.toNumber(BigNum.sanitize(State.data.cash))
end
local plot = plots:FindFirstChild("Plot" .. tostring(player:GetAttribute("Plot")))
check("player assigned a plot", plot ~= nil, plot and plot.Name)
check("clean start cash is $1.00 (hypothesis)", math.abs(cash() - 1) < 1e-9, Format.cash(session.profile.cash))

local function place(cf)
	root.CFrame = cf
	root.Position = cf.Position
end
local function moveTo(part)
	place(R.CFrame.new(part.CFrame.Position + R.Vector3.new(0, 3, 0)))
end
local function touch(padId)
	local pad = plot:FindFirstChild(padId)
	if not pad then
		return false
	end
	moveTo(pad)
	Engine.sig(pad, "Touched"):Fire(root)
	task.wait(0.5)
	return true
end
local Action = rs.Remotes.Action
local function send(...)
	Action:FireServer(...)
	task.wait(0.15)
end

-- opening ----------------------------------------------------------------------
check("stand unlock pad visible at start", plot:FindFirstChild("biz:stand") ~= nil)
touch("biz:stand")
check("buy Hot Dog Stand for $1 by stepping on pad", session.profile.pads["biz:stand"] == true and math.abs(cash()) < 1e-9, Format.cash(session.profile.cash))
check("stand building appears", plot:FindFirstChild("stand") ~= nil)
check("Condiment Station and Cash Register pads appear", plot:FindFirstChild("stand:condiment") ~= nil and plot:FindFirstChild("stand:register") ~= nil)
check("Bun Rack pad still hidden", plot:FindFirstChild("stand:bunrack") == nil)

local pg = player.PlayerGui
local card = waitFor(function()
	return pg:FindFirstChild("Biz_stand")
end)
check("stand world controls exist", card ~= nil)
local clickButton
for _, d in card:GetDescendants() do
	if d:IsA("TextButton") and d:FindFirstChildWhichIsA("Frame") and d.Size.Y.Offset == 34 then
		clickButton = d
	end
end
check("CLICK bar found", clickButton ~= nil)
local standAnchor = plot.Anchors.stand
place(R.CFrame.new(standAnchor.Position - R.Vector3.new(0, 14, 12)))

Engine.press(clickButton)
task.wait(0.25)
local midCash = cash()
local running = session.profile.biz.stand.running
task.wait(1.1)
check("one-second manual cycle pays $1.00 after it completes", running and midCash == 0 and math.abs(cash() - 1) < 1e-9, string.format("mid=%s end=%s", Format.cash(midCash), Format.cash(session.profile.cash)))
check("wallet shows server cash", math.abs(shownCash() - cash()) < 1e-9)

for _ = 1, 6 do
	Engine.press(clickButton)
end
task.wait(1.3)
check("repeated clicks during a cycle pay once", math.abs(cash() - 2) < 1e-9, Format.cash(session.profile.cash))

-- earn up to $6.20 by clicking
local clicks = 0
while cash() < 6.2 and clicks < 20 do
	Engine.press(clickButton)
	task.wait(1.15)
	clicks += 1
end
check("earn to $6.20 by clicking", cash() >= 6.2, Format.cash(session.profile.cash) .. " after " .. clicks .. " more cycles")
local before = cash()
touch("stand:condiment")
check("Condiment Station costs $6.20 exactly", math.abs(before - cash() - 6.2) < 1e-9, string.format("%s -> %s", Format.cash(before), Format.cash(session.profile.cash)))
task.wait(0.3)
check("stand output label now $2.00", waitFor(function()
	return Format.cash(BigNum.sanitize(State.data.biz.stand.output)) == "$2.00"
end, 2) ~= nil)

-- unaffordable pad: no deduction
before = cash()
touch("stand:register")
check("unaffordable Cash Register rejected, cash unchanged", session.profile.pads["stand:register"] == nil and cash() == before)

-- upgrade via blue button
while cash() < 5.10 do
	Engine.press(clickButton)
	task.wait(1.15)
end
local upBtn = Engine.findButton(card, "^Upgrade")
before = cash()
Engine.press(upBtn)
task.wait(0.4)
check("blue Upgrade costs $5.10 (observed)", math.abs(before - cash() - 5.10) < 1e-9 and session.profile.biz.stand.level == 2, Format.cash(session.profile.cash))

-- invalid / hostile requests ----------------------------------------------------
before = cash()
local levelBefore = session.profile.biz.stand.level
send("upgrade", "stand", 5)
send("upgrade", "stand", -3)
send("upgrade", "stand", 0 / 0)
send("upgrade", "nope", 1)
send("buyPad", "stand:billboard")
send("buyPad", { hack = true })
send("click", 12345)
send("forever", "stand:condiment")
send("rebirth")
send("evolve")
send("ascend")
send("mockBuy", "notAProduct")
send("phone", 999, "accept")
send(nil)
check("invalid requests change nothing", cash() == before and session.profile.biz.stand.level == levelBefore and session.profile.foreverTokens == 0)

-- SETUP: give cash to test simultaneous purchases
session.profile.cash = BigNum.new(250)
local regPad = plot:FindFirstChild("stand:register")
moveTo(regPad)
task.wait(0.6) -- let the touch debounce from the earlier attempt expire
Action:FireServer("buyPad", "stand:register")
Action:FireServer("buyPad", "stand:register")
Engine.sig(regPad, "Touched"):Fire(root)
Engine.sig(regPad, "Touched"):Fire(root)
Action:FireServer("buyPad", "stand:register")
task.wait(0.6)
check("simultaneous purchase requests deduct once", session.profile.pads["stand:register"] == true and math.abs(cash() - 150) < 1e-6, Format.cash(session.profile.cash))
check("Cash Register prop appears", plot:FindFirstChild("Prop_stand:register") ~= nil and plot:FindFirstChild("stand:register") == nil)
local c0 = cash()
task.wait(2.05)
check("register automates (no clicks needed)", cash() > c0 + 3, string.format("%s -> %s", Format.cash(c0), Format.cash(session.profile.cash)))

-- pickups ------------------------------------------------------------------------
local pick = waitFor(function()
	local f = plot:FindFirstChild("Pickups")
	return f and f:GetChildren()[1]
end, 12)
check("ingredient crate spawns at a rack", pick ~= nil)
if pick then
	local hit = pick:FindFirstChild("Hit")
	c0 = cash()
	place(R.CFrame.new(hit.Position + R.Vector3.new(30, 0, 0)))
	Engine.sig(hit, "Touched"):Fire(root)
	task.wait(0.3)
	local farOk = pick.Parent ~= nil
	place(R.CFrame.new(hit.Position))
	Engine.sig(hit, "Touched"):Fire(root)
	Engine.sig(hit, "Touched"):Fire(root)
	task.wait(0.3)
	check("pickup: far touch ignored, near touch pays once", farOk and pick.Parent == nil and session.profile.stats.pickups == 1, "stats.pickups=" .. tostring(session.profile.stats.pickups))
end

-- Manage panel ------------------------------------------------------------------------
local hud = pg.Hud
Engine.press(Engine.findButton(hud, "Manage"))
task.wait(0.3)
local panels = pg.Panels
check("Manage panel opens (locked message before power)", panels.Enabled and Engine.findButton(panels, "Go to Powers") ~= nil)
Engine.press(Engine.findButton(panels, "Go to Powers"))
task.wait(0.3)
check("Powers tab lists cards with investor and Robux buttons", Engine.findButton(panels, "TEST BUY") ~= nil and Engine.findButton(panels, "Maxed") == nil)
Engine.press(Engine.findButton(panels, "✕"))
task.wait(0.2)
check("red close button closes panel", not panels.Enabled)

-- mock Robux purchases ------------------------------------------------------------------
send("mockBuy", "manage")
task.wait(0.3)
check("mock purchase grants Manage", session.profile.robux.tiers.manage == 1 and #session.profile.robux.receipts == 1)
send("mockBuy", "manage", true)
task.wait(0.4)
check("duplicate receipt delivery grants nothing extra", session.profile.robux.tiers.manage == 1 and #session.profile.robux.receipts == 1)
send("mockBuy", "cash1h", false, true)
check("cancelled purchase grants nothing", #session.profile.robux.receipts == 1)
send("mockBuy", "manage")
check("already-owned pass not re-bought", #session.profile.robux.receipts == 1)
Engine.press(Engine.findButton(hud, "Manage"))
task.wait(0.4)
check("Manage panel lists businesses once Manage is owned", Engine.findButton(panels, "x1") ~= nil)
place(R.CFrame.new(5000, 5, 5000)) -- far away
before = cash()
Engine.press(Engine.findButton(panels, "x1"))
task.wait(0.4)
check("remote upgrade from Manage panel works from far away", session.profile.biz.stand.level == 3, "level " .. session.profile.biz.stand.level)
Engine.press(Engine.findButton(panels, "✕"))

-- SETUP: rich late game ------------------------------------------------------------
session.profile.cash = BigNum.fromParts(1, 120)
send("mockBuy", "remoteBuy")
local buys = 0
for _ = 1, 200 do
	Action:FireServer("buyNext")
	task.wait(0.17)
	buys += 1
	local G = server.require(rs.Shared.Logic.Game)
	if G.nextPad(session.profile) == nil then
		break
	end
end
local G = server.require(rs.Shared.Logic.Game)
local canAsc, owned, total = G.canAscend(session.profile)
check("Remote Buy walks the whole ladder (all 8 businesses, every pad)", canAsc, string.format("%d/%d after %d requests", owned, total, buys))
local allBuildings = true
for _, id in { "stand", "dash", "depot", "trading", "labs", "robotics", "republic", "hotdogx" } do
	if not plot:FindFirstChild(id) then
		allBuildings = false
	end
end
check("every business building is in the world", allBuildings)
-- dump top-down geometry of the finished plot for tools/smoke/render_map.py
do
	local origin = plot.SpawnPoint.CFrame.Position - R.Vector3.new(0, 3, 6)
	local out = {}
	for _, d in plot:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.9 then
			local cf, sz = d.CFrame, d.Size
			local pts = {}
			for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
				local w = cf * R.Vector3.new(c[1] * sz.X / 2, 0, c[2] * sz.Z / 2)
				table.insert(pts, { w.X - origin.X, w.Z - origin.Z })
			end
			local col = d.Color
			table.insert(out, { p = pts, y = cf.Position.Y + sz.Y / 2, c = { col.R, col.G, col.B } })
		end
	end
	local serde = require("@lune/serde")
	fs.writeFile("docs/evidence/plot_geometry.json", serde.encode("json", out))
end
task.wait(0.5)
check("staircase appears once everything is owned", plot:FindFirstChild("Staircase") ~= nil)

-- big numbers and fast production ------------------------------------------------------
session.profile.evolutions = 12
session.profile.cash = BigNum.fromParts(3, 564)
local t0 = Engine.remoteTraffic.toClient
task.wait(2)
local perSec = (Engine.remoteTraffic.toClient - t0) / 2
check("fast production stays aggregated (client messages per second)", perSec <= 12, string.format("%.1f msgs/s", perSec))
task.wait(0.3)
local wt
for _, d in hud:GetDescendants() do
	if d:IsA("TextLabel") and d.Text:find("^%$") and d.Parent.Name == "Wallet" then
		wt = d.Text
	end
end
check("wallet formats a 10^564 balance", wt ~= nil and wt:find("e564") ~= nil, tostring(wt))
session.profile.evolutions = 0

-- Investors / Rebirth through the UI --------------------------------------------------
session.profile.lifetime = BigNum.new(77e21 * 400) -- SETUP
session.profile.robux.tiers.remoteBuy = nil
task.wait(0.6)
send("sync")
task.wait(0.3)
Engine.press(Engine.findButton(hud, "Investors"))
task.wait(0.3)
local dlg = pg.Dialogs
check("Investors dialog shows offer", dlg.Enabled and Engine.findButton(dlg, "^Rebirth$") ~= nil)
Engine.press(Engine.findButton(dlg, "^Rebirth$"))
task.wait(0.2)
check("rebirth asks to confirm with resets listed", Engine.findButton(dlg, "Cancel") ~= nil)
Engine.press(Engine.findButton(dlg, "Cancel"))
task.wait(0.3)
check("cancel keeps everything", session.profile.pads["biz:dash"] == true)
Engine.press(Engine.findButton(hud, "Investors"))
task.wait(0.3)
Engine.press(Engine.findButton(dlg, "^Rebirth$"))
task.wait(0.2)
Engine.press(Engine.findButton(dlg, "^Rebirth$"))
task.wait(0.6)
local p = session.profile
check("rebirth: +20 investors, run reset, Manage (Robux) kept", BigNum.toNumber(p.investors) == 20 and p.pads["biz:stand"] == nil and math.abs(cash() - 1) < 1e-9 and p.robux.tiers.manage == 1, string.format("investors=%s cash=%s", Format.amount(p.investors, 0), Format.cash(p.cash)))
task.wait(0.4)
check("plot clears after rebirth", plot:FindFirstChild("stand") == nil and plot:FindFirstChild("biz:stand") ~= nil)
pcall(function()
	Engine.press(Engine.findButton(dlg, "Awesome"))
end)

-- powers with investors
send("buyPower", "runFaster")
check("Run Faster bought with 400 investors? (needs 400, has 20 -> rejected)", p.powers.runFaster == nil and BigNum.toNumber(p.investors) == 20)
p.investors = BigNum.new(1500) -- SETUP
task.wait(0.3) -- buyPower is rate limited
send("buyPower", "runFaster")
task.wait(0.2)
check("Run Faster tier 1 costs 400 investors and speeds walking", p.powers.runFaster == 1 and BigNum.toNumber(p.investors) == 1100 and character.Humanoid.WalkSpeed == 24, string.format("tier=%s investors=%s WalkSpeed=%s", tostring(p.powers.runFaster), Format.amount(p.investors, 0), tostring(character.Humanoid.WalkSpeed)))
task.wait(0.3)
send("buyPower", "stack")
task.wait(0.2)
check("Stack Upgrade unlocks x5 bulk", table.find(G.bulkOptions(p), 5) ~= nil)

-- Forever Purchase ---------------------------------------------------------------------
send("mockBuy", "forever")
task.wait(0.4)
check("Forever Purchase token granted", p.foreverTokens == 1)
Engine.press(Engine.findButton(hud, "Forever"))
task.wait(0.3)
Engine.press(Engine.findButton(dlg, "Hot Dog Billboard"))
task.wait(0.2)
Engine.press(Engine.findButton(dlg, "nvm"))
task.wait(0.2)
check("Forever: nvm returns to the list without spending", p.foreverTokens == 1 and Engine.findButton(dlg, "Hot Dog Billboard") ~= nil)
Engine.press(Engine.findButton(dlg, "Hot Dog Billboard"))
task.wait(0.2)
Engine.press(Engine.findButton(dlg, "^Yes$"))
task.wait(0.4)
check("Forever: Yes consumes exactly one token", p.foreverTokens == 0 and p.forever["stand:billboard"] == true)
send("forever", "stand:bunrack")
check("Forever: no second use without a token", p.forever["stand:bunrack"] == nil)

-- Evolution -------------------------------------------------------------------------------
p.investors = BigNum.new(501.2e15) -- SETUP
task.wait(0.6)
send("sync")
task.wait(0.3)
Engine.press(Engine.findButton(hud, "Evolution"))
task.wait(0.3)
Engine.press(Engine.findButton(dlg, "^Evolve$"))
task.wait(0.2)
Engine.press(Engine.findButton(dlg, "^Evolve$"))
task.wait(0.6)
check("evolution: x1 evolution, investors and investor powers reset, Robux + Forever kept", p.evolutions == 1 and p.investors.m == 0 and p.powers.runFaster == nil and p.robux.tiers.manage == 1 and p.forever["stand:billboard"] == true, string.format("evo=%d inv=%s runFaster=%s manage=%s forever=%s", p.evolutions, Format.amount(p.investors, 0), tostring(p.powers.runFaster), tostring(p.robux.tiers.manage), tostring(p.forever["stand:billboard"])))
pcall(function()
	Engine.press(Engine.findButton(dlg, "Awesome"))
end)

-- Ascension -----------------------------------------------------------------------------
p.cash = BigNum.fromParts(1, 150) -- SETUP
p.robux.tiers.remoteBuy = 1
for _ = 1, 200 do
	Action:FireServer("buyNext")
	task.wait(0.17)
	if G.nextPad(p) == nil then
		break
	end
end
task.wait(0.4)
Engine.press(Engine.findButton(hud, "Ascension"))
task.wait(0.3)
Engine.press(Engine.findButton(dlg, "^Ascend$"))
task.wait(0.2)
Engine.press(Engine.findButton(dlg, "^Ascend$"))
task.wait(0.6)
check("ascension: count 1, evolutions reset, +1 Forever token, Forever pad kept", p.ascensions == 1 and p.evolutions == 0 and p.foreverTokens == 1 and p.forever["stand:billboard"] == true)
pcall(function()
	Engine.press(Engine.findButton(dlg, "Awesome"))
end)
check("ascension price x3.33 shows on stand pad", (function()
	local pad = plot:FindFirstChild("biz:stand")
	return pad and pad.PadLabel.Price.Text == "$3.33"
end)())

-- Name editing ----------------------------------------------------------------------------
Engine.press(Engine.findButton(hud, "✏️"))
task.wait(0.3)
local tb = dlg:FindFirstChildWhichIsA("TextBox", true)
tb.Text = "badword dogs"
Engine.press(Engine.findButton(dlg, "^Save$"))
task.wait(0.5)
check("unsuitable name rejected by filter", p.name == nil)
tb.Text = string.rep("Hotdog", 6)
Engine.press(Engine.findButton(dlg, "^Save$"))
task.wait(0.3)
check("too-long name rejected", p.name == nil)
Engine.filterFails = true
tb.Text = "Carter Dogs"
Engine.press(Engine.findButton(dlg, "^Save$"))
task.wait(2.3)
check("filter outage fails closed", p.name == nil)
Engine.filterFails = false
Engine.press(Engine.findButton(dlg, "^Save$"))
task.wait(0.6)
check("good name saved and shown on plot sign", p.name == "Carter Dogs" and plot.Decor.PlotSign.Sign.SurfaceGui.Text.Text == "Carter Dogs")

-- Phone -------------------------------------------------------------------------------------
p.cash = BigNum.new(1e6)
send("buyPad", "biz:stand")
p.robux.tiers.remoteBuy = 1
send("buyPad", "stand:register")
session.rt.phoneNext = os.time() -- SETUP: offer now
local phoneGui = pg.Phone
waitFor(function()
	return session.rt.offer
end, 4)
check("phone offer arrives", session.rt.offer ~= nil)
local raised = false
for _ = 1, 5 do
	if not session.rt.offer then
		break
	end
	Engine.press(Engine.findButton(phoneGui, "Raise|Push it") or Engine.findButton(phoneGui, "^Raise$") or Engine.findButton(phoneGui, "^Push it$"))
	task.wait(0.5)
	raised = true
end
check("raise flow ends in a better/final offer or a walk-away without errors", raised and #Engine.errors == 0)
session.rt.offer = nil
session.rt.phoneNext = os.time()
waitFor(function()
	return session.rt.offer
end, 4)
local offerAmount = session.rt.offer and BigNum.toNumber(session.rt.offer.amount)
local deals0 = p.stats.deals or 0
local paid = 0
local conn = Engine.onClientEvent
Engine.onClientEvent = function(name, _, kind, data)
	if name == "Notify" and kind == "cash" and data.source == "deal" then
		paid += BigNum.toNumber(data.amount)
	end
end
Engine.press(Engine.findButton(phoneGui, "^Accept$"))
task.wait(0.3)
Engine.press(Engine.findButton(phoneGui, "^Accept$") or phoneGui)
task.wait(0.4)
Engine.onClientEvent = conn
check("accepting pays the offered amount once", offerAmount and paid == offerAmount and (p.stats.deals or 0) == deals0 + 1 and session.rt.offer == nil, offerAmount and Format.cash(offerAmount) or "no offer")

-- DogDash -----------------------------------------------------------------------------------
send("dashStart", 1, 1)
check("DogDash locked without the game pad", session.rt.race == nil)
p.cash = BigNum.new(1e9)
send("buyPad", "biz:dash")
send("buyPad", "dash:dashgame")
task.wait(1.1) -- dashStart is rate limited to once per second
Engine.press(Engine.findButton(hud, "DogDash"))
task.wait(0.2)
local dashGui = pg.DogDash
c0 = cash()
Engine.press(Engine.findButton(dashGui, "Start race"))
task.wait(0.3)
local race = session.rt.race
check("race starts and takes a 10% bet", race ~= nil and math.abs(BigNum.toNumber(race.bet) - c0 * 0.1) / (c0 * 0.1) < 0.01, race and Format.cash(race.bet) or "no race")
for _ = 1, 30 do
	Engine.press(Engine.findButton(dashGui, "CHEER"))
	task.wait(0.09)
end
waitFor(function()
	return session.rt.race == nil
end, 15)
check("race finishes and settles", session.rt.race == nil and p.stats.races == 1)

-- Studio dev hook (fast-forward used by docs/STUDIO_TEST_PLAN.md)
local hook = dm:GetService("ServerStorage"):FindFirstChild("SHDDev")
check("Studio dev hook exists", hook ~= nil)
if hook then
	hook:Invoke("cash", 3, 5)
	check("dev hook sets cash", math.abs(cash() - 3e5) < 1e-6, Format.cash(p.cash))
end

-- Save, leave, offline income, rejoin --------------------------------------------------------
-- leave in the middle of a race: it is settled before the final save
task.wait(31) -- DogDash cooldown (placeholder 30 s)
local races0 = p.stats.races or 0
Action:FireServer("dashStart", 2, 3)
task.wait(0.3)
check("second race running before leaving", session.rt.race ~= nil)
p.lifetime = BigNum.new(77e21 * 400) -- SETUP: investors on offer, so only the race blocks it
Action:FireServer("rebirth")
task.wait(0.3)
check("prestige refused while a race is running", (p.stats.rebirths or 0) == 1 and p.pads["biz:stand"] == true)
Engine.removePlayer(player)
task.wait(0.5)
local raw = Store._mockRaw(1001)
check("profile saved on leave", raw ~= nil)
local HttpService = server.game:GetService("HttpService")
local stored = HttpService:JSONDecode(raw)
check("race in progress at leave is settled and saved", stored.data.stats.races == races0 + 1)
check("plot released and attribute cleared", player:GetAttribute("Plot") == nil and plot.Decor.PlotSign.Sign.SurfaceGui.Text.Text == "Open plot")
local cashAtLeave = BigNum.toNumber(BigNum.sanitize(stored.data.cash))
stored.data.lastSeen -= 3600 -- SETUP: pretend an hour passed
Store._mockPut(1001, HttpService:JSONEncode(stored))
player = Engine.addPlayer(dm, "Carter", 1001)
Engine.localPlayer = player
session = waitFor(function()
	return Data.get(player)
end)
p = session.profile
local pending = BigNum.toNumber(p.pendingOffline)
check("rejoin restores progress", session ~= nil and math.abs(cash() - cashAtLeave) / cashAtLeave < 1e-9 and p.ascensions == 1 and p.name == "Carter Dogs")
check("offline income banked for the claim popup (automated businesses only)", pending > 0, Format.cash(p.pendingOffline))
local G2 = server.require(rs.Shared.Logic.Game)
local expected = BigNum.toNumber(G2.incomeRate(p, true)) * 3600
check("offline amount = 100% of automated income x elapsed", math.abs(pending - expected) / expected < 0.01, string.format("%s vs %s", Format.cash(pending), Format.cash(expected)))
c0 = cash()
Action:FireServer("claimOffline")
task.wait(0.3)
Action:FireServer("claimOffline")
task.wait(0.6)
check("offline claim pays once", cash() - c0 >= pending and cash() - c0 < pending * 1.5 and p.pendingOffline.m == 0, string.format("gained %s, pending was %s", Format.cash(cash() - c0), Format.cash(pending)))

-- failed load must not overwrite ---------------------------------------------------------------
Engine.removePlayer(player)
task.wait(0.5)
local goodRaw = Store._mockRaw(1001)
dm:GetService("Workspace"):SetAttribute("SHD_FailLoads", 5)
player = Engine.addPlayer(dm, "Carter", 1001)
Engine.localPlayer = player
session = waitFor(function()
	return Data.get(player)
end, 8)
check("failed load gives temporary profile with saving off", session ~= nil and session.canSave == false)
Engine.removePlayer(player)
task.wait(0.5)
check("failed-load session never overwrites the stored save", Store._mockRaw(1001) == goodRaw)
dm:GetService("Workspace"):SetAttribute("SHD_FailLoads", 0)

-- failed save keeps the old save -----------------------------------------------------------------
player = Engine.addPlayer(dm, "Carter", 1001)
Engine.localPlayer = player
session = waitFor(function()
	return Data.get(player)
end)
session.profile.cash = BigNum.new(42)
dm:GetService("Workspace"):SetAttribute("SHD_FailSaves", 1)
Engine.removePlayer(player)
task.wait(0.5)
check("failed save on leave leaves previous save intact", Store._mockRaw(1001) == goodRaw)

-- two players, separate plots ---------------------------------------------------------------------
local a = Engine.addPlayer(dm, "Carter", 1001)
local b = Engine.addPlayer(dm, "Friend", 2002)
local sa = waitFor(function()
	return Data.get(a)
end)
local sb = waitFor(function()
	return Data.get(b)
end)
check("two players get different plots", sa and sb and a:GetAttribute("Plot") ~= b:GetAttribute("Plot"))
check("new player starts fresh while returning player keeps progress", sb and BigNum.toNumber(sb.profile.cash) == 1 and sa.profile.ascensions == 1)

end
local okMain, mainErr = pcall(main)
if not okMain then
	check("test script ran to the end", false, tostring(mainErr))
end

-- report ----------------------------------------------------------------------------------------------
local passed, failed = 0, 0
for _, r in results do
	if r.ok then
		passed += 1
	else
		failed += 1
	end
end
local lines = {
	"# Headless smoke test (Lune) results",
	"",
	"Place: `" .. placePath .. "`. Runner: `lune run tools/smoke/smoke.luau` (Lune " .. "0.10.4" .. ").",
	"This drives the real server and client scripts from the built place with a simulated engine (signals, remotes, players). It is not a Roblox Studio playtest: no physics, rendering, real touch or network.",
	"",
	string.format("**%d passed, %d failed, %d script errors**", passed, failed, #Engine.errors),
	"",
	"| # | check | result | detail |",
	"|---|---|---|---|",
}
for i, r in results do
	table.insert(lines, string.format("| %d | %s | %s | %s |", i, r.name, if r.ok then "PASS" else "FAIL", (r.detail or ""):gsub("|", "/")))
end
if #Engine.errors > 0 then
	table.insert(lines, "")
	table.insert(lines, "## Script errors")
	for _, e in Engine.errors do
		table.insert(lines, "- " .. e:gsub("\n", " "))
	end
end
fs.writeDir("docs/evidence")
fs.writeFile("docs/evidence/smoke_report.md", table.concat(lines, "\n") .. "\n")
fs.writeFile("docs/evidence/smoke_log.txt", table.concat(Engine.log, "\n") .. "\n")
print(string.format("\n%d passed, %d failed, %d script errors", passed, failed, #Engine.errors))
process.exit(if failed == 0 and #Engine.errors == 0 then 0 else 1)
