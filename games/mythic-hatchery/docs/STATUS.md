# Status (short)

_Updated: 2026-10-05._

**Built (first full pass):**
- Six islands, 41 pets, 7 eggs, breakables, the Meadow hub (egg stands, Expedition Board, Golden machine,
  Rebirth statue, Index book). Everything is modelled from primitives; previews are in `renders/`.
- Hatching (odds shown, luck, shiny, triple/fast/auto), equip/lock/delete, Golden and Rainbow crafting,
  pet levels, farming with pets, gates, teleport, expeditions (offline timers), daily streak, playtime gifts,
  daily quests, Index rewards, rebirth, boosts and Server Luck, trading (journaled, dupe-safe), passes and
  gem packs, PolicyService gates, a session-locked DataStore with receipt dedupe, and a Studio dev panel.
- Mobile-first UI built in code, with a tutorial.
- Economy balanced by simulation (free player: Starfall ~10 h, first rebirth ~15 h, ~200-300 gems a day).

**Checks:** `bash tools/check.sh` (type check, unit tests, build). All pass.

**Not done yet: nothing has been playtested in Roblox Studio.**

## Next (owner)
1. Playtest in Studio with `docs/STUDIO_TESTS.md`.
2. Publish and create the 8 passes and 9 products (`docs/SETUP.md`), then send the IDs.
3. Upload the icon and thumbnails from `renders/marketing/`.

## Next (Claude)
- Fix what the playtest finds; retune with real numbers.
- Content ideas for updates: a 7th island, limited-time event eggs, pet enchants, a leaderboard board,
  licensed music.
