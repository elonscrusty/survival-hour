--!nonstrict
-- Server-authoritative combat.
--
-- Clients only send *intent*: "I attacked with my equipped item in this aim
-- direction (with this bow charge)". The server checks cooldowns, ammo and
-- state, then finds targets itself from server positions:
--   * melee   – cone query in front of the attacker's server-side root
--   * arrows  – server-simulated projectiles (gravity + raycast steps)
--   * guns    – server raycast from the attacker's head along the aim
-- Damage then flows through CombatService.DamagePlayer / structures / animals,
-- which applies friendly-fire, spawn protection, shield and armor rules.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Items = require(Shared:WaitForChild("Items"))
local Logic = Shared:WaitForChild("Logic")
local CombatRules = require(Logic:WaitForChild("CombatRules"))

local CombatService = {}

export type Source = { Kind: string, By: Player?, Name: string?, Pos: Vector3?, Weapon: string?, Heavy: boolean?, Head: boolean? }
local CFG = Config.Combat

local ctx: any
local nextAttack: { [Player]: number } = {}
local lastShot: { [Player]: number } = {}
local arrows: { { Owner: Player, Pos: Vector3, Vel: Vector3, T: number, Damage: number, Id: number, Start: Vector3, Weapon: string? } } = {}
local arrowId = 0

function CombatService.Init(c)
	ctx = c
	ctx.Util.Connect("Attack", "Attack", CombatService._onAttack)
	-- Any melee weapon or tool can block (spec: Light / Heavy / Block); the Shield blocks best.
	ctx.Util.Connect("BlockState", "Default", function(p: Player, on: any)
		local id = ctx.InventoryService.EquippedItem(p)
		local def = Items[id]
		local broken = (p:GetAttribute("GuardBrokenUntil") or 0) > workspace:GetServerTimeNow()
		local can = def ~= nil and not def.Ranged and (def.Kind == "Weapon" or def.Kind == "Tool") and not broken
		p:SetAttribute("Blocking", on == true and can and ctx.Util.IsAlive(p) and ctx.StaminaService.Get(p) > 1)
	end)
	ctx.Util.Connect("DrawState", "Default", function(p: Player, on: any)
		local def = Items[(ctx.InventoryService.EquippedItem(p))]
		p:SetAttribute("Drawing", on == true and def ~= nil and def.Ranged ~= nil and ctx.Util.IsAlive(p))
	end)
	ctx.Util.OnPlayerRemoving(function(p)
		nextAttack[p] = nil
		lastShot[p] = nil
	end)
end

function CombatService.Start()
	RunService.Heartbeat:Connect(CombatService._stepArrows)
end

-- Damage pipeline ----------------------------------------------------------------------------

