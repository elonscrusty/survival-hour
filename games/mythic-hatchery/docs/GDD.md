# Mythic Hatchery: game design

Hatch mythical creatures, ride and fly through a connected world, and command them in optional PvP battles.
A typical ten-minute session centres on riding, flying and battling. Habitat income funds better eggs and fusion.

## Loop
1. Ride and fly immediately on the starter Dragon. Buy two Meadow eggs with starter coins to build a battle team.
2. Incubate eggs with visible species, rarity and element odds. Discover five base species and six hidden hybrids.
3. Place spare creatures in habitat slots. Coins accumulate online/offline to a storage cap; tap to collect.
4. Remove three creatures from their other activities, select a team and queue for similarly strong opponents.
5. Command one active creature in real time; use unlocked moves and swap with a separate cooldown.
6. Battle participants earn XP in proportion to useful contribution. Levels unlock additional moves.
7. Unlock/upgrade habitat slots, explore regions, fuse pairs for rarity/hybrid chances, trade and collect cosmetics.

Rarity and levels provide substantial combat advantages. Defeated creatures recover immediately; arena points
fall on a loss. Battles remain optional. There are no races, care tasks or Baby/Teen/Adult/Ancient gameplay stages.
Habitat upgrades improve coin production/storage only. Assigned creatures cannot simultaneously battle or ride.

## World
One continuous six-region land: Meadow hub, Shadow Grove, Frost Peaks, Storm Coast, Ember Volcano, Sky Plateau.
Archway gates sit in natural ridges. The hub contains eggs, hatchery, fusion altar, coin shop, habitat plots and PvP arena.
All creature/world models use Roblox primitives generated from Python data: a blocky voxel-toy style, no uploaded meshes.

## Supporting systems
Daily/login rewards, playtime gifts, daily battle/hatch/fusion/expedition/coin quests, the Species|Element Index,
expeditions, rebirth, boosts, Server Luck and atomic creature-only trading support long-term collecting.
Ride/Fly/Neon potions apply per creature. Hats, saddles and auras use coins.

## Monetisation
Products and passes are defined in Products.luau. Gems buy premium eggs, potions and incubation skips.
Passes include extra incubators, faster incubation, VIP, Lucky, VIP Trader, extra creatures out, extra expeditions
and storage. Boosts include Coins, Battle XP, Luck and Server Luck. The obsolete AutoFarm and RingChampion
items are removed. All ids remain unconfigured; Studio offers test purchases while live buttons stay unavailable.
Paid random item restrictions disable gem eggs and paid luck. Trading respects account policy restrictions.
Strength can improve faster through purchases, while matching remains based on team strength.

## Provisional balance
Gameplay.luau contains tuning: level cap50, 2-second shared move cooldown, 8-second swap cooldown,
habitat prices/rates/caps, match ratio and rewards. Fused creatures start at level1. These values require playtesting.
