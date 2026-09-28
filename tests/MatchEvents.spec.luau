local MatchEvents = require("../src/shared/Logic/MatchEvents")

local function seq(values)
	local i = 0
	return function()
		i += 1
		return values[(i - 1) % #values + 1]
	end
end

return {
	no_condition_above_chance = function(t)
		t.eq(MatchEvents.PickCondition(0.7, seq({ 0.9 })), nil)
	end,
	condition_picked_below_chance = function(t)
		local c = MatchEvents.PickCondition(0.7, seq({ 0.1, 0.0 }))
		t.ok(c ~= nil)
		t.eq((c :: any).Id, MatchEvents.Conditions[1].Id)
	end,
	blocked_events_never_chosen = function(t)
		local w = { Fog = 1, Thunderstorm = 1 }
		for i = 0, 9 do
			t.eq(MatchEvents.PickEvent(w, nil, { Thunderstorm = true }, seq({ i / 10 })), "Fog")
		end
	end,
	all_blocked_gives_nil = function(t)
		t.eq(MatchEvents.PickEvent({ Fog = 1 }, nil, { Fog = true }, seq({ 0.5 })), nil)
	end,
	condition_boosts_weight = function(t)
		-- sorted kinds: Fog, Thunderstorm. Misty triples Fog: 3/4 of the range picks Fog
		local misty = MatchEvents.ById.Misty
		t.eq(MatchEvents.PickEvent({ Fog = 1, Thunderstorm = 1 }, misty, {}, seq({ 0.7 })), "Fog")
		t.eq(MatchEvents.PickEvent({ Fog = 1, Thunderstorm = 1 }, nil, {}, seq({ 0.7 })), "Thunderstorm")
	end,
	day_one_is_clear = function(t)
		t.eq(MatchEvents.BaseWeather(1, 1, nil, seq({ 0 })), "Clear")
	end,
	rain_and_cloud_bands = function(t)
		t.eq(MatchEvents.BaseWeather(2, 0.2, nil, seq({ 0.1 })), "Rain")
		t.eq(MatchEvents.BaseWeather(2, 0.2, nil, seq({ 0.3 })), "Cloudy")
		t.eq(MatchEvents.BaseWeather(2, 0.2, nil, seq({ 0.5 })), "Clear")
		t.eq(MatchEvents.BaseWeather(2, 0.2, MatchEvents.ById.Rainy, seq({ 0.3 })), "Rain")
	end,
	conditions_stay_subtle = function(t)
		for _, c in MatchEvents.Conditions do
			t.ok((c.WildlifeInterval or 1) >= 0.8 and (c.PredatorAggro or 1) <= 1.2, c.Id)
		end
	end,
	compass_words = function(t)
		t.eq(MatchEvents.Compass(0, -10), "north")
		t.eq(MatchEvents.Compass(10, 0), "east")
		t.eq(MatchEvents.Compass(0, 10), "south")
		t.eq(MatchEvents.Compass(-10, -10), "north-west")
	end,
}
