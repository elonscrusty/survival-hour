# Reference coverage checklist

Reference: Egg Empire (Roblox place 15800803561). Evidence codes refer to `REFERENCE_RESEARCH.md`
sources (S1-S17). "Footage" times are the capture points the owner listed for
https://www.youtube.com/watch?v=oPoHd-Cuppk (S14); this environment could only read that video's
auto-caption transcript, not watch it, so footage-based items are REPORTED, not visually verified.
The reference had 0 live players when checked (S1), and no Roblox client or Studio was available
here, so **no item was verified by playing the reference**.

Status key. Reference: V = verified (primary source), R = reported (guide/transcript), U = unknown.
Implementation: Done / Design (implemented with our own rule because the reference rule is
unknown) / Not done. Tests: Unit = CLI unit tests on the real modules; Headless = offline mock run
(`docs/HEADLESS_RESULTS.md`); Studio = not run (Studio unavailable).

## Screens, tabs and HUD
| Item | Ref | Evidence | Implementation | Tests |
|---|---|---|---|---|
| Three top counters | U (likely chickens/cash/gold) | S15 "chickens top left" | Done: Chickens, Cash, Gold Eggs | Headless; Studio not run |
| Left nav Shop / Eggs / Quests | R | S8-S10 (Shop on the left), owner brief | Done | Headless |
| Right nav Settings / Daily / Boosts | U (owner brief) | owner brief | Done | Headless |
| Gift / reward access ("Gift ready", Claim All) | R | S15, S9 | Done (6 playtime gifts, Claim All) | Unit + Headless |
| Auto Spawn toggle (right side) | R | S15 | Done (after tutorial; reference's like/group unlock not reproduced) | Unit |
| Big red Spawn button | R | S14/S15 (tap to spawn), owner brief | Done (tap, hold, F key / R2) | Unit + Headless |
| Cash Multiplier above Spawn, rises with fast taps | R | S14 | Done (x1-x5, decays) | Unit |
| Shop tabs Featured / Passes / Gold Eggs / Cash | U (owner brief) | owner brief | Done | Headless |
| Codes button in Shop (bottom right), Enter Code, Redeem | R | S8-S10 | Done | Unit + Headless |
| Code responses (success/invalid/used/expired/tutorial) | U (texts unknown) | S10 (tutorial needed) | Design texts | Unit |
| Eggs panel: current/next egg, Farm Value, progress, SKIP, REBIRTH | R (rebirth popup S15) / owner brief | S14, S15, footage 230-335 s | Done; SKIP rule Design | Unit + Headless |
| Quests list, progress, claim | R | S14, footage 230-335 s | Done (5/day rotating, Design) | Unit |
| Boosts BOOSTS / SHOP tabs, Use, timers | R | S14, footage 230-335 s | Done | Unit |
| Housing slots, capacities, upgrades | R | S14/S15, footage 420-615 s | Done (4 slots, 10 tiers, Design numbers) | Unit + Headless |
| Shipping tiers, fleet slots | R | S14/S15 | Done (8 tiers, 4+4 slots) | Unit |
| Workers tiers/slots | R | S14/S15 | Done (8 tiers, 2-8 slots) | Unit |
| Common / EPIC upgrade pages | R | S14/S15, footage 140-195 s | Done (14 Common, 8 Epic) | Unit |
| Settings contents | U | none | Design (music, sfx, effects, auto spawn, confirm spend, flock detail, notation) | Unit |
| Daily rewards | R (exists) | S9, S15 | Design 7-day ladder | Unit |
| Confirmation dialogs (rebirth/skip/prestige/gold spend) | U | none | Done | Headless |
| Tutorial overlay with progressive reveal | R (lines heard) | S14/S15, footage 0-80 s | Done (7 steps) | Unit + Headless |
| Paid-flow confirmation structure | U | not captured (no purchase made, by rule) | Roblox's own purchase prompt + our loading/result states; test checkout simulator | Unit + Headless |

## Actions, rules and progression
| Item | Ref | Evidence | Implementation | Tests |
|---|---|---|---|---|
| Spawn chickens into housing | R | S14/S15 | Done | Unit |
| Housing holds chickens; capacity limits spawning | R | S14, S2 (x2 Housing Capacity pass) | Done | Unit |
| Hens lay eggs into housing | R | S14 | Done (storage per house is Design) | Unit |
| Walk to housing to collect eggs | R | footage 0-80 s, S15 | Done (server ring check) | Unit + Headless |
| Walk to warehouse to deposit | R | S14/S15 | Done | Unit + Headless |
| Vehicles sell deposited eggs | R | S14/S15 tutorial text | Done | Unit |
| Workers move eggs automatically | R | S15 tutorial text | Done | Unit |
| Silos give offline earnings | R | S15 UI text, S2 pass | Done (Design numbers; reset on rebirth inferred) | Unit |
| Internal hatchery (+chickens/min per house) | R | S15 | Done (Coop Hatchery) | Unit |
| Auto Clicker Epic (1 chicken/s per level) | R | S14/S15 | Done | Unit |
| Egg sequence with themed farms | V (badge names) | S3 | Done with ORIGINAL names/themes (10 eggs) | Unit |
| Rebirth keeps only Epic upgrades | R | S14 | Done (plus currencies/boosts/rewards kept; table in DESIGN.md) | Unit |
| Prestige | V (exists) / U (rules) | S1 | Design (Star Eggs) | Unit |
| Diamond Eggs | V (exists) / U (role) | S1 | Not reproduced; Star Eggs is a Design stand-in | n/a |
| Premium +20% cash | V | S1 | Done | Unit (via ctx) |
| Boost stacking / VIP 5 active | R / V | S14, S2 | Done (3 active, 5 VIP) | Unit |
| Lucky Fox | R | S14-S16 | Done (Design reward) | Headless |
| Gamepass categories | V | S2 | Our own 11 passes, no IDs configured | Unit |
| Developer products | U | API needs auth | Our own Gold/Cash packs, no IDs configured | Unit |
| Codes list | R | S8-S10 | Our own codes (EGGFARM, WELCOME, HATCHED); reference codes not reused | Unit |
| Starting balances, prices, cost growth, capacities, rates | U | none | Design (tuned with tools/sim.luau) | Unit + sim |
| Skins / hatching / Triple-Fast-Lucky hatch | V (passes) / R | S2, S16 | **Not done** | n/a |
| Artifacts, rocket missions | R | S16, S2 | **Not done** | n/a |
| Obby + spin | R | S16 | **Not done** | n/a |
| Invite friend boost, like/group rewards | R | S15, S1 | **Not done** | n/a |

## Missing evidence (needed before claiming parity)
- Live inspection or current footage of every menu (the game is dormant; no client here).
- Any real number: capacities, prices, growth, production, shipping timing, egg values, farm value formula.
- SKIP, Prestige and Diamond Egg rules; the starting egg's name; the three top counters.
- Settings contents, daily ladder, quest list, boost list and durations, code response texts.
- Developer product list (API needs authorisation, not requested).

**Parity is not claimed.** The build reproduces the verified/reported structure with original
content and clearly labelled design values.
