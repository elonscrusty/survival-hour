# Review report

## What works (verified headless)

The full game loop runs end to end from the built place. The checks are in [TESTING.md](TESTING.md).

**Opening**
- A $1 Hot Dog Stand with a one-second CLICK cycle paying $1.00.
- The observed early upgrades: $6.20 x2, $82.50 x3, $100 automation, $785 x3 speed.
- Stand upgrades at $5.10 → $7.65 → $11.00 → $19.00.

**Progression**
- All eight businesses with pads and managers.
- Ingredient pickups.

**Menus and powers**
- Manage, Powers and Shop panel.
- Bulk/Max, Remote Buy, Run Faster, Expert Collector, Speed Up Time.

**Side systems**
- Phone negotiations.
- DogDash races.
- Filtered business names.

**Prestige**
- Alien Investors/Rebirth (+x2 and without-reset variants).
- Void Evolution.
- Ascension with staircase.
- Forever Purchase selection.

**Saves and purchases**
- Offline income.
- Versioned saves with failed-load protection.
- Idempotent Robux receipts with Studio-only mock purchases.

The server owns every number. Requests are validated and rate-limited. Big numbers go past 10^564.

## Code review

A separate review pass of the server and logic found 8 issues. All are fixed and have regression tests or smoke checks:

1. **DogDash cheering:** one burst of cheering lasted the whole race, so betting made money. The boost now decays, and the tuning keeps the expected return below 1.
2. **Value crossing resets:** a race payout, an open phone offer or unclaimed offline income could carry across a reset. Prestige is now refused during a race, open offers are closed, and offline income is settled first.
3. **Session lock:** the lock could be held after an early leave, a rejected save or a late autosave. Released locks, a closing flag and a shorter lock window fix this.
4. **Fast rejoin:** a quick rejoin could drop the new session. The rejoin now waits for the leave save, and only the matching session is removed.
5. **Released plots:** a released plot kept the player attribute and leftover pickups. Both are now cleared on release.
6. **Save hang:** an error inside a save could hang all later saves. Saves are now wrapped in pcall.
7. **Leaving mid-race:** this lost the bet. The race is now settled on leave.
8. **Format and join saves:**
   - "1000 million" now reads "1 billion".
   - Joining no longer re-saves every owned pass.

The top-down plot render also exposed a layout defect (rotated floor/walls, props spilling off lots), which is now fixed.

## Blockers and unverified items

- **No Roblox Studio here.** Nothing has been seen running in Studio, and there are no gameplay screenshots, mobile checks or frame-rate checks. Next step: [STUDIO_TEST_PLAN.md](STUDIO_TEST_PLAN.md).
- **No footage access.** YouTube, the Roblox APIs and the wiki were blocked by the network proxy, so nothing new was verified from the reference. Footage values come from the supplied research. See [RESEARCH.md](RESEARCH.md).
- **Mesh import** needs Carter's Roblox account. The world uses native-part stand-ins; the Blender .blend/FBX assets are ready.
- **Real DataStore persistence and Robux products** need a published new experience. See [LIVE_SETUP.md](LIVE_SETUP.md).

## Fidelity gaps (game runs on labelled placeholders)

61 catalog entries are placeholders or hypotheses (the **Unresolved** list in [CATALOG.md](CATALOG.md)):

- Stand upgrade costs and outputs after the 4th upgrade.
- Base output and timing of every business after the stand.
- Most later pads.
- Investor award formula; evolution thresholds after the first.
- Power tiers beyond tier 1; Remote Buy price.
- Pickup, phone and DogDash numbers.
- DogDash pad price.

Pad order is assumed sequential. The x-badge is read as the number of upgrades bought. Current World 2 parity and current Robux prices are **not** claimed.

## Files created or changed

- **New:** everything under `SellHotDogs/` in the `elonscrusty/survival-hour` repo, branch `claude/wonderful-clarke-9zwrll`. This includes the source, tools, tests, assets, docs, `build/SellHotDogs.rbxlx` and `SellHotDogs.zip`.
- **Unchanged:** no file outside `SellHotDogs/` was changed. The Survival Hour game is untouched. No Roblox experience, place, product, DataStore or setting was created or changed. No Robux was spent, nothing was published, and no paid service was used.
