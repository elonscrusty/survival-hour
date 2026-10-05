--!strict
-- Renders every player's equipped pets locally from the replicated `Pets`
-- player attribute. Pets follow their owner in a neat formation with a soft
-- hover, and fly to the breakable named by the owner's `Target` attribute,
-- hopping and lunging around it. One RenderStepped loop moves them all;
-- models are pooled so equipping/unequipping doesn't rebuild them.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local State = require("../Core/State")
local ModelCache = require("../Core/ModelCache")
local Breakables = require("../Core/Breakables")

local PetRenderer = {}

type Follower = {
	Uid: string,
	Key: string,
	Variant: string,
	Model: Model,
	Pos: Vector3,
	Yaw: number,
	Phase: number,
	Rainbow: { { Part: BasePart, Color: Color3 } }?,
}

type Owner = {
	Player: Player,
	Raw: string,
	Followers: { Follower },
	Conns: { RBXScriptConnection },
}

local localPlayer = Players.LocalPlayer
local folder: Folder
local owners: { [Player]: Owner } = {}
local pool: { [string]: { Model } } = {}

local SPACING = 4.6
local PER_ROW = 4
local CULL_DISTANCE = 320
local HOVER = 0.7
local POOL_PER_KEY = 4 -- spare models kept per pet look; extras are destroyed

local function hideOthers(): boolean
	return State.Setting("HideOthersPets", false) == true
end

local function acquire(petId: string, variant: string, shiny: boolean): Model
	local key = ModelCache.PetKey(petId, variant, shiny)
	local list = pool[key]
	if list and #list > 0 then
		return table.remove(list) :: Model
	end
	local m = ModelCache.Pet(petId, variant, shiny)
	if variant == "Golden" then
		local root = m.PrimaryPart
		if root and not root:FindFirstChildOfClass("PointLight") then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 210, 90)
			light.Brightness = 0.9
			light.Range = 7
			light.Parent = root
		end
	end
	return m
end

local function release(f: Follower)
	f.Model.Parent = nil
	if f.Rainbow then
		-- restore the authored colours before pooling
		for _, entry in f.Rainbow do
			entry.Part.Color = entry.Color
		end
	end
	local list = pool[f.Key]
	if not list then
		list = {}
		pool[f.Key] = list
	end
	local l = list :: { Model }
	if #l >= POOL_PER_KEY then
		f.Model:Destroy()
		return
	end
	table.insert(l, f.Model)
end

type Entry = { Uid: string, Id: string, Variant: string, Shiny: boolean }

local function parse(raw: any): { Entry }
	local out: { Entry } = {}
	if type(raw) ~= "string" or raw == "" then
		return out
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or type(decoded) ~= "table" then
		return out
	end
	for _, e in decoded do
		if type(e) == "table" and type(e.Id) == "string" then
			table.insert(out, {
				Uid = tostring(e.Uid or e.Id),
				Id = e.Id,
				Variant = if type(e.Variant) == "string" then e.Variant else "Normal",
				Shiny = e.Shiny == true,
			})
		end
		if #out >= 16 then
			break
		end
	end
	return out
end

local function rootOf(p: Player): BasePart?
	local char = p.Character
	if not char then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function rebuild(o: Owner)
	local raw = o.Player:GetAttribute("Pets")
	local entries: { Entry } = {}
	if o.Player == localPlayer or not hideOthers() then
		entries = parse(raw)
	end
	o.Raw = if type(raw) == "string" then raw else ""
	-- keep followers whose uid and look are unchanged
	local keep: { [string]: Follower } = {}
	for _, f in o.Followers do
		keep[f.Uid .. "#" .. f.Key] = f
	end
	local root = rootOf(o.Player)
	local start = if root then root.Position else Vector3.zero
	local list: { Follower } = {}
	for i, e in entries do
		local key = ModelCache.PetKey(e.Id, e.Variant, e.Shiny)
		local f = keep[e.Uid .. "#" .. key]
		if f then
			keep[e.Uid .. "#" .. key] = nil
		else
			local m = acquire(e.Id, e.Variant, e.Shiny)
			local nf: Follower = {
				Uid = e.Uid,
				Key = key,
				Variant = e.Variant,
				Model = m,
				Pos = start + Vector3.new(math.random() * 2 - 1, 1, math.random() * 2 - 1),
				Yaw = 0,
				Phase = (i - 1) * 1.7 + math.random() * 0.5,
				Rainbow = nil,
			}
			if e.Variant == "Rainbow" then
				local parts = {}
				for _, d in m:GetDescendants() do
					if d:IsA("BasePart") and d.Transparency < 1 then
						table.insert(parts, { Part = d, Color = d.Color })
					end
				end
				nf.Rainbow = parts
			end
			m.Parent = folder
			f = nf
		end
		table.insert(list, f :: Follower)
	end
	for _, f in keep do
		release(f)
	end
	o.Followers = list
end

local function track(p: Player)
	if owners[p] then
		return
	end
	local o: Owner = { Player = p, Raw = "", Followers = {}, Conns = {} }
	owners[p] = o
	table.insert(o.Conns, p:GetAttributeChangedSignal("Pets"):Connect(function()
		rebuild(o)
	end))
	rebuild(o)
