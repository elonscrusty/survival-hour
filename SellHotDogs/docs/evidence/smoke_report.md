# Headless smoke test (Lune) results

Place: `build/SellHotDogs.rbxlx`. Runner: `lune run tools/smoke/smoke.luau` (Lune 0.10.4).
This drives the real server and client scripts from the built place with a simulated engine (signals, remotes, players). It is not a Roblox Studio playtest: no physics, rendering, real touch or network.

**83 passed, 0 failed, 0 script errors**

| # | check | result | detail |
|---|---|---|---|
| 1 | server boots | PASS |  |
| 2 | plots built | PASS | 4 plots |
| 3 | profile loads (mock storage) | PASS |  |
| 4 | client boots and builds UI | PASS |  |
| 5 | client receives state | PASS |  |
| 6 | player assigned a plot | PASS | Plot1 |
| 7 | clean start cash is $1.00 (hypothesis) | PASS | $1.00 |
| 8 | stand unlock pad visible at start | PASS |  |
| 9 | buy Hot Dog Stand for $1 by stepping on pad | PASS | $0.00 |
| 10 | stand building appears | PASS |  |
| 11 | Condiment Station and Cash Register pads appear | PASS |  |
| 12 | Bun Rack pad still hidden | PASS |  |
| 13 | stand world controls exist | PASS |  |
| 14 | CLICK bar found | PASS |  |
| 15 | one-second manual cycle pays $1.00 after it completes | PASS | mid=$0.00 end=$1.00 |
| 16 | wallet shows server cash | PASS |  |
| 17 | repeated clicks during a cycle pay once | PASS | $2.00 |
| 18 | earn to $6.20 by clicking | PASS | $7.00 after 7 more cycles |
| 19 | Condiment Station costs $6.20 exactly | PASS | $7.00 -> $0.80 |
| 20 | stand output label now $2.00 | PASS |  |
| 21 | unaffordable Cash Register rejected, cash unchanged | PASS |  |
| 22 | blue Upgrade costs $5.10 (observed) | PASS | $1.70 |
| 23 | invalid requests change nothing | PASS |  |
| 24 | simultaneous purchase requests deduct once | PASS | $150.00 |
| 25 | Cash Register prop appears | PASS |  |
| 26 | register automates (no clicks needed) | PASS | $150.00 -> $157.62 |
| 27 | ingredient crate spawns at a rack | PASS |  |
| 28 | pickup: far touch ignored, near touch pays once | PASS | stats.pickups=1 |
| 29 | Manage panel opens (locked message before power) | PASS |  |
| 30 | Powers tab lists cards with investor and Robux buttons | PASS |  |
| 31 | red close button closes panel | PASS |  |
| 32 | mock purchase grants Manage | PASS |  |
| 33 | duplicate receipt delivery grants nothing extra | PASS |  |
| 34 | cancelled purchase grants nothing | PASS |  |
| 35 | already-owned pass not re-bought | PASS |  |
| 36 | Manage panel lists businesses once Manage is owned | PASS |  |
| 37 | remote upgrade from Manage panel works from far away | PASS | level 3 |
| 38 | Remote Buy walks the whole ladder (all 8 businesses, every pad) | PASS | 46/46 after 43 requests |
| 39 | every business building is in the world | PASS |  |
| 40 | staircase appears once everything is owned | PASS |  |
| 41 | fast production stays aggregated (client messages per second) | PASS | 9.0 msgs/s |
| 42 | wallet formats a 10^564 balance | PASS | $3e564 |
| 43 | Investors dialog shows offer | PASS |  |
| 44 | rebirth asks to confirm with resets listed | PASS |  |
| 45 | cancel keeps everything | PASS |  |
| 46 | rebirth: +20 investors, run reset, Manage (Robux) kept | PASS | investors=20 cash=$1.00 |
| 47 | plot clears after rebirth | PASS |  |
| 48 | Run Faster bought with 400 investors? (needs 400, has 20 -> rejected) | PASS |  |
| 49 | Run Faster tier 1 costs 400 investors and speeds walking | PASS | tier=1 investors=1,100 WalkSpeed=24 |
| 50 | Stack Upgrade unlocks x5 bulk | PASS |  |
| 51 | Forever Purchase token granted | PASS |  |
| 52 | Forever: nvm returns to the list without spending | PASS |  |
| 53 | Forever: Yes consumes exactly one token | PASS |  |
| 54 | Forever: no second use without a token | PASS |  |
| 55 | evolution: x1 evolution, investors and investor powers reset, Robux + Forever kept | PASS | evo=1 inv=0 runFaster=nil manage=1 forever=true |
| 56 | ascension: count 1, evolutions reset, +1 Forever token, Forever pad kept | PASS |  |
| 57 | ascension price x3.33 shows on stand pad | PASS |  |
| 58 | unsuitable name rejected by filter | PASS |  |
| 59 | too-long name rejected | PASS |  |
| 60 | filter outage fails closed | PASS |  |
| 61 | good name saved and shown on plot sign | PASS |  |
| 62 | phone offer arrives | PASS |  |
| 63 | raise flow ends in a better/final offer or a walk-away without errors | PASS |  |
| 64 | accepting pays the offered amount once | PASS | $5,822 |
| 65 | DogDash locked without the game pad | PASS |  |
| 66 | race starts and takes a 10% bet | PASS | $99.978 million |
| 67 | race finishes and settles | PASS |  |
| 68 | Studio dev hook exists | PASS |  |
| 69 | dev hook sets cash | PASS | $300,000 |
| 70 | second race running before leaving | PASS |  |
| 71 | prestige refused while a race is running | PASS |  |
| 72 | profile saved on leave | PASS |  |
| 73 | race in progress at leave is settled and saved | PASS |  |
| 74 | plot released and attribute cleared | PASS |  |
| 75 | rejoin restores progress | PASS |  |
| 76 | offline income banked for the claim popup (automated businesses only) | PASS | $83,939 |
| 77 | offline amount = 100% of automated income x elapsed | PASS | $83,939 vs $83,916 |
| 78 | offline claim pays once | PASS | gained $83,962, pending was $83,939 |
| 79 | failed load gives temporary profile with saving off | PASS |  |
| 80 | failed-load session never overwrites the stored save | PASS |  |
| 81 | failed save on leave leaves previous save intact | PASS |  |
| 82 | two players get different plots | PASS |  |
| 83 | new player starts fresh while returning player keeps progress | PASS |  |
