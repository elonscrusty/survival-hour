# Studio playtest checklist

_Written 2026-09-28 for the first ever Studio playtest (version 1.1.0). Nothing below has been run in Studio yet._
_Work top to bottom: Part A (the core game) catches the most bugs, so do it first. Parts B and C can wait for a second session._

Tick each box as you go: `[x]` = worked, write ✗ and one line if not.

---

## 0. Before you start (5 min)

**If anything fails:** open **View > Output**, copy every **red** line (and any line mentioning the failed thing), and send them to Claude with the test number (for example "A6.3 failed"). A screenshot of the screen also helps. Yellow/orange lines are usually fine, but send them too if they repeat many times.

Setup:
1. Download `build/SurvivalHour.rbxlx` from the branch and open it in Studio.
2. Open **View > Output** and keep it visible the whole time.
3. Press **Play** (solo).
4. [ ] Output shows `[SurvivalHour] v1.1.0 server started in Lobby mode (Studio)`.
5. [ ] No red lines in Output during the first 30 seconds. (Copy any you see.)
6. [ ] A purple **⚙ DEV** button sits at the top-left. It opens "DEV TOOLS (STUDIO ONLY)".

How to change a setting (needed for some tests):
- Stop the game first. In **Explorer**, open **ReplicatedStorage > Shared > Config** (double-click).
- Near the top is a block called `Config.Dev`. Change only the value after the `=` sign, then Play again.
- Put it back the way it was when the test is done.

Good to know:
- In Studio your profile starts with **20000 Coins and 300 Diamonds** and is **not saved** (unless test A12 says otherwise).
- In Studio you can play a match alone. It won't end by itself: use DEV **End match (my team wins)**.
- The DEV **Skip phase** button jumps Day → Night → Day, so you don't have to wait 2 minutes.

---

## Part A: core game (do this first)

### A1. Title screen and lobby
1. [ ] The title screen shows a slow camera circling the lobby fire and an **ENTER THE REFUGE** button.
2. [ ] The button first says "Loading the forest…" (grey), then turns green.
3. [ ] Tap it: you stand in the lobby clearing, golden-hour light, campfire in the middle.
4. [ ] The top bar shows your level, ◆ 300 and 20000 Coins.
5. [ ] The menu buttons (Party, Class, Power-up, Locker, Profile, Shop, ?) each open a panel, and ✖ closes it.
6. [ ] **Profile** panel: claim the daily bonus. Coins go up by 50.
7. [ ] With no season forced (normal setting), there is **no** Halloween banner, no purple mist and no pumpkins. (Today is before the event dates.)

### A2. Ready up and match start
1. [ ] Tap **READY UP**. It changes to "Searching… tap to cancel".
2. [ ] Tap again: searching stops. Tap once more to ready again.
3. [ ] After about 6 seconds a loading screen with tips appears.
4. [ ] Output shows `[Match] forest built in X.XXs`. Write the number down (target: under 10 s).
5. [ ] You appear next to your own campfire. A "GET READY" countdown runs for 12 seconds.
6. [ ] After the countdown it becomes Day 1 and a timer shows.
7. [ ] Top-right has BAG, CRAFT, BUILD, MAP. The fire fuel bar shows about **50%**.

### A3. Gathering by hand
1. [ ] Walk to a twig pile, a loose rock and a fern. A prompt appears on each; hold/press it.
2. [ ] Sticks, Stone and Plant Fibre appear in your pack (press **I** to check).
3. [ ] Tiny bits fly off when you gather. No red lines.
4. [ ] Your pack has **6 slots**. When all 6 are full, you get a "pack full" style warning, not an error.