-- Returns the damage actually dealt.
function CombatService.DamagePlayer(victim: Player, amount: number, source: Source): number
	local phase = ctx.MatchService.Phase
	if amount <= 0 or not victim:GetAttribute("InMatch") or not ctx.MatchService.Active or (phase ~= "Day" and phase ~= "Night") then
		return 0 -- no damage in the lobby, during the intro countdown or after the match ends
	end
	local hum = ctx.Util.Humanoid(victim)
	local root = ctx.Util.Root(victim)
	if not hum or not root or hum.Health <= 0 then
		return 0
	end
	if source.By then
		if source.By == victim then
			return 0
		end
		if ctx.Util.Team(source.By) == ctx.Util.Team(victim) then
			return 0 -- friendly fire off
		end
		if ctx.LivesService.IsProtected(source.By) then
			return 0 -- spawn / sunrise protection: protected players can't deal damage
		end
	end
	if ctx.LivesService.IsProtected(victim) then
		return 0
	end
	local dmg = amount
	-- Block (frontal): stops part of the hit for stamina; heavies drain extra and can break the guard.
	if victim:GetAttribute("Blocking") and source.Pos then
		local toAttacker = (source.Pos - root.Position) * Vector3.new(1, 0, 1)
		if toAttacker.Magnitude > 0.1 and root.CFrame.LookVector:Dot(toAttacker.Unit) > 0.25 then
			local bid, slot = ctx.InventoryService.EquippedItem(victim)
			local bdef = Items[bid]
			local isShield = bdef and bdef.BlockReduction ~= nil
			local r = CombatRules.Block(dmg, if isShield then bdef.BlockReduction else CFG.BlockReduction, ctx.StaminaService.Get(victim),
				if isShield then CFG.ShieldDrainPerHp else CFG.BlockDrainPerHp, if source.Heavy then CFG.HeavyGuardDrain else 0)
			ctx.StaminaService.Drain(victim, r.Drain)
			local bchar = victim.Character
			if bchar then
				bchar:SetAttribute("BlockHitAt", workspace:GetServerTimeNow())
			end
			if slot then
				ctx.InventoryService.Wear(victim, slot, math.max(1, math.ceil((dmg - r.Taken) / 4)))
			end
			dmg = r.Taken
			Net.FireAll("Fx", "Block", { Pos = root.Position })
			if r.GuardBroken then
				victim:SetAttribute("Blocking", false)
				victim:SetAttribute("GuardBrokenUntil", workspace:GetServerTimeNow() + CFG.GuardBreakTime)
				Net.FireClient("HitFeedback", victim, "GuardBreak", 0, source.Pos)
				if source.By then
					Net.FireClient("HitFeedback", source.By, "GuardBreak", 0, root.Position)
				end
			end
		end
	end
	-- Armour: every worn piece reduces damage and wears a little.
	local inv = ctx.InventoryService.Get(victim)
	if inv and next(inv.Armor) then
		local shares = {}
		for _, st in inv.Armor do
			table.insert(shares, (Items[st.Id] and Items[st.Id].DamageReduction) or 0)
		end
		local red = dmg * CombatRules.ArmorReduction(shares, CFG.ArmorCap)
		dmg -= red
		for piece in table.clone(inv.Armor) do
			ctx.InventoryService.Wear(victim, "Armor" .. piece, math.max(1, math.ceil(red / 3)))
		end
	end
	dmg = math.max(1, math.floor(dmg + 0.5))
	ctx.LivesService.RecordDamage(victim, source.Kind, source.By, source.Name)
	ctx.ChannelService.OnDamaged(victim)
	ctx.CampService.NoteHurt(victim)
	hum.Health = math.max(0, hum.Health - dmg)
	ctx.PowerupService.OnPlayerHurt(victim, dmg)
	ctx.PowerupService.Tally(victim, "DamageTaken", dmg)
	if typeof(source.By) == "Instance" and source.By:IsA("Player") and source.By ~= victim then
		ctx.PowerupService.Tally(source.By, "DamageDealt", dmg)
		ctx.EventService.Note("PvP")
	elseif source.Kind == "Animal" then
		ctx.EventService.Note("Wildlife")
	end
	-- hit reaction (Animation flinches away from the attacker)
	local vchar = victim.Character
	if vchar then
		vchar:SetAttribute("HitAt", workspace:GetServerTimeNow())
		if source.Pos then
			local away = (root.Position - source.Pos) * Vector3.new(1, 0, 1)
			vchar:SetAttribute("HitDir", if away.Magnitude > 0.1 then away.Unit else nil)
		end
	end
	Net.FireClient("HitFeedback", victim, "Hurt", dmg, source.Pos)
	if source.By then
		Net.FireClient("HitFeedback", source.By, "Player", dmg, root.Position)
	end
	ctx.Util.PlaySound("HitFlesh", root)
	return dmg
end

-- Aim/target helpers ------------------------------------------------------------------------

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.new(0, 0, -1)
end

-- What kind of thing is this part? Returns kind, object.
function CombatService.Classify(part: Instance): (string?, any)
	local p = ctx.Util.PlayerFromPart(part)
	if p then
		return "Player", p
	end
	local animal = ctx.WildlifeService.FromPart(part)
	if animal then
		return "Animal", animal
	end
	local structure = ctx.BuildService.FromPart(part)
	if structure then
		return "Structure", structure
	end
	local node = ctx.GatherService.FromPart(part)
	if node then
		return "Node", node
	end
	return nil, nil
end

