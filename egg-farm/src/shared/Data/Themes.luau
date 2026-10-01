--!strict
-- Farm themes, one per egg. Colours are RGB 0-255 (shared code cannot use Color3 in tests).
-- The palette keeps the same grass/wood/roof structure across themes so every farm reads as the
-- same low-poly world: ground, path, wood, roof, accent, sky tint, decoration kind.

export type Theme = {
	name: string,
	ground: { number },
	groundEdge: { number },
	path: { number },
	wood: { number },
	roof: { number },
	accent: { number },
	fog: { number },
	ambient: { number },
	decor: string, -- "trees" | "clover" | "hives" | "palms" | "pines" | "cacti" | "rocks" | "crystals" | "orbs" | "spires"
}

return {
	meadow = { name = "Sunny Meadow", ground = { 108, 186, 82 }, groundEdge = { 86, 158, 66 }, path = { 214, 186, 132 }, wood = { 168, 112, 70 }, roof = { 206, 64, 52 }, accent = { 255, 214, 74 }, fog = { 196, 228, 255 }, ambient = { 128, 128, 140 }, decor = "trees" },
	clover = { name = "Clover Hills", ground = { 76, 176, 96 }, groundEdge = { 58, 146, 78 }, path = { 222, 200, 150 }, wood = { 150, 104, 72 }, roof = { 46, 140, 92 }, accent = { 255, 255, 255 }, fog = { 200, 240, 220 }, ambient = { 120, 140, 128 }, decor = "clover" },
	honey = { name = "Honey Grove", ground = { 150, 182, 70 }, groundEdge = { 124, 156, 58 }, path = { 232, 196, 110 }, wood = { 160, 100, 52 }, roof = { 236, 160, 36 }, accent = { 255, 196, 40 }, fog = { 255, 236, 190 }, ambient = { 150, 136, 110 }, decor = "hives" },
	beach = { name = "Seashell Shore", ground = { 236, 214, 156 }, groundEdge = { 218, 192, 132 }, path = { 250, 236, 200 }, wood = { 186, 140, 96 }, roof = { 54, 170, 196 }, accent = { 255, 120, 110 }, fog = { 190, 236, 255 }, ambient = { 140, 150, 160 }, decor = "palms" },
	snow = { name = "Frosty Peaks", ground = { 234, 242, 250 }, groundEdge = { 206, 220, 236 }, path = { 170, 196, 220 }, wood = { 132, 96, 72 }, roof = { 70, 120, 200 }, accent = { 140, 220, 255 }, fog = { 220, 232, 250 }, ambient = { 150, 160, 180 }, decor = "pines" },
	desert = { name = "Cactus Mesa", ground = { 226, 168, 104 }, groundEdge = { 200, 140, 84 }, path = { 246, 214, 160 }, wood = { 150, 94, 60 }, roof = { 196, 84, 52 }, accent = { 90, 170, 90 }, fog = { 255, 222, 180 }, ambient = { 160, 136, 110 }, decor = "cacti" },
	volcano = { name = "Magma Ridge", ground = { 82, 72, 72 }, groundEdge = { 60, 52, 54 }, path = { 140, 110, 100 }, wood = { 96, 70, 60 }, roof = { 220, 80, 30 }, accent = { 255, 140, 40 }, fog = { 120, 90, 80 }, ambient = { 140, 100, 90 }, decor = "rocks" },
	crystal = { name = "Crystal Caverns", ground = { 120, 96, 170 }, groundEdge = { 96, 74, 146 }, path = { 196, 180, 236 }, wood = { 110, 90, 130 }, roof = { 80, 200, 220 }, accent = { 200, 120, 255 }, fog = { 170, 150, 220 }, ambient = { 130, 120, 170 }, decor = "crystals" },
	space = { name = "Nebula Fields", ground = { 52, 58, 96 }, groundEdge = { 40, 44, 76 }, path = { 120, 130, 190 }, wood = { 90, 96, 130 }, roof = { 230, 90, 200 }, accent = { 120, 240, 255 }, fog = { 40, 40, 80 }, ambient = { 110, 110, 160 }, decor = "orbs" },
	golden = { name = "Sunburst Kingdom", ground = { 246, 210, 96 }, groundEdge = { 224, 184, 70 }, path = { 255, 240, 196 }, wood = { 176, 120, 60 }, roof = { 255, 255, 255 }, accent = { 255, 170, 30 }, fog = { 255, 236, 180 }, ambient = { 170, 150, 110 }, decor = "spires" },
} :: { [string]: Theme }
