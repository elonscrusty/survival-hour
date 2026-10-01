# Egg Empire: reference research

The reference is the Roblox game "Egg Empire 🐣" (place 15800803561, universe 5462477948). We study it only for its functional structure. No images or assets were downloaded or saved. Video transcripts were read as text only.

Status key:
- **VERIFIED**: stated directly by a primary source (the Roblox API or game page, or the game's own UI text read aloud in a video).
- **REPORTED**: a secondhand claim, a guide claim, or something a YouTuber said or did. It may be stale or garbled by auto-captions.
- **UNKNOWN**: no evidence was found.

All sources were accessed on 2026-10-01.

## Sources

| # | URL | What it is | Result |
|---|---|---|---|
| S1 | https://games.roblox.com/v1/games?universeIds=5462477948 | Official Roblox games API (game metadata) | Loaded |
| S2 | https://apis.roblox.com/game-passes/v1/universes/5462477948/game-passes?passView=Full&pageSize=100 | Official Roblox game-pass API | Loaded (21 passes) |
| S3 | https://badges.roblox.com/v1/universes/5462477948/badges?limit=100 | Official Roblox badges API | Loaded (10 badges) |
| S4 | https://groups.roblox.com/v1/groups/5124586 | Official Roblox group API (Chickens Inc) | Loaded |
| S5 | https://games.roblox.com/v1/games/votes?universeIds=5462477948 | Roblox votes API | Loaded |
| S6 | https://www.roblox.com/games/15800803561/Egg-Empire | Game page | Loaded via WebFetch. The page text said "no running experiences"; it held the same description as S1 |
| S7 | https://rowatcher.com/games/5462477948/egg-empire | Third-party stats tracker | Loaded |
| S8 | https://tryhardguides.com/egg-empire-codes/ | Codes guide, updated 2024-08-12 | Loaded |
| S9 | https://www.destructoid.com/egg-empire-codes/ | Codes guide, updated 2024-08-12 | Loaded |
| S10 | https://earlygame.com/es/guides/codigos/egg-empire-codigos | Spanish codes guide, 2024-06-11 | Loaded |
| S11 | https://progameguides.com/roblox/egg-empire-codes/ | Codes guide | **Failed (HTTP 403)** |
| S12 | https://sportskeeda.com/roblox-news/egg-empire-codes | Codes guide | **Failed (HTTP 403)** |
| S13 | https://twinfinite.net/?p=1084054 | Codes guide | **Failed (HTTP 403)** |
| S14 | https://www.youtube.com/watch?v=oPoHd-Cuppk | "I Went NOOB To PRO In EGG EMPIRE and COMPLETED THE GAME.." by Crazyfox playz, published 2024-06-06. Auto-caption transcript and description read | Loaded |
| S15 | https://www.youtube.com/watch?v=Cn1Dh-vZd5w | "Becoming The RICHEST Chicken Farmer, Roblox Egg Empire" by Kenji Plays, a stream with an early-game walkthrough (YouTube date 2024-10-13). Auto-caption transcript read | Loaded |
| S16 | https://www.youtube.com/watch?v=bWTNwLICKjE | "Finally Getting More items Unlocked, Egg Empire" by TrickyMist, 2024-10-08. Auto-caption transcript read | Loaded |
| S17 | https://www.youtube.com/watch?v=5oxlEC-vSeY | "How fast can we Prestige?, Egg Empire" by TrickyMist, 2024-10-23. Transcript almost empty | Loaded, little content |
| -- | egg-empire.fandom.com, egg-empire-roblox.fandom.com | Fan wiki candidates | **404, no wiki found** |
| -- | Developer-products API (apis.roblox.com/developer-products/...) | Robux product list | **Refused (needs auth)** |
| -- | Group wall API | Announcements | **Refused (needs auth)** |
| -- | Web searches for "eggs list", "rebirth", "housing shack super shack", "shipping vehicles", "research epic" | Search | Only codes pages and Egg, Inc. (mobile game) pages came back. No Egg Empire wiki, Trello or Discord text was found |

Note: S14's YouTuber says Egg Empire looks like a Roblox take on the mobile game **Egg, Inc.** (REPORTED, S14). Many search hits for terms like "Shack 250 / Super Shack 500", "Epic Research" or "Vehicles" are about **Egg, Inc.**, not Egg Empire. Don't mix the two games up.

## 1. Identity and description

| Fact | Status | Source |
|---|---|---|
| Name "Egg Empire 🐣". Creator is the group "Chickens Inc" (group 5124586). The group owner is user GamingDan (@0GamingDan). The group has about 627K members | VERIFIED | S1, S4 |
| Universe created 2023-12-29. Last updated 2026-05-03 | VERIFIED | S1 |
| Genre is Simulation / Tycoon. Max 10 players per server. No private servers. Copying not allowed | VERIFIED | S1 |
| About 17.08M visits, about 85.9K favorites, 320,175 up / 4,475 down votes | VERIFIED | S1, S5 |
| 0 players at the time accessed. The tracker reports an all-time recent peak of 5 (July 2026), so the game is essentially dormant | VERIFIED (0 playing) / REPORTED (peak) | S1, S7 |
| Description (paraphrased): spawn chickens to lay eggs, sell the eggs for cash, upgrade your farm, unlock new eggs and build the biggest empire. The update section lists "Prestiging" and "Diamond Eggs". It promotes the code "200KLikes" and says the next code comes at 225K likes. It says joining the group and liking the game give in-game rewards | VERIFIED | S1 |
| Premium players get +20% Cash | VERIFIED | S1 |
| Tags: Collector, Simulator, Egg, Farm, Tycoon, Clicker, Tapping, Chicken, Pet | VERIFIED | S1 |

## 2. Currencies and HUD

| Fact | Status | Source |
|---|---|---|
| Cash is the main soft currency, earned by selling eggs | VERIFIED (description) | S1 |
| Gold Eggs ("Golden Eggs") are the premium or meta currency. They buy "Epic" upgrades (Auto Clicker and others) and come from codes, quests, daily/playtime rewards, an obby spin, and Robux | REPORTED | S8, S9, S14, S15, S16 |
| Diamond Eggs exist and arrived with the Prestige update. Their use is unknown | VERIFIED (exists) / UNKNOWN (role) | S1 |
| Eggs are a carried or stored resource that you collect and deposit. The HUD shows an egg count (for example "3,000 eggs in this car") | REPORTED | S14 |
| The chicken count is shown at the top left ("46 chickens top left") | REPORTED | S15 |
| A "cash multiplier" bar sits just above the cash bar. It rises with fast clicking (about 5.3–5.8x when clicking hard; 25x was seen once). The video reports a bug where leaving the game resets it | REPORTED | S14 |
| The exact three top HUD counters | UNKNOWN (likely chickens, cash and gold eggs, but not confirmed) | -- |

## 3. Chickens and spawning

| Fact | Status | Source |
|---|---|---|
| Click or tap the screen or the spawn button to spawn chickens. The chickens walk into housing and lay eggs | REPORTED | S14, S15 |
| "Auto Spawn" toggle (red, right side of the screen). The game asked the player to like the game and join the Chickens Inc group to unlock auto-click | REPORTED | S15 |
| The Auto Clicker Epic upgrade spawns 1 chicken per second and can be leveled up | REPORTED | S14, S15 |
| Chickens are laid out in housing. Each house adds 2 chickens per minute through an "internal hatchery" upgrade | REPORTED | S15 |
| Chicken skins (pets) are hatched from eggs and give cash multipliers (for example a 90x skin). Skins can be stacked when equipped (see the gamepasses). A "Huge chicken" counts as 5 chickens | REPORTED | S16, S2 |
| A random Fox appears and gives cash when clicked. "Fox Frenzy" gives a reward that scales with current cash, at up to about 100x | REPORTED | S14, S15, S16 |
| Random drops of boosts (for example a 10x earnings boost) | REPORTED | S14 |
| Chicken Madness upgrade: +0.1% bonus for each running chicken | REPORTED | S15 |

## 4. Housing

| Fact | Status | Source |
|---|---|---|
| The farm has several housing plots ("I could buy another house"). Each plot upgrades through tiers. You can own several houses of the same tier ("two Super Shacks") | REPORTED | S14, S15 |
| Tier names seen, in rough order: Shack, then Super Shack, then (Suburban House / two-story / townhouse, unclear), then Long House (about 30K cash in one run), then Barn (about 1M cash), and so on up to Skyscrapers, then "Military bases" and "KFC" (joke tiers), then Universe, Chicken Teleporters, and World Portal (the final tier in S14) | REPORTED (names from captions, order approximate) | S14, S15 |
| Capacities Shack 250 / Super Shack 500 / Long House 1,000 / Barn 2,000 | **UNKNOWN**: no Egg Empire source confirms them. Searches only turned up Egg, Inc. habitat data | -- |
| Housing upgrade "House Extension": +5% capacity | REPORTED | S15 |
| Gamepass "x2 Housing Capacity!" doubles how many chickens housing holds | VERIFIED | S2 |
| Exact slot count and price curve | UNKNOWN | -- |

## 5. Eggs, farms and rebirth or prestige

| Fact | Status | Source |
|---|---|---|
| Farm eggs, from the badges (created 2024-05-30 and later), in award-count order: Rainbow (2.26M awarded), then Sandcastle (1.26M), Yeti (825K), Jungle (432K), Sun (254K), Galaxy (148K), Overlord (87K), Angel (52K, added 2024-06-13) and Devil (29K, added 2024-06-27). A "Welcome!" badge also exists | VERIFIED (names and counts); order inferred from counts and matching S14 | S3 |
| The starting egg has no badge and its name is unknown (Egg, Inc. calls it "Edible", but that is unconfirmed here) | UNKNOWN | -- |
| A "Rebirth" pop-up appears when a new egg unlocks ("Unlocked a new egg! Start a new Farm to earn cash faster"). It starts, for example, a "Rainbow Egg Farm" | REPORTED (UI text heard) | S15 |
| Rebirth keeps only Epic (Gold Egg) upgrades. Cash, housing, vehicles, workers and Common upgrades reset. Each new egg sells for more | REPORTED | S14 |
| Example threshold: Galaxy Egg costs 23 Qi. The first rebirth was at about 60M | REPORTED | S14 |
| Overlord is described as "rebirth 8" in one video, and the Angel egg appears after a later rebirth | REPORTED (count conflicts by one with the badge order) | S16 |
| "Prestiging" exists (a later update). Its rules, its currency (probably Diamond Eggs) and what it resets are unknown | VERIFIED (exists) / UNKNOWN (rules) | S1, S17 |
| A "farm value" requirement formula | UNKNOWN | -- |

## 6. Shipping (vehicles) and silos

| Fact | Status | Source |
|---|---|---|
| Flow: collect eggs, deposit them at the vehicle area, and the vehicles sell the eggs for cash. Tutorial lines: "Your vehicle will sell these eggs to give you cash", "Upgrade your vehicles to sell eggs faster" | REPORTED (tutorial text read aloud) | S14, S15 |
| Fleet of several slots, each upgradable. Vehicle names seen: Transit Van (about 50K), Box Truck/"box car" (about 15M), Semi Truck, and later Supercars | REPORTED | S14, S15 |
| An upgrade adds one slot to the vehicle fleet | REPORTED | S14 |
| A late-game vehicle costs about 5 Sx each | REPORTED | S14 |
| Gamepasses "x2 Vehicle Shipping Rate!" (vehicles sell twice as fast) and "Supercars Pack!" (3 extra supercars permanently) | VERIFIED | S2 |
| Silos: "Silos allow you to earn while you're away" (offline earnings). Built with cash. There is an Epic upgrade for silo capacity | REPORTED (UI text read aloud) | S15, S14 |
| Gamepass "10 Permanent Silos!" (Pro Silo Permit) | VERIFIED | S2 |
| Vehicle capacities and exact prices | UNKNOWN | -- |

## 7. Workers

| Fact | Status | Source |
|---|---|---|
| "You can also hire workers to move eggs automatically." Workers carry eggs from the houses to the deposit | REPORTED (tutorial text) | S15, S14 |
| A "Hire Worker" panel. The captions mention "200 eggs minimum" (meaning unclear) | REPORTED | S15 |
| Worker tiers seen: Zombie, then Peasant (about 30M, also quoted at about 100K), then Lumberjack, Farmer, Builderman and Agents. "Buff Noob" costs about 1T | REPORTED (order approximate) | S14, S15 |
| The worker slot count grows with progress (for example "four Farmers") | REPORTED | S14 |
| Gamepasses "+2 Worker Slots" and "x2 Worker Capacity!" (workers carry twice the eggs) | VERIFIED | S2 |

## 8. Upgrades (Common = cash, Epic = Gold Eggs)

| Fact | Status | Source |
|---|---|---|
| Common (cash) upgrades come in tiers (tier 1, 2, 3, unlocked over time) and reset on rebirth | REPORTED | S14 |
| Common upgrade names and effects heard: Super Food, Premium Nest (more egg-laying rate), Increase Egg Value / Big Eggs (+25% egg value), Double Egg Value, Triple Egg Value, Chicken Madness (+0.1% per running chicken), Increase Max Chicken Bonus, House Extension (+5% capacity), internal hatchery (+2 chickens per minute per house), Increase Vehicle Fleet Size by 1, and a late upgrade that raises egg-laying rate and egg value by 15% | REPORTED | S14, S15 |
| Epic (Gold Egg) upgrades are kept through rebirth. Names heard: Auto Clicker (1 chicken per second, levelable), Increase Internal Hatch Rate, Lab Upgrade (lowers upgrade costs), Silo Capacity | REPORTED | S14, S15 |
| Gamepass "Cheap Upgrades!" makes all Cash upgrades 50% off | VERIFIED | S2 |
| Exact costs, max levels and cost growth | UNKNOWN | -- |

## 9. Boosts, quests, rewards and other features

| Fact | Status | Source |
|---|---|---|
| Boosts: 3x Earnings potion for 20 min, 10x Internal Hatchery for 10 min, 10x Earnings, 50x Earnings for 2 h, and "2x All Active Boosts". Up to 5 at once with VIP | REPORTED (VIP limit VERIFIED) | S14, S2 |
| Code rewards name boosts such as "x10 Earning Boost", "Housing Hatchery Boost" and "x10 all Active Boosts" | REPORTED | S9 |
| Quests with Gold Egg rewards (for example a 100 Gold Egg quest) | REPORTED | S14 |
| "Gift ready" / "Free reward to claim" with Claim All (for example "a dozen" Gold Eggs). Playtime and daily rewards | REPORTED | S15, S9 |
| Invite a friend for a 20% boost | REPORTED | S15 |
| Obby (easy and hard). Finishing it gives a spin, which gave 6 Gold Eggs once | REPORTED | S16 |
| Rocket missions: fuel each one with 1 billion eggs. A mission takes about 20 min. Up to 3 missions. Rewards include artifacts (equip 2, or 4 with a gamepass) | REPORTED (pass VERIFIED) | S16, S2 |
| Shop opens from a button on the left side. It has a Codes button at the bottom right | REPORTED | S8, S9, S10 |
| Shop tab names (Featured, Passes, Gold Eggs, Cash) | UNKNOWN (not confirmed by any source) | -- |
| Robux cash multiplier ladder in the shop: x2 for 5 R$, x5 for 19, x10 for 49, about x30 for 99, then 149, and x100 for 249 | REPORTED (approximate) | S14 |

## 10. Gamepasses (all VERIFIED, S2; Robux prices as of 2026-10-01)

| Pass | R$ | Effect |
|---|---|---|
| VIP | 249 | Use up to 5 boosts at once, VIP chat tag, "much more" |
| x2 Cash! | 249 | 2x cash |
| x2 Chickens! | 199 | Doubles the chickens you get |
| x2 Gold Eggs! | 199 | 2x Gold Eggs |
| x2 Offline Earnings! | 79 | 2x while away |
| Cheap Upgrades! | 299 | Cash upgrades 50% off |
| 10 Permanent Silos! | 249 | Build 10 silos permanently |
| Supercars Pack! | 399 | 3 extra supercars |
| +2 Worker Slots | 799 | 2 extra workers |
| x2 Housing Capacity! | 349 | Housing holds twice as many chickens |
| x2 Vehicle Shipping Rate! | 199 | Vehicles sell twice as fast |
| x2 Worker Capacity! | 249 | Workers carry twice the eggs |
| Triple Hatch! | 299 | Hatch 3 eggs at once |
| Fast Hatch! | 99 | Hatch twice as fast |
| Super Lucky! | 99 | Better hatch luck |
| +100 Skin Storage! | 129 | +100 skins |
| +500 Skin Storage! | 299 | +500 skins |
| 3 Skins Equipped! | 329 | Equip 3 skins; multipliers stack |
| +2 Artifacts Equipped! | 199 | Equip 4 artifacts instead of 2 |
| Auto Collect | not for sale | Collects and sells eggs automatically |
| Infinite Storage | not for sale | Unlimited skin storage |

Developer products (Robux one-offs): UNKNOWN. The API needs auth. S14 reports the cash-multiplier and boost purchases listed in section 9.

## 11. Codes

| Code | Reward | Status | Source |
|---|---|---|---|
| Release | 10 Gold Eggs | REPORTED (3 guides agree) | S8, S9, S10 |
| 1KLikes | 25 Gold Eggs | REPORTED (shown in-game in S14) | S8, S9, S10, S14 |
| 25KLikes | x10 all Active Boosts | REPORTED | S9 |
| 50KLikes | Conflicting: "10 Housing Hatchery Boost" (S9) or 50 Gold Eggs (S10) | REPORTED (conflict) | S9, S10 |
| Sorry4Bugs | x10 Earning Boost | REPORTED | S9 |
| 75KLikes | unspecified rewards | REPORTED | S9 |
| 100KLikes | 200 Gold Eggs | REPORTED | S9 |
| 125KLikes | 200 Gold Eggs (S9) or 250 Gold Eggs (search snippet) | REPORTED (conflict) | S9 |
| 150KLikes | unspecified | REPORTED | S8 |
| Nearly200K | 200 Gold Eggs | REPORTED | S9 |
| 175KLikes | 150 Gold Eggs | REPORTED | S9 |
| 200KLikes | 2 x10 Earning Boosts. Still promoted in the game description | VERIFIED (code exists) / REPORTED (reward) | S1, S9 |

Redemption: Shop button (left), then Codes at the bottom right, type into the "Enter Code" box, then Redeem. You must finish the tutorial first (S10). One guide calls the button "ABX Codes", which is probably a scrape artifact. In-game success or error messages: UNKNOWN.

## Unknown / missing evidence

- Exact housing capacities, slot counts and prices. The 250/500/1,000/2,000 numbers are **not** confirmed for Egg Empire and may come from Egg, Inc.
- Vehicle capacities and prices, and the exact worker tier list and prices.
- Name of the starting egg, egg sale values, and the farm-value or rebirth-threshold formula (only the "about 60M first rebirth" and "Galaxy 23 Qi" anecdotes exist).
- How Prestige works: its currency (probably Diamond Eggs), what it resets and what it grants.
- Starting cash, base laying rate, base sell price and the cost-growth multipliers.
- Full Common/Epic upgrade list with numbers. Names come only from auto-captions and may be misheard.
- Shop tab names. Daily reward schedule. Quest list. Exact boost list and durations beyond the anecdotes.
- Developer products (Robux) list and prices.
- In-game text for code redemption (success, invalid, already used).
- What the three top HUD counters are.
- Official update log, Discord or Trello content: none found publicly. Several guide sites (progameguides, sportskeeda, twinfinite) returned 403.
