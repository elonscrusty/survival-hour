# Mythic Hatchery implementation plan

## Authority
The owner's October 6 design choices supersede the old Pet Expedition and growth/race contracts.
No racing. Optional one-on-one PvP; each trainer commands a team of three, one active at a time.
All unlocked moves are available. Moves share a cooldown; swapping has a separate longer cooldown.
Species determines core moves; element supplies an elemental attack.
Rarity and levels substantially affect strength. Match opponents by the strength of their chosen teams.
Creatures recover after battles. Winners gain arena points and losers lose points.
Only creatures that enter battle earn XP, weighted by useful contribution.
One habitat per player with unlockable, upgradeable slots. Assigned creatures earn coins online and
offline to a storage cap, collected manually. Assigned creatures cannot battle or be ridden.
Habitat upgrades affect production and storage only. Creatures never earn passive XP.
Starter creature can ride and fly immediately. Fusion consumes two creatures and produces an egg
with improved rarity odds and possible hidden hybrid.

## Provisional defaults
Fused hatchlings start at level 1. Numerical tuning is provisional, isolated in data, and not a claim
that the economy is balanced. A battle ends when a team has no conscious creatures. Knockout forces a
replacement; manual swaps obey the longer cooldown. Losing a battle still pays coins and participation XP.
Habitat slot capacity caps accumulated coins rather than offline time; full slots stop producing.
Battle state, time, results, prices, reward budgets and contribution are server-owned.

## Sequence
1. Shared foundation: deterministic hatch odds, level/XP math, habitat accrual and assignment,
   species/element moves, authoritative battle commands, reward calculation and fusion. Add CLI tests.
2. Convert saved profiles and state snapshots. Preserve session locks, receipts and trade journals.
   Implement incubation, inventory, reward and trade conversion before hooking new services.
3. Replace arena, add habitat and battle matchmaking services; enforce remote validation/rate limits.
   Grant one persisted starter mount, implement server-checked riding and flying.
4. Mobile client: habitat collection/assignment, team selection, opponent queue, command buttons,
   move unlocks, fusion warnings, incubators and ride/fly controls. Remove racing and care UI.
5. Primitive creature/plot/arena models and connected world. Build and Studio playtest.

## Verification
Each changed logic module gets red/green tests. Run tools/check.sh --quick after each system.
The supplied baseline has 18 passing tests and 9 module-load failures from deleted Pets.luau,
plus a syntax error in Net.luau. Report these until their conversion pass fixes them.
Focused tests do not establish whole-game readiness. Live DataStore, matchmaking, client controls
and multiplayer replication require Studio testing.
