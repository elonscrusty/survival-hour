--!strict
-- World boards: ProximityPrompts with attribute Menu ("Housing" | "Shipping" | "Workers" |
-- "Silos" | "Upgrades" | "Eggs") and optional Slot open the matching menu. Only prompts inside
-- the local player's own plot (ancestor Model with attribute OwnerUserId == LocalPlayer.UserId)
-- react; prompts on other plots are disabled locally. While a menu is open the whole
-- ProximityPromptService is disabled locally so nothing in the world can be triggered.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")

local Prompts = {}

local FARM_TABS = { Housing = true, Shipping = true, Workers = true, Silos = true }

local me = Players.LocalPlayer

-- The plot Model (Workspace.Plots.Plot<N>) that contains `inst`, if any.
function Prompts.PlotOf(inst: Instance): Model?
	local cur: Instance? = inst.Parent
	while cur and cur ~= Workspace do
		if cur:IsA("Model") and cur:GetAttribute("OwnerUserId") ~= nil then
			return cur
		end
		cur = cur.Parent
	end
	return nil
end

function Prompts.IsMine(inst: Instance): boolean
	local plot = Prompts.PlotOf(inst)
	return plot ~= nil and plot:GetAttribute("OwnerUserId") == me.UserId
end

-- The local player's plot, or nil.
function Prompts.OwnPlot(): Model?
	local plots = Workspace:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, p in plots:GetChildren() do
		if p:IsA("Model") and p:GetAttribute("OwnerUserId") == me.UserId then
			return p
		end
	end
	return nil
end

function Prompts.Start(host: any)
	local watched: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any

	local function apply(prompt: ProximityPrompt)
		if prompt:GetAttribute("Menu") == nil then
			return
		end
		prompt.Enabled = Prompts.IsMine(prompt)
	end

	local function watch(prompt: ProximityPrompt)
		if watched[prompt] then
			return
		end
		watched[prompt] = true
		apply(prompt)
		prompt:GetAttributeChangedSignal("Menu"):Connect(function()
			apply(prompt)
		end)
	end

	local function scanPlot(plot: Instance)
		for _, d in plot:GetDescendants() do
			if d:IsA("ProximityPrompt") then
				watch(d)
			end
		end
	end

	local function hookPlots(plots: Instance)
		plots.DescendantAdded:Connect(function(d)
			if d:IsA("ProximityPrompt") then
				task.defer(watch, d)
			end
		end)
		local function hookPlot(plot: Instance)
			scanPlot(plot)
			plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
				for _, d in plot:GetDescendants() do
					if d:IsA("ProximityPrompt") then
						apply(d)
					end
				end
			end)
		end
		for _, p in plots:GetChildren() do
			hookPlot(p)
		end
		plots.ChildAdded:Connect(hookPlot)
	end

	task.spawn(function()
		local plots = Workspace:WaitForChild("Plots", 60)
		if plots then
			hookPlots(plots)
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
		if player ~= me then
			return
		end
		local menu = prompt:GetAttribute("Menu")
		if type(menu) ~= "string" or not Prompts.IsMine(prompt) then
			return
		end
		local slot = prompt:GetAttribute("Slot")
		local opts = if type(slot) == "number" then { slot = slot } else nil
		if FARM_TABS[menu] then
			host:Open("Farm", menu, opts)
		elseif menu == "Upgrades" then
			host:Open("Upgrades", nil, opts)
		elseif menu == "Eggs" then
			host:Open("Eggs", nil, opts)
		end
	end)

	host:OnBlockingChanged(function(blocking: boolean)
		ProximityPromptService.Enabled = not blocking
	end)
end

return Prompts