-- Melee: best target in a 60 degree cone.
local function meleeTarget(attacker: Player, origin: Vector3, dir: Vector3, range: number): (string?, any, Vector3?)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { attacker.Character :: Instance }
	local reach = range + Config.Combat.MeleeTolerance
	local parts = workspace:GetPartBoundsInRadius(origin + dir * reach * 0.5, reach * 0.6 + 2, params)
	local best: { Kind: string?, Obj: any, Pos: Vector3?, Score: number } = { Kind = nil, Obj = nil, Pos = nil, Score = math.huge }
	local priority = { Player = 0, Animal = 0, Structure = 20, Node = 30 }
	local seen = {}
	for _, part in parts do
		local kind, obj = CombatService.Classify(part)
		if kind and not seen[obj] then
			seen[obj] = true
			local pos = part.Position
			local to = pos - origin
			local horiz = Vector3.new(to.X, 0, to.Z)
			local dist = horiz.Magnitude
			if dist <= reach + part.Size.Magnitude * 0.25 and math.abs(to.Y) < 9 then
				local facing = if dist > 0.5 then dir:Dot(horiz.Unit) else 1
				-- Players and animals can't be hit through walls: require line of sight.
				if facing > 0.45 and (kind == "Player" or kind == "Animal") then
					local los = RaycastParams.new()
					los.FilterType = Enum.RaycastFilterType.Exclude
					los.FilterDescendantsInstances = { attacker.Character :: Instance }
					los.IgnoreWater = true
					local eye = origin + Vector3.new(0, 1.5, 0)
					local block = workspace:Raycast(eye, pos - eye, los)
					if block and block.Instance ~= part and CombatService.Classify(block.Instance) ~= kind then
						facing = 0
					end
				end
				if facing > 0.45 then
					local score = dist + priority[kind] - facing * 2
					if score < best.Score then
						best = { Kind = kind, Obj = obj, Pos = pos, Score = score }
					end
				end
			end
		end
	end
	return best.Kind, best.Obj, best.Pos
end

-- Attack --------------------------------------------------------------------------------------

function CombatService._onAttack(p: Player, payload: any)
	if type(payload) ~= "table" or not ctx.Util.IsUnit(payload.Dir) then
		return
	end
	local char = p.Character
	local root = ctx.Util.Root(p)
	if not char or not root or not ctx.Util.IsAlive(p) then
		return
	end
	local id, slot = ctx.InventoryService.EquippedItem(p)
	local def = Items[id]
	if not def or def.Kind == "Utility" then
		return
	end
	local t = os.clock()
	local heavy = payload.Heavy == true and not def.Ranged
	local cd = (def.Cooldown or 0.6) * (if heavy then CFG.HeavyCooldownMult else 1)
	if t < (nextAttack[p] or 0) then
		return
	end
	-- A heavy needs a wind-up since the last swing (the client holds it for HeavyWindup).
	if heavy and t - (nextAttack[p] or 0) < CFG.HeavyWindup * 0.8 then
		heavy = false
	end
	if ctx.ChannelService.IsBusy(p) then
		ctx.ChannelService.Cancel(p, "Attacked")
	end
	if p:GetAttribute("Blocking") then
		p:SetAttribute("Blocking", false)
	end
	nextAttack[p] = t + cd * 0.9 -- small tolerance for latency jitter
	char:SetAttribute("Action", "Attack")
	char:SetAttribute("ActionAt", workspace:GetServerTimeNow())
	char:SetAttribute("ActionItem", id)
	char:SetAttribute("ActionHeavy", heavy)
	p:SetAttribute("Drawing", false)
	char:SetAttribute("ActionVariant", ((char:GetAttribute("ActionVariant") or 0) + 1) % 2) -- alternate swing direction

	local inMatch = p:GetAttribute("InMatch") == true and ctx.MatchService.IsPlaying()

	if def.Ranged == "Arrow" then
		CombatService._fireArrow(p, def, payload, slot)
		return
	elseif def.Ranged == "Hitscan" then
		CombatService._fireGun(p, def, payload, slot)
		return
	end

	-- Melee / tools
	local dir = flat(payload.Dir)
	ctx.Util.PlaySound("Swing", root)
	if not inMatch then
		return
	end
	local kind, obj, hitPos = meleeTarget(p, root.Position, dir, def.Range or 5)
	if not kind then
		return
	end
	-- Stamina: light 6 / heavy 18; without enough, heavies become lights and swings are weak.
	local tired = false
	if inMatch then
		if heavy and not ctx.StaminaService.Spend(p, CFG.HeavyStamina) then
			heavy = false
		end
		if not heavy and not ctx.StaminaService.Spend(p, CFG.LightStamina) then
			tired = true
		end
	end
	local dmg = CombatRules.MeleeDamage(def.Damage or 5, heavy, CFG.HeavyMult, tired)
	local worn = false
	if kind == "Player" then
		dmg = dmg * ctx.PowerupService.DamageMult(p, "Player")
		if CombatService.DamagePlayer(obj, dmg, { Kind = "Player", By = p, Pos = root.Position, Weapon = id, Heavy = heavy }) > 0 then
			worn = true
		end
	elseif kind == "Animal" then
		dmg = dmg * (def.AnimalMult or 1) * ctx.PowerupService.DamageMult(p, "Animal")
		if ctx.WildlifeService.Damage(obj, dmg, p) then
			worn = true
		end
	elseif kind == "Structure" then
		if id == "RepairHammer" then
			ctx.BuildService.Repair(p, obj)
			worn = true
		else
			local sdmg = dmg * (def.StructureMult or 1) * Config.Combat.StructureDamageScale
			if ctx.BuildService.Damage(obj, sdmg, p) then
				worn = true
			end
		end
	elseif kind == "Node" then
		if ctx.GatherService.Hit(p, obj, id) then
			worn = true
		end
	end
	if worn and slot then
		ctx.InventoryService.Wear(p, slot, if def.ToolType then ctx.PowerupService.ToolWear(p, def.ToolType) else 1)
	end
	if hitPos and kind ~= "Node" then
		Net.FireAll("Fx", "Impact", { Pos = hitPos, Kind = kind })
	end
