local MenuRouter = require("../src/shared/Logic/MenuRouter")

local function make()
	return MenuRouter.new({
		Shop = { tabs = { "Featured", "Passes", "Gold", "Cash" } },
		Codes = {},
		Farm = { tabs = { "Housing", "Shipping", "Workers", "Silos" } },
		Settings = {},
	})
end

return {
	starts_closed = function(t)
		local r = make()
		t.eq(r:Current(), nil)
		t.no(r:IsBlockingWorld())
	end,
	one_panel_at_a_time = function(t)
		local r = make()
		t.ok(r:Open("Shop"))
		t.ok(r:IsBlockingWorld())
		t.ok(r:Open("Settings"))
		t.eq(r:Current(), "Settings", "opening another replaces it")
		t.no(r:IsOpen("Shop"))
		t.no(r:Open("Nope"), "unknown panel refused")
		t.eq(r:Current(), "Settings")
	end,
	close_and_toggle = function(t)
		local r = make()
		r:Toggle("Shop")
		t.eq(r:Current(), "Shop")
		r:Toggle("Shop")
		t.eq(r:Current(), nil)
		r:Open("Farm")
		r:Close()
		t.no(r:IsBlockingWorld())
	end,
	tabs_remembered = function(t)
		local r = make()
		r:Open("Shop")
		t.eq(r:GetTab("Shop"), "Featured", "first tab by default")
		t.ok(r:SetTab("Cash"))
		t.no(r:SetTab("Bogus"), "unknown tab ignored")
		t.eq(r:GetTab("Shop"), "Cash")
		r:Open("Farm", "Silos")
		t.eq(r:GetTab("Farm"), "Silos")
		r:Close()
		r:Open("Shop")
		t.eq(r:GetTab("Shop"), "Cash", "remembered after reopening")
		r:Open("Farm", "Nope")
		t.eq(r:GetTab("Farm"), "Silos", "bad tab keeps the remembered one")
		t.eq(r:GetTab("Codes"), nil, "panels without tabs")
	end,
	set_tab_without_panel = function(t)
		local r = make()
		t.no(r:SetTab("Cash"))
	end,
	one_modal_on_top = function(t)
		local r = make()
		r:Open("Farm")
		t.ok(r:OpenModal("confirm", { a = 1 }))
		t.no(r:OpenModal("other"), "at most one modal")
		t.eq(r:Modal(), "confirm")
		t.eq(r.modalData.a, 1)
		r:CloseModal()
		t.eq(r:Modal(), nil)
		t.eq(r:Current(), "Farm", "closing the modal keeps the panel")
	end,
	modal_without_panel_blocks = function(t)
		local r = make()
		t.ok(r:OpenModal("offline"))
		t.ok(r:IsBlockingWorld())
		r:CloseModal()
		t.no(r:IsBlockingWorld())
	end,
	opening_panel_clears_modal = function(t)
		local r = make()
		r:Open("Shop")
		r:OpenModal("confirm")
		r:Open("Settings")
		t.eq(r:Modal(), nil)
		r:OpenModal("confirm")
		r:Close()
		t.eq(r:Modal(), nil)
		t.no(r:IsBlockingWorld())
	end,
	back_behaviour = function(t)
		local r = make()
		r:Open("Shop", "Gold")
		r:Open("Codes", nil, true)
		r:OpenModal("confirm")
		r:Back()
		t.eq(r:Modal(), nil, "back closes the modal first")
		t.eq(r:Current(), "Codes")
		r:Back()
		t.eq(r:Current(), "Shop", "back returns to the opener")
		t.eq(r:GetTab("Shop"), "Gold")
		r:Back()
		t.eq(r:Current(), nil, "then closes")
		r:Open("Codes")
		r:Back()
		t.eq(r:Current(), nil, "no opener: close")
	end,
	listeners = function(t)
		local r = make()
		local n = 0
		local off = r:Subscribe(function()
			n += 1
		end)
		r:Open("Shop")
		r:Open("Shop") -- no change
		r:SetTab("Passes")
		off()
		r:Close()
		t.eq(n, 2)
	end,
}
