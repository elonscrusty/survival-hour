# Pet Expedition: Studio playtest checklist

Open `build/PetExpedition.rbxlx` in Roblox Studio. Keep the **Output** window open (View → Output) the whole time.
Red lines in Output are errors; yellow lines are warnings. Tick each box when it works. If a check fails, take a
screenshot of the screen and copy the red lines from Output (see the last section).

**Getting coins and gems fast:** there is no dev cheat button or command in the code. Gems: Shop → Gems → "Test buy"
(free in Studio). Coins: only by farming, plus the 2x Coins test boost. Expeditions: no timer shortcut, so use the gem Skip.

**Important:** once "Studio Access to API Services" is on, everything you test-buy in Studio (passes, gems) is saved
to your real account and stays in the live game. Do sections 1-10 with it OFF, then turn it on for section 11.

## 1. First boot
- [ ] 1. Press **Play**. Within ~10 seconds six islands appear in a row with bridges, gates and water around them.
- [ ] 2. Output shows no red lines. (With API access off, one yellow line "Studio has no DataStore access" is normal.)
- [ ] 3. Top of screen: coins show **150**, gems show **0** with a green **+** button.
- [ ] 4. Left side: 8 buttons: Pets, Shop, Trips, Quests, Index, Islands, Trade, Settings.
- [ ] 5. A yellow hint at the bottom says "Walk to the egg stand and hatch your first pet!" with a glowing beam and bouncing arrow.
- [ ] 6. Keys P, M, X, J, I, N, T, K each open their window; Esc closes it.
- [ ] 7. In the Meadow hub you can find: Meadow Egg stand, Prism Egg stand, Expedition Board, Craft Machine, Rebirth Statue, Index Book.

## 2. Hatching
- [ ] 1. Walk to the Meadow Egg and press the prompt (E). The Hatch window opens with a spinning egg and price **100**.
- [ ] 2. The Odds list shows every pet with a percentage, and "NEW" next to pets you don't have. The percentages look like they add up to 100%.
- [ ] 3. Press **Hatch 1**. The egg animation plays (about 3 seconds), the pet is revealed, a "New pet discovered" toast appears, coins drop to **50**.
- [ ] 4. The new pet follows you. The hint changes to "Tap a coin pile to send your pets!".
- [ ] 5. With fewer than 100 coins, press Hatch 1: a red message says you can't afford it, no coins are taken.
- [ ] 6. **Hatch 3** without the pass shows a lock and a popup offering Triple Hatch. Press "Not now".
- [ ] 7. Shop → Passes → Triple Hatch → **Test buy**. A "Thank you! You got Triple Hatch" toast shows.
- [ ] 8. Hatch 3 now shows the price for 3 eggs (300) and gives 3 pets in one animation.
- [ ] 9. Test-buy **Fast Hatch**: the animation now takes about 1 second.
- [ ] 10. Test-buy **Lucky**: the egg window shows "Luck x1.5 (Rare+ boosted)", old odds crossed out and new odds in green.
- [ ] 11. Press **Auto: OFF** so it turns ON. Eggs keep hatching, a pill "Auto hatching ..." with a red **Stop** sits at the bottom.
- [ ] 12. Walk far away from the stand while auto hatching: it stops with "Auto hatch stopped: you walked away."
- [ ] 13. Prism Egg stand shows a gem price (400). Buy gems first (section 9), hatch it, gems drop by 400.

## 3. Farming breakables
- [ ] 1. Click a coin pile near you. Your pets run to it, an HP bar shrinks, it breaks, coins fly to the coin counter.
- [ ] 2. A break effect and sound play, and a "+coins" popup appears. A new breakable appears there after 6-14 seconds.
- [ ] 3. Try crates, chests, gem rocks and big chests: bigger ones take longer and pay more; gem rocks sometimes give gems.
- [ ] 4. Click a breakable very far away: "Too far away! Walk closer."
- [ ] 5. Pets → Unequip All, then click a coin pile: "Equip a pet first! Open Pets."
- [ ] 6. Walk away from a breakable while your pets are attacking it: nothing errors in Output.
- [ ] 7. Reset your character (Esc → Reset) mid-attack: you respawn, pets come back, farming still works.

