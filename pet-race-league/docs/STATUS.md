# Status

## Done (first pass)
- Lobby built in code: spawn, 3 egg stands with odds boards, Speed Ring, Jump Hurdles, Stamina Treadmill, Race Portal, a global trophy leaderboard, trees and paths.
- 15 pets across 6 rarities, built from parts with ears, tails, horns, wings and neon. They grow slightly as they level.
- Hatching with a pity counter, a hatch reveal animation, and Ride it / Again buttons.
- Riding: the pet is welded under the player. Speed, jump and dash come from pet stats, and the server sets them.
- Training: XP and levels from 1 to 50 for each stat.
- Races: queue, 3-2-1 countdown, checkpoints, falls send you back to a checkpoint, mud and boost pads, live place and timer, a 30-second hurry-up after the first finisher, results with coins, trophies, medals and best times.
- Anti-cheat: checkpoints must be reached in order and at believable speeds.
- Leagues: Bronze, Silver, Gold, Diamond, Champion.
- Shop: coin cosmetics (trails, paint), plus Robux coin packs, cosmetics and the Big Barn pass.
- Saving with DataStore: retries, autosave, save on shutdown, duplicate-receipt guard.
- First-time tutorial cards.
- 33 Blender models (pets, eggs, trees, rocks, flowers, fence, lamps, pedestal, speed gate, portal arch, race arch, pillar, cloud, trophy statue), an upload script and a loader with part fallbacks.
- Review fixes: whole-race anti-cheat (no teleport wins), training teleport checks, pet collision box (hurdles must be jumped), pet pivot at feet, session-locked saves, Robux purchases confirmed only after saving, a race loop that recovers from errors.
- 54 unit tests, a clean type check and a Rojo build.

## Not tested yet
- Nothing has run in Studio yet. Follow `docs/STUDIO_TESTS.md`.
- Models aren't uploaded yet (`tools/upload_models.py`, needs the owner's Open Cloud key).

## Ideas for next passes
- Sounds and music.
- More tracks (and a weekly featured track).
- Daily rewards and quests.
- Trading pets between players.
- Animated pet legs (they don't move yet).
- Leagues matchmaking (separate portals per league).
