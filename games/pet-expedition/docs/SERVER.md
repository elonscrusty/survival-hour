# Pet Expedition: server notes

Entry: `src/server/Main.server.luau` calls `Net.Init()`, requires every service in `ORDER`, runs each
`Init(ctx)` (services reach each other as `ctx.<Name>`), then spawns each `Start()`.

## Services (`src/server/Services/`)
| Service | Job |
|---|---|
| `Util` | join/leave hooks, remote wrapper (`Util.Function` / `Util.Event`: per-player per-remote token bucket from `Util.Limits`, refuses until the profile is loaded, pcall, `{ ok = false, err }` on failure), validation, `Notify` / `Toast` |
| `DataService` | DataStore `Config.DataStoreName`, key `p_<UserId>`, session lock via UpdateAsync, autosave, release on leave + BindToClose, change counter (`Touch`; `SaveSession` is true only if a finished write includes the caller's changes), trade journals (`t_<TradeId>`) and their replay on load. Memory profiles only in Studio; a live server without DataStore gives read-only "Failed" sessions |
| `StateService` | coalesced `State` pushes (0.2 s), `Pets` / `Vip` / `Target` attributes, leaderstats, Premium / group / PolicyService flags, `SetSetting`, `ClientReady`, coin and luck multipliers |
| `WorldService` | `World.Build()`, area tracking (sends players found deep inside a locked island back), `OpenGate`, `Teleport` |
| `HatchService` | `HatchEgg` (cooldown, Triple Hatch pass, gem-egg policy, distance to the egg stand, storage, price, luck) |
| `PetService` | equip / equip best / unequip all / delete / lock / craft, pet XP and `LevelUp` |
| `BreakableService` | spawns breakables per island zone, `SetTarget`, damage ticks, reward split by damage, respawn, Auto Farm |
| `ExpeditionService` | start / claim / skip |
| `RewardService` | daily, playtime (per server session), quests, Index, `Discovered` |
| `RebirthService` | rebirth |
| `BoostService` | personal boosts, server luck (this server only) |
| `PurchaseService` | ProcessReceipt (dedupe by PurchaseId, granted only after a save that includes it), passes (purchase event confirmed with UserOwnsGamePassAsync), Studio `DevPurchase` |
| `TradeService` | requests (timeout, cooldown, account age, policy), offers, ready + countdown, journaled swap (below), cancel on leave before the swap starts |

## Pure rules (`src/shared/Logic/`, unit tested in `tests/`)
`Rng`, `Schema` (profile shape, caps), `PetMath`, `Hatch`, `Economy` (currency, multipliers, boosts, gates,
rebirth), `Inventory`, `Expedition`, `Rewards`, `Profile` (defaults, sanitising, PlayerState), `Trade`,
`RateLimiter`.

## Rules worth knowing
- New players: 150 coins, Meadow open. Coins cap 1e15, gems 1e12.
- Pets on expeditions are busy (no equip / delete / craft / trade). Pets offered in an open trade can't be
  deleted, crafted or sent on expeditions. Locked pets can't be deleted, crafted or traded.
- Traded pets get fresh uids from the receiver and arrive unlocked.
- Trade swap (dupe-safe): (1) both profiles get `PendingTrade = id` and must save, else the trade is
  cancelled; (2) the journal with both sides' changes is written to `t_<id>`; (3) both sides are applied
  (`Trade.ApplySide`, idempotent via `AppliedTrades`) and saved with retries; the journal is removed once
  both saves succeed. A profile loading with `PendingTrade` replays its side from the journal, or clears
  the flag if there is no journal (the journal couldn't be read → read-only session). If the journal
  write can't be confirmed, both keep `PendingTrade` (no trading, deleting or crafting) until their next
  join settles it the same way for both. While a swap runs, all of both players' remote functions are
  refused.
- **Gem pets** (Prism Egg, `Source = "Gem"`): their power uses the PowerMult of the owner's highest opened
  island, computed whenever power is used (`PetMath.Power(pet, Economy.HighestArea(profile))`); with no
  island given they count as Meadow pets. They refund on delete at Meadow level. So gems buy a pet that is
  strong where the player already is, never a progression skip, and can't be turned into gate coins.
  The client should show power the same way.
- Breakable loot: `Economy.SplitBreak` splits coins by damage share and gems by largest remainder (the
  total is exact). Only players with at least 5% of the damage get credit (minimum 1 coin, Break quest,
  Broken stat, pet XP).
- Expedition coins use the coin multiplier snapshotted at start (`ExpeditionMult[slot]`).
- Expedition claims are refused (nothing paid) if the found pets wouldn't fit in storage.
- Gem eggs and trading stay off until PolicyService answers (allowed in Studio if it can't answer).
- Playtime gifts are per server session (rejoining restarts them), as `Config.PlaytimeGifts` describes.