## 4. Gates and teleport
- [ ] 1. Walk to the gate to Mushroom Grove: a barrier blocks you and the prompt says "Open 5K".
- [ ] 2. With under 5,000 coins, try to open it: refused, coins unchanged.
- [ ] 3. Farm to 5,000, open it (confirm popup). Coins drop by 5,000, the barrier disappears, you can walk through.
- [ ] 4. An island banner shows "Mushroom Grove" when you arrive. Its egg stand costs 3.6K.
- [ ] 5. Islands window (N): Meadow and Grove have **Teleport**, Frostbite shows "Open 120K", the rest show Locked.
- [ ] 6. Teleport back and forth: you land on the island each time.

## 5. Pets: inventory, equip, lock, delete, craft
- [ ] 1. Open Pets (P). Tiles show each pet with its power. Equipped pets are marked.
- [ ] 2. Select a pet → **Equip** / unequip works. You can't equip more than 3 (without passes).
- [ ] 3. **Equip Best** equips the 3 strongest. **Unequip All** removes them all from your side.
- [ ] 4. Test-buy **+3 Pets Equipped**: you can now equip 6.
- [ ] 5. **Lock** a pet, then press Delete on it: "That pet is locked." Unlock it again.
- [ ] 6. Delete an equipped pet: "Unequip it first...". Delete an unequipped one: "Deleted 1 pet +coins".
- [ ] 7. **Multi-delete**: tap several pets, the button shows "Delete 3", confirm, they are gone.
- [ ] 8. With 5 of the same pet (unlocked), press **Craft**: confirm, "Crafted Golden ..." toast, 5 pets become 1 gold pet.
- [ ] 9. With fewer than 5: "Need 5 matching unlocked pets (you have N)."
- [ ] 10. The Craft Machine in the hub opens the same crafting choices.
- [ ] 11. Pets gain levels while farming: a "reached level 2!" toast appears after a while.

## 6. Expeditions
- [ ] 1. Open Trips (X) or the Expedition Board. One free slot shows "Start". Two locked slots show "Unlock +2 slots".
- [ ] 2. Start → pick Sunny Meadow → pick 5 min → pick up to 3 pets → it shows "Expected about N coins" → Send.
- [ ] 3. Toast "Your pets set off! Come back in 5m". The slot shows a progress bar counting down and "Skip (gems)".
- [ ] 4. Pets on the trip can't be equipped, deleted or crafted (they show as busy).
- [ ] 5. Press Skip with enough gems: confirm "Finish now?", about 10 gems for 5 minutes, then the button says **Claim!**.
- [ ] 6. Claim: a reward window shows coins (maybe gems, an egg, or a rare pet) and a **Yay!** button.
- [ ] 7. Locked islands in step 2 show "Locked" and say "Open (island) first!".
- [ ] 8. Test-buy **+2 Expedition Slots**: 3 slots now. Run 3 trips at once.
- [ ] 9. Optional: let one 5-minute trip finish without skipping; it turns to Claim! on its own.

## 7. Quests, daily, playtime, Index
- [ ] 1. Quests (J) → Daily tab: "Claim Day 1" gives **500 coins and 10 gems**. Pressing again is refused.
- [ ] 2. Quests tab: 3 quests with progress bars. Hatch or break things and watch the matching bar go up.
- [ ] 3. Finish one quest: Claim gives its gems; the button then says "Claimed".
- [ ] 4. Gifts tab: after **3 minutes** of play the first gift (300 coins) can be claimed; 8 minutes gives 5 gems.
- [ ] 5. Index (I or the Index Book): discovered pets in colour, others hidden. Reward rows show "found/needed".
- [ ] 6. A red dot with a count appears on side buttons when something can be claimed.

## 8. Rebirth
- [ ] 1. Open the Rebirth Statue. It lists what you get, what resets and what you keep, and a bar "coins / 6B".
- [ ] 2. The Rebirth button is greyed out below 6 billion coins.
- Note: there is no dev command to give coins, so a real rebirth can't be tested in Studio yet. Ask Claude for a Studio-only "give coins" button if you want to test it.

