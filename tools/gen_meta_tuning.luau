-- Prints the TUNING.md meta-progression tables (classes, power-ups, XP / Coins,
-- cosmetics, Robux products) straight from the modules, so the doc matches the code.
-- Usage (project root):  luau tools/gen_meta_tuning.luau > /tmp/meta.md

local Classes = require("../src/shared/Classes")
local Perks = require("../src/shared/Perks")
local Progression = require("../src/shared/Progression")
local Cosmetics = require("../src/shared/Cosmetics")
local Products = require("../src/shared/Products")

local out = {}
local function w(s)
	table.insert(out, s)
end

w("### Classes (Diamonds, one per match, locked at match join)")
w("")
w("| Class | ◆ | Effects |")
w("|-------|---|---------|")
for _, d in Classes.List do
	w(string.format("| %s %s | %d | %s |", d.Glyph, d.Name, d.Price, table.concat(d.Lines, "; ")))
end
w("")
w("### Power-ups (Diamonds, one equipped, no mid-match swap)")
w("")
w("| Power-up | ◆ | Effect |")
w("|----------|---|--------|")
for _, d in Perks.List do
	w(string.format("| %s %s | %d | %s |", d.Glyph, d.Name, d.Price, d.Text))
end
w("")
w("### XP and Coins")
w("")
w("| Source | XP | Coins |")
w("|--------|----|-------|")
local keys = {}
for k in Progression.XP do
	keys[k] = true
end
for k in Progression.Coins do
	keys[k] = true
end
local sorted = {}
for k in keys do
	table.insert(sorted, k)
end
table.sort(sorted)
for _, k in sorted do
	w(string.format("| %s | %d | %d |", k, Progression.XP[k] or 0, Progression.Coins[k] or 0))
end
w("")
w(string.format("Win: exactly %d ◆. Level curve: %d XP for level 1→2, +20 per level (level 100 = %d XP total). Every 5 levels +%d Coins, every 10 levels +%d ◆.",
	Progression.WinDiamonds, Progression.XPForLevel(1), Progression.TotalForLevel(100), Progression.LevelCoins, Progression.MilestoneDiamonds))
w(string.format("Daily bonus %d Coins +20 per consecutive day (max %d). Weekly bonus after %d matches: %d + 75 per win (max %d).",
	Progression.DailyCoins(1), Progression.DailyCoins(99), Progression.WeeklyMatches, Progression.WeeklyCoins(0), Progression.WeeklyCoins(99)))
w("")
w("### Cosmetics (Coins; purely visual)")
w("")
w("Price bands: " .. (function()
	local b = {}
	for _, r in { "Common", "Uncommon", "Rare", "Epic", "Legendary" } do
		table.insert(b, string.format("%s %d–%d", r, Cosmetics.Bands[r][1], Cosmetics.Bands[r][2]))
	end
	return table.concat(b, " · ")
end)())
w("")
w("| Cosmetic | Type | Rarity | Coins / unlock |")
w("|----------|------|--------|----------------|")
for _, d in Cosmetics.List do
	w(string.format("| %s | %s | %s | %s |", d.Name, d.Type, d.Rarity, if d.Level then "level " .. d.Level elseif d.Price > 0 then tostring(d.Price) else "bundle"))
end
w("")
w("Bundles: " .. (function()
	local b = {}
	for name, list in Cosmetics.Bundles do
		table.insert(b, name .. " (" .. table.concat(list, ", ") .. ")")
	end
	table.sort(b)
	return table.concat(b, " · ")
end)())
w("")
w("### Developer products (create these in Creator Hub)")
w("")
w("Only Coin packs and cosmetic bundles are on sale. The other kinds stay defined so old receipts still resolve.")
w("")
w("| Key | Kind | Suggested price (R$) | On sale |")
w("|-----|------|----------------------|---------|")
local list = table.clone(Products.List)
table.sort(list, function(a, b)
	return a.Key < b.Key
end)
for _, p in list do
	w(string.format("| `%s` | %s | %d | %s |", p.Key, p.Kind, p.SuggestedPrice, if Products.OnSale(p.Key) then "yes" else "no (legacy)"))
end
print(table.concat(out, "\n"))
