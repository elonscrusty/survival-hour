# Publish Checklist (do this when you're at your PC)

## 1. Open and test (10 min)
1. Download `build/SurvivalHour.rbxlx` from the branch and open it in Roblox Studio.
2. Press **Play**. Click **ENTER THE REFUGE**, try the lobby buttons, then **READY UP**. In Studio a match
   starts with just you.
3. Play a couple of in-game days: gather, craft an axe, chop, feed the fire, upgrade the Workbench, build.
4. Open **View → Output**. Copy anything red or orange and send it to Claude.

## 2. Publish (2 min)
1. **File → Publish to Roblox → Create new experience**. Name it **Survival Hour** and choose the account
   **kcdrewcarter** (the account that owns the uploaded models).
2. **Home → Game Settings**:
   - **Security**: turn on *Enable Studio Access to API Services* (needed for saving).
   - **Places → Survival Hour → Server size**: 20. Matches take 4 players; the lobby holds more.
   - **Permissions**: keep it *Private* until you've tested.
3. **File → Publish to Roblox** again after any change.

## 3. Robux products (ChatGPT can do this)
Ask ChatGPT to run **PART 3 (products)** from the earlier prompt: 4 Coin packs and 2 bundles. Paste the six
product IDs to Claude, who puts them in `Products.luau`. Then re-publish.

## 4. Store page (create.roblox.com → Survival Hour)
- **Icon**: `Marketing/Icon_512.png`
- **Thumbnails**: `Marketing/Thumbnail_1_Night.png`, `Thumbnail_2_Camp.png`, `Thumbnail_3_Forest.png`
- **Genre**: Survival. **Devices**: Computer, Phone, Tablet.
- **Maturity questionnaire**: answer honestly. The game has combat with weapons against players and animals
  (no gore) and cosmetic in-experience purchases.
- **Description** (paste):

> **Keep your fire burning. Outlast everyone.**
>
> Every survivor starts with nothing but a campfire and a workbench. Gather sticks and stones, craft your
> first axe, chop trees and keep your fire fed: while it burns, you come back after every death. Let it go
> out and you're on your final life.
>
> 🌲 Explore a living forest of caves, cabins, ruins and mines, and loot chests from Common to Very Rare.
> 🔨 Upgrade your Workbench through five tiers, build walls, gates, traps and storage.
> 🐺 Hunt deer, rabbits and boars, and survive wolf packs and bears that grow bolder every night.
> 🔥 From Night 3 enemy fires can be snuffed. Raid, defend, and be the last one standing.
> ⭐ Level up, earn Coins and Diamonds, unlock classes, power-ups and cosmetics. Robux only buys cosmetics.

## 5. Before going public
- [ ] Play a full match with 3 friends (4 players starts a real match).
- [ ] Buy one Coin pack with a test account and check the Coins arrive and survive a rejoin.
- [ ] Rejoin and check Coins, Diamonds, level, class, power-up and cosmetics all persisted.
- [ ] Try it on a phone (the Roblox app): check the buttons, the panels and the build mode.
- [ ] Delete the Open Cloud API key used for the uploads.
- [ ] (Optional) Pick licensed audio for ambience, crackle, rain and footsteps in `src/shared/Sounds.luau`.
- [ ] Set **Permissions → Public**.
