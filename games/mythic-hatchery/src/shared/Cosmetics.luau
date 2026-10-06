--!strict
-- Coin-shop cosmetics. Owned per player; any number of that player's creatures
-- can wear an owned cosmetic (one per slot per creature). Purely visual.

export type Cosmetic = { Id: string, Name: string, Slot: string, Coins: number }

local Cosmetics = {}

Cosmetics.Slots = { "Hat", "Aura", "Saddle" }

Cosmetics.List = {
	{ Id = "PartyHat", Name = "Party Hat", Slot = "Hat", Coins = 2500 },
	{ Id = "TopHat", Name = "Top Hat", Slot = "Hat", Coins = 40000 },
	{ Id = "WizardHat", Name = "Wizard Hat", Slot = "Hat", Coins = 900000 },
	{ Id = "Crown", Name = "Crown", Slot = "Hat", Coins = 2.5e7 },
	{ Id = "SparkleAura", Name = "Sparkle Aura", Slot = "Aura", Coins = 15000 },
	{ Id = "FlameAura", Name = "Flame Aura", Slot = "Aura", Coins = 500000 },
	{ Id = "FrostAura", Name = "Frost Aura", Slot = "Aura", Coins = 500000 },
	{ Id = "StormAura", Name = "Storm Aura", Slot = "Aura", Coins = 1.2e7 },
	{ Id = "ShadowAura", Name = "Shadow Aura", Slot = "Aura", Coins = 3e8 },
	{ Id = "LeatherSaddle", Name = "Leather Saddle", Slot = "Saddle", Coins = 8000 },
	{ Id = "RoyalSaddle", Name = "Royal Saddle", Slot = "Saddle", Coins = 6e7 },
} :: { Cosmetic }

Cosmetics.ById = {} :: { [string]: Cosmetic }
for _, c in Cosmetics.List do
	Cosmetics.ById[c.Id] = c
end

return Cosmetics
