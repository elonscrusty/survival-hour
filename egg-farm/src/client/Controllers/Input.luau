--!strict
-- Keyboard / gamepad bindings.
--   F (keyboard) or R2 (gamepad): SPAWN. Tap = one spawn, hold = repeat (~8/s).
--     (Space is jump and E is the default ProximityPrompt key, so F is used.)
--   B (gamepad) or Backspace: close the open menu / modal (Back).
-- Touch and mouse go through the on-screen buttons.

local ContextActionService = game:GetService("ContextActionService")

local Input = {}

Input.SpawnKeys = { Enum.KeyCode.F, Enum.KeyCode.ButtonR2 }
Input.BackKeys = { Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace }

function Input.Start(host: any, hud: any)
	ContextActionService:BindAction("EggFarmSpawn", function(_, state: Enum.UserInputState)
		if host:IsBlocking() then
			hud.SpawnRelease()
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin then
			hud.SpawnPress()
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			hud.SpawnRelease()
		end
		return Enum.ContextActionResult.Sink
	end, false, table.unpack(Input.SpawnKeys))

	ContextActionService:BindAction("EggFarmBack", function(_, state: Enum.UserInputState)
		if not host:IsBlocking() then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin then
			host.Router:Back()
		end
		return Enum.ContextActionResult.Sink
	end, false, table.unpack(Input.BackKeys))
end

return Input
