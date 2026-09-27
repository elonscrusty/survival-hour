# Setup Guide

## 1. Build or open the place

**Option A: open the built file.** Open `build/SurvivalHour.rbxlx` in Roblox Studio.

**Option B: rebuild from source** (after editing code):

```bash
rojo build default.project.json -o build/SurvivalHour.rbxlx
```

**Option C: live-sync while developing.** Install the Rojo Studio plugin (v7.x), then run the command below and click *Connect* in the plugin:

```bash
rojo serve default.project.json
```

The project was built and verified with **Rojo 7.7.0**.

## 2. Test in Studio (no live lobby needed)

1. Press **Play**. You spawn on the lobby island (in the sky above the match area).
2. Walk into the glowing **Ready ring**, or press **READY UP**. In Studio the lobby hosts the match itself. It waits `Config.Dev.StudioFillWait` (6 s) for other test clients, then builds the forest and moves everyone in.
3. Use the purple **⚙ DEV** button (Studio only) to skip phases, spawn animals, give items, drop a care package, set the workbench level, put out a fire, and so on.
4. For multiplayer, open **Test → Clients and Servers**, choose 2–8 players, and ready up on each client.
5. Purchases in Studio: every product ID is `0` until you configure it, so Studio uses a clearly labelled **[DEV] simulated purchase** that goes through the same grant pipeline. No Robux are involved. Live servers never simulate.

Useful `Config.Dev` switches (`src/shared/Config.luau`):

| Setting | Default | Purpose |
|---------|---------|---------|
| `StudioMinPlayers` | 1 | ready players needed to start a local match |
| `StudioAllowSingleTeam` | true | a match with one populated team doesn't end instantly |
| `StudioPhaseLength` | nil | set e.g. `20` for fast day/night cycles |
| `SaveInStudio` | false | write real DataStores from Studio (also needs API access, see below) |

## 3. Publish (account steps you perform)

1. **File → Publish to Roblox** and create or choose an experience. This one place is both the lobby and the match server (DECISIONS D1).
2. **Game Settings → Security**: turn on **Enable Studio Access to API Services** if you want DataStore/MemoryStore testing from Studio.
3. **Game Settings → Places → Max Players**: set to **20** or more. Matches are capped at 16 by the matchmaker, and lobbies can hold a few more.
4. **Avatar settings**: R15 is recommended. The procedural animations support R6 too, but R15 was the design target.
5. No third-party teleport setting is needed: matches reserve servers of the same place.

## 4. Developer products

1. Creator Hub → your experience → **Monetization → Developer Products**. Create one product for each row marked **On sale: yes** in the *Developer products* table in [TUNING.md](TUNING.md): the four Coin packs and the two cosmetic bundles. The prices there are suggestions. The legacy kinds (revives, care packages, bandages, Diamonds, powerup unlocks) are off sale under the non-pay-to-win rules, so they don't need products.
2. Copy each product ID into `src/shared/Products.luau` (`ProductId = <id>`) for the matching `Key`. Leave any product you don't want at `0`; its button then shows "Unavailable" in live servers.
3. Rebuild or re-sync, then publish.
4. Displayed prices are always read live with `GetProductInfoAsync` (regional pricing aware), never hard-coded.
5. Bundles contain fixed items (no paid random items). If a player already owns an item from a bundle, it is refunded at its Coin price.

How receipts are handled (no setup needed):

- `ProcessReceipt` grants into the buyer's DataStore profile, idempotently by `PurchaseId`, and returns `PurchaseGranted` only after a successful save.
- Coin packs add Coins; bundles unlock their cosmetics. Legacy receipts (old Diamond packs, powerup unlocks, revives) still resolve, so no purchase is ever lost.

## 5. Data stores & matchmaking

- DataStore name: `SurvivalHourProfiles_v1` (`Config.Data.StoreName`). Profiles are session-locked. A failed load means the session runs **without saving**, so a blank profile never overwrites real data.
- Profile schema v2 (`ProfileRules.SchemaVersion`): the first time a v1 profile loads, the Diamonds spent on retired powerups are refunded.
- Leaderboards: OrderedDataStores `SurvivalHourProfiles_v1_Board_Wins` and `…_Board_XP`, written after each match and read every 2 minutes by lobby servers. All calls are pcall-guarded. They stay empty in Studio unless `SaveInStudio` is on.
- MemoryStore sorted maps: `SH_Queue_v1`, `SH_Assign_v1`, `SH_Manifest_v1`, `SH_MatchmakerLock_v1`. There's nothing to create: MemoryStore is on automatically for published experiences.
- Match servers are reserved with `TeleportService:ReserveServer(game.PlaceId)`. A match server reads its team manifest from MemoryStore by `game.PrivateServerId`.

## 6. Audio (optional, recommended)

The game plays engine-bundled sounds (`rbxasset://sounds/...`) where they fit. Silent slots are waiting for licensed audio: `AmbientLobby`, `AmbientDay`, `AmbientNight`, `AmbientCave`, `Wind`, `FireCrackle`, `PlaneDrone`, and the surface footsteps `FootGrass`, `FootLeaves`, `FootMud`, `FootStone`, `FootWood` and `FootMetal`. A footstep slot, once set, replaces the default running sound on that floor material. To add campfire crackle, ambience, a plane drone and richer SFX, open `src/shared/Sounds.luau` and fill `AssetId` for each cue with audio you have the rights to use: your own uploads, or Creator Store audio licensed for use in experiences. Cues with no asset stay silent. No asset IDs were invented.

## 7. Remaining account-dependent steps

- [ ] Publish the place and set Max Players ≥ 20.
- [ ] Create the 6 on-sale developer products (4 Coin packs, 2 bundles) and paste their IDs into `Products.luau`.
- [ ] (Optional) Enable Studio API access and set `SaveInStudio = true` for a persistence test.
- [ ] (Optional) Choose licensed audio and set `AssetId`s.
- [ ] Complete the experience questionnaire / maturity settings on Creator Hub.
- [ ] Run the live-server checks in [TESTING.md](TESTING.md) §3. They need at least 8 real accounts.
