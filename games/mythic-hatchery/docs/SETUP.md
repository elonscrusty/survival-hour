# Mythic Hatchery: setup and launch (owner steps)

Everything here is done on a PC in Roblox Studio or on create.roblox.com.

## 1. Open the game
1. Download the supplied `MythicHatchery.rbxlx`, or run `bash tools/check.sh` to generate `build/MythicHatchery.rbxlx`.
2. Double-click it to open in Roblox Studio and press **Play**. The map, creatures and UI all build when the game
   starts (nothing is stored as uploaded meshes).
3. In Studio every Robux button works as a free test purchase, labelled as a test.

Run the checks in STUDIO_TESTS.md before making the experience public. Set maximum players to 8 for the current eight-plot map.

## 2. Publish
1. File → **Publish to Roblox As…** → new experience, name **Mythic Hatchery**.
2. Game Settings → **Security** → turn on **Enable Studio Access to API Services** (this lets saving work in Studio).
3. Game Settings → Basic Info: upload `renders/marketing/icon_512.png` as the icon, and
   `renders/marketing/thumbnail_1.jpg` / `thumbnail_2.jpg` as thumbnails. Genre: Simulator. Set Maturity questionnaire (all "No").
4. Permissions → **Public** when you're ready.

## 3. Create the Robux items
create.roblox.com → your experience → **Monetization**.

**Passes** (Monetization → Passes → Create a Pass, then turn on "Item for Sale" and set the price):
| Key | Name | Price |
|---|---|---|
| HatchSlots | +2 Hatch Slots | 249 |
| FastIncubation | 2x Incubation | 299 |
| VipTrader | VIP Trader | 199 |
| VIP | VIP | 199 |
| Lucky | Lucky | 349 |
| MoreEquip | +3 Creatures Out | 249 |
| MoreExpeditions | +2 Expedition Slots | 199 |
| BigBackpack | Big Stable | 99 |

**Developer Products** (Monetization → Developer Products → Create):
| Key | Name | Price |
|---|---|---|
| Gems250 | 250 Gems | 49 |
| Gems550 | 550 Gems | 99 |
| Gems1500 | 1,500 Gems | 249 |
| Gems3300 | 3,300 Gems | 499 |
| Gems7000 | 7,000 Gems | 999 |
| Gems19000 | 19,000 Gems | 2499 |
| BoostCoins | 2x Coins (30 min) | 49 |
| BoostGrowth | 2x Battle XP (30 min) | 49 |
| BoostLuck | 2x Luck (30 min) | 79 |
| ServerLuck | Server Luck (15 min) | 199 |

Copy each item's ID and send them all to Claude in one message ("VIP 12345, Lucky 23456, ..."), and Claude
will paste them into `src/shared/Products.luau`. Pass icons can be made from `renders/` images.

## 4. Optional
- **Group bonus:** make a Roblox group and send its ID; members get +5% coins (`Config.GroupId`).
- **Music:** pick tracks from the Creator Store audio (free, licensed) and send their IDs.
- **Ads:** once it plays well, run a small Sponsored Experience campaign (start with ~500-1,000 Robux/day) and
  keep the thumbnail that gets the best click rate.

## 5. Tips that move earnings
- Update often (a new island or egg every 1-2 weeks) and announce it in the game title, e.g. "[🌋 NEW EGG]".
- Weekend events: turn on 2x Luck for everyone (a Config change) and say so in the title.
- Limited eggs: set a new Limited egg (dates + Edition) in `Eggs.luau` each season; announce it in the title.
- Watch Analytics → Monetization: conversion rate and ARPPU. If almost nobody buys, lower the cheapest
  gem pack; if many people buy, add more passes and limited-time eggs.
