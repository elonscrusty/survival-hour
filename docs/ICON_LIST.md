# Icon list (menus and UI)

Right now every icon in the game is drawn in code from a shape, a colour and a symbol
(DECISIONS D36). This is the list of everything that would show a real image icon instead.
Make them **512×512 transparent PNGs** with one consistent style (same outline, lighting and
angle). Once they're uploaded to Roblox, send Claude the image IDs and each one gets swapped in.
Anything without an image keeps its current drawn icon.

Counts are in brackets. **Priority 1** is what players see most.

## Priority 1: currencies and main buttons (25)
- **Currencies (2):** Coins, Diamonds
- **Lobby menu tiles (8):** Party, Class, Power-up, Locker, Profile, Shop, How to Play, Buy Coins
- **Lobby top bar (1):** Settings (gear)
- **In-match buttons (9):** Bag, Craft, Build, Map, Attack, Aim/Block, Heal, Swap, Run
- **In-match status (5):** Health, Stamina, Campfire fuel, Lives / Final Life, Day/Night clock

## Priority 2: items in the bag, craft and storage menus (68)
- **Resources (12):** Stick, Stone, Wood, Plant Fibre, Leather, Rope, Berries, Mushroom,
  Scrap, Iron, Coal, Rare Component
- **Axes (4):** Crude Axe, Stone Axe, Iron Axe, Steel Axe
- **Pickaxes (4):** Crude Pickaxe, Stone Pickaxe, Iron Pickaxe, Steel Pickaxe
- **Other tools (4):** Crowbar, Sledgehammer, Repair Hammer, Canteen
- **Weapons (10):** Fists, Crude Spear, Stone Spear, Crude Bow, Hunting Bow, Crossbow, Sword,
  Shield, Flintlock Pistol, Hunting Rifle
- **Ammo (3):** Arrows, Bolts, Bullets
- **Healing (3):** Bandage, First Aid Kit, Medkit
- **Explosives (1):** Breaching Charge
- **Backpacks (5):** Fibre Pack, Hide Pack, Scrap-Frame Pack, Iron-Frame Pack, Expedition Pack
- **Armour (16):** Leather Vest, plus Helmet / Chestpiece / Leggings in each of 5 materials:
  Hide, Reinforced Hide, Scrap, Iron, Tactical
  (tip: make 3 shapes and recolour them per material, which is 3 drawings instead of 15)
- **Resources on the map (2):** Tree and Rock markers (optional)

## Priority 3: build menu (19)
Wooden Crate, Reinforced Chest, Metal Locker, Survival Safe, Wooden Wall, Wooden Door,
Wooden Floor, Window Wall, Reinforced Wall, Reinforced Door, Scrap Wall, Metal Wall, Heavy Gate,
Spike Barricade, Snare, Bear Trap, Tripwire Alarm, Advanced Alarm, Watchtower

## Priority 4: Class Hall and Power-ups (17)
- **Classes (7):** Survivor, Lumberjack, Miner, Hunter, Scavenger, Raider, Tracker
  (a portrait each, like the class cards in the screenshot)
- **Power-ups (10):** Strong Back, Endurance, Toolsmith, Quick Heal, Runner, Firekeeper,
  Craftsman, Night Owl, Hardy, Second Wind

## Priority 5: Locker cosmetics (62)
- **Outfits (6):** Woodsman Plaid, Ranger Greens, Autumn Hunter, Night Stalker, Ember Warden,
  Pumpkin Patch
- **Tool skins (4):** Copper Wrap, Moss Grip, Frostbite, Gilded
- **Backpack skins (3):** Canvas Pack, Leaf Camo Pack, Royal Pack
- **Campfire skins (4):** Blue Flame, Spirit Flame, Void Flame, Jack-o'-Flame
- **Workbench skins (2):** Oak Plate, Ironbound Plate
- **Storage skins (2):** Mossy Crest, Gold Crest
- **Nameplates (10):** Bark, Moss, Silver, Gold, Ember, Seasoned, Centurion, Ghostly,
  Veteran, Legend
- **Titles (21):** usually text only, so these can share one "title scroll" icon
- **Emotes (4):** Wave, Flex, Warm Hands, Pumpkin Cheer
- **Elimination effects (3):** Ember Burst, Leaf Storm, Starfall
- **Victory poses (3):** Torch Held High, Axe on Shoulder, Log Throne
- **Locker tabs (11):** one small icon per type above (can reuse one item from each group)

## Roblox website images (needed to publish, 15)
- **Badges (9, 512×512, circular crop):** First Night, First Blood, Fire Extinguisher, Explorer,
  Bear Hunter, Survivor, Untouchable, Final Stand, Master Crafter
- **Robux products (6):** 500 Coins, 1,200 Coins, 3,000 Coins, 7,000 Coins, Founder Bundle,
  Ember Bundle
- Game icon and thumbnails already exist in `Marketing/`.

## Small extras (optional)
- Rarity gems: Common, Uncommon, Rare, Epic, Legendary (5)
- Notification symbols: info, success, warning, danger (4)
- Map markers: your camp, POIs (cave, cabin, ruins, mine), supply drop, event (about 7)
- Halloween event banner (1)

**Total:** about 205 icons, or about 190 if the armour and title tricks are used.
Priorities 1-2 (about 90 icons) cover most of what players see.