end

-- Bow -------------------------------------------------------------------------------------------

function CombatService._fireArrow(p: Player, def: any, payload: any, slot: string?)
	local inv = ctx.InventoryService.Get(p)
	local head = p.Character and p.Character:FindFirstChild("Head") :: BasePart?
	if not inv or not head then
		return
	end
	local ammo = def.AmmoType or "Arrow"
	if (inv.Ammo[ammo] or 0) <= 0 then
		ctx.Util.Notify(p, if ammo == "Bolt" then "No bolts! Craft them at Workbench Tier IV." else "No arrows! Craft them at Workbench Tier II.", "warn")
		return
	end
	local t = os.clock()
	local drawTime = (def.DrawTime or 0.6) * ctx.PowerupService.DrawMult(p)
	-- Server-side minimum draw: charge can't exceed time since the last shot allows.
	local maxCharge = math.clamp((t - (lastShot[p] or 0)) / drawTime, 0, 1)
	local charge = math.clamp(if ctx.Util.IsFinite(payload.Charge) then payload.Charge else 0, 0.2, maxCharge)
	lastShot[p] = t
	inv.Ammo[ammo] -= 1
	if slot then
		ctx.InventoryService.Wear(p, slot, 1)
	else
		ctx.InventoryService.Sync(p)
	end
	local spread = math.rad((def.Spread or 1) * (1.5 - charge) * ctx.PowerupService.SpreadMult(p))
	local dir = (CFrame.lookAt(Vector3.zero, payload.Dir) * CFrame.Angles((math.random() - 0.5) * spread, (math.random() - 0.5) * spread, 0)).LookVector
	local speed = Config.Combat.ArrowSpeed * (0.55 + 0.45 * charge)
	local origin = head.Position + dir * 2
	arrowId += 1
	table.insert(arrows, { Owner = p, Pos = origin, Vel = dir * speed, T = 0, Damage = (def.Damage or 20) * (0.4 + 0.6 * charge), Id = arrowId, Start = origin, Weapon = def.Id })
	Net.FireAll("Fx", "Arrow", { Id = arrowId, Origin = origin, Velocity = dir * speed, Gravity = Config.Combat.ArrowGravity })
	ctx.Util.PlaySound("BowRelease", head)
end

