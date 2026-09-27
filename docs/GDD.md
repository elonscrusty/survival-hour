# Survival Hour — Game Design Document (Survival Wars rules)

> One forest. One fire each. Keep yours burning.

## 1. Pitch
Survival Hour is a competitive solo forest-survival game for Roblox (PC + mobile). Every player spawns
at their own camp with a Campfire and a Tier I Workbench. By day they gather, craft, build and explore
caves and ruins; by night predators hunt and, from Night 3, enemy fires can be snuffed. While your
fire burns you respawn; once it goes out you are on your final life. The last survivor wins.

The full spec is `Survival_Wars_Master_Continuation.pdf`; [SPEC_AUDIT.md](SPEC_AUDIT.md) tracks every
requirement and [IMPLEMENTATION_LOG.md](IMPLEMENTATION_LOG.md) records how each phase implemented it.

## 2. Match flow
1. **Lobby (forest refuge)**: a golden-hour clearing around a gathering fire. Stations: Trading Post (Coins and
   bundles), Class Shrine (classes and power-ups), Outfitter (cosmetics locker), Hall of Fame (profile,
   rewards, leaderboards), Party board and the Ready arch. Pick a class and a power-up, then ready up.
2. **Match**: solo; 4 camps per map (Config.Match). Day 120 s (dawn → day → sunset) and a moonlit night 120 s,
   repeating with no time limit. At each sunrise living players get 15 s of protection and can't deal damage.
3. **Win**: last player standing. Placements: 1st 500 XP / 250 Coins / exactly 2 ◆; 2nd 250 XP / 100 Coins;
   3rd 50 Coins.

## 3. Fire and lives
* Unlimited respawns while your fire burns: 8 s, 12 s, 16 s, then 20 s.
* Fuel: 1 Wood = +2 %. At 0 % the fire goes out for good and you are on your final life.
* Fire levels 1–5 burn longer and take longer to snuff (8–20 s).
* Snuffing: from Night 3, day or night, holding a filled canteen. Damage, moving or letting go cancels it.
* Only materials drop on death, in one loot bag. Tools, weapons, armour, backpack and Workbench progress are kept.

## 4. Progression inside a match
Hand-gather sticks, stones, fibre and berries → Crude Axe / Pickaxe / Spear → exact yields
(small tree 4 Wood, medium 8, large 16 with a Stone Axe) → Workbench Tiers I–V (pack + storage) → stone,
iron and steel tools, bows and crossbows, five armour tiers, storage tiers, walls, doors, gates and traps.
POIs by rarity and caves (small / medium / large) hold one-time chests with Common → Very Rare loot, ore
and scrap.

## 5. Systems summary
* **Inventory:** slot-based stacks; backpacks from 10 to 40 slots; two tool slots; Head / Chest / Legs armour.
* **Combat:** light / heavy / block with any melee weapon (stamina matters, guards break); Crude Bow,
  Hunting Bow, Crossbow; headshots ×1.75; armour caps at 50 %.
* **Wildlife:** deer and rabbits flee, boars charge, wolves hunt in packs at night, bears defend territory.
  Each night raises pressure (pack size, aggression, roaming), never health.
* **Storage and raids:** tiered storage breached with a crowbar, sledgehammer or breaching charge. The owner gets an alert.
* **Healing:** Bandage +20, First Aid +50, Medkit +100. It takes time and damage interrupts it. You warm up slowly at your own fire.

## 6. Meta progression (between matches)
* **XP and levels (1–100):** status only. Rewards are Coins every 5 levels, 1 ◆ every 10 levels, and titles and nameplates at milestones.
* **Coins** buy cosmetics in the spec price bands: outfits, tool / backpack / campfire / workbench / storage skins,
  nameplates, titles, emotes, elimination effects and victory poses. Cosmetics are purely visual.
* **Diamonds** come from wins (exactly 2) and level milestones. They buy **classes** (Survivor free; Lumberjack,
  Miner, Hunter, Scavenger, Raider, Tracker) and **power-ups** (Strong Back … Second Wind). You equip one of
  each, and both are locked when the match starts. Classes and power-ups are sidegrades, never raw damage or health.
* **Daily and weekly bonuses**, plus **leaderboards** (wins, XP).
* **Robux** buys only Coin packs and cosmetic bundles.

All numbers: [TUNING.md](TUNING.md). Open design defaults: [DECISIONS.md](DECISIONS.md).

## 7. Look and feel
Stylised-realistic forest: Blender meshes (146 core + 57 Survival Wars assets) over procedural fallbacks,
a layered forest floor, cliffs, rivers and caves. Lighting presets: dawn, day, sunset, moonlit night and
the lobby's golden hour. Audio uses engine-bundled cues, with slots for licensed ambience and surface footsteps.
