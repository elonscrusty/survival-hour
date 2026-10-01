local PlotRegistry = require("../src/shared/Logic/PlotRegistry")

return {
	one_plot_per_player_and_player_per_plot = function(t)
		local r = PlotRegistry.new(2)
		t.eq(PlotRegistry.Claim(r, 10), 1)
		t.eq(PlotRegistry.Claim(r, 10), 1, "claiming again returns the same plot")
		t.eq(PlotRegistry.Claim(r, 20), 2)
		t.eq(PlotRegistry.Claim(r, 30), nil, "server full")
	end,

	ownership_checks = function(t)
		local r = PlotRegistry.new(2)
		PlotRegistry.Claim(r, 10)
		PlotRegistry.Claim(r, 20)
		t.ok(PlotRegistry.Owns(r, 10, 1))
		t.no(PlotRegistry.Owns(r, 10, 2), "cannot act on another player's plot")
		t.no(PlotRegistry.Owns(r, 20, 1))
	end,

	release_frees_the_plot = function(t)
		local r = PlotRegistry.new(1)
		PlotRegistry.Claim(r, 10)
		t.eq(PlotRegistry.Release(r, 10), 1)
		t.no(PlotRegistry.Owns(r, 10, 1))
		t.eq(PlotRegistry.Claim(r, 30), 1, "reused")
		t.eq(PlotRegistry.Release(r, 99), nil)
	end,
}
