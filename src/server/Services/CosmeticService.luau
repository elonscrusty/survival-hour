--!nonstrict
-- Applies worn cosmetics (Shared/Cosmetics). Purely visual — nothing here
-- changes stats, hitboxes or visibility in a way that helps in a fight:
--   Outfit        body colours (torso / limbs)
--   Nameplate     coloured plate behind the title/level tag over your head
--   Title         text on that tag
--   ToolSkin      coloured grip wrap on every held tool/weapon
--   BackpackSkin  colour of the worn pack shell
--   CampfireSkin  flame / light colour of your camp fire
--   WorkbenchSkin coloured plate on your workbench
--   StorageSkin   coloured crest on storage you place
--   Emote         lobby emote (pose + particle burst)
--   EliminationFx burst where you eliminate someone
--   VictoryPose   pose on the end screen when you win

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))

local CosmeticService = {}

local ctx: any
local lastEmote: { [Player]: number } = {}

local function rgb(c: { number }?): Color3?
	return if c then Color3.fromRGB(c[1], c[2], c[3]) else nil
end

-- Worn cosmetic def of a type (validated against ownership), or nil.
function CosmeticService.Worn(p: Player, typ: string): Cosmetics.Def?
	local session = ctx.DataService.Get(p)
	local profile = session and session.Profile
	local id = profile and profile.Wearing[typ]
	local def = id and Cosmetics.ById[id]
	return if def and def.Type == typ and profile.Cosmetics[id] then def else nil
end

function CosmeticService.Init(c)
	ctx = c
	ctx.Util.OnPlayerAdded(function(p: Player)
		p.CharacterAdded:Connect(function(char)
			task.wait(0.5)
			if char.Parent then
				CosmeticService.Apply(p)
			end
		end)
	end)
	ctx.Util.OnPlayerRemoving(function(p)
		lastEmote[p] = nil
	end)
	-- Premium members get a gold star on their tag (cosmetic only; Roblox pays
	-- Premium Payouts for their playtime automatically).
	Players.PlayerMembershipChanged:Connect(function(p: Player)
		CosmeticService.Apply(p)
	end)
	ctx.MatchService.On("PlayerJoinedMatch", function(p: Player)
		task.delay(2, function()
			CosmeticService._applyCamp(p)
		end)
	end)
end

-- Re-applies everything visible on the character (safe to call repeatedly).
function CosmeticService.Apply(p: Player)
	local char = p.Character
	local outfit = CosmeticService.Worn(p, "Outfit")
	local plate = CosmeticService.Worn(p, "Nameplate")
	local title = CosmeticService.Worn(p, "Title")
	local tool = CosmeticService.Worn(p, "ToolSkin")
	local pack = CosmeticService.Worn(p, "BackpackSkin")
	p:SetAttribute("Title", if title then title.Text else nil)
	p:SetAttribute("ToolSkin", rgb(tool and tool.Color))
	p:SetAttribute("PackSkin", rgb(pack and pack.Color))
	if not char then
		return
	end
	-- Outfit
	local bc = char:FindFirstChildOfClass("BodyColors")
	if outfit and outfit.Color then
		if not bc then
			bc = Instance.new("BodyColors")
			bc.Parent = char
		end
		local torso = rgb(outfit.Color) :: Color3
		local limbs = rgb(outfit.Color2) or torso
		bc.TorsoColor3 = torso
		bc.LeftArmColor3 = torso
		bc.RightArmColor3 = torso
		bc.LeftLegColor3 = limbs
		bc.RightLegColor3 = limbs
		char:SetAttribute("Outfit", outfit.Id)
	elseif char:GetAttribute("Outfit") and bc then
		bc:Destroy()
		char:SetAttribute("Outfit", nil)
	end
	-- Title / level tag
	local head = char:FindFirstChild("Head") :: BasePart?
	if head then
		local tag = head:FindFirstChild("CosmeticTag") :: BillboardGui?
		local level = p:GetAttribute("Level") or 1
		if not tag then
			tag = Instance.new("BillboardGui")
			tag.Name = "CosmeticTag"
			tag.Size = UDim2.fromOffset(150, 20)
			tag.StudsOffset = Vector3.new(0, 3.4, 0)
			tag.MaxDistance = 45
			tag.LightInfluence = 0
			tag.Parent = head
			local label = Instance.new("TextLabel")
			label.Name = "Text"
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.TextScaled = true
			label.Font = Enum.Font.GothamBold
			label.TextColor3 = Color3.new(1, 1, 1)
			label.TextStrokeTransparency = 0.4
			label.AutoLocalize = false -- titles and levels stay as written
			label.Parent = tag
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 6)
			corner.Parent = label
		end
		local label = (tag :: BillboardGui):FindFirstChild("Text") :: TextLabel
		local premium = p.MembershipType == Enum.MembershipType.Premium
		label.Text = (if premium then "★ " else "") .. (if title then title.Text .. " · " else "") .. "Lv " .. tostring(level)
		label.TextColor3 = if premium then Color3.fromRGB(255, 220, 120) else Color3.new(1, 1, 1)
		label.BackgroundColor3 = rgb(plate and plate.Color) or Color3.fromRGB(30, 30, 30)
		label.BackgroundTransparency = if plate then 0.15 else 0.7
	end
	-- Held tool wrap refresh
	local held = char:FindFirstChild("HeldItem")
	if held then
		CosmeticService.DressHeld(p, held :: Model)
	end
	if ctx.InventoryService.Get(p) then
		ctx.InventoryService._refreshHeld(p) -- backpack tint
	end
