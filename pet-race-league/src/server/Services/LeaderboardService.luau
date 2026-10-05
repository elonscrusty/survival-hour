-- Global top-10 trophies board in the lobby (OrderedDataStore). Falls back to the
-- players in this server when DataStores aren't available (Studio without API access).
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local LeaderboardService = {}

local ctx: any
local store: OrderedDataStore? = nil
local rows: { TextLabel } = {}

local function buildBoard()
	local board = ctx.WorldService.Leaderboard :: BasePart?
	if not board then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.14)
	title.BackgroundTransparency = 1
	title.Text = "TOP RACERS"
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 220, 90)
	title.Parent = gui
	for i = 1, 10 do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.fromScale(0.92, 0.075)
		row.Position = UDim2.fromScale(0.04, 0.15 + (i - 1) * 0.083)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = if i == 1 then Color3.fromRGB(255, 215, 0) elseif i == 2 then Color3.fromRGB(210, 210, 220) elseif i == 3 then Color3.fromRGB(220, 150, 90) else Color3.new(1, 1, 1)
		row.Text = i .. ".  ---"
		row.Parent = gui
		rows[i] = row
	end
	gui.Parent = board
end

local nameCache: { [number]: string } = {}
local function nameOf(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local n = if ok then name else "Racer"
	nameCache[userId] = n
	return n
end

local function refresh()
	-- push our players' scores
	local entries = {}
	if store then
		for _, p in Players:GetPlayers() do
			local d = ctx.DataService.Get(p)
			if d and d.Trophies > 0 then
				pcall(function()
					(store :: OrderedDataStore):SetAsync("u" .. p.UserId, d.Trophies)
				end)
			end
		end
		local ok, pages = pcall(function()
			return (store :: OrderedDataStore):GetSortedAsync(false, 10)
		end)
		if ok then
			for _, e in pages:GetCurrentPage() do
				local id = tonumber(string.sub(e.key, 2))
				if id then
					table.insert(entries, { Name = nameOf(id), Trophies = e.value })
				end
			end
		end
	end
	if #entries == 0 then
		for _, p in Players:GetPlayers() do
			local d = ctx.DataService.Get(p)
			if d then
				table.insert(entries, { Name = p.DisplayName, Trophies = d.Trophies })
			end
		end
		table.sort(entries, function(a, b)
			return a.Trophies > b.Trophies
		end)
	end
	for i, row in rows do
		local e = entries[i]
		row.Text = if e then string.format("%d.  %s  -  %d", i, e.Name, e.Trophies) else i .. ".  ---"
	end
end

function LeaderboardService.Init(c)
	ctx = c
	local ok, res = pcall(function()
		return DataStoreService:GetOrderedDataStore("PetRaceLeague_Trophies_v1")
	end)
	if ok then
		store = res
	end
end

function LeaderboardService.Start()
	buildBoard()
	task.wait(5)
	while true do
		local ok, err = pcall(refresh)
		if not ok then
			warn("[Leaderboard] " .. tostring(err))
			store = nil -- fall back to this server's players
		end
		task.wait(60)
	end
end

return LeaderboardService
