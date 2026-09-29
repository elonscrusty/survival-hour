--!strict
-- Uploaded icon images (Roblox image asset ids), by icon key. Anything missing
-- keeps its drawn glyph icon. Keys:
--   Item_<ItemId>        bag / craft / storage / hotbar / build menu (e.g. Item_StoneAxe)
--   Class_<ClassId>      Class Hall badges            Perk_<PerkId>     power-ups
--   Cosmetic_<Id>        Locker                       Product_<Key>     Robux shop
--   Lobby_<Tile>         lobby menu tiles (Party, Class, PowerUp, Locker, Profile, Shop, HowToPlay, BuyCoins)
--   Hud_<Button>         in-match buttons (Bag, Craft, Build, Map, Attack, Aim, Heal, Swap, Run)
--   Currency_Coins / Currency_Diamonds
-- The list in docs/ICON_LIST.md shows what each icon is for.

local IconIds: { [string]: number } = {}

return IconIds