function CombatService._stepArrows(dt: number)
	if #arrows == 0 then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local match = workspace:FindFirstChild("Match")
	local pickups = match and match:FindFirstChild("Pickups")
	for i = #arrows, 1, -1 do
		local a = arrows[i]
		a.T += dt
		local owner = a.Owner
		params.FilterDescendantsInstances = { owner.Character :: Instance, pickups :: Instance }
		local vel = a.Vel - Vector3.new(0, Config.Combat.ArrowGravity * dt, 0)
		local step = vel * dt
		local hit = workspace:Raycast(a.Pos, step, params)
		a.Vel = vel
		if hit then
			table.remove(arrows, i)
			Net.FireAll("Fx", "ArrowStop", { Id = a.Id, Pos = hit.Position })
			if owner.Parent and owner:GetAttribute("InMatch") then
				local kind, obj = CombatService.Classify(hit.Instance)
				local wdef = Items[a.Weapon or "Bow"] or Items.Bow
				local head = kind == "Player" and hit.Instance.Name == "Head" and wdef.Headshots == true
				local dmg = CombatRules.Headshot(a.Damage, head, CFG.HeadshotMult)
				if head then
					Net.FireClient("HitFeedback", owner, "Headshot", math.floor(dmg + 0.5), hit.Position)
				end
				if kind == "Player" then
					local dealt = CombatService.DamagePlayer(obj, dmg * ctx.PowerupService.DamageMult(owner, "Player"), { Kind = "Player", By = owner, Pos = a.Start, Weapon = wdef.Id, Head = head })
					if dealt > 0 then
						ctx.PowerupService.OnArrowHit(owner, obj, (hit.Position - a.Start).Magnitude)
					end
				elseif kind == "Animal" then
					ctx.WildlifeService.Damage(obj, dmg * ctx.PowerupService.DamageMult(owner, "Animal"), owner)
				elseif kind == "Structure" then
					ctx.BuildService.Damage(obj, dmg * (wdef.StructureMult or 0.4), owner)
				end
			end
		else
			a.Pos += step
			if a.T > Config.Combat.ArrowMaxTime then
				table.remove(arrows, i)
				Net.FireAll("Fx", "ArrowStop", { Id = a.Id, Pos = a.Pos })
			end
		end
	end
end

-- Guns -------------------------------------------------------------------------------------------

function CombatService._fireGun(p: Player, def: any, payload: any, slot: string?)
	local inv = ctx.InventoryService.Get(p)
	local head = p.Character and p.Character:FindFirstChild("Head") :: BasePart?
	if not inv or not head then
		return
	end
	if (inv.Ammo.Bullet or 0) <= 0 then
		ctx.Util.Notify(p, "Out of bullets! Find more in care packages and crates.", "warn")
		return
	end
	inv.Ammo.Bullet -= 1
	if slot then
		ctx.InventoryService.Wear(p, slot, 1)
	else
		ctx.InventoryService.Sync(p)
	end
	local spread = math.rad(def.Spread or 1)
	local dir = (CFrame.lookAt(Vector3.zero, payload.Dir) * CFrame.Angles((math.random() - 0.5) * spread, (math.random() - 0.5) * spread, 0)).LookVector
	local origin = head.Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { p.Character :: Instance }
	local hit = workspace:Raycast(origin, dir * (def.Range or 120), params)
	local endPos = if hit then hit.Position else origin + dir * (def.Range or 120)
	Net.FireAll("Fx", "Shot", { Origin = origin + dir * 2, End = endPos })
	ctx.Util.PlaySound("Gunshot", head)
	if not hit or not p:GetAttribute("InMatch") then
		return
	end
	local kind, obj = CombatService.Classify(hit.Instance)
	if kind == "Player" then
		local isHead = hit.Instance.Name == "Head"
		local dmg = CombatRules.Headshot(def.Damage or 25, isHead, CFG.HeadshotMult)
		if isHead then
			Net.FireClient("HitFeedback", p, "Headshot", math.floor(dmg + 0.5), hit.Position)
		end
		CombatService.DamagePlayer(obj, dmg * ctx.PowerupService.DamageMult(p, "Player"), { Kind = "Player", By = p, Pos = origin, Weapon = def.Id, Head = isHead })
	elseif kind == "Animal" then
		ctx.WildlifeService.Damage(obj, (def.Damage or 25) * ctx.PowerupService.DamageMult(p, "Animal"), p)
	elseif kind == "Structure" then
		ctx.BuildService.Damage(obj, (def.Damage or 25) * (def.StructureMult or 0.5), p)
	end
end

return CombatService
