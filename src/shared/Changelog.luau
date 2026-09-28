--!strict
-- "What's new" notes, shown once in the lobby to returning players after an
-- update. When publishing an update: bump Config.Version and add an entry at
-- the top (newest first). Players who haven't finished a match skip it.

export type Entry = { Version: string, Lines: { string } }

local Changelog: { Entry } = {
	{
		Version = "1.0.0",
		Lines = {
			"Survival Hour is live. Thanks for playing!",
			"Premium members now show a gold ★ on their name tag.",
			"Tell us what you think in the game's group or comments.",
		},
	},
}

return Changelog
