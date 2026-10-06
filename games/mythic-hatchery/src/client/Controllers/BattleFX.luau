--!strict
-- Cosmetic, action-driven battle feedback. The server remains the only battle authority.
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local BattleFX = {}
type Effect = { Folder: Folder, Connections: {RBXScriptConnection}, Tweens: {Tween}, Restores: {[Model]: CFrame}, Alive: boolean }
local palette: {[string]: Color3} = {
	Fire = Color3.fromRGB(255, 130, 64), Ice = Color3.fromRGB(115, 225, 255),
	Storm = Color3.fromRGB(250, 223, 96), Nature = Color3.fromRGB(104, 239, 151),
	Shadow = Color3.fromRGB(190, 129, 255),
}
local folder: Folder? = nil
local effects: {Effect} = {}
local battleId: string? = nil
local sequence = 0
local generation = 0

local function finish(effect: Effect)
	if not effect.Alive then return end
	effect.Alive = false
	for _, connection in effect.Connections do connection:Disconnect() end
	for _, tween in effect.Tweens do tween:Cancel() end
	for model, pivot in effect.Restores do
		if model.Parent then model:PivotTo(pivot) end
	end
	effect.Folder:Destroy()
	local index = table.find(effects, effect)
	if index then table.remove(effects, index) end
end

local function clear()
	while #effects > 0 do finish(effects[1]) end
end

local function beginEffect(): Effect
	while #effects >= 6 do finish(effects[1]) end
	local container = Instance.new("Folder")
	container.Name = "Action"
	container.Parent = folder
	local effect: Effect = {Folder = container, Connections = {}, Tweens = {}, Restores = {}, Alive = true}
	table.insert(effects, effect)
	Debris:AddItem(container, 3)
	task.delay(2.5, function() finish(effect) end)
	return effect
end

