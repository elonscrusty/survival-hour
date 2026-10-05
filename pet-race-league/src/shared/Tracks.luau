-- Race tracks. Each track is a straight run along +X made of segments, laid out by
-- Logic/TrackLayout and built from parts by the server's TrackBuilder.
-- Segment kinds:
--   Straight {L}            plain floor
--   Gap {L}                 no floor: jump it or fall (respawn at checkpoint)
--   Hurdles {L, H, Count}   walls of height H to jump over
--   Ramp {L, Rise}          slope up (Rise > 0) or down (Rise < 0)
--   Steps {L, Count, Rise}  platforms, each Rise higher than the last
--   Boost {L}               speed pad
--   Mud {L}                 slows you down
--   Zigzag {L, Count}       pillars to steer around
export type Segment = {
	Kind: string,
	L: number,
	H: number?,
	Count: number?,
	Rise: number?,
}

export type Track = {
	Id: string,
	Name: string,
	Theme: string, -- "Meadow" | "Canyon" | "Sky"
	Segments: { Segment },
}

local Tracks = {}

local list: { Track } = {
	{
		Id = "MeadowDash",
		Name = "Meadow Dash",
		Theme = "Meadow",
		Segments = {
			{ Kind = "Straight", L = 60 },
			{ Kind = "Hurdles", L = 60, H = 3, Count = 3 },
			{ Kind = "Boost", L = 30 },
			{ Kind = "Gap", L = 6 },
			{ Kind = "Straight", L = 40 },
			{ Kind = "Zigzag", L = 70, Count = 5 },
			{ Kind = "Ramp", L = 40, Rise = 8 },
			{ Kind = "Straight", L = 30 },
			{ Kind = "Ramp", L = 40, Rise = -8 },
			{ Kind = "Mud", L = 40 },
			{ Kind = "Boost", L = 30 },
			{ Kind = "Straight", L = 60 },
		},
	},
	{
		Id = "CanyonLeap",
		Name = "Canyon Leap",
		Theme = "Canyon",
		Segments = {
			{ Kind = "Straight", L = 50 },
			{ Kind = "Gap", L = 7 },
			{ Kind = "Straight", L = 30 },
			{ Kind = "Gap", L = 9 },
			{ Kind = "Boost", L = 30 },
			{ Kind = "Hurdles", L = 70, H = 4, Count = 4 },
			{ Kind = "Mud", L = 30 },
			{ Kind = "Ramp", L = 50, Rise = 12 },
			{ Kind = "Gap", L = 10 },
			{ Kind = "Straight", L = 30 },
			{ Kind = "Zigzag", L = 60, Count = 6 },
			{ Kind = "Ramp", L = 50, Rise = -12 },
			{ Kind = "Boost", L = 30 },
			{ Kind = "Straight", L = 50 },
		},
	},
	{
		Id = "SkySteps",
		Name = "Sky Steps",
		Theme = "Sky",
		Segments = {
			{ Kind = "Straight", L = 40 },
			{ Kind = "Steps", L = 60, Count = 5, Rise = 4 },
			{ Kind = "Straight", L = 30 },
			{ Kind = "Gap", L = 11 },
			{ Kind = "Boost", L = 30 },
			{ Kind = "Hurdles", L = 60, H = 5, Count = 3 },
			{ Kind = "Steps", L = 50, Count = 4, Rise = 5 },
			{ Kind = "Gap", L = 12 },
			{ Kind = "Zigzag", L = 60, Count = 6 },
			{ Kind = "Ramp", L = 60, Rise = -30 },
			{ Kind = "Mud", L = 30 },
			{ Kind = "Boost", L = 30 },
			{ Kind = "Straight", L = 50 },
		},
	},
}

Tracks.List = list
Tracks.ById = {} :: { [string]: Track }
for _, t in list do
	Tracks.ById[t.Id] = t
end

Tracks.Width = 30

return Tracks
