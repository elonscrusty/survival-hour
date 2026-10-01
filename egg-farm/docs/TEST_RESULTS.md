# Test results

Run on 2026-10-01 in the cloud build environment (Linux, no Roblox Studio). Three layers, from
most to least trustworthy about real Roblox behaviour. **None of them is a Studio playtest**.
The first real run should follow `docs/STUDIO_TESTS.md`.

## 1. Unit tests (Luau CLI, real modules): 141 passed, 0 failed
`bash tools/check.sh` = type check (luau-lsp 1.53.0 with Roblox definitions, zero diagnostics) +
unit tests + Rojo builds of both places (both ok).

| Spec | Tests | Covers |
|---|---|---|
| Economy | 20 | starting state, spawn cap, laying/storage, collect/deposit, vehicles (load, wait, sell, return), single charges, slots in order, unlock tiers, max level, fleet permit, workers, Common/Epic effects, Auto Spawn, Cash Multiplier, plain-data snapshot |
| Conservation | 6 | egg ledger exact under 3 x 3,000 random interleaved actions incl. rebirths; collect during ticks; sale = eggs x value; rebirth discards |
| Validation | 8 | garbage actions, NaN/inf/negative/fraction/strings in every slot action, bad ids/text, typed settings, replayed `seq`, client-sent prices ignored, repeated purchase charged once, every state field in exactly one reset/keep list |
| Progression | 8 | rebirth requirement, exact reset/keep, applied once, SKIP rules, prestige, Star Egg bonus, egg steps |
| Rewards | 9 | quest claim once, off-day quests, UTC day reset, daily once/streak/day-7 repeat, client clock ignored, playtime gifts and Claim All, x2 Gold pass, cash rewards scale |
| Boosts | 6 | inventory, activation, stacking cap, active limit/VIP, expiry on server time across a reconnect, Boost Booster |
| Codes | 5 | tutorial gate, case-insensitive once, invalid/expired/oversized, no server table, shipped codes well-formed |
| Commerce | 7 | no Robux IDs shipped, receipt idempotency, passes, gold-only items refused, gold shop, test checkout success/cancel/fail, receipt trimming |
| Persistence | 7 | memory adapter: new profile, failed load gives no profile, session conflict, stale-lock steal keeps last save, interrupted save + retry, release/reconnect, isolation |
| Migrations | 6 | current version, v0 upgrade, nested defaults, newer refused, corrupt refused, impossible numbers repaired |
| LargeNumbers | 5 | max-scale hour (exact ledger, < 2^53), cash clamp, absurd population, finite prices/rates, step cost independent of population |
| RateLimiter | 5 | bursts/refill, keys, clock going backwards, number/id/text validators |
| PlotRegistry / Plots | 3 / 7 | one plot per player, ownership, release/reuse; layout invariants |
| Flock | 10 | visual caps per setting/own/other plot, at least one bird per occupied house, growth curve |
| MenuRouter / PurchaseState / Tutorial | 10 / 8 / 7 | single panel, modal stacking, tab memory, back; button states incl. rejected/loading; tutorial steps and reveals |

## 2. Balance simulator (`luau tools/sim.luau`)
A plain greedy bot (no boosts, passes, quests, codes or Robux), walking a 25 s collection loop:
eggs 1→10 take 23, 26, 30, 35, 41, 43, 52, 57, 59 min; Prestige ready after **7.2 h**.

## 3. Headless integration (`bash tools/headless/run.sh`): offline Roblox MOCK
Real server and client scripts run against a hand-written Roblox API mock. Details, limits and
per-scenario output: `docs/HEADLESS_RESULTS.md`. Latest run after the final fixes:

| Scenario | Result |
|---|---|
| fresh_player_tutorial | 35 pass: whole tutorial through the real UI in 363 simulated seconds |
| two_player_isolation | 21 pass: no cross-plot collect/deposit/prompt/fox; forged actions change nothing |
| menus_route | 48 pass: every menu/tab, dimmer, one request per rapid tap, Gold-Egg confirms (incl. Epic upgrades) |
| progression_rebirth | 15 pass: exact reset/keep through the UI; no leaked instances over 4 rebirth cycles |
| reconnect_and_saves | 14 pass: rejoin restores, failed load kicks without touching the save, failed save retries |
| shop_codes_boosts | 26 pass: simulated checkout, all code responses, boost buy/use/expire |
| render_dump | 3 pass: HUD fits at 1280x720, 390x844 and 844x390 (approximate layout engine) |
| perf_large_population | 7 pass: 8 full farms at 3.2M chickens for 600 simulated s; server 0.26 ms/frame avg (p95 2.0); one client 3.8 ms/frame on flock=high, 1.1 on low (mock Luau time); own flock capped at 120 rigs, neighbours 4; snapshots 2.9 KB at 2/s |

0 runtime errors in game code across all scenarios.

## Not tested (and why)
- **Roblox Studio playtest**: Studio wasn't reachable from this environment (the Studio connection runs on the owner's PC).
- **Real DataStores / ProfileStore against Roblox**: needs a published place with API access (owner decision).
- **Real Robux checkout**: no product IDs exist and nothing may be bought; only the simulated checkout is tested.
- **Physics, rendering, real touch input, real network, phone frame rate**: the mock doesn't model them.

## Images
`docs/screenshots/offline_*.png` are offline renders of the world and UI that the real code
generated inside the mock (Blender Cycles / PIL). They are not Roblox screenshots.
`docs/renders/*.png` are previews of the Blender models.
