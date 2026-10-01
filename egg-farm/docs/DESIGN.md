# Egg Farm design decisions

Egg Farm keeps the *functional structure* of the reference (Egg Empire): a third-person walk-around
farm where you spawn chickens, collect eggs from housing, carry them to a warehouse, and vehicles
sell them. Every name, number, model, icon and sound is original. Where the reference's exact
behaviour is unknown (most numbers: see `REFERENCE_RESEARCH.md`), the game uses **DESIGN values**,
labelled as such in each `src/shared/Data/*.luau` header. Nothing here claims to match the
reference's balance.

## Core loop (state transitions)
Each step is a separate, server-validated transition. Eggs are whole numbers and are conserved:
`laid = in houses + carried + warehouse + on workers + on vehicles + sold + discarded`
(tested by random fuzzing in `tests/Conservation.spec.luau`).

| Step | Trigger | Rule |
|---|---|---|
| Spawn | SPAWN button (tap, or hold to repeat ~8/s), E/F key, Auto Spawn, Coop Hatchery | +`spawnPerTap` chickens per accepted tap, capped by total housing capacity ("Housing full!"). Rate-limited on the server. |
| Lay | server tick (4 Hz) | each house lays `occupants x layRate` (0.1 egg/chicken/s base) into its own storage until full (`capacity x 8` eggs, more with Roomy Nest Boxes). A full house stops laying ("FULL" bubble). |
| Collect | standing in a house's ring (server distance check) | moves `min(stored, free basket space)` into the basket (100 eggs base). |
| Deposit | standing in the warehouse ring | moves the whole basket into the warehouse (shipping stock). |
| Ship | server tick | an idle vehicle at the dock loads from the warehouse; it leaves when full or after 3 s with a partial load; the sale happens halfway through its trip; it then drives back. |
| Sell | vehicle halfway point | cash += eggs x egg value x sale multipliers x Cash Multiplier (tap combo). |
| Workers | server tick | each worker picks up from the fullest house halfway through its cycle and drops at the warehouse at the end. |

Population is a plain number; there is no physics object per chicken. The flock you see is a
bounded client-side sample (see "Visual cap" below).

## Currencies and HUD
- **Chickens** (population / capacity), **Cash**, **Gold Eggs**: the three top counters. The reference's exact three counters are unconfirmed; these are the three quantities the reference footage and guides mention most.
- **Star Eggs**: earned by Prestige; +5% cash each, forever. (The reference added "Diamond Eggs" with Prestige; their use is unknown, so this is a DESIGN stand-in under an original name.)
- **Cash Multiplier**: every accepted Spawn tap adds +0.08 (cap x5, +1 per Combo Master level); it decays 0.75/s after 1.5 s without taps. It multiplies sales. Session-only by design (the reference reportedly loses it on leaving; we make that explicit rather than calling it a bug).
- Roblox Premium members get +20% cash (stated on the reference's game page).

## Progression
- 10 eggs (Farm Egg ... Sunburst Egg), each its own themed farm. Egg value x40 per egg; cash prices x30 per egg.
- **Farm Value** = cash on hand + cash spent on this farm. When it reaches the egg's goal, **REBIRTH** starts the next egg's farm.
- **SKIP** (DESIGN): from 25% of the goal you may pay Gold Eggs to rebirth early: `ceil((1 - value/goal) x 30 x egg#)`.
- **PRESTIGE** (DESIGN): on the last egg at its goal, start over at egg 1 and gain `10 + 5 x prestiges` Star Eggs.
- Rebirth grants Gold Eggs (`15 x new egg#`, doubled by the x2 Gold Eggs pass).

### What a new farm resets (single source: `State.RESET_FIELDS` / `KEPT_FIELDS`)
| Reset on rebirth / skip / prestige | Kept |
|---|---|
| cash, chickens, hatch progress, Farm Value spending, houses (back to one Little Coop), basket, warehouse, vehicles (back to one Farm Pickup), workers, silos, Common upgrades | Gold Eggs, Star Eggs, Epic upgrades, boosts (inventory and running), quests/daily/gift progress, redeemed codes, settings, tutorial, passes, purchase receipts, pending offline cash, lifetime stats |
Eggs still on the farm are recorded as "discarded" so the egg ledger stays exact. The reference
reportedly keeps only Epic upgrades through rebirth; that matches this table.

## Pacing (tools/sim.luau)
A plain greedy bot (no boosts, passes, quests or Robux; walks a collection loop every 25 s, taps
5/s, Auto Spawn on) reaches each egg in: 23, 26, 30, 35, 41, 43, 52, 57, 59 minutes, and Prestige
after ~7.2 hours. Re-run after changing numbers: `luau tools/sim.luau [walkSeconds]`.

## Rewards and timing
All timing uses the server clock (`workspace:GetServerTimeNow()`); clients never send times.
- Quests: 5 per UTC day from a rotating pool; progress counts from that day; each claim once.
- Daily: one claim per UTC day; consecutive days build a 7-day ladder (day 7 repeats); a missed day restarts the streak.
- Gifts: 6 playtime gifts per UTC day (3, 8, 15, 25, 40, 60 min of server-counted playtime), Claim / Claim All.
- Boosts: inventory items. Using one starts it on server real time (it keeps running while you're offline and survives rejoining). Using the same boost again adds its duration (max 6 h). Up to 3 different boosts at once (5 with VIP). Different boosts multiply; Boost Booster doubles the bonus part of the others.
- Codes: server-only table (`src/server/Data/Codes.luau`), case-insensitive, once per player, need the tutorial finished. Responses: redeemed, doesn't exist, already redeemed, expired, finish the tutorial first, slow down.
- Offline: only **silos** earn while you are away (reported for the reference). Each silo covers 30 min (+15 per Silo Capacity level) at 50% of the farm's steady rate (laying limited by shipping, no boosts). Paid out through a "Welcome back" claim. The farm itself does not run while you are offline.
- Lucky Fox (reported for the reference): appears every 2.5-5 min at your farm for 40 s; catching it pays 30-120 s of earnings.

## Visual cap (flock)
See the Flock module header (`src/shared/Logic/Flock.luau`) for exact numbers. The rendered flock
is a representative sample that grows with population and never limits the real population or
production. Other players' plots show fewer chickens and only within view distance.

## Security model
- The client only names intents (`FarmAction`). Prices, rewards and balances are computed on the server from shared rules.
- Every action: type allow-list, numeric validation (no NaN/inf/negatives/fractions), id/text validation, per-player rate limit, `seq` replay rejection, `expect` level check (double taps and stale menus can't buy twice), affordability and prerequisites. Handlers never yield, so each one is atomic.
- Collect/deposit/fox are triggered by the server from the character's position on the player's own plot; there is no client remote for them.
- Robux receipts are idempotent per purchase id and only acknowledged after a save that contains them.
- Saves: ProfileStore session locks; failed/conflicting loads kick instead of creating a default profile; migrations run on a copy; newer-version saves are refused.

## Not implemented (reference features outside this build)
Chicken skins / hatching / skin storage, artifacts and rocket missions, the obby and its spin,
invite-friend boost, group/like rewards for Auto Spawn. They are listed in `REFERENCE_COVERAGE.md`.
