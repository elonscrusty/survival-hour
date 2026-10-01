# Saves, mock storage and receipts

## Profile (version 2)

Defined and validated in `src/shared/Logic/Profile.luau`. Big numbers are `{ m = mantissa, e = exponent }` (value = m × 10^e). Plain tables, so they survive JSON and DataStores, and wallets beyond 10^308 work.

| field | type | reset by |
|---|---|---|
| `v` | number (2) | never |
| `cash`, `lifetime` | Big | rebirth, evolution, ascension |
| `totalEarned` | Big | never |
| `biz[id]` | `{ level, progress (0–1), running }` | rebirth, evolution, ascension |
| `pads[padId]` | true | rebirth, evolution, ascension |
| `forever[padId]` | true | never (Forever Purchase) |
| `foreverTokens` | number | spent on use |
| `investors` | Big | evolution, ascension (spent on powers) |
| `evolutions` | number | ascension |
| `ascensions` | number | never |
| `powers[id]` | tier bought with investors | evolution, ascension |
| `robux.passes`, `robux.tiers` | Robux unlocks | never |
| `robux.receipts` | last 200 PurchaseIds | never (bounded list) |
| `robux.rebirthCredits`, `robux.skipSeconds` | Robux credits waiting to be used | spent on use |
| `name` | business name (filtered) | never |
| `lastSeen` | unix time | updated on every save |
| `pendingOffline` | Big, offline income not yet claimed | claimed |
| `stats` | counters | never |

## Migration and validation

- `Profile.migrate(raw, now)` upgrades older versions step by step (`MIGRATIONS[1]` turns v1 into v2) and then rebuilds the profile field by field. Unknown pad IDs are dropped, tiers are clamped, and NaN or negative cash is rejected.
- Corrupt data, a newer version or invalid cash returns `nil` plus a reason. **It is never silently replaced by an empty profile.**

## Load and save flow (`Data.luau`, `Store.luau`)

1. Load with up to 3 tries and backoff. `ok=false` means "could not read", which is different from "no save yet".
2. If the load fails or the data is rejected, the player gets a temporary profile with `canSave = false` and a red banner. Nothing is written, so the stored save is untouched. This is tested in the smoke test.
3. Autosave every 60 s. The game also saves on leave and on `BindToClose` (with a 25 s budget). Saves run one at a time per player.
4. DataStore mode uses `UpdateAsync` with a session lock (`lock = {job, t}`, 30 min expiry). A save that finds another server's lock is skipped and reported as failed.

## Mock storage (default)

`src/shared/Config.luau`: `Storage = "mock"` keeps saves as JSON in server memory. It survives leave and rejoin **within one server session** (one Studio play session) and is lost when the server stops. Failure injection for testing in Studio (command bar, server side):

```lua
workspace:SetAttribute("SHD_FailLoads", 3) -- next 3 load attempts fail
workspace:SetAttribute("SHD_FailSaves", 1) -- next save fails
```

**Real DataStore persistence was not tested** (it needs a published experience with API access; see LIVE_SETUP.md).

## Robux receipts

- `ProcessReceipt` → `deliver(session, key, PurchaseId)`. If the PurchaseId is already in `robux.receipts`, nothing is granted again. Otherwise the game grants, records the id and **saves before returning `PurchaseGranted`**. If the save fails, or saving is off after a failed load, it returns `NotProcessedYet` so Roblox retries.
- Game passes are checked on join (`UserOwnsGamePassAsync`) and after `PromptGamePassPurchaseFinished`, using the id `pass:<passId>`.
- Time skips with no income yet are banked as `skipSeconds` and paid out once income exists.
- **Mock purchases (Studio only, `Config.MockPurchases`)**: the Shop shows **TEST BUY** buttons that send `mockBuy`. This runs the same `deliver` path with fake `mock-<guid>` receipts. The Studio test card also has **Resend last receipt** (duplicate delivery: no second grant) and **Cancelled purchase** (nothing granted or stored). The server ignores `mockBuy` outside Studio.
