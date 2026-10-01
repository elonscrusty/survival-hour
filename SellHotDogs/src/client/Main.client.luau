--!strict
-- Sell Hot Dogs client entry: render server state, send requests. No grants are computed here.
local Controllers = script.Parent:WaitForChild("Controllers")

local State = require(Controllers.State)
local Effects = require(Controllers.Effects)
local Hud = require(Controllers.Hud)
local WorldUI = require(Controllers.WorldUI)
local Panels = require(Controllers.Panels)
local Dialogs = require(Controllers.Dialogs)
local PhoneUI = require(Controllers.PhoneUI)
local DashUI = require(Controllers.DashUI)
local Ambient = require(Controllers.Ambient)

Effects.init()
Hud.init()
WorldUI.init()
Panels.init()
Dialogs.init()
PhoneUI.init()
DashUI.init()
Ambient.init()
State.init()
