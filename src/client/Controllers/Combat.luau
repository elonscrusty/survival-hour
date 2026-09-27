--!nonstrict
-- Combat input → server intents. Melee/tools swing on press (and repeat while
-- held), bows draw on press and fire on release, guns fire on press, shields
-- block while Aim is held. The server re-validates everything.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Items)
local Powerups = require(Shared.Powerups)
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
	if player:GetAttribute("Powerup") == "Sharpshooter" then
		local lv = Powerups.ById.Sharpshooter.Levels[player:GetAttribute("PowerupLevel") or 1]
		if lv then
			t *= 1 - lv.Passive.DrawPct / 100
		end
	end
	return t
end

local function attackOnce()
	local id = equippedId()
	local def = Items[id]
	if not def or def.Kind == "Utility" then
		return
	end
	local t = os.clock()
	if t < nextAttack then
		return
	end
	nextAttack = t + (def.Cooldown or 0.6)
	local dir = CameraCtl.AimDirection(true)
	if not def.Ranged then
		face(dir)
	end
	State.Emit("LocalAction", { Kind = "Attack", Item = id })
	Net.Event("Attack"):FireServer({ Dir = dir })
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
		if a.Name == "Ability" and a.Down then
			if canAct() then
				Net.Event("UseAbility"):FireServer()
			end
			return
		end
		if a.Name == "Aim" then
			State.Set("AimHeld", a.Down)
			local id = equippedId()
			if id == "Shield" then
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
				if not inv or (inv.Ammo.Arrow or 0) <= 0 then
					State.Emit("Notify", { Text = "No arrows! Craft them at Workbench level 2.", Kind = "warn" })
					return
				end
				drawStart = os.clock()
				chargeBar.Visible = true
				CameraCtl.SetAiming(true)
				State.Emit("LocalAction", { Kind = "Draw", Item = id })
			else
				releaseBow()
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
		local held = Input.Down.Attack
		if held and canAct() then
			local def = Items[equippedId()]
			if def and not def.Ranged then
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
		if id ~= "Shield" and State.Get("AimHeld") then
			Net.Event("BlockState"):FireServer(false)
		end
	end)
end

return Combat
