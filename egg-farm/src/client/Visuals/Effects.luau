--!strict
-- Small, bounded effects for the local player's own farm:
--   Collected / Deposited  egg burst + floating "+N eggs" at the ring
--   Sold                   floating "+$X" over the vehicle's dock bay
--   Purchased              a puff at whatever was bought (house, bay, worker start, silo)
--   ring pulse             when standing in a ring that has something to do right now
--   "FULL" bubble          over houses whose stored eggs reached their storage
-- Bursts, texts and puffs honour settings.effects; the pulse and FULL bubble are gameplay hints
-- and always show. Every effect is pooled or destroyed when it ends; counts are capped.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local Kit = require(Shared:WaitForChild("Models"):WaitForChild("Kit"))

local Effects = {}

local MAX_EGGS = 48
local MAX_TEXTS = 10
local MAX_PUFFS = 6
local GRAVITY = Vector3.new(0, -60, 0)

type Egg = { part: BasePart, vel: Vector3, age: number, life: number }
type Text = { part: BasePart, gui: BillboardGui, label: TextLabel, age: number, life: number }
type Puff = { parts: { BasePart }, age: number, life: number, size: number }

local ctx: any = nil
local own: any = nil
local unsubs: { () -> () } = {}
local eggs: { Egg } = {}
local eggPool: { BasePart } = {}
local texts: { Text } = {}
local puffs: { Puff } = {}
local pulses: { [string]: BasePart } = {}
local bubbles: { [number]: BillboardGui } = {}
local rng = Random.new()
local pulseClock = 0
local checkAcc = 0
local activeRings: { [string]: BasePart } = {}

-- ------------------------------------------------------------------ lookups on the own plot
local function child(root: Instance?, ...: string): Instance?
	local cur = root
	for _, name in { ... } do
		if not cur then
			return nil
		end
		cur = cur:FindFirstChild(name)
	end
	return cur
end

local function ringOf(slot: number): BasePart?
	local r = own and child(own.plot, "Houses", "House" .. slot, "CollectRing")
	return if r and r:IsA("BasePart") then r else nil
end

local function depositRing(): BasePart?
	local r = own and child(own.plot, "Warehouse", "DepositRing")
	return if r and r:IsA("BasePart") then r else nil
end

local function posOf(inst: Instance?): Vector3?
	if not inst then
		return nil
	end
	if inst:IsA("BasePart") then
		return inst.Position
	elseif inst:IsA("Model") then
		return inst:GetPivot().Position
	end
	return nil
end

local function accentOf(ring: BasePart?): Color3
	local glow = ring and ring:FindFirstChild("Glow")
	if glow and glow:IsA("BasePart") then
		return glow.Color
	end
	return Color3.fromRGB(255, 214, 74)
end

-- ------------------------------------------------------------------ primitives
local function burst(at: Vector3, count: number)
	if not ctx or not ctx.effects then
		return
	end
	for _ = 1, count do
		if #eggs >= MAX_EGGS then
			return
		end
		local part = table.remove(eggPool)
		if not part then
			part = Kit.Egg(nil, CFrame.identity, Vector3.new(0.7, 0.95, 0.7), { name = "EggFx", color = Kit.Fixed.cream, collide = false, shadow = false })
		end
		assert(part)
		part.Transparency = 0
		part.CFrame = CFrame.new(at + Vector3.new(0, 1, 0))
		part.Parent = ctx.container
		local a = rng:NextNumber() * math.pi * 2
		local out = 4 + rng:NextNumber() * 6
		table.insert(eggs, {
			part = part,
			vel = Vector3.new(math.cos(a) * out, 16 + rng:NextNumber() * 8, math.sin(a) * out),
			age = 0,
			life = 0.8 + rng:NextNumber() * 0.3,
		})
	end
end

local function floatText(at: Vector3, text: string, color: Color3)
	if not ctx or not ctx.effects then
		return
	end
	if #texts >= MAX_TEXTS then
		local oldest = table.remove(texts, 1) :: Text
		oldest.part:Destroy()
	end
	local part = Kit.Part(ctx.container, {
		name = "TextFx",
		size = Vector3.new(0.2, 0.2, 0.2),
		cf = CFrame.new(at + Vector3.new(0, 4, 0)),
		transparency = 1,
		collide = false,
		shadow = false,
	})
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 56)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 250
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(40, 30, 20)
	label.Parent = gui
	table.insert(texts, { part = part, gui = gui, label = label, age = 0, life = 1.4 })
end

