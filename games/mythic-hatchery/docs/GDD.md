# Mythic Hatchery: game design

> Superseded in part by the owner's October 6 battle/habitat decisions in
> [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md). No racing or growth stages.
> Those decisions take precedence wherever this legacy design differs.

**Pitch:** Hatch mythical creatures, raise them from Baby to Ancient, fuse them into rarer eggs and hidden
hybrids, then ride and fly them through a sky race. Trade with friends.

## Core loop
1. **Buy an egg** (coins at an island stand, gems for the Mythic Egg and Limited eggs). It goes straight into an
   incubator (3 slots, +2 with a pass).
2. **Hatch** when the timer ends: a random species (Dragon, Griffin, Phoenix, Hydra, Unicorn), rarity (Common, Rare,
   Epic, Legendary, Mythic) and element (Fire, Ice, Storm, Nature, Shadow). Odds are always shown.
3. **Care**: Feed (every 15 min), Play (25 min), Sleep (60 min) to grow Baby → Teen → Adult → Ancient. Neglect only
   pauses growth; creatures never get sick.
4. **Fuse** two Adults into a Fused Egg with better rarity odds. Cross-species pairs can hatch one of 6 hidden hybrids
   (Wyvern, Emberwyrm, Pegasus, Leviathan, Chimera, Solaris).
5. **Ride and fly** Adults with the Ride or Fly potion; race through the Sky Arena above the hub.
6. Creatures you take with you **farm treasure** for coins, which open gates to the next region and better eggs.
   Spare creatures go on **expeditions**. Late game: **rebirth** for a permanent coin bonus.

## Regions (one connected land)
| # | Region | Element | Gate | Egg |
|---|---|---|---|---|
| 1 | Sunny Meadow (hub) | Nature | open | 100 |
| 2 | Shadow Grove | Shadow | 5K | 3.6K |
| 3 | Frost Peaks | Ice | 120K | 72K |
| 4 | Storm Coast | Storm | 2.7M | 1.5M |
| 5 | Ember Volcano | Fire | 54M | 30M |
| 6 | Sky Plateau | all | 1.1B | 540M |

Each region's egg rolls that region's element 60% of the time. Creatures earn 25% more coins in the region of
their element. Regions are joined by gate archways in hedges, cliffs and walls (no islands or bridges).
The hub has the Hatchery, Fusion Altar, Cosmetic Shop, Mythic and Limited egg stands, the Creature Ring and the
race pad under the Sky Arena.

## Other systems (kept from Pet Expedition)
Daily login streak, playtime gifts, 3 daily quests (incl. care, fusion and race goals), the Index (species ×
element, with hybrids hidden), boosts and Server Luck, trading (creatures only, confirm countdown), the Creature
Ring (walk-in brawls; growth matters most), rebirth.

## Robux (all optional; `src/shared/Products.luau`)
- **Passes:** +2 Hatch Slots (249), 2x Incubation (299), VIP Trader (199), VIP (199), Lucky (349),
  +3 Creatures Out (249), +2 Expedition Slots (199), Auto Farm (249), Big Stable (99), Ring Champion (299).
- **Products:** gem packs (49–2,499 Robux), 2x Coins (49), 2x Growth (49), 2x Luck (79), Server Luck (199).
- **Gems buy:** the Mythic Egg (400), Limited eggs (750, time-limited, with an Edition tag), Ride (150), Fly (300)
  and Neon (200) potions, and incubation skips.
- **Coins buy:** island eggs, Feed, fusion, cosmetics (hats, auras, saddles).

## Fairness and compliance
Odds listed for every egg (species, rarity and element, with luck). PolicyService: players where paid random items
are restricted can't buy gem eggs or paid luck; trading turns off where paid item trading isn't allowed. Trades are
creatures only, both players confirm, and the swap is atomic.
