# Pet Expedition: game design

**Pitch:** Hatch cute pets, send them to break treasure across six islands, and send your spare
pets on timed expeditions that keep earning while you're away.

## Why it earns
- **A daily habit:** expedition timers (5 min to 8 h), a daily streak, daily quests and playtime gifts give
  players a reason to come back several times a day. Players who return are the ones who spend.
- **Collection:** 40 species × Normal/Golden/Rainbow × Shiny, plus an Index with rewards. The expedition-only
  pets can't be hatched, which makes expeditions worth running.
- **Social:** trading, other players' pets visible around the map, and a Server Luck boost that one player
  buys for the whole server (a public, generous purchase that others see).
- **Fair monetisation:** everything can be earned in play. Robux speeds things up (passes, gems, boosts), and
  odds are always shown.

## Core loop
1. Break coin piles, crates and chests with your equipped pets → **coins**, sometimes **gems**.
2. Spend coins on the island's **egg** → new pets; equip the strongest.
3. Save coins to open the **gate** to the next island (bigger coins, stronger eggs).
4. Spare pets go on **expeditions**, which bring back coins, gems, free eggs and rare finds.
5. Combine 5 of the same pet into a **Golden** (and 5 Golden into a **Rainbow**); pets level up as they work.
6. At the end, **rebirth** for a permanent +100% coin bonus and gems, then run the islands again faster.

## Pet Ring
A roped ring north of the Meadow hub. Walk in and your strongest equipped pets fight everyone else inside,
free-for-all; walk out and you're safe. KOs give trophies, coins and pet XP; the longest streak wears the
King of the Ring crown. Alone in the ring, wild challengers jump in. Ring strength is mostly pet level (time
spent), with rarity and paid help (Ring Champion's extra fighter, 2x XP, rarer pets) worth up to about 2x:
paying gets you stronger faster but a dedicated free player can still win.

## Islands
| # | Island | Gate (coins) | Egg cost | Expedition-only pet |
|---|---|---|---|---|
| 1 | Sunny Meadow | open | 100 | Sunflower Sprite (Epic) |
| 2 | Mushroom Grove | 5K | 3.6K | Fairy Moth (Legendary) |
| 3 | Frostbite Peaks | 120K | 72K | Polar King (Legendary) |
| 4 | Coral Cove | 2.7M | 1.5M | Pearl Seahorse (Legendary) |
| 5 | Ember Volcano | 54M | 30M | Phoenix (Mythic) |
| 6 | Starfall Isles | 1.1B | 540M | Void Kraken (Mythic) |

Each island multiplies coins by 8× and pet power by 6×, so a new island's Common pet beats the last
island's Rare. The Prism Egg (400 gems) sits in the Meadow hub and holds 4 exclusive pets, including the
Mythic Diamond Dragon (1%).

## Robux (all optional; see `src/shared/Products.luau`)
Game passes: VIP (199), Lucky (349), Triple Hatch (299), Fast Hatch (99), +3 Equipped (249),
+2 Expedition Slots (199), Auto Farm (249), Big Backpack (99), Ring Champion (299).
Developer products: gem packs (49–2,499 Robux), 2x Coins (49), 2x Pet XP (49), 2x Luck (79), Server Luck (199).
The best value per Robux is in larger packs, and the first pack is cheap (49) to make a first purchase easy.

## Fairness and compliance
- Odds are listed on every egg, including how luck changes them.
- PolicyService: players in regions where paid random items are restricted can't open the Prism Egg; trading
  turns off where paid item trading isn't allowed.
- Trades need both players to press Ready, then a 4-second countdown. Any change cancels Ready.
  Locked pets can't be traded.
- No chat-based scams: you can only trade pets (not gems), and the trade window shows both sides.

## Pacing targets (free player, from the balance simulation)
Grove ~10 min, Frost ~45 min, Coral ~2 h, Volcano ~5 h, Starfall ~10 h, first rebirth ~15 h.
Gems: ~200-300 a day for an active free player (a Prism Egg every 1.5-2 days). Breakables give at most
15 gems an hour. Expeditions are a strong supplement but never out-earn active play.