### A4. Crafting
1. [ ] Gather at least 8 Stick, 3 Stone and 3 Plant Fibre (or use DEV **+20 of every material**).
2. [ ] At your Workbench press **C**. The WORKBENCH panel opens.
3. [ ] Craft **Crude Axe**. A short progress bar runs (about 1.5 s).
4. [ ] The pack loses exactly 8 Stick, 3 Stone and 3 Plant Fibre. The axe appears in a tool slot.
5. [ ] Start a craft and walk away mid-way: it cancels and nothing is taken.
6. [ ] Recipes from higher tiers show a lock.

### A5. Chopping and mining
1. [ ] Equip the Crude Axe (number key) and hit a **small** tree. Chips fly; the last hit throws a bigger burst.
2. [ ] A small tree gives **exactly 4 Wood**.
3. [ ] A **large** tree refuses the Crude Axe (needs a Stone Axe). Use DEV **Give Stone Axe**, then it gives **16 Wood**.
4. [ ] DEV **Give Stone Pickaxe**, mine a small rock pile: **3 Stone**. A large rock: **12 Stone**.
5. [ ] The chopped tree leaves a stump. (It regrows later; no need to wait.)

### A6. Campfire
1. [ ] Stand at your fire with Wood. Use the **Add Wood** prompt.
2. [ ] Each Wood adds about 2% to the fuel bar. Wood leaves your pack.
3. [ ] The fire keeps burning and nothing turns red in Output.
4. [ ] Standing near your fire slowly heals you (after DEV **Take 25 damage**, health creeps up).
5. [ ] DEV **Extinguish Fox fire** (use Owl if your team is Owl): a dark-red flash and a "YOUR FIRE IS OUT" banner.
6. [ ] After that, the HUD says you are on your **Final Life** (thin red frame round the screen edge).
7. [ ] Start a new match before continuing (DEV **End match**, wait for the lobby, ready again).

### A7. Workbench upgrade
1. [ ] Try the real upgrade: Tier II costs 64 Wood, 36 Stone, 10 Plant Fibre (pack + your storage together). Skip if too slow.
2. [ ] Or press DEV **Workbench Lv 2**. The Workbench model changes and a "⚒ WORKBENCH TIER II" banner shows.
3. [ ] Press **C**: Tier II recipes are now unlocked.
4. [ ] DEV **Workbench Lv 5**: the Workbench shows Tier V (steel top). No red lines.

### A8. Building
1. [ ] Get Wood (DEV **+20 of every material**, twice if needed). Press **B**. The BUILD picker opens.
2. [ ] Pick **Wood Wall** (12 Wood). A see-through preview follows you. **R** rotates it.
3. [ ] Preview is **red** outside your camp, on top of the fire or Workbench, or overlapping another wall.
4. [ ] Preview is green inside your camp. Place it: 12 Wood leaves the pack, the wall stands on the ground (not half-buried).
5. [ ] Place a second wall end-to-end with the first: it's allowed.
6. [ ] Build a **Wooden Door** (20 Wood, 2 Rope) and walk through it: it opens for you.
7. [ ] Build a **Wooden Crate** (storage). Open it, put materials in, take them out. Numbers match.

### A9. Death and respawn
1. [ ] DEV **Kill me**. A respawn screen shows who/what killed you and counts down from **8**.
2. [ ] You respawn at your own campfire with a short golden shimmer (3 s protection).
3. [ ] A supply bag lies where you died with your materials. Your worn gear and tools stayed with you.
4. [ ] Kill yourself again: the countdown is **12**. Third time: **16**. Fourth and later: **20**.
5. [ ] Walk to the supply bag and take your things back.
6. [ ] DEV **Extinguish** your own fire, then **Kill me**: you are **eliminated** (no respawn). The spectator bar appears.
7. [ ] The spectator bar has a **Return to Lobby** button and **PLAY AGAIN**. Return to Lobby puts you back in the lobby.

