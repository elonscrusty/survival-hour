# Mythic Hatchery status

Updated October 6, 2026. This is an incomplete conversion, not a playable release.

## Current design
Read IMPLEMENTATION_PLAN.md and the revision at the top of CONTRACTS.md.
The owner chose optional PvP, three-creature teams, real-time commands, battle-only XP,
levels instead of growth stages, and a habitat that produces collectible coins online/offline.
No racing. Starter mount can ride and fly immediately.

## Implemented shared foundation
- Hatch: independent species/rarity/element rolls; capped rarity luck; fused parent odds and hybrids.
- Level: battle XP, multiple level-ups, maximum-level cap, rarity/level strength.
- Habitat: slot assignment/removal, stored income, offline accrual, caps, collection, upgrades.
- Moves: species moves plus an elemental attack, two initial moves and four level unlocks.
- Battle: team snapshots, one active creature, shared move cooldown, separate swap cooldown,
  knockouts/forced replacements, healing/guard contributions, forfeit/timeout, strength matching,
  participation-weighted XP, coin and arena-point reward calculations.
- Fusion: validate available parents and payment/egg space; prepare two-parent consumption and an egg.
- Net: removed stray pet-era remote declarations that made the module invalid Luau.

## Verification
44 focused tests pass: /tmp/sh-tools/luau/luau tests/foundation.luau.
Changed pure modules and new tests pass standalone Luau analysis with zero diagnostics.
Net.luau passes Luau compilation. git diff --check passes.
Whole-project tools/check.sh --quick still fails: 62 tests pass; eight legacy modules fail to load
(PetMath, Economy, Inventory, Expedition, Rewards, Profile, Trade, Models) because Pets.luau was deleted.
The old client/server also still have pet-era type/API diagnostics. No Studio playtest has occurred.

## Next integration pass
Convert Schema/Profile/Inventory/Economy and persistence before connecting the foundation to services.
Adapt Types/Config with the new fields and remove old race/care fields as clients/services migrate.
Map saved creature fields to Level.Creature snapshots without allowing client-supplied stats.
Create habitat unlock/assignment services with ownership, duplicate-assignment and busy-state checks.
Grant the starter mount once per saved profile; prevent rerolling it by rejoining.
Create opponent queues, session cleanup, server-owned clocks and reward settlement once per battle id.
Add minimum participation/repeat-opponent protections before awarding arena income/XP.
Convert incubation, purchases, rewards, trades and expeditions without weakening receipt/session/journal rules.
Then build mobile controls and primitive models. Do not publish this branch yet.

## Provisional defaults and limitations
Fused hatchlings start at level 1. No fusion level minimum has been chosen; the preparation module does not impose one.
Max level 50, six total moves, 2-second command delay, 8-second swap delay, reward amounts and habitat prices/rates
are temporary numbers in Gameplay.luau, pending balance work. Matchmaking currently exposes a comparison rule,
not an integrated queue. Habitat slot unlock limits are tuning data awaiting service enforcement.
Pure reward functions calculate values; they do not grant or persist anything.
Review was performed by the author; an independent review remains pending.
