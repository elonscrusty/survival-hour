--!strict
-- Uploaded animation clips (asset ids), by clip name. Empty = every action
-- uses the procedural animation in Controllers/Animation and Controllers/Creatures.
-- Paste the owner's published ids here (e.g. `SwingLight = 1234567890,`); any
-- clip left out keeps its procedural fallback. Clip names and what triggers
-- them: src/shared/Logic/AnimClips.luau. The clips must be owned by the account
-- that owns the experience (kcdrewcarter), or Roblox refuses to play them.

local AnimationIds: { [string]: number } = {}

return AnimationIds
