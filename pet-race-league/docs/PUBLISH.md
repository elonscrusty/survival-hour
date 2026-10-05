# Publishing Pet Race League

Everything in the game is done. These steps are the parts only the owner can do on Roblox: publishing, products, badges and uploads. Do them in this order. Steps marked **PC** need Roblox Studio on a computer. Steps marked **Phone OK** work in a phone browser on create.roblox.com.

## 1. Open and publish the place (PC, 10 minutes)
1. Download `pet-race-league/build/PetRaceLeague.rbxlx` from the branch and open it in Roblox Studio.
2. **File → Publish to Roblox As… → Create new experience.** Use the name and description below.
3. **Game Settings** (Home tab):
   - **Security:** turn on **Enable Studio Access to API Services**. This is needed for saving.
   - **Avatar:** Avatar Type = **R15**.
   - **Places → Server Size (Max Players):** 12.
4. Press **Play** once and run through `docs/STUDIO_TESTS.md`, at least sections 1, 2, 5 and 7.

## 2. Experience page (Phone OK)
On create.roblox.com → your experience:
- **Name:** Pet Race League
- **Description:**
  > Hatch adorable pets, ride them and race your friends! 🐾🏁
  > 🥚 Hatch 15 pets from Common to Mythic
  > 🏃 Train Speed, Jump and Stamina in the Speed Ring, Hurdles and Treadmill
  > 🏆 Race on 3 obstacle tracks, win medals and climb from Bronze to Champion league
  > 🎁 Daily rewards, daily quests and codes!
  > Codes: LAUNCH, ZOOM, PETRACE
- **Genre:** Obby & Platformer (or Simulation). **Devices:** Phone, Tablet, Computer, Console.
- **Icon:** upload `models/storeart/Icon.png`.
- **Thumbnails:** upload `models/storeart/Thumb1.png`, `Thumb2.png` and `Thumb3.png`.
- **Maturity & Compliance questionnaire:** answer honestly. The game has no violence or blood, no chat features of its own, and only cosmetic purchases plus Coins. It's normally rated **Minimal / All ages**.

## 3. Robux products (Phone OK)
Experience → **Monetization → Developer Products → Create** for each one below. Copy each product's **ID** into `src/shared/Products.luau` (the `Id = nil` fields).

| Key | Name | Price |
|---|---|---|
| Coins500 | 500 Coins | 25 |
| Coins3000 | 3,000 Coins | 120 |
| Coins10000 | 10,000 Coins | 350 |
| RainbowTrail | Rainbow Trail | 99 |
| GalaxyPaint | Galaxy Paint | 79 |

Then **Monetization → Passes → Create**: **Big Barn** (+36 pet slots), 149 Robux, put on sale. Copy its ID into `Products.Passes`.

## 4. Badges (Phone OK, optional)
Experience → **Engagement → Badges → Create** for each badge below. Each needs a 512×512 image; you can reuse the icon. Put each ID in `Config.Badges` in `src/shared/Config.luau`.

| Key | Badge name | Description |
|---|---|---|
| FirstRace | First Race | Finish your first race |
| FirstWin | Winner! | Win a race against other players |
| GoldMedal | Gold Medal | Finish a race fast enough for Gold |
| Legendary | Legendary Luck | Hatch a Legendary or Mythic pet |
| Gold | Gold League | Reach the Gold league |
| Champion | Champion | Reach the Champion league |
| MaxLevel | Fully Trained | Train any pet stat to level 50 |

Roblox may charge for badges after your free ones each day, so this step is optional.

## 5. Upload the 3D models (needs an API key)
1. create.roblox.com → **Open Cloud → API Keys → Create API Key.** Add **Assets** with **Read** and **Write**. Allowed IPs: `0.0.0.0/0`. Set an expiry date.
2. Either run `ROBLOX_API_KEY=… ROBLOX_USER_ID=<your user id> python3 tools/upload_models.py` on your PC, or add the key to a Claude session as a secret and ask Claude to upload.
3. That fills in the IDs in `src/shared/Models.luau`.
4. **Delete the API key** afterwards.

The game works without this step: it uses part-built pets and props until the models are uploaded.

## 6. Rebuild and publish the final version (PC)
After filling in IDs (steps 3–5), ask Claude to rebuild `build/PetRaceLeague.rbxlx`. Or run `rojo build default.project.json -o build/PetRaceLeague.rbxlx`. Then:
1. Open the new file in Studio.
2. **File → Publish to Roblox** (choose the same experience).
3. Experience page → set it to **Public**.

## 7. After launch
- Add new codes in `Config.Codes` for updates (for example 1K visits) and remove old ones.
- Music: put a licensed track id in `src/shared/Sounds.luau` (`Sounds.Music`). It must be your own upload or Creator Store audio licensed for experiences.
- Check **Analytics → Retention** after a week. If day-1 retention is low, make the first race easier (`Config.Race.MedalSpeeds`).