local function puff(at: Vector3, size: number, color: Color3)
	if not ctx or not ctx.effects or #puffs >= MAX_PUFFS then
		return
	end
	local parts = {}
	for i = 1, 3 do
		local off = Vector3.new(rng:NextNumber() - 0.5, rng:NextNumber() * 0.5, rng:NextNumber() - 0.5) * size
		parts[i] = Kit.Part(ctx.container, {
			name = "PuffFx",
			size = Vector3.one,
			cf = CFrame.new(at + off),
			shape = "Ball",
			color = if i == 1 then color else Color3.new(1, 1, 1),
			transparency = 0.3,
			collide = false,
			shadow = false,
		})
	end
	table.insert(puffs, { parts = parts, age = 0, life = 0.6, size = size })
end

-- ------------------------------------------------------------------ farm events
local function onCollected(data: any)
	local slot = type(data) == "table" and tonumber(data.slot) or nil
	local ring = slot and ringOf(slot)
	if not ring then
		return
	end
	local amount = tonumber(data.amount) or 0
	burst(ring.Position, math.clamp(math.floor(math.log10(math.max(amount, 1)) + 3), 3, 7))
	floatText(ring.Position, "+" .. Format.Short(amount) .. " eggs", Color3.fromRGB(255, 246, 210))
end

local function onDeposited(data: any)
	local ring = depositRing()
	if not ring then
		return
	end
	local amount = type(data) == "table" and tonumber(data.amount) or 0
	burst(ring.Position, 6)
	floatText(ring.Position, "+" .. Format.Short(amount or 0) .. " stored", Color3.fromRGB(255, 236, 140))
end

local function onSold(data: any)
	local slot = type(data) == "table" and tonumber(data.slot) or 1
	local bay = own and child(own.plot, "Dock", "Bay" .. tostring(slot))
	local at = posOf(bay)
	if not at then
		return
	end
	local cash = type(data) == "table" and tonumber(data.cash) or 0
	floatText(at + Vector3.new(0, 4, 0), "+" .. Format.Cash(cash or 0), Color3.fromRGB(120, 255, 130))
end

local function onPurchased(data: any)
	if type(data) ~= "table" or not own then
		return
	end
	local kind = data.kind
	local at: Vector3? = nil
	local size = 8
	if kind == "house" then
		at = posOf(child(own.plot, "Houses", "House" .. tostring(data.slot), "Building"))
		size = 16
	elseif kind == "vehicle" then
		at = posOf(child(own.plot, "Dock", "Bay" .. tostring(data.slot)))
	elseif kind == "worker" then
		at = posOf(child(own.plot, "WorkerPath", "Start"))
	elseif kind == "silo" then
		at = posOf(child(own.plot, "Silos", "Silo" .. tostring(data.count)))
		if at then
			at += Vector3.new(0, 8, 0)
		end
	end
	if not at then
		local char = Players.LocalPlayer.Character
		at = char and posOf(char)
	end
	if at then
		puff(at + Vector3.new(0, 3, 0), size, accentOf(ringOf(1)))
	end
end

-- ------------------------------------------------------------------ FULL bubbles
local function setBubble(slot: number, show: boolean)
	local b = bubbles[slot]
	if not show then
		if b then
			b.Enabled = false
		end
		return
	end
	local ring = ringOf(slot)
	if not ring then
		return
	end
	if not b then
		local gui = Instance.new("BillboardGui")
		gui.Name = "FullBubble" .. slot
		gui.Size = UDim2.fromOffset(110, 46)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 220
		gui.ResetOnSpawn = false
		local frame = Instance.new("TextLabel")
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromRGB(230, 60, 50)
		frame.Font = Enum.Font.FredokaOne
		frame.Text = "FULL"
		frame.TextScaled = true
		frame.TextColor3 = Color3.new(1, 1, 1)
		frame.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = Color3.new(1, 1, 1)
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = frame
		local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		gui.Parent = pg
		bubbles[slot] = gui
		b = gui
	end
	assert(b)
	b.Adornee = ring
	b.Enabled = true
end

function Effects.OnSnapshot(snap: any)
	if not snap or type(snap.housing) ~= "table" then
		return
	end
	for slot = 1, 4 do
		local h = snap.housing[slot]
		local full = h ~= nil and (h.tier or 0) > 0 and (h.storage or 0) > 0 and (h.eggs or 0) >= h.storage
		setBubble(slot, full and own ~= nil)
	end
end

-- ------------------------------------------------------------------ ring pulse
local function pulsePart(key: string): BasePart
	local p = pulses[key]
	if not p then
		p = Kit.Part(nil, {
			name = "RingPulse",
			size = Vector3.new(0.1, 14, 14),
			cf = CFrame.identity,
			shape = "Cylinder",
			material = Enum.Material.Neon,
			transparency = 0.5,
			collide = false,
			shadow = false,
		})
		pulses[key] = p
	end
	assert(p)
	return p
end

