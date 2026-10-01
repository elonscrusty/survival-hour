# Sell Hot Dogs: evidence-linked catalog

Generated from `catalog/economy.json` by `tools/gen_catalog.py`. Statuses: **observed** (read in dated footage by the supplied research), **secondary** (wiki/guide claim, unverified), **hypothesis** (our interpretation of observations), **placeholder** (unknown; labelled stand-in so the game runs).

## Sources

| id | source | note |
|---|---|---|
| N | [narrow, "Roblox Sell Lemons.." (uploaded 2026-06-10, 765 s)](https://www.youtube.com/watch?v=IJB1f-o7_bk) | Frames inspected by the earlier research pass (supplied in the handoff). Not re-watched in this session: YouTube is blocked by this environment's egress proxy. |
| B | [Bemmy, "Spending $5000 ROBUX on TIME SKIPS in SELL LEMONS??" (uploaded 2026-06-25, 806 s)](https://www.youtube.com/watch?v=Vu0A1VN1KTs) | Frames inspected by the earlier research pass (supplied in the handoff). Not re-watched in this session. |
| W-stand | [Sell Lemons fandom wiki: Lemon Stand](https://sell-lemons-roblox.fandom.com/wiki/Lemon_Stand) | Secondary. Page fetch blocked here; claims taken from the handoff and from 2026-10-01 web-search summaries. |
| W-dash | [Sell Lemons fandom wiki: LemonDash](https://sell-lemons-roblox.fandom.com/wiki/LemonDash) | Secondary. |
| W-income | [Sell Lemons fandom wiki: Income Sources (via web-search summary 2026-10-01)](https://sell-lemons-roblox.fandom.com/wiki/Income_Sources) | Secondary. Unlock and automation costs of all eight businesses. |
| W-depot | [Sell Lemons fandom wiki: Lemon Depot (via web-search summary 2026-10-01)](https://sell-lemons-roblox.fandom.com/wiki/Lemon_Depot) | Secondary. Some costs look inconsistent (below the unlock price) and are flagged. |
| W-trading | [Web-search summary of Sell Lemons Trading upgrades (2026-10-01)](https://allthings.how/sell-lemons-money-guide-fastest-ways-to-get-rich-roblox/) | Secondary, low confidence. |
| W-rebirth | [Sell Lemons fandom wiki: Rebirth](https://sell-lemons-roblox.fandom.com/wiki/Rebirth) | Secondary. |
| W-evo | [Sell Lemons fandom wiki: Evolution](https://sell-lemons-roblox.fandom.com/wiki/Evolution) | Secondary. |
| W-asc | [Sell Lemons fandom wiki: Ascension](https://sell-lemons-roblox.fandom.com/wiki/Ascension) | Secondary. |
| W-powers | [Sell Lemons fandom wiki: Powers / Robux; allthings.how powers guide (web-search summary 2026-10-01)](https://sell-lemons-roblox.fandom.com/wiki/Powers) | Secondary. Investor costs for Manage/Run Faster/Stack Upgrade; Robux prices conflict between guides. |
| W-mini | [Minigames: sportskeeda / techwiser summaries (web-search 2026-10-01)](https://sell-lemons-roblox.fandom.com/wiki/Minigames) | Secondary. Lemon Dash: four balls, bet on one, press Cheer. |
| W-phone | [Phone deals: sportskeeda beginner guide (web-search 2026-10-01)](https://www.sportskeeda.com/roblox-news/sell-lemons-a-beginner-s-guide) | Secondary. Accept or Raise; pushing too hard makes the buyer cancel. |
| D | [Official experience description](https://www.roblox.com/games/79268393072444/Sell-Lemons) | Description claim '100% offline income' (not a measured formula). |
| OURS | Sell Hot Dogs design decision | No reference value exists; this is a labelled stand-in so the game runs. Listed in docs/CATALOG.md under Unresolved. |

Timestamps like `N 00:48.2` mean source N at video time 00:48.2.

## All values

| area | item | value | unit | status | source | note |
|---|---|---|---|---|---|---|
| Start | Starting cash | $1.00 | $ | hypothesis | N 00:15; W-stand | A $1.00 wallet was visible near N 00:15 and the wiki claims the stand unlocks for $1. Clean new-player balance is unverified. |
| Hot Dog Stand | Base output at level 1 | $1.00 | $/cycle | observed | N 00:33.9 | $1.00 label, no multipliers. |
| Hot Dog Stand | Base output at level 2 | $1.91 | $/cycle | hypothesis | N 00:48.2 | $3.81 label / x2 condiment. Single animated read; low confidence. |
| Hot Dog Stand | Base output at level 3 | $2.92 | $/cycle | hypothesis | N 00:48.6; N 00:58 | $5.84/x2 and $17.51/x6 agree (2.92, 2.918). |
| Hot Dog Stand | Base output at level 4 | $4.04 | $/cycle | hypothesis | N 00:59 | $24.26/x6. |
| Hot Dog Stand | Output beyond level 4 | increment x1.11/level |  | placeholder | OURS | UNRESOLVED. Beyond level 4 each level adds the previous increment x1.11 (the growth of the three observed increments 0.905, 1.015, 1.123). Not a verified formula. |
| Hot Dog Stand | Level upgrade #1 cost | $5.10 | $ | observed | N 00:29; 00:35; 00:47.6 | First stand upgrade, no badge. |
| Hot Dog Stand | Level upgrade #2 cost | $7.65 | $ | observed | N 00:48.2 | Yellow x1 badge. |
| Hot Dog Stand | Level upgrade #3 cost | $11.00 | $ | observed | N 00:48.4 | Yellow x2 badge. |
| Hot Dog Stand | Level upgrade #4 cost | $19.00 | $ | observed | N 01:00-01:01 | Yellow x3 badge. Hypothesis H-BADGE: the badge counts upgrades already bought. |
| Hot Dog Stand | Level upgrade cost beyond #4 | x1.5 per level |  | placeholder | OURS | UNRESOLVED. After the 4th upgrade each further upgrade costs x1.5 the previous. The real repeated-upgrade formula, rounding and milestones are unknown. |
| Other businesses | outputPerUnlockCost | 0.02 |  | placeholder | OURS | UNRESOLVED. Level-1 output per cycle = 2% of the business's unlock price. |
| Other businesses | cycleTime | 3 |  | placeholder | OURS | UNRESOLVED. Base cycle time 3 s for every later business. |
| Other businesses | firstLevelCostPerUnlockCost | 0.3 |  | placeholder | OURS | UNRESOLVED. First level upgrade costs 30% of the unlock price, then x1.5 per level (same placeholder growth as the stand). |
| Hot Dog Stand | Unlock (ref: Lemon Stand) | $1.00 | $ | secondary | W-stand | Wiki claim $1. |
| Hot Dog Stand | Base output | $1.00 | $/cycle | observed | N 00:33.9 |  |
| Hot Dog Stand | Cycle time | 1.0 | s | observed | N 00:34.0-00:35.0 | Displayed countdown 1s, 0.8s ... 0.2s, then CLICK. |
| Hot Dog Stand | Condiment Station (ref: Juicer): x2 cash | $6.20 | $ | observed | N 00:36-00:38; 00:47 |  |
| Hot Dog Stand | Cash Register (ref: Cash Register): automates | $100.00 | $ | observed | N 00:35; 01:04-01:06 |  |
| Hot Dog Stand | Bun Rack (ref: Cup Stand): x3 cash | $82.50 | $ | observed | N 00:55-00:57; 04:10 |  |
| Hot Dog Stand | Bun Rack requires condiment |  |  | hypothesis | OURS | Pad order assumed sequential. |
| Hot Dog Stand | Hot Dog Billboard (ref: Billboard): x3 speed | $785.00 | $ | observed | N 01:03 |  |
| Hot Dog Stand | Hot Dog Billboard requires bunrack |  |  | hypothesis | OURS | Pad order assumed sequential. |
| Hot Dog Stand | Relish Mixer (ref: Sugar Mixer): x2 cash | $105,000 | $ | secondary | W-stand |  |
| Hot Dog Stand | Relish Mixer requires billboard |  |  | hypothesis | OURS | Pad order assumed sequential. |
| Hot Dog Stand | Street Flyers (ref: Street Fliers): x2 speed | $1.1e+06 | $ | secondary | W-stand |  |
| Hot Dog Stand | Street Flyers requires relish |  |  | hypothesis | OURS | Pad order assumed sequential. |
| Hot Dog Stand | Flame Grill (ref: Ice Maker): x4 cash | $7.35e+07 | $ | secondary | W-stand |  |
| Hot Dog Stand | Flame Grill requires flyers |  |  | hypothesis | OURS | Pad order assumed sequential. |
| Hot Dog Stand | BOGO Deals (ref: Bogo Deals): x4 speed | $2e+10 | $ | secondary | W-stand |  |
| Hot Dog Stand | BOGO Deals requires grill |  |  | hypothesis | OURS | Pad order assumed sequential. |
| DogDash | Unlock (ref: LemonDash) | $17,000 | $ | secondary | W-dash; W-income |  |
| DogDash | DogDash Floor (ref: Floor): structure | $19,500 | $ | observed | N 02:10 |  |
| DogDash | Walls (ref: Walls): structure | $21,500 | $ | secondary | W-dash |  |
| DogDash | Walls requires floor |  |  | hypothesis | OURS | Pad order assumed sequential. |
| DogDash | Higher Fees (ref: Higher Fees): x3 cash | $39,500 | $ | secondary | W-dash |  |
| DogDash | Higher Fees requires walls |  |  | hypothesis | OURS | Pad order assumed sequential. |
| DogDash | Delivery Bike (ref: Company Vehicle): x2 speed | $275,000 | $ | secondary | W-dash |  |
| DogDash | Delivery Bike requires fees |  |  | hypothesis | OURS | Pad order assumed sequential. |
| DogDash | Dispatch Manager (ref: Manager): automates | $995,000 | $ | secondary | W-dash; W-income |  |
| DogDash | DogDash the Game (ref: Lemon Dash the Game): unlocks minigame | $50,000 | $ | placeholder | N 03:20 (locked pad seen; price not readable) | UNRESOLVED price. |
| Delivery Depot | Unlock (ref: Lemon Depot) | $1.35e+10 | $ | secondary | W-income |  |
| Delivery Depot | Bigger Fleet (ref: Bigger Fleet): x2 speed | $21,500 | $ | secondary | W-depot | CONFLICT: cost is below the depot unlock price; likely a summary error. |
| Delivery Depot | Refrigerated Trucks: x3 cash | $9.7e+11 | $ | secondary | W-depot |  |
| Delivery Depot | Refrigerated Trucks requires fleet |  |  | hypothesis | OURS | Pad order assumed sequential. |
| Delivery Depot | Automated Loading: x4 cash | $3.65e+12 | $ | secondary | W-depot |  |
| Delivery Depot | Automated Loading requires fridge |  |  | hypothesis | OURS | Pad order assumed sequential. |
| Delivery Depot | Depot Manager (ref: automation): automates | $1.4e+13 | $ | secondary | W-income |  |
| Delivery Depot | Automated Boxing: x2 cash | $1.95e+13 | $ | secondary | W-depot |  |
| Delivery Depot | Automated Boxing requires loading |  |  | hypothesis | OURS | Pad order assumed sequential. |
| Delivery Depot | GPS Logistics: x3 speed | $6.25e+13 | $ | secondary | W-depot |  |
| Delivery Depot | GPS Logistics requires boxing |  |  | hypothesis | OURS | Pad order assumed sequential. |
| Delivery Depot | Express Lanes (ref: Toll Evasion): x2 cash | $3.85e+14 | $ | secondary | W-depot |  |
| Delivery Depot | Express Lanes requires gps |  |  | hypothesis | OURS | Pad order assumed sequential. |
| Delivery Depot | Delivery Insurance: x2 cash | $3.6e+15 | $ | secondary | W-depot |  |
| Delivery Depot | Delivery Insurance requires express |  |  | hypothesis | OURS | Pad order assumed sequential. |
| Delivery Depot | Even Bigger Fleet: x3 speed | $1.15e+16 | $ | secondary | W-depot |  |
| Delivery Depot | Even Bigger Fleet requires insurance |  |  | hypothesis | OURS | Pad order assumed sequential. |
| Delivery Depot | Wholesale Pricing: x3 cash | $3.7e+17 | $ | secondary | W-depot |  |
| Delivery Depot | Wholesale Pricing requires fleet2 |  |  | hypothesis | OURS | Pad order assumed sequential. |
| Delivery Depot | Exterior Displays (ref: Exterior Sign / Exterior Displays): x2 speed | $4e+19 | $ | secondary | W-depot; B 04:40 (name seen as a Forever Purchase target) |  |
| Delivery Depot | Exterior Displays requires wholesale |  |  | hypothesis | OURS | Pad order assumed sequential. |
| Delivery Depot | Truck Branding: x4 speed | $7.35e+20 | $ | secondary | W-depot |  |
| Delivery Depot | Truck Branding requires exterior |  |  | hypothesis | OURS | Pad order assumed sequential. |
| Delivery Depot | Turbochargers: x4 speed | $1.65e+27 | $ | secondary | W-depot |  |
| Delivery Depot | Turbochargers requires branding |  |  | hypothesis | OURS | Pad order assumed sequential. |
| Delivery Depot | Self-Driving Trucks: x7 cash | $1.3e+32 | $ | secondary | W-depot |  |
| Delivery Depot | Self-Driving Trucks requires turbo |  |  | hypothesis | OURS | Pad order assumed sequential. |
| Delivery Depot | Mustard Fuel Lines (ref: Citrus Fuel Lines): x3 cash | $1.8e+34 | $ | secondary | W-depot |  |
| Delivery Depot | Mustard Fuel Lines requires selfdrive |  |  | hypothesis | OURS | Pad order assumed sequential. |
| Hot Dog Trading | Unlock (ref: Lemon Trading) | $2.6e+17 | $ | secondary | W-income |  |
| Hot Dog Trading | Expert Brokers: x2 speed | $1.2e+17 | $ | secondary | W-trading | CONFLICT: below unlock price. |
| Hot Dog Trading | Secret Sauce Finances (ref: Obfuscated Finances): x3 cash | $1.2e+17 | $ | secondary | W-trading |  |
| Hot Dog Trading | Trading Manager (ref: automation): automates | $8.55e+19 | $ | secondary | W-income |  |
| Hot Dog Trading | 24-Hour Trading: x7 cash | $5e+21 | $ | placeholder | W-trading (x7 cash claimed; cost unknown) | UNRESOLVED cost. |
| Hot Dog Trading | 24-Hour Trading requires sauce |  |  | hypothesis | OURS | Pad order assumed sequential. |
| Test Kitchen Labs | Unlock (ref: Lemon Labs) | $1.45e+26 | $ | secondary | W-income |  |
| Test Kitchen Labs | Head Scientist (ref: automation): automates | $2.5e+32 | $ | secondary | W-income |  |
| Test Kitchen Labs | Experimental Testing (ref: Experimental Testing): x2 cash | $1e+27 | $ | placeholder | B 05:10 (name seen as a Forever Purchase target) | UNRESOLVED cost and effect. |
| Kitchen Robotics | Unlock (ref: Lemon Robotics) | $1.4e+41 | $ | secondary | W-income |  |
| Kitchen Robotics | Robot Foreman (ref: automation): automates | $7.2e+44 | $ | secondary | W-income |  |
| Hot Dog Republic | Unlock (ref: Lemon Republic) | $2.75e+56 | $ | secondary | W-income |  |
| Hot Dog Republic | Minister of Mustard (ref: automation): automates | $4.3e+63 | $ | secondary | W-income |  |
| HotDogX | Unlock (ref: LemonX) | $8.85e+82 | $ | secondary | W-income |  |
| HotDogX | Mission Control (ref: automation): automates | $2.65e+91 | $ | secondary | W-income |  |
| Prestige | rebirthMinCash | 7.7e+22 |  | secondary | W-rebirth | Approx. $77 sextillion lifetime cash before the first investor. Interpreted as: investors offered = 0 below this. |
| Prestige | investorAwardRule | floor(sqrt(lifetime / rebirthMinCash)) |  | placeholder | OURS | UNRESOLVED award formula. |
| Prestige | cashBonusPerInvestor | 0.01 |  | secondary | W-rebirth | +1% cash per investor. CONFLICT: B 11:40 shows +32% per investor in a late-game state; the rule that grows it is unknown. |
| Prestige | rebirthKeeps | investors, powers, evolutions, ascension, Robux purchases, Forever Purchase pads, business name |  | hypothesis | W-rebirth; B 01:40 |  |
| Prestige | evolutionSpeedMult | 42 |  | observed | B 10:40 | UI text: each evolution gives x42 income speed. Stacking assumed multiplicative (W-evo). |
| Prestige | evolutionFirstInvestors | 5.012e+17 |  | secondary | W-evo |  |
| Prestige | evolutionGrowth | 1000 |  | placeholder | OURS | UNRESOLVED. Each further evolution needs 1000x more investors. |
| Prestige | evolutionResets | cash, businesses, pads, investors, investor-bought powers |  | observed | B 01:40 | Warning text says most progress incl. investors and powers resets; Robux purchases are safe. |
| Prestige | ascensionCashMult | 7.77 |  | secondary | W-asc |  |
| Prestige | ascensionPriceMult | 3.33 |  | secondary | W-asc |  |
| Prestige | ascensionRequires | every pad on the plot owned |  | secondary | W-asc | Claim: all buttons/Staircase. |
| Prestige | ascensionResets | everything except ascension count, Robux purchases, Forever Purchase pads, business name |  | secondary | W-asc |  |
| Prestige | ascensionForeverTokens | 1 |  | secondary | W-asc |  |
| Prestige | recipes | Classic, Chili, Cheese, Jalapeno, Cosmic, Void |  | placeholder | OURS | Hot-dog stand-ins for the fruit evolution chain (B 10:40 shows Purity+1 -> Lemon+2). Names after the 6th repeat with +n. |
| Powers | Manage investor cost by tier | 100 | investors | secondary | W-powers |  |
| Powers | Run Faster investor cost by tier | 400, 4000, 40000 | investors | secondary | W-powers | Tier 1 = 400 investors, x1.5 speed (secondary). Tiers 2-3 costs and speeds are UNRESOLVED placeholders. |
| Powers | Stack Upgrade investor cost by tier | 1000, 10000, 100000 | investors | secondary | W-powers | Tier 1 = 1000 investors, x5 at once (secondary). Tiers 2-3 and the Max button gate are UNRESOLVED placeholders. |
| Powers | Remote Buy investor cost by tier | 2500 | investors | placeholder | W-powers (exists; cost unknown) | UNRESOLVED investor cost. |
| Powers | Expert Collector investor cost by tier | 800, 8000, 80000 | investors | placeholder | W-powers; B 00:10 | Effect direction secondary; costs and multipliers UNRESOLVED. |
| Pickups | rackCapacity | 5 |  | placeholder | OURS | UNRESOLVED. B 06:10 shows a pickup under a tree; quantities/capacity unknown. |
| Pickups | spawnEvery | 6 |  | placeholder | OURS |  |
| Pickups | valueSeconds | 10 |  | placeholder | OURS | A crate pays 10 s of current income (min $1). |
| Pickups | pickupRange | 9 |  | placeholder | OURS | Server distance check in studs. |
| Phone | firstAfter | 90 |  | placeholder | OURS |  |
| Phone | every | 240 |  | placeholder | OURS |  |
| Phone | offerSeconds | [60, 300] |  | placeholder | OURS | Offer = current income per second x random seconds in this range. UNRESOLVED; N 09:00 shows a $296.102 trillion offer. |
| Phone | raiseStep | 1.25 |  | placeholder | OURS |  |
| Phone | raiseOdds | {"better": 0.5, "final": 0.3, "walk": 0.2} |  | placeholder | W-phone (pushing too hard cancels) |  |
| Phone | expires | 45 |  | placeholder | OURS |  |
| Dash | runners | 4 |  | secondary | W-mini |  |
| Dash | betFractions | [0.1, 0.25, 0.5] |  | placeholder | OURS |  |
| Dash | winPays | 2.6 |  | placeholder | OURS | UNRESOLVED payout; chosen so betting never makes money on average. |
| Dash | raceSeconds | 8 |  | placeholder | OURS |  |
| Dash | cheerBoost | 0.003 |  | placeholder | OURS | Each cheer in the last second adds 0.3% speed to the chosen racer (max 6 cheers/s count). Tuned so constant cheering stays below break-even (about 36% wins x 2.6 = 0.92 expected return); measured in tests/Dash.spec.luau. |
| Dash | cooldown | 30 |  | placeholder | OURS |  |
| Offline | rate | 1.0 |  | secondary | D | Description claims 100% offline income. Only automated businesses earn. No cap is applied because none is evidenced. |
| Names | maxLength | 24 |  | placeholder | N 10:00 (name editing exists; limit unknown) |  |
| Names | minLength | 3 |  | placeholder | OURS |  |

## Robux offerings (displays only; never charged as constants)

| product | kind | grants | Robux seen in footage | status/source | secondary claim | note |
|---|---|---|---|---|---|---|
| Permanent Power - Expert Collector | pass | expertPicker tier +1 (permanent) | 135 | observed B 00:10 (creator's native checkout, Plus savings shown) | 149 |  |
| Forever Purchase | product | 1 Forever Purchase token | 1350 | observed B 00:10 (shop card; pricing status unresolved) | 1499 |  |
| Cash - 24 Hours | product | 86400 s of current income | 135 | observed B 02:10 (shop card) | - | Grant calculation UNRESOLVED: 24 h x current automated income per second. |
| Cash - 7 Days | product | 604800 s of current income | 180 | observed B 02:10 (native checkout with Plus savings) | - |  |
| x2 Alien Investors | pass | doubles investors offered at rebirth | 630 | observed B 11:40 (offer control; checkout not inspected) | 699 |  |
| Manage | pass | Manage power (permanent) | - | unknown  | 199 |  |
| Run Faster | product | Run Faster tier +1 (permanent) | - | unknown  | 99 |  |
| Stack Upgrade | product | Stack Upgrade tier +1 (permanent) | - | unknown  | 199 |  |
| Remote Buy | pass | Remote Buy power (permanent) | - | unknown  | 999 |  |
| Speed Up Time | pass | x2 speed for every business (permanent) | - | unknown  | 799 | Guides conflict: 799 vs 319. |
| Cash - 1 Hour | product | 3600 s of current income | - | unknown  | 19 | Smaller skip tiers are secondary; exact set unknown. |
| Rebirth Without Reset | product | investors currently offered, without resetting | - | unknown  | 99 |  |

Live prices must come from `MarketplaceService:GetProductInfo` for the new game's own IDs (regional pricing); these numbers are historical displays from one creator's session.

## Unresolved (61 entries)

Every row below is a guess or interpretation that the game currently runs on. Replace with evidence when available.

| area | item | current value | status | note |
|---|---|---|---|---|
| Start | Starting cash | $1.00 | hypothesis | A $1.00 wallet was visible near N 00:15 and the wiki claims the stand unlocks for $1. Clean new-player balance is unverified. |
| Hot Dog Stand | Base output at level 2 | $1.91 | hypothesis | $3.81 label / x2 condiment. Single animated read; low confidence. |
| Hot Dog Stand | Base output at level 3 | $2.92 | hypothesis | $5.84/x2 and $17.51/x6 agree (2.92, 2.918). |
| Hot Dog Stand | Base output at level 4 | $4.04 | hypothesis | $24.26/x6. |
| Hot Dog Stand | Output beyond level 4 | increment x1.11/level | placeholder | UNRESOLVED. Beyond level 4 each level adds the previous increment x1.11 (the growth of the three observed increments 0.905, 1.015, 1.123). Not a verified formula. |
| Hot Dog Stand | Level upgrade cost beyond #4 | x1.5 per level | placeholder | UNRESOLVED. After the 4th upgrade each further upgrade costs x1.5 the previous. The real repeated-upgrade formula, rounding and milestones are unknown. |
| Other businesses | outputPerUnlockCost | 0.02 | placeholder | UNRESOLVED. Level-1 output per cycle = 2% of the business's unlock price. |
| Other businesses | cycleTime | 3 | placeholder | UNRESOLVED. Base cycle time 3 s for every later business. |
| Other businesses | firstLevelCostPerUnlockCost | 0.3 | placeholder | UNRESOLVED. First level upgrade costs 30% of the unlock price, then x1.5 per level (same placeholder growth as the stand). |
| Hot Dog Stand | Bun Rack requires condiment |  | hypothesis | Pad order assumed sequential. |
| Hot Dog Stand | Hot Dog Billboard requires bunrack |  | hypothesis | Pad order assumed sequential. |
| Hot Dog Stand | Relish Mixer requires billboard |  | hypothesis | Pad order assumed sequential. |
| Hot Dog Stand | Street Flyers requires relish |  | hypothesis | Pad order assumed sequential. |
| Hot Dog Stand | Flame Grill requires flyers |  | hypothesis | Pad order assumed sequential. |
| Hot Dog Stand | BOGO Deals requires grill |  | hypothesis | Pad order assumed sequential. |
| DogDash | Walls requires floor |  | hypothesis | Pad order assumed sequential. |
| DogDash | Higher Fees requires walls |  | hypothesis | Pad order assumed sequential. |
| DogDash | Delivery Bike requires fees |  | hypothesis | Pad order assumed sequential. |
| DogDash | DogDash the Game (ref: Lemon Dash the Game): unlocks minigame | $50,000 | placeholder | UNRESOLVED price. |
| Delivery Depot | Bigger Fleet (ref: Bigger Fleet): x2 speed | $21,500 | secondary | CONFLICT: cost is below the depot unlock price; likely a summary error. |
| Delivery Depot | Refrigerated Trucks requires fleet |  | hypothesis | Pad order assumed sequential. |
| Delivery Depot | Automated Loading requires fridge |  | hypothesis | Pad order assumed sequential. |
| Delivery Depot | Automated Boxing requires loading |  | hypothesis | Pad order assumed sequential. |
| Delivery Depot | GPS Logistics requires boxing |  | hypothesis | Pad order assumed sequential. |
| Delivery Depot | Express Lanes requires gps |  | hypothesis | Pad order assumed sequential. |
| Delivery Depot | Delivery Insurance requires express |  | hypothesis | Pad order assumed sequential. |
| Delivery Depot | Even Bigger Fleet requires insurance |  | hypothesis | Pad order assumed sequential. |
| Delivery Depot | Wholesale Pricing requires fleet2 |  | hypothesis | Pad order assumed sequential. |
| Delivery Depot | Exterior Displays requires wholesale |  | hypothesis | Pad order assumed sequential. |
| Delivery Depot | Truck Branding requires exterior |  | hypothesis | Pad order assumed sequential. |
| Delivery Depot | Turbochargers requires branding |  | hypothesis | Pad order assumed sequential. |
| Delivery Depot | Self-Driving Trucks requires turbo |  | hypothesis | Pad order assumed sequential. |
| Delivery Depot | Mustard Fuel Lines requires selfdrive |  | hypothesis | Pad order assumed sequential. |
| Hot Dog Trading | Expert Brokers: x2 speed | $1.2e+17 | secondary | CONFLICT: below unlock price. |
| Hot Dog Trading | 24-Hour Trading: x7 cash | $5e+21 | placeholder | UNRESOLVED cost. |
| Hot Dog Trading | 24-Hour Trading requires sauce |  | hypothesis | Pad order assumed sequential. |
| Test Kitchen Labs | Experimental Testing (ref: Experimental Testing): x2 cash | $1e+27 | placeholder | UNRESOLVED cost and effect. |
| Prestige | investorAwardRule | floor(sqrt(lifetime / rebirthMinCash)) | placeholder | UNRESOLVED award formula. |
| Prestige | cashBonusPerInvestor | 0.01 | secondary | +1% cash per investor. CONFLICT: B 11:40 shows +32% per investor in a late-game state; the rule that grows it is unknown. |
| Prestige | rebirthKeeps | investors, powers, evolutions, ascension, Robux purchases, Forever Purchase pads, business name | hypothesis |  |
| Prestige | evolutionGrowth | 1000 | placeholder | UNRESOLVED. Each further evolution needs 1000x more investors. |
| Prestige | recipes | Classic, Chili, Cheese, Jalapeno, Cosmic, Void | placeholder | Hot-dog stand-ins for the fruit evolution chain (B 10:40 shows Purity+1 -> Lemon+2). Names after the 6th repeat with +n. |
| Powers | Remote Buy investor cost by tier | 2500 | placeholder | UNRESOLVED investor cost. |
| Powers | Expert Collector investor cost by tier | 800, 8000, 80000 | placeholder | Effect direction secondary; costs and multipliers UNRESOLVED. |
| Pickups | rackCapacity | 5 | placeholder | UNRESOLVED. B 06:10 shows a pickup under a tree; quantities/capacity unknown. |
| Pickups | spawnEvery | 6 | placeholder |  |
| Pickups | valueSeconds | 10 | placeholder | A crate pays 10 s of current income (min $1). |
| Pickups | pickupRange | 9 | placeholder | Server distance check in studs. |
| Phone | firstAfter | 90 | placeholder |  |
| Phone | every | 240 | placeholder |  |
| Phone | offerSeconds | [60, 300] | placeholder | Offer = current income per second x random seconds in this range. UNRESOLVED; N 09:00 shows a $296.102 trillion offer. |
| Phone | raiseStep | 1.25 | placeholder |  |
| Phone | raiseOdds | {"better": 0.5, "final": 0.3, "walk": 0.2} | placeholder |  |
| Phone | expires | 45 | placeholder |  |
| Dash | betFractions | [0.1, 0.25, 0.5] | placeholder |  |
| Dash | winPays | 2.6 | placeholder | UNRESOLVED payout; chosen so betting never makes money on average. |
| Dash | raceSeconds | 8 | placeholder |  |
| Dash | cheerBoost | 0.003 | placeholder | Each cheer in the last second adds 0.3% speed to the chosen racer (max 6 cheers/s count). Tuned so constant cheering stays below break-even (about 36% wins x 2.6 = 0.92 expected return); measured in tests/Dash.spec.luau. |
| Dash | cooldown | 30 | placeholder |  |
| Names | maxLength | 24 | placeholder |  |
| Names | minLength | 3 | placeholder |  |