### A10. Day and night
1. [ ] DEV **Skip phase** during Day 1: it becomes Night 1. Lighting goes dark-blue but you can still see.
2. [ ] At night, animals get more aggressive: DEV **Spawn Wolf**. A wolf comes at you, shows a warning, then lunges.
3. [ ] Kill it (DEV **Give Sword**). It topples over and drops Leather.
4. [ ] **Skip phase** again: Day 2 begins. You get a golden shimmer for 15 s (sunrise protection).
5. [ ] During that shimmer you can't hurt other players (check in C1 with two players).

### A11. Match end and rewards
1. [ ] Note your Coins and ◆ in the lobby before the match.
2. [ ] In a match, DEV **End match (my team wins)**.
3. [ ] The end screen shows VICTORY, your place (1st), XP, Coins, ◆ and a recap (day reached, animals, resources...).
4. [ ] Rewards include **+250 Coins**, **+500 XP** and **exactly +2 ◆** for the win (plus anything earned during the match).
5. [ ] A short "survival story" timeline lists real things you did (first tools, nights survived...).
6. [ ] After about 15 seconds you are back in the lobby. The top bar shows the new totals.
7. [ ] Play another match and press **PLAY AGAIN** on the end screen: you land in the lobby already searching.
8. [ ] Profile panel: matches played and wins went up.

### A12. Rejoin keeps your progress (needs a setting)
Setup: **File > Game Settings > Security > Enable Studio Access to API Services** ON. In Config, set `SaveInStudio = true`.
Note: this uses your real save for this game. That's fine before launch. Coins start at the normal amount, not 20000.
1. [ ] Play. Write down your Coins, ◆ and level.
2. [ ] Win a match (DEV **End match**). Write down the new totals.
3. [ ] Stop. Play again. The totals are the **same** as in step 2.
4. [ ] Buy something in the Locker, stop, play again: you still own it and still wear it.
5. [ ] Output has no red lines mentioning DataService or DataStore.
6. [ ] Put `SaveInStudio` back to `false` when done.

---

## Part B: newest features (this session)

### B1. Launch extras
**Analytics (should do nothing in Studio)**
1. [ ] Through a whole match there are **no** lines mentioning `TelemetryService` or `AnalyticsService` in Output.

**Premium ★ tag**
1. [ ] Zoom out and look at the tag above your character's head.
2. [ ] If your account has Roblox Premium: it reads **★ Lv 1** in gold. If not: **Lv 1** in white, no star.
3. [ ] Wear a Title from the Locker: the tag becomes "(★) Title · Lv N". Take it off: the title part disappears.

**What's new panel and favourite prompt**
These only appear for returning players, and your Studio profile is new each time, so in normal Studio play they should stay hidden.
1. [ ] Normal Studio play: **no** "WHAT'S NEW" panel and no favourite prompt appear. (Correct for a new player.)
2. [ ] With saving on (A12 setup): session 1, win one match, stop. Session 2: about 4 s after entering the lobby, Roblox asks you to **favourite** the game (in Studio it may just do nothing; there must be no red line).
3. [ ] Session 3: the favourite prompt does **not** come back.
4. [ ] To see the WHAT'S NEW panel itself: set `PreviewWhatsNew = true` in `Config.Dev`, press Play. The panel opens in the lobby showing the newest notes. Set it back to `false` after.

**Restart notice**
1. [ ] Can't be tested in Studio (Studio never shows it). Check it once live: Creator Dashboard > "Restart servers" should show "This server is closing (usually for an update)…" before you're kicked.

### B2. Animation loader
No animations are uploaded yet, so **nothing should look different**.
1. [ ] In a match, swing fists, axe (tap and hold), sword, spear; chop, mine, craft, eat, bandage. Everything moves like before (the built-in poses).
2. [ ] Wolves, bears, deer, boars and rabbits walk and run as before (DEV **Spawn** buttons).
3. [ ] Play an emote from the Locker in the lobby: same as before.
4. [ ] No lines starting `[AnimTracks]` appear in Output.

