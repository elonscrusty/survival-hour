--!strict
-- Client bootstrap: snapshot store, UI (layers, menus, HUD, tutorial, prompts, input, feedback)
-- and then the world visuals (written separately; started only if present).
-- Each piece starts inside a pcall so one failure can't take the whole client down.

local Store = require(script.Parent.Store)

local UI = script.Parent.UI
local Controllers = script.Parent.Controllers
local Menus = script.Parent.Menus

local Layout = require(UI.Layout)
local Num = require(UI.Num)
local Button = require(UI.Button)
local Sound = require(Controllers.Sound)
local Toasts = require(Controllers.Toasts)

local function try(label: string, fn: () -> ())
	local ok, err = pcall(fn :: any)
	if not ok then
		warn("[EggFarm] " .. label .. " failed: " .. tostring(err))
	end
end

Store.Start()
Layout.Start()

-- settings that affect every screen
Store.OnChanged(function(snap: any)
	Num.SetNotation(snap.settings.notation)
	Sound.Apply(snap.settings)
end)
Button.ClickHook = function()
	Sound.Play("click")
end

try("toasts", Toasts.Start)

local host: any = nil
try("menus", function()
	local Host = require(Menus.Host)
	host = Host.new(Store, {
		require(Menus.Shop) :: any,
		require(Menus.Codes) :: any,
		require(Menus.Eggs) :: any,
		require(Menus.Quests) :: any,
		require(Menus.Boosts) :: any,
		require(Menus.Daily) :: any,
		require(Menus.Gifts) :: any,
		require(Menus.Settings) :: any,
		require(Menus.Upgrades) :: any,
		require(Menus.Farm) :: any,
	})
end)

if host then
	local Hud = require(Controllers.Hud)
	try("hud", function()
		Hud.Start(Store, host)
	end)
	try("tutorial", function()
		require(Controllers.Tutorial).Start(Store, host, Hud)
	end)
	try("prompts", function()
		require(Controllers.Prompts).Start(host)
	end)
	try("input", function()
		require(Controllers.Input).Start(host, Hud)
	end)
	try("offline", function()
		require(Controllers.Offline).Start(Store, host)
	end)
end
try("events", function()
	require(Controllers.Events).Start(Store)
end)

-- World visuals (flock, vehicles, workers, effects) are a separate module.
local visualsFolder = script.Parent:FindFirstChild("Visuals")
if visualsFolder and visualsFolder:FindFirstChild("Visuals") then
	try("visuals", function()
		(require :: any)(visualsFolder:FindFirstChild("Visuals")).Start(Store)
	end)
end