## 9. Shop and every Robux item (all "Test buy" in Studio)
- [ ] 1. The green **+** next to gems opens Shop → Gems. Tabs: Passes, Gems, Boosts.
- [ ] 2. Gems: test-buy each pack. Gems go up by exactly 250, 550, 1,500, 3,300, 7,000, 19,000.
- [ ] 3. VIP: coins from breakables go up about 20%; your chat messages show a gold **[VIP]** tag.
- [ ] 4. Auto Farm: Settings → Auto Farm switches ON; pets attack nearby coins without clicking. Before buying it shows "Get pass".
- [ ] 5. Big Backpack: pet storage goes from 60 to 210 (shown in Pets).
- [ ] 6. Lucky, Triple Hatch, Fast Hatch, +3 Equipped, +2 Slots: already checked in sections 2, 5, 6.
- [ ] 7. Buying a pass you own: "You already own (pass)!".
- [ ] 8. 2x Coins boost: a timer appears top-right (30:00) and coins per break double. Buy again: timer extends to about 60:00.
- [ ] 9. 2x Luck boost: timer appears; egg odds show the boost.
- [ ] 10. Server Luck: a banner under the coins shows your name and 15:00 for everyone in the server.
- [ ] 11. Settings: Music, Sound effects and Hide other pets switch ON/OFF and stay after closing the window.

## 10. Trading (2 players)
Setup: Test tab → Clients and Servers → 2 players → Start. Three windows open (server + 2 players).
- [ ] 1. Both players hatch a few pets. Player 1 → Trade (T) → **Request** next to Player 2. Toast "Trade request sent".
- [ ] 2. Player 2 sees "Player1 wants to trade!" with a shrinking bar and Accept/Decline.
- [ ] 3. Decline: nothing opens. Request again within 10 s: "Wait Ns before asking again."
- [ ] 4. Let a request run out (20 s): the popup closes on its own.
- [ ] 5. Accept: both see the trade window, "Your offer" and "Their offer". No gem box (trading is pets only).
- [ ] 6. Add pets on both sides; each side sees the other's pets appear. A locked pet: "Locked pets can't be traded".
- [ ] 7. Both press **Ready**: a 4-second countdown starts. Change an offer during it: countdown stops, both un-ready.
- [ ] 8. Let the countdown finish: the pets swap. Check both Pets windows; received pets are unlocked.
- [ ] 9. During a trade, try opening another window: "Finish or cancel your trade first."
- [ ] 10. Start a new trade, then close Player 2's window (leave): Player 1's trade closes, nobody loses pets.
- [ ] 11. Pets on an expedition can't be added to a trade.

## 11. Saving (needs API access)
Setup: File → Publish, then Game Settings → Security → **Enable Studio Access to API Services** → Save.
- [ ] 1. Play. No yellow "no DataStore access" line in Output.
- [ ] 2. Note your coins, gems, pet count and one expedition timer. Press Stop, wait 5 seconds, Play again.
- [ ] 3. Everything is the same; the expedition timer kept running while you were away.
- [ ] 4. Play for 2+ minutes (autosave), stop, play again: still saved.

## 12. Phone view
Test tab → **Device** → pick a phone (e.g. iPhone 14), landscape. Press Play.
- [ ] 1. Coins, gems and the side buttons fit on screen and don't overlap.
- [ ] 2. Open every window: all buttons are visible and tappable, nothing is cut off at the edges.
- [ ] 3. Tapping a coin pile with the mouse (as a finger) sends pets. The jump button doesn't cover menus.
- [ ] 4. Hatch animation, trade window and reward popups fit the screen.

## What to send Claude
- The section and step number that failed (e.g. "6.5").
- A screenshot of the screen at that moment.
- In Output, right-click → **Copy All** (or select the red lines and Ctrl+C) and paste the text. Red lines matter most; include the 3 lines above them.
- For trading, copy Output from the **Server** window too, not just the player windows.