**Later, when you upload your first clip (one-time check):**
1. Upload a light-swing animation from your own account (kcdrewcarter). Copy its number.
2. Send the number to Claude, or add `SwingLight = <number>,` in **ReplicatedStorage > Shared > AnimationIds**.
3. [ ] In a match, DEV **Give Sword** and tap attack: your clip plays instead of the built-in swing.
4. [ ] Everything else (chopping, walking, other swings) still uses the built-in poses.
5. [ ] With 2 clients (C1 setup), the other player sees your clip too.
6. [ ] If the clip is broken, after about 4 s Output shows `[AnimTracks] clip SwingLight didn't load; using the procedural animation` and swings go back to normal. Send Claude that line.

### B3. Halloween 2026 season
Setup: in Config, set `ForceSeason = "Halloween2026"`. Keep `SaveInStudio = false` (the preview is ignored when saving is on).

**Lobby look**
1. [ ] Output shows no red lines at start.
2. [ ] The lobby has a warm orange tint and a thin purple mist near the ground that follows you.
3. [ ] **Six jack-o'-lanterns** stand in a ring round the lobby fire, facing it, sitting on the ground (not floating or buried), glowing orange and flickering.
4. [ ] An orange banner reads "🎃 Halloween event: N days left · limited items in the Locker" (N is about 35 today).
5. [ ] Tapping the banner opens the **Locker**.
6. [ ] Screenshot the lobby for Claude (to judge whether the tint and mist look good).

**Locker limited items** (you have 20000 Coins)
1. [ ] These appear with an orange "🎃 LIMITED · N days left" tag: Pumpkin Patch (Outfit) 7500, Ghostly Nameplate 22000, Night Terror (Title) 6000, Pumpkin Cheer (Emote) 3000, Jack-o'-Flame (Campfire skin) 15000.
2. [ ] **Ghostly Nameplate** Buy button is grey (22000 is more than you have).
3. [ ] Buy **Pumpkin Patch**: Coins go 20000 → 12500. The tag changes to "LIMITED EDITION" and a Wear button appears.
4. [ ] Wear it: your body turns orange with dark legs.
5. [ ] **Jack-o'-Flame** is now grey (15000 > 12500). Buy **Pumpkin Cheer** (3000) and press ▶ Play: the emote plays.
6. [ ] Title tab: **Hallowed** shows "Play 5 matches during Halloween 2026 (0/5)" and a lock, no Buy button.

**In a match**
1. [ ] Start a match. **Two** jack-o'-lanterns stand next to **your own** campfire.
2. [ ] Walk to an enemy camp (or check in C1 with two players): **no** lanterns there on your screen.
3. [ ] The mist and tint stay during day and night and don't make night unreadable.
4. [ ] End the match: back in the lobby the camp lanterns are gone and the six lobby ones are still there.