local function checkRings()
	table.clear(activeRings)
	local snap = ctx and ctx.snapshot
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not own or not snap or not root or not root:IsA("BasePart") then
		return
	end
	local pos = root.Position
	local function inside(ring: BasePart): boolean
		local rel = ring.CFrame:PointToObjectSpace(pos)
		local r = math.max(ring.Size.X, ring.Size.Z) / 2 + 1
		return rel.X * rel.X + rel.Z * rel.Z <= r * r and math.abs(rel.Y) < 9
	end
	local carried = tonumber(snap.carried) or 0
	local cap = tonumber(snap.carryCap) or math.huge
	if type(snap.housing) == "table" and carried < cap then
		for slot = 1, 4 do
			local h = snap.housing[slot]
			local ring = ringOf(slot)
			if h and (h.tier or 0) > 0 and (h.eggs or 0) >= 1 and ring and inside(ring) then
				activeRings["c" .. slot] = ring
			end
		end
	end
	local dep = depositRing()
	if carried > 0 and dep and inside(dep) then
		activeRings.d = dep
	end
end

-- ------------------------------------------------------------------ lifecycle
function Effects.Init(c: any)
	ctx = c
	local Store = c.Store
	table.insert(unsubs, Store.OnEvent("Collected", onCollected))
	table.insert(unsubs, Store.OnEvent("Deposited", onDeposited))
	table.insert(unsubs, Store.OnEvent("Sold", onSold))
	table.insert(unsubs, Store.OnEvent("Purchased", onPurchased))
end

function Effects.SetOwnPlot(info: any)
	own = info
	if not info then
		for slot in bubbles do
			setBubble(slot, false)
		end
		for _, p in pulses do
			p.Parent = nil
		end
	end
end

function Effects.Update(dt: number, _c: any)
	-- eggs: simple ballistic arcs, then back to the pool
	for i = #eggs, 1, -1 do
		local e = eggs[i]
		e.age += dt
		if e.age >= e.life then
			e.part.Parent = nil
			table.insert(eggPool, e.part)
			table.remove(eggs, i)
		else
			e.vel += GRAVITY * dt
			e.part.CFrame = CFrame.new(e.part.Position + e.vel * dt) * CFrame.Angles(e.age * 6, e.age * 4, 0)
			if e.life - e.age < 0.25 then
				e.part.Transparency = 1 - (e.life - e.age) / 0.25
			end
		end
	end
	for i = #texts, 1, -1 do
		local t = texts[i]
		t.age += dt
		if t.age >= t.life then
			t.part:Destroy()
			table.remove(texts, i)
		else
			local f = t.age / t.life
			t.gui.StudsOffset = Vector3.new(0, f * 4, 0)
			t.label.TextTransparency = math.max(0, (f - 0.6) / 0.4)
			t.label.TextStrokeTransparency = 0.2 + 0.8 * math.max(0, (f - 0.6) / 0.4)
		end
	end
	for i = #puffs, 1, -1 do
		local p = puffs[i]
		p.age += dt
		if p.age >= p.life then
			for _, part in p.parts do
				part:Destroy()
			end
			table.remove(puffs, i)
		else
			local f = p.age / p.life
			for _, part in p.parts do
				part.Size = Vector3.one * (p.size * (0.3 + f))
				part.Transparency = 0.3 + 0.7 * f
			end
		end
	end
	-- ring pulse (checked at 10 Hz, animated every frame)
	checkAcc += dt
	if checkAcc >= 0.1 then
		checkAcc = 0
		checkRings()
	end
	pulseClock += dt
	for key, p in pulses do
		local ring = activeRings[key]
		if ring and ctx then
			local d = math.max(ring.Size.X, ring.Size.Z)
			local s = 1 + 0.1 * math.sin(pulseClock * 7)
			p.Size = Vector3.new(0.1, d * s, d * s)
			p.CFrame = ring.CFrame * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.pi / 2)
			p.Color = accentOf(ring)
			p.Transparency = 0.35 + 0.25 * math.sin(pulseClock * 7)
			if p.Parent ~= ctx.container then
				p.Parent = ctx.container
			end
		elseif p.Parent then
			p.Parent = nil
		end
	end
	for key in activeRings do
		if not pulses[key] then
			pulsePart(key) -- shown from the next frame
		end
	end
end

function Effects.Destroy()
	for _, u in unsubs do
		u()
	end
	table.clear(unsubs)
	for _, e in eggs do
		e.part:Destroy()
	end
	table.clear(eggs)
	for _, p in eggPool do
		p:Destroy()
	end
	table.clear(eggPool)
	for _, t in texts do
		t.part:Destroy()
	end
	table.clear(texts)
	for _, p in puffs do
		for _, part in p.parts do
			part:Destroy()
		end
	end
	table.clear(puffs)
	for _, p in pulses do
		p:Destroy()
	end
	table.clear(pulses)
	for _, b in bubbles do
		b:Destroy()
	end
	table.clear(bubbles)
	own = nil
	ctx = nil
end

return Effects
