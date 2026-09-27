# Survival Hour — Game Design Document

> Four clans. One forest. Keep your fire burning.

## 1. Pitch
Survival Hour is a 16-player competitive forest survival game for Roblox (PC + mobile).
Four clans of up to four players spawn at campfires around a forest. By day they
gather, craft and fortify. By night wolves, bears and bats roam, leather can be
hunted, and raiders carrying canteens of stream water can put out enemy fires.
A clan whose fire is out can no longer respawn. Last clan standing wins.

## 2. Identity
| Clan | Colour | Symbol | Camp motif |
|------|--------|--------|------------|
| Fox  | ember orange `#E8743B` | ▲ triangle | red-cedar lodge, orange banners |
| Owl  | river blue `#3B8BE8`   | ● circle   | slate-roof hut, blue lanterns |
| Stag | heather violet `#9B59D0` | ◆ diamond | antler arch, violet banners |
| Hare | meadow gold `#E8C63B`  | ■ square   | thatched hut, gold pennants |

Colours are always paired with the clan symbol and name so they never rely on colour alone.

Visual style: stylised-realistic. Real Roblox materials (Wood, WoodPlanks, Slate,
Grass, LeafyGrass, Rock, Fabric) on chunky, readable silhouettes; warm day
palette and a cool blue night that stays readable.

## 3. Match flow
1. **Lobby** — party up (≤4), pick an equipped powerup, shop, ready up (UI toggle or step on the Ready ring).
2. **Matchmaking** — parties are packed into 4 teams (≤4 each, 8–16 players, all teams non-empty, parties never split).
3. **Match** — Day (120 s) / Night (120 s) repeating with no time limit.
4. **Win** — last clan with a living or legitimately respawnable player. Winners still in the server get +10 💎.
5. **Return** — players are sent back to the lobby.

## 4. Lives and fire
* Every death while your fire burns uses one of **3 free respawns** (5 s delay).
* With no free respawns left and the fire burning, the player gets a **20 s revive window** in which they or a teammate may buy a Robux revive. Price tier rises with each paid revive that player has received this match (whoever pays).
* When the window closes, the player is eliminated. Pending prompts never extend it.
* **Fire out ⇒ no respawns or revives.** Any death eliminates. Fires never relight.
* Fires can only be extinguished at night, by an enemy holding **Pour** for 10 s with a filled canteen.

## 5. Progression inside a match
Gather (sticks, stone, plants by hand; wood with an axe) → craft **Stone Axe** →
build walls/storage → hunt at night for **leather** → craft **rope** from plants →
upgrade the workbench (L2) → **Canteen** → fill at a stream → raid at night.

Full recipes, costs and stats: [TUNING.md](TUNING.md).

## 6. Systems summary
* **Inventory:** Weapon ×2, Tool ×1, Utility ×1, worn Armor, bandage pouch (3), ammo pouch, resource pack (30 units).
* **Workbench:** 3 levels × 5 recipes. Upgrades are shared and paid from team storage plus the upgrader's pack.
* **Building:** free placement and rotation inside a 55-stud radius around your fire. Server-validated.
* **Storage:** has to be built. Teammates deposit and withdraw. Enemies can steal (3 s channel, interrupted by damage).
* **Wildlife:** wolves (packs, lunge), bears (roar, charge), bats (swooping swarms). They spawn only at night and avoid burning campfire light.
* **Loot:** 1 free public care package every day (3 random entries, 4 s open). Players can buy extra public packages. Hidden forest crates restock each dawn.
* **Healing:** slow regeneration near your own burning fire; bandages (3 s, +45 HP) from crates, packages or Robux.
* **Powerups:** 6 permanent powerups, each with 3 levels. One is equipped at a time and can only be changed in the lobby.

## 7. Fixed requirements vs. chosen defaults
Fixed requirements from the brief are applied as written. Where the brief left something open, the default we chose is listed in [DECISIONS.md](DECISIONS.md).