**Hallowed title counting** (all in one Play session; it resets when you stop)
Each counting match: start, gather one thing by hand, **Skip phase** twice (Day 1 → Night 1 → Day 2), then **End match**.
1. [ ] After one counting match, the Hallowed card shows **(1/5)**.
2. [ ] A match ended on **Day 1** (no skipping) does **not** count.
3. [ ] A match where you reach Day 2 but gather **nothing** does **not** count. (DEV "+20 materials" doesn't count as gathering.)
4. [ ] After the 5th counting match, a notification says "Unlocked: Hallowed…" and the title can be worn. Tag over head: "Hallowed · Lv N".
5. [ ] Optional (slow): stand still for 4+ minutes in a match until the AFK warning and "rewards paused" show, then reach Day 2 and end: it does **not** count.

**Season off again**
1. [ ] Set `ForceSeason = nil`. Play: no banner, no tint, no mist, no pumpkins, no Halloween items in the Locker.

---

## Part C: edge cases (most likely to break)

### C1. Two players at once
Setup: **Test tab > Clients and Servers**, choose **2** players, press **Start**. Two player windows plus a server window open.
1. [ ] Both windows reach the lobby. Each sees the other walking.
2. [ ] Tap READY UP in both windows within 6 seconds. Both land in the **same** match at **different** camps.
3. [ ] Each player's HUD shows its own team (Fox, Owl...). Both fire bars start at about 50%.
4. [ ] Player 1 hits Player 2 with a sword: Player 2's health drops, both see the hit.
5. [ ] During the first 3 s after a respawn, or the 15 s sunrise shimmer, hits do **no** damage.
6. [ ] Player 2 builds a wall; Player 1 can't build inside Player 2's camp (red preview).
7. [ ] Player 1 kills Player 2: Player 1 sees "⚔ YOU DOWNED …"; Player 2's respawn screen names Player 1.
8. [ ] Extinguish Player 2's fire (DEV), then kill Player 2: Player 2 is eliminated; Player 1 gets VICTORY and **+2 ◆**. Player 2's end screen shows 2nd place.
9. [ ] Both return to the lobby afterwards.

### C2. Leaving mid-match
1. [ ] In a 2-player match, close Player 2's window. Player 1's match keeps running without errors.
2. [ ] Player 1 then wins (or the match ends by itself). Note which happened for Claude.
3. [ ] Eliminated player presses **Return to Lobby** while the match goes on: they reach the lobby and can READY again.
4. [ ] Solo: close the Play session mid-match (Stop). The Output has no red lines while stopping.

### C3. Dying during an action
For each: start the action, then press DEV **Kill me** (or have the other player kill you).
1. [ ] While crafting: the progress bar vanishes; nothing crafted, nothing lost; you can craft after respawn.
2. [ ] While chopping a tree: after respawn you can chop again; your arm isn't stuck in a pose.
3. [ ] While using a bandage (**H**) or eating: the heal stops; no stuck pose.
4. [ ] While the BUILD preview is showing: the preview disappears; build works after respawn.
5. [ ] With the crate (storage) panel open: the panel closes; nothing is duplicated.
6. [ ] While adding wood to the fire: fuel is correct after respawn.

### C4. Night and day switching mid-action
1. [ ] Press **Skip phase** while crafting, chopping and holding a prompt: each action finishes or cancels cleanly.
2. [ ] Skip phase while dead (respawn countdown running): you still respawn normally.
3. [ ] Reach Night 3 (Skip phase 5 times from Day 1): a "FIRES EXPOSED" announcement shows.
4. [ ] Wolves spawned at night leave or stop at dawn.
5. [ ] With the Halloween season forced, switch day/night a few times: lanterns and mist stay, no flicker to white.

### C5. Mobile layout (device emulator)
Setup: **Test tab > Device** (the phone icon), pick a phone, turn it to **landscape**, then Play.
Try: **iPhone SE** (small), a modern phone (like iPhone 14), and an **iPad**.
1. [ ] Lobby: READY UP, the top bar and the menu buttons don't overlap each other.
2. [ ] Halloween banner (with ForceSeason on) fits on screen and doesn't cover READY UP or the menu.
3. [ ] Locker panel fits and scrolls; the "LIMITED" tags and Buy buttons are readable and tappable.
4. [ ] In a match: ATTACK, AIM/BLOCK, HEAL, SWAP and RUN buttons are reachable and don't cover the jump button.
5. [ ] BAG, CRAFT, BUILD, MAP (top-right) are tappable and open their panels.
6. [ ] Prompt cards (gather, Add Wood) can be tapped; hold prompts work by holding.
7. [ ] End screen: PLAY AGAIN button is visible and tappable.
8. [ ] Screenshot any screen where something is cut off or overlapping, with the device name.

---

## When you're done
Send Claude:
- The boxes that failed (test number + one line of what happened).
- Every red Output line, copied as text.
- The forest build time from A2.4.
- Screenshots: lobby with Halloween on (B3), and any broken mobile screen (C5).
