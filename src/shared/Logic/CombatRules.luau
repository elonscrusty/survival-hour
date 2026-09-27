--!strict
-- Pure combat maths (tested by tests/CombatRules.spec.luau): armour, blocking,
-- light/heavy melee and headshots. CombatService applies the results.

local CombatRules = {}

-- Total armour reduction from worn pieces (each piece carries its share of the
-- set value). Spec: even an endgame full set stays under ~45-50%.
function CombatRules.ArmorReduction(pieceReductions: { number }, cap: number): number
	local r = 0
	for _, v in pieceReductions do
		r += v
	end
	return math.clamp(r, 0, cap)
end

export type BlockResult = { Taken: number, Drain: number, GuardBroken: boolean }

-- Blocking a frontal hit: `reduction` of the damage is stopped, costing stamina
-- per point stopped (`drainPerHp`), plus `extraDrain` from heavy attacks. Running
-- out of stamina breaks the guard and lets the rest through.
function CombatRules.Block(dmg: number, reduction: number, stamina: number, drainPerHp: number, extraDrain: number): BlockResult
	local blocked = dmg * reduction
	local drain = blocked * drainPerHp + extraDrain
	if drain <= stamina then
		return { Taken = dmg - blocked, Drain = drain, GuardBroken = false }
	end
	-- Partial block with what's left, then the guard breaks.
	local afford = math.max(0, stamina - extraDrain)
	local partial = if drainPerHp > 0 then math.min(blocked, afford / drainPerHp) else blocked
	return { Taken = dmg - partial, Drain = stamina, GuardBroken = true }
end

-- Melee damage for a swing: heavy hits harder; tired (not enough stamina) swings are weak.
function CombatRules.MeleeDamage(base: number, heavy: boolean, heavyMult: number, tired: boolean): number
	local d = base * (if heavy then heavyMult else 1)
	return if tired then d * 0.5 else d
end

function CombatRules.Headshot(dmg: number, isHead: boolean, mult: number): number
	return if isHead then dmg * mult else dmg
end

return CombatRules
