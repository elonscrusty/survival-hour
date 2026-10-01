# Studio test plan (for Carter's PC)

Open `build/SellHotDogs.rbxlx` only, never another place. For each step, tick it and note anything odd, and take a screenshot where marked 📸. Studio's Output window (View → Output) should show `[SellHotDogs] server ready` and no red errors. Copy any red lines into the notes.

## A. First arrival (desktop, Play / F5)
1. You spawn by the road on Plot 1, facing the plot. The world is bright and sunny, there's a road with yellow dashes, and trees are not in the way. 📸
2. The top wallet shows **$1.00**, the name pill shows "*YourName*'s Hot Dogs ✏️", and the bottom bar shows Manage / Powers / Shop.
3. Walk onto the yellow **Hot Dog Stand $1.00** circle. The stand appears with a flash and sound, and the wallet shows $0.00. 📸
4. Over the stand: name, **$1.00**, a green **CLICK** bar and a blue **Upgrade $5.10** button. Click CLICK: the bar fills and counts 1s → 0.1s, then the wallet goes up by exactly $1.00. Pressing `E` near the stand does the same.
5. Spam CLICK during a cycle: you only get paid once per second.
6. Earn $6.20 and step on **Condiment Station**. The output shows **$2.00**. Step on **Cash Register** without $100: you get a red "Need $100.00" message and no cash is taken.
7. Press Upgrade: it costs $5.10, then $7.65, then $11.00, then $19.00. The gold badge shows x1, x2, x3.
8. Buy the Cash Register. CLICK changes to a running timer and cash keeps coming without clicking.
9. Bun Rack and Billboard pads appear in order. The guide sparkle line points at the next affordable pad.

## B. Phone / tablet (Test → Device emulator: iPhone landscape, iPad, a small Android)
10. 📸 each device. Check that the wallet, name pill, toasts, right buttons, bottom bar, phone (lower-left, above the thumbstick) and jump button don't overlap or go off screen.
11. Open Manage / Powers / Shop: the panel fits, scrolls, the tabs change colour and the red ✕ closes it. Long numbers stay inside their buttons.
12. Tap the stand controls in the world. They are big enough to hit.

## C. Mid game (use the Shop's TEST BUY buttons; no Robux is charged)
13. TEST BUY **Manage** → the Manage tab lists businesses with bars and Upgrade buttons that work from anywhere.
14. TEST BUY **Remote Buy** → **Buy Next** appears in the bottom bar and buys the cheapest pad.
15. TEST BUY **Stack Upgrade** → the gold bulk button cycles x1 / x5. The Upgrade button shows the total cost.
16. Shop → **Resend last receipt** → message "Duplicate receipt delivered – no second grant", and nothing doubles. **Cancelled purchase** → nothing changes.
17. Ingredient crates appear at the racks. Walk into one: a cash pop and toast. A friend (2-player test) can't collect yours.
18. Within a few minutes (or right after `game.ServerStorage.SHDDev:Invoke("phone")`) the phone slides in with an offer: try **Raise** (better / final / walk away) and **Accept** (cash once) on separate offers. 📸
19. Buy DogDash, then "DogDash the Game". The right-side **DogDash** button opens the race: pick a racer, bet, Start, mash CHEER. The winner is shown and you're paid only if you win. 📸
20. Tap the name pill: try "badword", a 30-character name and an empty name (all rejected with a message), then a good name (the plot sign updates).

## D. Late game and resets (Studio-only fast-forward hook)
While playing, switch the command bar to the **Server** view and run (it affects every player):
```lua
game.ServerStorage.SHDDev:Invoke("cash", 1, 120)       -- $1e120
game.ServerStorage.SHDDev:Invoke("lifetime", 3.08, 25) -- 20 investors on offer
```
21. Buy Next repeatedly (or walk the pads): all 8 businesses build with their signs, and the staircase appears once everything is owned. 📸 each stage area.
22. Right side **Investors** → shows held/offered → Rebirth → confirm lists what resets → Cancel keeps everything → Rebirth again → "20 investors joined". The plot clears and Manage (TEST BUY) is still owned.
23. Powers: buy Run Faster (needs 400 investors; run `game.ServerStorage.SHDDev:Invoke("investors", 1.5, 3)` first). You walk faster.
24. TEST BUY Forever Purchase → **♾️ Forever** → pick an upgrade → nvm (back, nothing spent) → pick → Yes (token used) → it survives the next rebirth.
25. `game.ServerStorage.SHDDev:Invoke("investors", 5.012, 17)` → **Evolution** at 100% → Evolve → confirm. The stand sign changes to CHILI DOGS, and investors/powers reset.
26. Own everything again → **Ascension** → Ascend → confirm. Prices are x3.33 (stand pad $3.33) and you get +1 Forever token.
27. Huge numbers: `game.ServerStorage.SHDDev:Invoke("cash", 3, 564)` → the wallet shows `$3e564` without overflowing its box. 📸

## E. Saves (mock storage, one Studio session)
28. In 2-player mode, leave with player 2 and rejoin (Studio's client window: close and re-add). Progress comes back.
29. Command bar: `workspace:SetAttribute("SHD_FailLoads",3)`, then rejoin → red banner "save couldn't be loaded". Leave and rejoin normally → the old progress is still there.
30. Offline income: with a Cash Register owned, run `game.ServerStorage.SHDDev:Invoke("offline", 3600)` → "Welcome back!" popup with one hour of automated income → Collect pays once. (Also try leaving 1+ minute in 2-player mode and rejoining.)

## F. Performance and effects
31. With `game.ServerStorage.SHDDev:Invoke("evolutions", 12)` the stands show "MAX SPEED". There's no flood of pops or sounds and the frame rate is fine.

Report: device list, pass/fail per number, screenshots, Output errors.

## G. Pass 2 (look and feel)
32. HUD: the wallet and name pill are small at the top centre. The "Next: …" bar in the top-left shows the next purchase, its picture and how close you are. It turns gold and says READY! when you can afford it. 📸
33. Buttons grow slightly when you hover or press them. Panels and pop-ups pop in. Toasts fade out. New right-side buttons wiggle when they first appear.
34. Buying things: the new building or prop grows out of the ground with confetti, a sound and a small camera bump. "x2 CASH!", "x3 SPEED!", "AUTOMATIC!" and "LEVEL UP!" float over the business.
35. Banners: "$100 earned!" and "$1,000 earned!" appear on the way up, "DogDash is open!" on unlocking a business, and "Hot Dog Stand level 10!" at levels 10, 25, 50 and 100. At each of those levels a picnic table, umbrella, balloons or statue appears by that business and more customers walk up to it.
36. Decor tab: buy each decoration (`SHDDev:Invoke("cash", 1, 13)` first). Check every placement looks deliberate and nothing blocks pads, paths or the stand. 📸 each:
    - an entrance arch, 4 planters lining the walkway and string lights
    - balloons on the stand corners and a diner sign beside it
    - benches facing the path
    - 10 lamp posts along the path
    - a fountain in the middle of the round plaza, with a picnic table and an umbrella either side
    - topiaries by HotDogX
    - the statue at the far end

    Decorations stay after a rebirth.
37. Sky: soft 3D clouds, a hot-dog blimp circling, hot-air balloons, bird flocks and cloud puffs on the horizon. Delivery vans drive along the road. 📸
38. Icons: every menu card and button shows a picture. Before upload these are live 3D previews or emoji; after upload they are the rendered pictures.
39. After uploading the models (`tools/upload_assets.py`): stand-ins turn into the Blender models within a few seconds of starting. If they face backwards, set `MeshYaw = 180` in Config.
