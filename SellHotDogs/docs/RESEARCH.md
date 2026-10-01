# Research register

## What this session could and could not inspect (2026-10-01)

Environment: a Linux cloud container whose egress proxy **blocked** youtube.com, i.ytimg.com, roblox.com (games/catalog APIs), create.roblox.com, sell-lemons-roblox.fandom.com, bloxodes.com and other guide sites. These failed with `CONNECT tunnel failed, response 403` or the fetch tool's `EGRESS_BLOCKED` error.

- **No footage was watched in this session.** Every footage-based value comes from the earlier research supplied in the handoff and is attributed to it. It is not re-verified.
- **Web search summaries** (search-engine snippets, not page loads) were available. They were used only to collect **secondary** claims, and each one is labelled `secondary` in the catalog.
- The Roblox Studio MCP server configured for this session failed to start (`cmd.exe` not found: it is a Windows tool). Studio was not reachable.
- The earlier research folder on Carter's PC (`C:\Users\myson\Documents\Codex\2026-10-01\task\Sell Hot Dogs`) is not reachable from here. Its files (`source-evidence-*.md`, contact sheets, extraction manifests, the design spec) should be kept with this project on Carter's PC. They were not copied into the ZIP because they hold reference footage frames.

## Sources

| id | source | used for | status |
|---|---|---|---|
| N | narrow, "Roblox Sell Lemons..", 2026-06-10, 765 s: https://www.youtube.com/watch?v=IJB1f-o7_bk | opening cycle, stand prices, upgrade labels, Floor price, phone final offer (09:00), name editing (10:00), DogDash pad (03:20) | directly observed **by the supplied research** |
| B | Bemmy, "Spending $5000 ROBUX on TIME SKIPS in SELL LEMONS??", 2026-06-25, 806 s: https://www.youtube.com/watch?v=Vu0A1VN1KTs | Robux displays (00:10, 02:10, 11:40), reset warning (01:40), Forever targets (04:40, 05:10), pickup (06:10), phone (07:10), evolution UI (10:40), investors (11:40) | directly observed **by the supplied research** |
| D | https://www.roblox.com/games/79268393072444/Sell-Lemons (place 79268393072444, universe 7395930870) | "100% offline income" description claim | description claim |
| W-* | fandom wiki pages (Lemon_Stand, LemonDash, Income_Sources, Lemon_Depot, Rebirth, Evolution, Ascension, Powers, Robux, Minigames); allthings.how, sportskeeda, techwiser, bloxron guides | business unlock and manager prices, later upgrade lists, rebirth/evolution/ascension rules, powers, minigame shape, phone behaviour | **secondary** (from 2026-10-01 search summaries; pages could not be opened) |

## Timestamped observations relied on (from the supplied research)

| source & time | observation | units / state | confidence |
|---|---|---|---|
| N 00:15 | wallet $1.00 visible | balance, early | medium (start cash unverified) |
| N 00:33.9 | stand label $1.00, CLICK, wallet $3.00, Juicer + Cash Register pads unbought | $ per cycle | high |
| N 00:34.0–00:35.0 | countdown 1s, 0.8s, 0.6s, 0.4s, 0.2s, CLICK | displayed seconds | high |
| N 00:35.0–00:35.4 | wallet animates $3.24 → $3.79 → $3.99 → $4.00 | animated HUD, not a ledger | high (as display) |
| N 00:29 / 00:35 / 00:47.6 | stand upgrade $5.10 | $ | high |
| N 00:48.2 | upgrade $7.65, yellow x1; stand $3.81 | $ | medium (label animating) |
| N 00:48.4–00:48.6 | upgrade $11.00, x2; stand $5.84 | $ | high |
| N 00:58–01:01 | stand $17.51 → $24.26; upgrade $19.00, x3; Cup Stand owned | $ | high |
| N 00:36–00:38, 00:47 | Juicer $6.20, x2 cash; stand then $2.00 | $ | high |
| N 00:55–00:57, 04:10 | Cup Stand $82.50, x3 cash | $ | high |
| N 00:35, 01:04–01:06 | Cash Register $100, automates | $ | high |
| N 01:03 | Billboard $785, x3 speed | $ | high |
| N 02:10 | Floor $19,500 | $ | high |
| N 02:40, 04:10 | stand $4,772 (0.3 s left); $18,816 with x8 badge | progression checkpoints | high (as snapshots) |
| N 03:20 | locked "Lemon Dash the Game" pad | UI | high |
| N 09:00 | final offer / no deal / goodbye; $296.102 trillion offer | phone | high |
| N 10:00 | business name editing | UI | high |
| B 00:10 | Expert Picker checkout 135 Robux (Plus savings); Forever Purchase card 1,350 Robux | creator's dated checkout | high (as display) |
| B 01:40 | warning: most progress incl. investors and powers resets; Robux purchases safe | evolution reset | high |
| B 02:10 | Cash – 24 Hours card 135 Robux; Cash – 7 Days checkout 180 Robux | creator's dated display | high (as display) |
| B 04:40, 05:10 | Forever Purchase targets "Exterior Displays", "Experimental Testing"; Yes / nvm / close / Cancel | UI flow | high |
| B 06:10 | pickup effect under a fruit tree | UI | high |
| B 07:10 | phone with three choices | UI | high |
| B 10:40 | each evolution x42 income speed; 75%; Purity+1 evo 19 → Lemon+2 evo 20 | late-game state | high (as display) |
| B 11:40 | +32% cash per investor; 2.85 nonagintillion held; 939.807 nonagintillion offered; x2 Investors 630 Robux | late-game state | high (as display) |

## Interpretations made here (hypotheses, all in the catalog)

- **H-BADGE**: the yellow xN badge next to the stand upgrade counts the level upgrades already bought (x1 at the 2nd upgrade, x3 at the 4th). Not verified. The x8 badge at N 04:10 fits it.
- **Per-level output**: dividing stand labels by the installed cash multipliers gives 1.00, 1.905, 2.92 and 4.043 for levels 1–4. Two independent reads agree on level 3 (5.84 / 2 and 17.51 / 6). Beyond level 4 the output is a labelled placeholder.
- **Pad order**: each upgrade pad needs the previous one. This fits the opening, where Juicer and Register are visible first. The real unlock graph is unverified.
- **Start cash $1** and **stand unlock $1** are consistent with N 00:15 and the wiki. A clean new-player start was not observed.

## Open questions that need footage or the live game

1. Stand level-upgrade cost and output for levels 5+ (and whether bulk/milestone rules exist).
2. Base output and cycle time of every business after the stand.
3. Full pad list and prices for Trading, Labs, Robotics, Republic and HotDogX (and the conflicting Depot "Bigger Fleet $21,500" / Trading "Expert Brokers" prices that sit below the unlock price).
4. Investor award formula, the per-investor bonus growth (1% vs the +32% seen late), and evolution thresholds after the first.
5. Pickup capacity, spawn rate and value; phone offer timing, odds and amount rule; DogDash gate price, bet sizes and payout.
6. Power tier costs and caps (Run Faster, Stack, Expert Picker), Remote Buy cost, when Max bulk unlocks.
7. Whether offline income has a cap or a claim flow, and what time it counts.
8. Current Robux catalog, product types and prices for Carter's account and region.
