local D = require("../src/shared/Logic/ClassDeals")
local L = require("../src/shared/Logic/ClassHallLayout")
local Classes = require("../src/shared/Classes")
local Progression = require("../src/shared/Progression")

local DAY0 = Progression.DayNumber(1790000000) -- a day in Sept 2026

local function count(t: { [string]: number }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

return {
	exactly_two_deals_20_and_10 = function(t)
		for day = DAY0, DAY0 + 60 do
			local deals = D.Deals(day)
			t.eq(count(deals), 2, "two deals on day " .. day)
			local seen = {}
			for _, pct in deals do
				seen[pct] = true
			end
			t.ok(seen[20] and seen[10], "one 20% and one 10%")
		end
	end,
	never_free_or_default = function(t)
		for day = DAY0, DAY0 + 365 do
			for id in D.Deals(day) do
				local def = Classes.ById[id]
				t.ok(def ~= nil, "known class")
				t.ok(def.Price > 0, "never a free class")
				t.ok(id ~= Classes.Default, "never the default class")
			end
		end
	end,
	deterministic_per_day = function(t)
		for day = DAY0, DAY0 + 30 do
			local a, b = D.Deals(day), D.Deals(day)
			for id, pct in a do
				t.eq(b[id], pct, "same deals every call")
			end
		end
		-- the same UTC day from two clocks (two servers) agrees
		local t1 = DAY0 * 86400 + 5
		local t2 = DAY0 * 86400 + 86399
		t.eq(Progression.DayNumber(t1), Progression.DayNumber(t2))
	end,
	deals_rotate_over_days = function(t)
		local hits: { [string]: boolean } = {}
		for day = DAY0, DAY0 + 60 do
			for id in D.Deals(day) do
				hits[id] = true
			end
		end
		t.ok(count(hits) >= 5, "most paid classes get a deal within two months")
	end,
	price_rounding = function(t)
		local def = Classes.ById.Hunter -- 75
		local found20, found10 = false, false
		for day = DAY0, DAY0 + 365 do
			local pct = D.Percent("Hunter", day)
			local price = D.Price(def, day)
			if pct == 20 then
				t.eq(price, 60)
				found20 = true
			elseif pct == 10 then
				t.eq(price, 68, "67.5 rounds to 68")
				found10 = true
			else
				t.eq(price, 75, "full price without a deal")
			end
		end
		t.ok(found20 and found10, "Hunter gets both deals within a year")
		t.eq(D.Price(Classes.ById.Survivor, DAY0), 0, "free stays free")
	end,
	custom_list = function(t)
		local list = {
			{ Id = "Survivor", Name = "S", Price = 0, Order = 1, Glyph = "", Color = {}, Summary = "", Lines = {}, Effects = {} },
			{ Id = "Solo", Name = "X", Price = 10, Order = 2, Glyph = "", Color = {}, Summary = "", Lines = {}, Effects = {} },
		}
		local deals = D.Deals(DAY0, list)
		t.eq(count(deals), 1, "only one class can be on deal")
		t.eq(deals.Solo, 20)
	end,
	timer_and_stars = function(t)
		t.eq(D.SecondsLeft(DAY0 * 86400), 86400)
		t.eq(D.SecondsLeft(DAY0 * 86400 + 86399), 1)
		t.eq(D.LeftText(5 * 3600 + 12 * 60 + 30), "5h 12m")
		t.eq(D.LeftText(40), "1m")
		t.eq(D.Stars(0), 1)
		t.eq(D.Stars(40), 2)
		t.eq(D.Stars(75), 2)
		t.eq(D.Stars(100), 3)
		t.eq(D.Stars(150), 3)
		t.eq(D.Stars(200), 4)
	end,
	layout_phone_landscape = function(t)
		-- 800x400 phone: Panels scale 0.714, top inset 36 -> about 1098x487 UI units
		local lay = L.Compute(1098, 487)
		t.no(lay.Stacked)
		t.eq(lay.Cols, 3)
		t.ok(lay.CardW >= 110, "cards stay tappable")
		t.ok(lay.Centre.W >= 240, "room for the avatar and buttons")
		t.ok(lay.Right.X + lay.Right.W <= 1098, "fits the width")
		t.ok(lay.Left.H <= 487, "fits the height")
	end,
	layout_desktop_and_narrow = function(t)
		local wide = L.Compute(1670, 900)
		t.no(wide.Stacked)
		t.ok(wide.Cols >= 3 and wide.Cols <= 4)
		t.ok(wide.Right.X + wide.Right.W <= 1670)
		local min = L.Compute(820, 480)
		t.ok(min.Centre.W >= 240, "narrowest wide layout keeps a usable centre")
		local tall = L.Compute(660, 1300)
		t.ok(tall.Stacked, "portrait stacks")
		t.eq(tall.Cols, 2)
		t.ok(tall.Right.X + tall.Right.W <= 660)
		t.ok(tall.Left.Y + tall.Left.H <= 1300)
	end,
}
