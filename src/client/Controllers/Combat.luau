--!nonstrict
-- Combat input → server intents. Melee/tools: tap = LIGHT attack, hold and
-- release after the wind-up = HEAVY attack (more damage, more stamina, breaks
-- guards). Aim (RMB / L2) with any melee weapon or tool = BLOCK. Bows and
-- crossbows draw on press and fire on release; guns fire on press (repeat while
-- held). The server re-validates everything (stamina, cooldowns, wind-up).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Net = require(Shared.Net)
local UI = require("../UI/UI")
local Theme = require("../UI/Theme")
local State = require("../State")
local CameraCtl = require("./Camera")
local Input = require("./Input")

local Combat = {}

local player = Players.LocalPlayer
local nextAttack = 0
local drawStart: number? = nil
local swingStart: number? = nil -- melee press time (light vs heavy)
local chargeBar: Frame
local chargeSet: (number, string?) -> ()

local function equippedId(): string
	local inv = State.Get("Inventory")
	if not inv or not inv.Equipped then
		return "Fists"
	end
	local st = inv.Slots[inv.Equipped]
	return if st then st.Id else "Fists"
end

local function canAct(): boolean
	return player:GetAttribute("InMatch") == true and player:GetAttribute("LifeState") == "Alive" and not State.Get("Building")
end

local function face(dir: Vector3)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local flat = Vector3.new(dir.X, 0, dir.Z)
		if flat.Magnitude > 0.05 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
		end
	end
end

local function drawTime(def: any): number
	local t = def.DrawTime or 0.6
	return t * ((player:GetAttribute("DrawMult") :: number?) or 1)
end

local function attackOnce(heavy: boolean?)
	local id = equippedId()
	local def = Items[id]
	if not def or def.Kind == "Utility" then
		return
	end
	local t = os.clock()
	if t < nextAttack then
		return
	end
	nextAttack = t + (def.Cooldown or 0.6) * (if heavy then Config.Combat.HeavyCooldownMult else 1)
	local dir = CameraCtl.AimDirection(true)
	if not def.Ranged then
		face(dir)
	end
	State.Emit("LocalAction", { Kind = if heavy then "Heavy" else "Attack", Item = id })
	Net.Event("Attack"):FireServer({ Dir = dir, Heavy = heavy == true })
end

local function isMelee(def: any): boolean
	return def ~= nil and not def.Ranged and (def.Kind == "Weapon" or def.Kind == "Tool")
end

local function releaseBow()
	if not drawStart then
		return
	end
	local id = equippedId()
	local def = Items[id]
	local charge = math.clamp((os.clock() - drawStart) / drawTime(def), 0, 1)
	drawStart = nil
	chargeBar.Visible = false
	if def and def.Ranged == "Arrow" then
		local dir = CameraCtl.AimDirection(true)
		State.Emit("LocalAction", { Kind = "Release", Item = id })
		Net.Event("Attack"):FireServer({ Dir = dir, Charge = charge })
		nextAttack = os.clock() + (def.Cooldown or 0.35)
	end
	if not State.Get("AimHeld") then
		CameraCtl.SetAiming(false)
	end
end

function Combat.Start()
	local gui = UI.new("ScreenGui", { Name = "Charge", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 3, Parent = player:WaitForChild("PlayerGui") })
	chargeBar, chargeSet = UI.bar({ Size = UDim2.fromOffset(120, 10), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 26), Parent = gui }, Theme.Colors.Accent)
	chargeBar.Visible = false

	State.On("Action", function(a)
		if a.Name == "Aim" then
			State.Set("AimHeld", a.Down)
			local id = equippedId()
			if id == "Shield" or isMelee(Items[id]) then
				Net.Event("BlockState"):FireServer(a.Down and canAct())
				State.Emit("LocalAction", { Kind = if a.Down then "BlockOn" else "BlockOff", Item = id })
			elseif Items[id] and Items[id].Ranged then
				CameraCtl.SetAiming(a.Down and canAct())
			elseif not a.Down then
				CameraCtl.SetAiming(false)
			end
			return
		end
		if a.Name ~= "Attack" then
			return
		end
		if not canAct() then
			return
		end
		local id = equippedId()
		local def = Items[id]
		if not def then
			return
		end
		if def.Ranged == "Arrow" then
			if a.Down then
				if os.clock() < nextAttack then
					return
				end
				local inv = State.Get("Inventory")
				local ammo = def.AmmoType or "Arrow"
				if not inv or (inv.Ammo[ammo] or 0) <= 0 then
					State.Emit("Notify", { Text = if ammo == "Bolt" then "No bolts! Craft them at Workbench Tier IV." else "No arrows! Craft them at Workbench Tier II.", Kind = "warn" })
					return
				end
				drawStart = os.clock()
				chargeBar.Visible = true
				CameraCtl.SetAiming(true)
				State.Emit("LocalAction", { Kind = "Draw", Item = id })
			else
				releaseBow()
			end
		elseif isMelee(def) or id == "Fists" then
			-- Melee: measure the hold; release decides light vs heavy.
			if a.Down then
				swingStart = os.clock()
			elseif swingStart then
				local held = os.clock() - swingStart
				swingStart = nil
				chargeBar.Visible = false
				attackOnce(held >= Config.Combat.HeavyWindup)
			end
		elseif a.Down then
			attackOnce()
		end
	end)

	-- Hold-to-repeat for melee/tools/guns; charge bar for bows.
	RunService.Heartbeat:Connect(function()
		if drawStart then
			local def = Items[equippedId()]
			if not def or def.Ranged ~= "Arrow" or not canAct() then
				drawStart = nil
				chargeBar.Visible = false
				CameraCtl.SetAiming(false)
				return
			end
			local c = math.clamp((os.clock() - drawStart) / drawTime(def), 0, 1)
			chargeSet(c, if c >= 1 then "FULL" else "")
		end
		-- Heavy wind-up meter while a melee press is held.
		if swingStart then
			if not canAct() or not Input.Down.Attack then
				swingStart = nil
				chargeBar.Visible = false
			else
				local c = math.clamp((os.clock() - swingStart) / Config.Combat.HeavyWindup, 0, 1)
				if c > 0.3 then
					chargeBar.Visible = true
					chargeSet(c, if c >= 1 then "HEAVY" else "")
				end
			end
		end
		-- Guns repeat while held.
		local held = Input.Down.Attack
		if held and canAct() then
			local def = Items[equippedId()]
			if def and def.Ranged == "Hitscan" then
				attackOnce()
			end
		end
	end)

	player:GetAttributeChangedSignal("LifeState"):Connect(function()
		if player:GetAttribute("LifeState") ~= "Alive" then
			drawStart = nil
			chargeBar.Visible = false
			CameraCtl.SetAiming(false)
			Net.Event("BlockState"):FireServer(false)
		end
	end)
	State.On("Inventory", function()
		local id = equippedId()
		if id ~= "Shield" and not isMelee(Items[id]) and State.Get("AimHeld") then
			Net.Event("BlockState"):FireServer(false)
		end
	end)
end

return Combat
