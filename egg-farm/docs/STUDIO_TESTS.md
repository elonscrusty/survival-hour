# Studio playtest checklist (first real run)

Nothing has been run in Roblox Studio yet. Use `build/EggFarm.Test.rbxlx` (memory saves, simulated
checkout, F8 DEV panel). Keep the Output window open (View → Output) and note every red error.
Tick each line; write what you saw if it differs.

## 0. Identify the place
- [ ] File → Open from File → `egg-farm/build/EggFarm.Test.rbxlx`. Title bar shows that file name.
- [ ] Explorer: `ServerScriptService` has `Server`, `Vendor`, `TestHarness`; `ReplicatedStorage` has `Shared`, `TestFixtures`.
- [ ] Play: Output prints `[EggFarm] TEST PLACE: in-memory saves, simulated checkout.`

## 1. Fresh tutorial (1 player)
- [ ] You spawn on a farm (not the hub) with one coop, a warehouse and a pickup at the dock.
- [ ] Only SPAWN (and the tutorial text) is visible at first.
- [ ] Tap SPAWN 20 times: chicken counter rises, chickens appear around the coop, Cash Multiplier above SPAWN climbs and then falls back.
- [ ] Hold SPAWN: repeats; at 100 chickens it says housing is full.
- [ ] Walk into the coop's ring: basket counter fills, "+N eggs" pops up.
- [ ] Walk into the warehouse ring: basket empties, warehouse fills; the pickup loads, drives off along the road and returns; cash pops up and increases.
- [ ] Tutorial asks to upgrade the vehicle: the Shipping board at the dock (E) or the Farm button opens Shipping; upgrade to Delivery Van; the model changes.
- [ ] Reach $500, then upgrade housing (board at the coop, E): Twin Coop model appears.
- [ ] Tutorial finishes; left (Shop, Eggs, Quests) and right (Settings, Daily, Boosts) buttons, Gift and Auto Spawn appear.

## 2. Every menu route
For each: opens, tabs switch, list scrolls (mouse wheel + touch drag), close X works, Backspace closes, nothing behind it is clickable, SPAWN is disabled while open.
- [ ] Shop: Featured, Passes, Gold Eggs, Cash; Codes button opens Codes.
- [ ] Codes: `EGGFARM` → success (+25 Gold Eggs); again → already redeemed; `NOPE` → doesn't exist; `TESTEXPIRED` → expired; 7 quick tries → "Too many code attempts".
- [ ] Eggs: current/next egg, Farm Value bar, SKIP (disabled + reason early), REBIRTH disabled until the goal.
- [ ] Quests (progress bars move live), Daily (claim once; claim again says already), Gifts (timers; Claim All), Boosts (BOOSTS and SHOP tabs).
- [ ] Farm: Housing / Shipping / Workers / Silos tabs. Upgrades: COMMON / EPIC.
- [ ] Settings: toggle each; leave and rejoin (DEV → Kick) → settings kept.
- [ ] Opening a second menu replaces the first; a confirm dialog sits on top of a menu; only one at a time.

## 3. Purchase states
- [ ] An unaffordable button looks disabled and says why when tapped; it becomes active the moment cash is enough.
- [ ] Double-tap Upgrade quickly: charged once.
- [ ] Locked tiers say they unlock on a later egg; maxed items say MAX.
- [ ] Shop → a Robux item → DEV checkout success/cancel/fail → loading, then the matching result; success grants (e.g. Gold Egg count rises; pass shows OWNED).

## 4. Workers, silos, fox, boosts
- [ ] Hire a worker: an NPC walks between houses and the warehouse carrying a crate; warehouse fills without you.
- [ ] Build a silo; DEV → Simulate 2h offline → "Welcome back" modal pays cash.
- [ ] DEV → Spawn Lucky Fox → walk to it → "Catch!" pays cash.
- [ ] DEV → All boosts → use Cash x3: timer counts down; sale popups are 3x larger; DEV → Fast-forward past 20 min → boost ends.

## 5. Progression
- [ ] DEV → Jump to egg 2 (sets cash to the goal) → Eggs → REBIRTH → confirm lists reset/kept → new farm: theme colours change, one coop + pickup, Gold Eggs and Epic upgrades kept.
- [ ] DEV → Jump to egg 10 → PRESTIGE → back to egg 1 with Star Eggs.
- [ ] DEV → Max current farm: big buildings appear; chicken visuals stay bounded (Settings → flock low/normal/high changes the count); frame rate stays smooth.

## 6. Saves and reconnect
- [ ] DEV → Kick → rejoin: farm restored (same server only; test saves are memory).
- [ ] DEV → Fail next load → Kick → rejoin: you are kicked with "couldn't load your farm safely"; rejoin again: farm intact.

## 7. Two players
- [ ] Test → Clients and Servers → 2 players. Each gets a different plot.
- [ ] Player 1 stands in Player 2's rings: nothing is collected; Player 2's boards show no prompts to Player 1.
- [ ] Each sees the other's flock (fewer chickens) and buildings.

## 8. Mobile layout
- [ ] Studio Device emulator: iPhone SE/small Android portrait and landscape, a tablet. HUD fits the safe area, text readable, buttons ≥ thumb size, menus scroll, nothing overlaps the thumbstick/jump button.
- [ ] Long numbers (DEV + Cash several times) stay short ("1.23Qa").

## 9. Production place sanity
- [ ] Open `build/EggFarm.rbxlx`: no TestHarness/DEV panel. Output shows ProfileStore's line about API access. Without access it says data will not be saved and the game still plays (ProfileStore's own temporary store). Publishing and enabling API access are your decisions; real DataStore saving is only validated after that.
