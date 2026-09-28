# Status (short)

_Updated: 2026-09-28. The full history is in [IMPLEMENTATION_LOG.md](IMPLEMENTATION_LOG.md); read it only when needed._

**Built:** every spec phase and all polish/expansion passes, including:
- Events and match conditions, and the Match Director.
- Endgame tension, recap and survival story.
- Challenges, badges hooks and mastery titles.
- Noise and parry.
- AFK handling and Play Again.
- Camp scouting and trophies.
- 20 reworked models.
- Launch extras: Roblox Analytics (funnel, economy, results), Premium ★ tag, one-time favourite
  prompt, "What's new" panel (`Changelog.luau`), update-restart notice, translation-safe name labels.
- Seasonal events (v1.1.0): `Config.Seasons` + `Logic/Seasons`. First season Halloween 2026
  (Oct 24 - Nov 3 UTC): 5 limited Coin cosmetics (sold only in season, kept forever), the earned
  "Hallowed" title (5 matches in season), lobby banner + Locker "LIMITED" tags, client-only
  spooky grade, mist and jack-o'-lanterns (`Controllers/Season`). Preview in Studio with
  `Config.Dev.ForceSeason = "Halloween2026"`.
- Class Hall: full-screen class picker (`Controllers/ClassHall`): card grid with hex badges,
  rarity stars and an owned filter, the player's avatar on a turning pedestal in class colours,
  perks + play-style tips. Daily deals (`Logic/ClassDeals`): each UTC day two paid classes get
  -20% / -10%, same on every server; the server charges the deal price.
- Class levels (`Logic/ClassLevels`): one task per class, Level 2/3 make its percentage perks x1.25/x1.5
  (bow draw never grows, breach capped x1.2; Hunter gets hides, Tracker shorter trail delay). Earned only.
- Lobby hub pass: a lit Class Hall cabin west of the fire (a mannequin per class in its windows,
  neon CLASSES sign, counter opens the classes panel), a per-player Daily Challenges board near
  spawn with a reset timer (`Controllers/LobbyBoards` + `Logic/LobbyBoards`), a live
  "READY UP · n/4" counter and hazard stripes on the ready ring, string lights along the paths.
- Animation loader: paste uploaded clip ids into `AnimationIds.luau` (names in `Logic/AnimClips`);
  missing clips keep the procedural animation. ChatGPT prompt for making the clips is in chat history.
- Animal meshes: 28 segmented part meshes (wolf, bear, deer with doe/buck heads, rabbit, boar, bat;
  `blender/assets/animals.py`, `Renders/ContactSheet_Animals.png`). `Animals.Build` welds one onto
  each rig part once a species' meshes are all uploaded, so the procedural Motor6D animation moves them.

**Checks:** `bash tools/check.sh` covers the type check, 205 unit tests, 36 skins/lobby checks and the build. All pass.

**Not done yet: nothing has been playtested in Roblox Studio.** All numbers are working targets.

## Next (owner)
1. Playtest in Studio: follow `docs/STUDIO_TESTS.md`.
2. Re-upload 20 models and upload the new camp shack + 28 animal meshes (`docs/MODEL_REUPLOAD.md`).
3. Create 9 badges and 6 Robux products, then send the IDs.
4. Make animation clips (ChatGPT prompt) and send the ids.
5. Choose licensed audio. Delete the API key. Publish (`docs/PUBLISH_CHECKLIST.md`).

## Next (Claude, after the first playtest)
- Fix what the playtest finds; tune numbers (use balance-analyst).
- Map content held for Studio validation: treasure maps, keys and locked rooms, dens, shortcuts, resource hotspots, footprints.
