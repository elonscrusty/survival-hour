--!strict
-- Provisional tuning for the owner's October 6 battle/habitat design.
-- Keep this separate from the pet-era Config until the integration pass.
return {
	MaxLevel = 50,
	XpBase = 40,
	XpGrowth = 1.18,
	LevelPowerPerLevel = 0.18,
	Habitat = {
		BaseSlots = 3, MaxSlots = 8, MaxUpgrade = 10,
		CoinsPerPowerSecond = 0.1,
		BaseCapacity = 3600,
		UpgradeRate = 1.5, UpgradeCapacity = 2,
		UpgradeCost = 500, UpgradeCostMult = 2,
	},
	Battle = {
		TeamSize = 3,
		MoveCooldown = 2, SwapCooldown = 8,
		BaseHp = 100, BaseDamage = 18,
		ElementBonus = 1.25,
		MatchStrengthRatio = 1.5,
		WinCoins = 120, LoseCoins = 40,
		WinXp = 120, LoseXp = 60,
		WinPoints = 20, LosePoints = 10,
		MaxSeconds = 180,
	},
	MoveLevels = { 1, 1, 5, 10, 20, 35 },
}
