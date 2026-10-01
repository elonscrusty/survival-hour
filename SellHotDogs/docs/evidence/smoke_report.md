# Headless smoke test (Lune) results

Place: `build/SellHotDogs.rbxlx`. Runner: `lune run tools/smoke/smoke.luau` (Lune 0.10.4).
This drives the real server and client scripts from the built place with a simulated engine (signals, remotes, players). It is not a Roblox Studio playtest: no physics, rendering, real touch or network.

**91 passed, 0 failed, 0 script errors**

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
| 18 | earn to $6.20 by clicking | PASS | $7.00 after 6 more cycles |
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
| 29 | wallet is compact (200 x 42 design px) | PASS |  |
| 30 | next-unlock bar names the next purchase | PASS | Next: Bun Rack  READY! |
| 31 | sky objects, traffic and customers spawned locally | PASS | 36 local objects |
| 32 | Decor tab lists items with picture icons | PASS | 12 icon views |
| 33 | buying Flower Planters spends $250 and places it on the plot | PASS | $157.62 |
| 34 | milestone banner sent when lifetime cash passes $1,000 | PASS |  |
| 35 | reaching level 10 adds a milestone prop and banner | PASS |  |
| 36 | loaded mesh replaces the stand-ins in place (all 4 planters) | PASS | 4 meshes, 4 pieces |
| 37 | Manage panel opens (locked message before power) | PASS |  |
| 38 | Powers tab lists cards with investor and Robux buttons | PASS |  |
| 39 | red close button closes panel | PASS |  |
| 40 | mock purchase grants Manage | PASS |  |
| 41 | duplicate receipt delivery grants nothing extra | PASS |  |
| 42 | cancelled purchase grants nothing | PASS |  |
| 43 | already-owned pass not re-bought | PASS |  |
| 44 | Manage panel lists businesses once Manage is owned | PASS |  |
| 45 | remote upgrade from Manage panel works from far away | PASS | level 3 |
| 46 | Remote Buy walks the whole ladder (all 8 businesses, every pad) | PASS | 46/46 after 43 requests |
| 47 | every business building is in the world | PASS |  |
| 48 | staircase appears once everything is owned | PASS |  |
| 49 | fast production stays aggregated (client messages per second) | PASS | 9.5 msgs/s |
| 50 | wallet formats a 10^564 balance | PASS | $3e564 |
| 51 | Investors dialog shows offer | PASS |  |
| 52 | rebirth asks to confirm with resets listed | PASS |  |
| 53 | cancel keeps everything | PASS |  |
| 54 | rebirth: +20 investors, run reset, Manage (Robux) kept | PASS | investors=20 cash=$1.00 |
| 55 | plot clears after rebirth | PASS |  |
| 56 | Run Faster bought with 400 investors? (needs 400, has 20 -> rejected) | PASS |  |
| 57 | Run Faster tier 1 costs 400 investors and speeds walking | PASS | tier=1 investors=1,100 WalkSpeed=24 |
| 58 | Stack Upgrade unlocks x5 bulk | PASS |  |
| 59 | Forever Purchase token granted | PASS |  |
| 60 | Forever: nvm returns to the list without spending | PASS |  |
| 61 | Forever: Yes consumes exactly one token | PASS |  |
| 62 | Forever: no second use without a token | PASS |  |
| 63 | evolution: x1 evolution, investors and investor powers reset, Robux + Forever kept | PASS | evo=1 inv=0 runFaster=nil manage=1 forever=true |
| 64 | ascension: count 1, evolutions reset, +1 Forever token, Forever pad kept | PASS |  |
| 65 | ascension price x3.33 shows on stand pad | PASS |  |
| 66 | unsuitable name rejected by filter | PASS |  |
| 67 | too-long name rejected | PASS |  |
| 68 | filter outage fails closed | PASS |  |
| 69 | good name saved and shown on plot sign | PASS |  |
| 70 | phone offer arrives | PASS |  |
| 71 | raise flow ends in a better/final offer or a walk-away without errors | PASS |  |
| 72 | accepting pays the offered amount once | PASS | $4,682 |
| 73 | DogDash locked without the game pad | PASS |  |
| 74 | race starts and takes a 10% bet | PASS | $99.978 million |
| 75 | race finishes and settles | PASS |  |
| 76 | Studio dev hook exists | PASS |  |
| 77 | dev hook sets cash | PASS | $300,000 |
| 78 | second race running before leaving | PASS |  |
| 79 | prestige refused while a race is running | PASS |  |
| 80 | profile saved on leave | PASS |  |
| 81 | race in progress at leave is settled and saved | PASS |  |
| 82 | plot released and attribute cleared | PASS |  |
| 83 | rejoin restores progress | PASS |  |
| 84 | offline income banked for the claim popup (automated businesses only) | PASS | $83,939 |
| 85 | offline amount = 100% of automated income x elapsed | PASS | $83,939 vs $83,916 |
| 86 | offline claim pays once | PASS | gained $83,962, pending was $83,939 |
| 87 | failed load gives temporary profile with saving off | PASS |  |
| 88 | failed-load session never overwrites the stored save | PASS |  |
| 89 | failed save on leave leaves previous save intact | PASS |  |
| 90 | two players get different plots | PASS |  |
| 91 | new player starts fresh while returning player keeps progress | PASS |  |