end

local function untrack(p: Player)
	local o = owners[p]
	if not o then
		return
	end
	owners[p] = nil
	for _, c in o.Conns do
		c:Disconnect()
	end
	for _, f in o.Followers do
		release(f)
	end
end

local function angleLerp(a: number, b: number, t: number): number
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + d * t
end

local rainbowClock = 0

local function step(dt: number)
	local now = os.clock()
	local cam = Workspace.CurrentCamera
	local camPos = if cam then cam.CFrame.Position else Vector3.zero
	local alpha = 1 - math.exp(-dt * 7)
	local turn = 1 - math.exp(-dt * 10)
	rainbowClock += dt
	local doRainbow = rainbowClock > 0.08
	if doRainbow then
		rainbowClock = 0
	end
	for p, o in owners do
		local root = rootOf(p)
		local n = #o.Followers
		if n == 0 then
			continue
		end
		if not root or (root.Position - camPos).Magnitude > CULL_DISTANCE then
			for _, f in o.Followers do
				if f.Model.Parent ~= nil then
					f.Model.Parent = nil
				end
			end
			continue
		end
		local rootPos = root.Position
		local hum = (root.Parent :: Instance):FindFirstChildOfClass("Humanoid")
		local groundY = rootPos.Y - (if hum then hum.HipHeight else 2) - root.Size.Y / 2
		local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		if look.Magnitude < 0.01 then
			look = Vector3.new(0, 0, -1)
		end
		look = look.Unit
		local flat = CFrame.lookAt(Vector3.new(rootPos.X, groundY, rootPos.Z), Vector3.new(rootPos.X, groundY, rootPos.Z) + look)
		local targetId = p:GetAttribute("Target")
		local info = if type(targetId) == "string" then Breakables.Get(targetId) else nil
		if info and (info.Center - rootPos).Magnitude > 200 then
			info = nil
		end
		local rows = math.ceil(n / PER_ROW)
		for i, f in o.Followers do
			local goal: Vector3
			local faceDir: Vector3?
			if info then
				-- circle the breakable, hopping and lunging in
				local radius = math.max(info.Size.X, info.Size.Z) / 2 + 2.2
				local ang = (i - 1) / n * math.pi * 2 + now * 0.25
				local lunge = math.max(0, math.sin(now * 5 + f.Phase)) * 1.4
				local r = radius - lunge
				local hop = math.abs(math.sin(now * 5 + f.Phase)) * 1.8
				goal = Vector3.new(info.Center.X + math.cos(ang) * r, info.Bottom + 0.2 + hop, info.Center.Z + math.sin(ang) * r)
				faceDir = Vector3.new(info.Center.X - goal.X, 0, info.Center.Z - goal.Z)
			else
				local row = (i - 1) // PER_ROW
				local inRow = if row < rows - 1 then PER_ROW else n - row * PER_ROW
				local col = (i - 1) % PER_ROW
				local x = (col - (inRow - 1) / 2) * SPACING
				local z = 5 + row * SPACING + math.abs(x) * 0.25 -- slight V shape
				local base = flat:PointToWorldSpace(Vector3.new(x, 0, z))
				goal = Vector3.new(base.X, groundY + HOVER + math.sin(now * 2.4 + f.Phase) * 0.35, base.Z)
			end
			local dist = (goal - f.Pos).Magnitude
			local prev = f.Pos
			if dist > 90 then
				f.Pos = goal
			else
				f.Pos = f.Pos:Lerp(goal, alpha)
			end
			local moved = f.Pos - prev
			local dir: Vector3
			if faceDir and faceDir.Magnitude > 0.05 then
				dir = faceDir
			elseif Vector3.new(moved.X, 0, moved.Z).Magnitude > dt * 3 then
				dir = Vector3.new(moved.X, 0, moved.Z)
			else
				dir = look
			end
			local yaw = math.atan2(-dir.X, -dir.Z)
			f.Yaw = angleLerp(f.Yaw, yaw, turn)
			if f.Model.Parent ~= folder then
				f.Model.Parent = folder
			end
			f.Model:PivotTo(CFrame.new(f.Pos) * CFrame.Angles(0, f.Yaw, 0))
			if doRainbow and f.Rainbow then
				for k, entry in f.Rainbow do
					local hue = (now * 0.25 + k * 0.07) % 1
					entry.Part.Color = entry.Color:Lerp(Color3.fromHSV(hue, 0.65, 1), 0.45)
				end
			end
		end
	end
end

function PetRenderer.Init()
	local f = Instance.new("Folder")
	f.Name = "ClientPets"
	f.Parent = Workspace
	folder = f
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(untrack)
	for _, p in Players:GetPlayers() do
		track(p)
	end
	-- re-evaluate everyone when HideOthersPets flips
	local lastHide = hideOthers()
	State.Changed:Connect(function()
		local h = hideOthers()
		if h ~= lastHide then
			lastHide = h
			for _, o in owners do
				rebuild(o)
			end
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return PetRenderer