local function tween(effect: Effect, object: Instance, duration: number, properties: {[string]: any}): Tween
	local result = TweenService:Create(object, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
	table.insert(effect.Tweens, result)
	result:Play()
	return result
end

local function part(effect: Effect, color: Color3, size: Vector3, position: Vector3): Part
	local result = Instance.new("Part")
	result.Name = "BattleLight"
	result.Anchored = true
	result.CanCollide = false
	result.CanTouch = false
	result.CanQuery = false
	result.CastShadow = false
	result.Material = Enum.Material.Neon
	result.Color = color
	result.Size = size
	result.Position = position
	result.Parent = effect.Folder
	return result
end

local function burst(effect: Effect, position: Vector3, color: Color3)
	local glow = part(effect, color, Vector3.one, position)
	glow.Shape = Enum.PartType.Ball
	glow.Transparency = 0.3
	tween(effect, glow, 0.35, {Size = Vector3.one * 4.8, Transparency = 1})
	-- A thin expanding ground halo plus six short, distinct sparks.
	local halo = part(effect, color, Vector3.new(0.08, 1.5, 1.5), position - Vector3.new(0, 1, 0))
	halo.Shape = Enum.PartType.Cylinder
	halo.Orientation = Vector3.new(0, 0, 90)
	halo.Transparency = 0.55
	tween(effect, halo, 0.45, {Size = Vector3.new(0.08, 7, 7), Transparency = 1})
	for index = 1, 6 do
		local angle = index * math.pi / 3
		local direction = Vector3.new(math.cos(angle), 0.35, math.sin(angle))
		local spark = part(effect, color, Vector3.new(0.16, 0.16, 0.65), position)
		spark.CFrame = CFrame.lookAt(position, position + direction)
		tween(effect, spark, 0.3, {Position = position + direction * 3.2, Transparency = 1})
	end
end

local function popup(effect: Effect, position: Vector3, text: string, color: Color3)
	local anchor = part(effect, color, Vector3.one * 0.1, position + Vector3.new(0, 3, 0))
	anchor.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(180, 52)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 180
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 28
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.fromRGB(24, 23, 38)
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	tween(effect, anchor, 0.8, {Position = anchor.Position + Vector3.new(0, 2.5, 0)})
	task.delay(0.35, function()
		if effect.Alive then tween(effect, label, 0.45, {TextTransparency = 1, TextStrokeTransparency = 1}) end
	end)
end

local function flash(effect: Effect, model: Model, color: Color3)
	local highlight = Instance.new("Highlight")
	highlight.Adornee = model
	highlight.FillColor = color
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = effect.Folder
	tween(effect, highlight, 0.35, {FillTransparency = 1})
end

local function moveModel(effect: Effect, model: Model, target: CFrame, duration: number)
	if not model.Parent then return end
	local value = Instance.new("CFrameValue")
	value.Value = model:GetPivot()
	value.Parent = effect.Folder
	local connection = value.Changed:Connect(function(pivot: CFrame)
		if effect.Alive and model.Parent then model:PivotTo(pivot) end
	end)
	table.insert(effect.Connections, connection)
	local animation = tween(effect, value, duration, {Value = target})
	local completed: RBXScriptConnection? = nil
	completed = animation.Completed:Connect(function()
		connection:Disconnect()
		if completed then completed:Disconnect() end
		value:Destroy()
	end)
	table.insert(effect.Connections, completed :: RBXScriptConnection)
end

local function findModel(uid: any, id: string): Model?
	if type(uid) ~= "string" then return nil end
	for _, instance in workspace:GetDescendants() do
		if instance:IsA("Model") and instance:GetAttribute("CreatureUid") == uid and tostring(instance:GetAttribute("BattleId")) == id then
			return instance
		end
	end
	return nil
end

local function present(action: any, actor: Model, target: Model?)
	local effect = beginEffect()
	local color = palette[action.Element] or Color3.fromRGB(246, 218, 157)
	local origin = actor:GetPivot()
	local kind = action.Kind
	if kind == "Guard" then
		local shield = part(effect, color, Vector3.one * 5, origin.Position)
		shield.Shape = Enum.PartType.Ball
		shield.Transparency = 0.75
		tween(effect, shield, 0.65, {Size = Vector3.one * 6.5, Transparency = 1})
		popup(effect, origin.Position, "GUARD", color)
		return
	elseif kind == "Swap" then
		burst(effect, origin.Position, color)
		flash(effect, actor, color)
		popup(effect, origin.Position, "READY", color)
		return
	elseif kind == "Heal" then
		burst(effect, origin.Position, palette.Nature)
		flash(effect, actor, palette.Nature)
		popup(effect, origin.Position, "+" .. tostring(math.floor(tonumber(action.Amount) or 0)), palette.Nature)
		return
	end
	if not target then finish(effect); return end
	local targetPivot = target:GetPivot()
	local direction = targetPivot.Position - origin.Position
	if direction.Magnitude < 0.01 then finish(effect); return end
	effect.Restores[actor] = origin
	local lunge = origin + direction.Unit * math.min(3, direction.Magnitude * 0.3)
	moveModel(effect, actor, lunge, 0.13)
	task.delay(0.14, function()
		if not effect.Alive then return end
		moveModel(effect, actor, origin, 0.22)
		local boltStart = lunge.Position + Vector3.new(0, 1, 0)
		local boltEnd = targetPivot.Position + Vector3.new(0, 1, 0)
		local bolt = part(effect, color, Vector3.one * 0.9, boltStart)
		bolt.Shape = Enum.PartType.Ball
		local streak = part(effect, color, Vector3.new(0.16, 0.16, 2), boltStart)
		streak.CFrame = CFrame.lookAt(boltStart, boltEnd)
		tween(effect, bolt, 0.18, {Position = boltEnd})
		tween(effect, streak, 0.18, {Position = boltEnd, Transparency = 1})
		task.delay(0.18, function()
			if not effect.Alive or not target.Parent then return end
			bolt:Destroy()
			burst(effect, boltEnd, color)
			flash(effect, target, color)
			popup(effect, targetPivot.Position, "−" .. tostring(math.floor(tonumber(action.Amount) or 0)), Color3.fromRGB(255, 211, 195))
			effect.Restores[target] = targetPivot
			moveModel(effect, target, targetPivot + direction.Unit * 0.25, 0.06)
			task.delay(0.07, function()
				if effect.Alive then moveModel(effect, target, targetPivot, 0.12) end
			end)
		end)
	end)
end

function BattleFX.Destroy()
	generation += 1
	clear()
	if folder then folder:Destroy(); folder = nil end
	battleId = nil
	sequence = 0
end

function BattleFX.Init()
	BattleFX.Destroy()
	local container = Instance.new("Folder")
	container.Name = "BattleFeedback"
	container.Parent = workspace
	folder = container
end

function BattleFX.Play(view: any)
	if not folder then return end
	if type(view) ~= "table" or view.Id == nil then
		if battleId then generation += 1; clear(); battleId = nil; sequence = 0 end
		return
	end
	local id = tostring(view.Id)
	if id ~= battleId then generation += 1; clear(); battleId = id; sequence = 0 end
	local action = view.LastAction
	if type(action) ~= "table" or type(action.Sequence) ~= "number" or action.Sequence <= sequence then return end
	sequence = action.Sequence
	local timestamp = tonumber(action.At)
	local now = tonumber(view.ServerTime)
	if not timestamp or not now or now - timestamp > 3 or timestamp > now + 1 then return end
	-- Complete prior movement before another action can take ownership of a pivot.
	clear()
	-- Replicated model replacements can arrive just after the state remote.
	local ticket = generation
	local function attempt(remaining: number)
		if ticket ~= generation or not folder or action.Sequence ~= sequence then return end
		local actor = findModel(action.ActorUid, id)
		local target = findModel(action.TargetUid, id)
		if actor and (target or action.Kind ~= "Damage") then present(action, actor, target)
		elseif remaining > 0 then task.delay(0.12, function() attempt(remaining - 1) end) end
	end
	attempt(3)
end

return BattleFX