end

-- Adds a coloured grip wrap to a freshly created held-item model.
function CosmeticService.DressHeld(p: Player, model: Model)
	local color = p:GetAttribute("ToolSkin") :: Color3?
	local old = model:FindFirstChild("SkinWrap")
	if old then
		old:Destroy()
	end
	local handle = model.PrimaryPart
	if not color or not handle then
		return
	end
	local wrap = Instance.new("Part")
	wrap.Name = "SkinWrap"
	wrap.Size = Vector3.new(0.34, 0.5, 0.34)
	wrap.Color = color
	wrap.Material = Enum.Material.Fabric
	wrap.CanCollide = false
	wrap.CanQuery = false
	wrap.CanTouch = false
	wrap.Massless = true
	wrap.CFrame = handle.CFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = wrap
	weld.Parent = wrap
	wrap.Parent = model
end

-- Campfire flame colour + workbench plate for the player's own camp.
function CosmeticService._applyCamp(p: Player)
	local camp = ctx.CampService.GetCamp(ctx.Util.Team(p))
	if not camp then
		return
	end
	local fire = CosmeticService.Worn(p, "CampfireSkin")
	if fire and camp.Fire then
		local c1, c2 = rgb(fire.Color) :: Color3, rgb(fire.Color2) or rgb(fire.Color) :: Color3
		for _, d in camp.Fire:GetDescendants() do
			if d:IsA("Fire") then
				d.Color = c1
				d.SecondaryColor = c2
			elseif d:IsA("PointLight") then
				d.Color = c1
			elseif d:IsA("ParticleEmitter") and d.Name ~= "Smoke" then
				d.Color = ColorSequence.new(c2, c1)
			end
		end
		camp.Fire:SetAttribute("FlameSkin", fire.Id)
	end
	local bench = CosmeticService.Worn(p, "WorkbenchSkin")
	if bench and camp.Workbench then
		CosmeticService._plate(camp.Workbench, rgb(bench.Color) :: Color3, "BenchPlate")
	end
end

-- Workbench upgrades rebuild the model: re-apply.
function CosmeticService.OnWorkbenchRebuilt(team: number)
	for _, p in ctx.Util.TeamPlayers(team) do
		local bench = CosmeticService.Worn(p, "WorkbenchSkin")
		local camp = ctx.CampService.GetCamp(team)
		if bench and camp and camp.Workbench then
			CosmeticService._plate(camp.Workbench, rgb(bench.Color) :: Color3, "BenchPlate")
		end
	end
end

-- Storage the player places gets their crest.
function CosmeticService.OnStructurePlaced(p: Player, model: Model, kind: string?)
	if kind ~= "Storage" then
		return
	end
	local crest = CosmeticService.Worn(p, "StorageSkin")
	if crest then
		CosmeticService._plate(model, rgb(crest.Color) :: Color3, "Crest")
	end
end

function CosmeticService._plate(model: Model, color: Color3, name: string)
	local old = model:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local cf, size = model:GetBoundingBox()
	local plate = Instance.new("Part")
	plate.Name = name
	plate.Anchored = true
	plate.CanCollide = false
	plate.CanQuery = false
	plate.CanTouch = false
	plate.Size = Vector3.new(math.min(1.6, size.X * 0.4), 0.8, 0.12)
	plate.Color = color
	plate.Material = Enum.Material.Metal
	-- front face (local -Z), a little above the middle
	plate.CFrame = cf * CFrame.new(0, size.Y * 0.1, -size.Z / 2 - 0.07)
	plate.Parent = model
end

-- Lobby emote: short pose + burst in the emote's colour.
function CosmeticService.Emote(p: Player, id: string)
	local session = ctx.DataService.Get(p)
	local def = Cosmetics.ById[id]
	if not session or not def or def.Type ~= "Emote" or not session.Profile.Cosmetics[id] then
		return
	end
	local t = os.clock()
	if t - (lastEmote[p] or 0) < 3 then
		return
	end
	lastEmote[p] = t
	local char = p.Character
	local root = ctx.Util.Root(p)
	if not char or not root then
		return
	end
	char:SetAttribute("Action", "Emote")
	char:SetAttribute("ActionAt", workspace:GetServerTimeNow())
	char:SetAttribute("ActionItem", id)
	Net.FireAll("Fx", "Cosmetic", { Pos = root.Position + Vector3.new(0, 2, 0), Color = rgb(def.Color) or Color3.new(1, 1, 1), Count = 20 })
end

function CosmeticService.OnElimination(killer: Player, victim: Player)
	local fx = CosmeticService.Worn(killer, "EliminationFx")
	local root = ctx.Util.Root(victim)
	if fx and root then
		Net.FireAll("Fx", "Cosmetic", { Pos = root.Position, Color = rgb(fx.Color) or Color3.new(1, 1, 1), Count = 45 })
	end
end

function CosmeticService.OnVictory(p: Player)
	local pose = CosmeticService.Worn(p, "VictoryPose")
	local char = p.Character
	if char then
		char:SetAttribute("Action", "Victory")
		char:SetAttribute("ActionAt", workspace:GetServerTimeNow())
		char:SetAttribute("ActionItem", if pose then pose.Id else "")
	end
	local root = ctx.Util.Root(p)
	if root then
		Net.FireAll("Fx", "Cosmetic", { Pos = root.Position + Vector3.new(0, 3, 0), Color = Color3.fromRGB(255, 215, 90), Count = 40 })
	end
end

return CosmeticService
