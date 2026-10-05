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
- Publish pass: daily login streak (7 tiers), 3 daily quests, promo codes (server-only list), 7 badges (ids to fill in), sound effects with a mute switch, tutorial step for DAILY, a game icon and 3 thumbnails (`models/storeart/`), and the publish guide `docs/PUBLISH.md`.
- Second review fixes: DAILY menu scrolls on phones, speed gates face along the ring, arches and gates don't collide, save lock released if a player leaves while loading, a kick if another server takes the save, badges only marked once really awarded.
- Look pass: bright toon style, chibi ride-sized pets (big heads, glossy eyes), the rider sits on the pet, outlines on world pets, sparkles on Legendary/Mythic, sunny lighting with bloom, candy UI.
- Animation pass: every pet is rigged (Root, Body, Head, EarL/EarR, Tail, WingL/WingR, 4 legs). One animation module (`Logic/PetAnim`) drives breathing, look-around, blinking, ear twitches, tail wag, a trotting run cycle with bounce and lean, jump stretch, landing squash and dust, wing flaps and happy hops (hatch, level up, race win). It runs on ridden pets, followers and the hatch/menu previews. Blender models are skinned to the same skeleton, and `blender/animate.py` renders `models/storeart/PetAnimations.mp4` with the same maths.
- 70 unit tests, a clean type check and a Rojo build.

## Owner steps left
Follow `docs/PUBLISH.md`: publish from Studio, the store page, Robux products, badges (optional) and the model upload.

## Not tested yet
- Nothing has run in Studio yet. Follow `docs/STUDIO_TESTS.md`.
- Models aren't uploaded yet (`tools/upload_models.py`, needs the owner's Open Cloud key).

## Ideas for next passes
- Sounds and music.
- More tracks (and a weekly featured track).
- Trading pets between players.
- Check mesh pet bone axes in Studio after uploading (PetAnimator `BONE_AXIS`).
- Leagues matchmaking (separate portals per league).
