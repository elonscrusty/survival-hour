# Live setup (NOT performed: needs Carter's decisions and account)

None of these steps were done. They publish or charge, so the owner should do them, in this order.

## 1. Publish a NEW experience

- In Studio, open `build/SellHotDogs.rbxlx` and choose **File → Publish to Roblox As… → Create new experience**. Do **not** overwrite an existing place.
- Set the max players to 4 (the world has 4 plots; `Config.Plots`).

## 2. Meshes (optional, for the Blender look)

Follow `assets/ASSETS.md`: import `assets/exports/*.fbx` with the 3D Importer and place them in `ReplicatedStorage/Assets/<Name>`. The game then uses them instead of the native-part stand-ins. Models that are matched by name today: the 8 business buildings use their own names (`HotDogStand`, `DashShop`, …). Pad props use the `model` names in `catalog/economy.json`.

## 3. Saves

- In the new experience's settings, turn on **Security → Enable Studio Access to API Services**. Do this only for this experience.
- In `src/shared/Config.luau` set `Storage = "datastore"`, rebuild, and test: join, earn, leave, rejoin. Also test two servers (the session lock).

## 4. Robux products

- On the Creator Dashboard for the new experience, create the products in `src/shared/Products.luau`:
  - Game passes: Speed Up Time, x2 Investors, Manage, Remote Buy.
  - Developer products: Expert Collector, Run Faster, Stack Upgrade, Forever Purchase, Rebirth Without Reset, Cash 1 Hour / 24 Hours / 7 Days.
- Choose the prices. The Robux amounts in `docs/CATALOG.md` are **historical displays from one creator's session** or secondary guide claims, not prices to copy. Turn on regional pricing if wanted (https://create.roblox.com/docs/production/monetization/regional-pricing).
- Paste each new ID into `Products.luau`, set `Config.MockPurchases = false` for the live build, and rebuild. Prices shown in game come from `MarketplaceService:GetProductInfo`.
- Never reuse Sell Lemons product IDs.

## 5. Audio

Upload `assets/audio/*.wav` and put the IDs in `src/client/Controllers/Effects.luau`. Otherwise the engine-bundled sounds stay.

## 6. Before going public

Run `docs/STUDIO_TEST_PLAN.md` on desktop and on the phone/tablet emulators, in single-player and 2-player modes. Then replace the placeholders in `docs/CATALOG.md` (Unresolved list) once evidence exists.
