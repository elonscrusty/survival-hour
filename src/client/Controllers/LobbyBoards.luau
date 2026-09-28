--!nonstrict
-- In-world lobby boards drawn per player: the Daily Challenges board (your dailies, progress,
-- rewards and the reset timer) and the queue counter over the ready ring. The server builds
-- the parts (Refuge.ChallengeBoard / Refuge.QueueZone); the text comes from Logic/LobbyBoards.
-- The GUIs live in PlayerGui, adorned to the parts, so they are this player's only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LobbyText = require(Shared:WaitForChild("Logic"):WaitForChild("LobbyBoards"))
local State = require(script.Parent.Parent:WaitForChild("State"))

local LobbyBoards = {}

local player = Players.LocalPlayer

local WARM = Color3.fromRGB(255, 225, 160)
local DIM = Color3.fromRGB(200, 184, 160)
local DONE = Color3.fromRGB(150, 240, 150)

local function label(props: { [string]: any }, parent: Instance): TextLabel
	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.Font = Enum.Font.GothamBold
	tl.TextScaled = true
	tl.TextColor3 = WARM
	tl.TextStrokeTransparency = 0.6
	for k, v in props do
		(tl :: any)[k] = v
	end
	tl.Parent = parent
	return tl
end

-- Challenge board ------------------------------------------------------------------------------

local board: { gui: SurfaceGui, reset: TextLabel, rows: Frame }? = nil

local function buildBoard(face: BasePart, gui: Instance)
	-- hide the server's static title on this client; ours draws over the same face
	local static = face:FindFirstChild("BoardStatic")
	if static and static:IsA("SurfaceGui") then
		static.Enabled = false
	end
	local sg = Instance.new("SurfaceGui")
	sg.Name = "ChallengeBoard"
	sg.Adornee = face
	sg.Face = Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(600, 350)
	sg.LightInfluence = 0.15
	sg.ResetOnSpawn = false
	sg.Parent = gui
	label({ Name = "Title", Text = "DAILY CHALLENGES", Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(20, 10), Size = UDim2.new(1, -40, 0, 52) }, sg)
	local reset = label({ Name = "Reset", Text = "", TextColor3 = Color3.fromRGB(140, 220, 255), Position = UDim2.fromOffset(20, 62), Size = UDim2.new(1, -40, 0, 30) }, sg)
	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.fromOffset(20, 104)
	rows.Size = UDim2.new(1, -40, 1, -150)
	rows.Parent = sg
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = rows
	label({ Name = "Hint", Text = "Claim rewards at the Hall of Fame", TextColor3 = DIM, Font = Enum.Font.GothamMedium, Position = UDim2.new(0, 20, 1, -40), Size = UDim2.new(1, -40, 0, 26) }, sg)
	board = { gui = sg, reset = reset, rows = rows }
end

local function drawBoard()
	local b = board
	if not b then
		return
	end
	b.reset.Text = LobbyText.ResetText(math.floor(workspace:GetServerTimeNow()))
	for _, c in b.rows:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local profile = State.Get("Profile")
	local rows = LobbyText.DailyRows(profile and profile.Challenges)
	if #rows == 0 then
		local f = Instance.new("Frame")
		f.BackgroundTransparency = 1
		f.Size = UDim2.new(1, 0, 0, 44)
		f.Parent = b.rows
		label({ Text = "Loading your challenges…", TextColor3 = DIM, Size = UDim2.fromScale(1, 1) }, f)
		return
	end
	for i, r in rows do
		local f = Instance.new("Frame")
		f.LayoutOrder = i
		f.BackgroundColor3 = if r.Done then Color3.fromRGB(40, 70, 44) else Color3.fromRGB(60, 48, 38)
		f.BackgroundTransparency = 0.2
		f.BorderSizePixel = 0
		f.Size = UDim2.new(1, 0, 0, 52)
		f.Parent = b.rows
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = f
		local color = if r.Claimed then DIM elseif r.Done then DONE else WARM
		label({ Text = (if r.Done then "✓ " else "") .. r.Text, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 8), Size = UDim2.new(0.62, -12, 1, -16) }, f)
		label({ Text = r.Progress, TextColor3 = color, Position = UDim2.new(0.62, 0, 0, 8), Size = UDim2.new(0.16, 0, 1, -16) }, f)
		label({ Text = r.Reward, TextColor3 = if r.Claimed then DIM else Color3.fromRGB(255, 210, 90), TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0.78, 0, 0, 8), Size = UDim2.new(0.22, -12, 1, -16) }, f)
	end
end

-- Queue counter --------------------------------------------------------------------------------

local queue: { gui: BillboardGui, title: TextLabel, sub: TextLabel }? = nil

local function buildQueue(anchor: BasePart, gui: Instance)
	local bb = Instance.new("BillboardGui")
	bb.Name = "QueueCounter"
	bb.Adornee = anchor
	bb.Size = UDim2.new(16, 0, 5, 0)
	bb.MaxDistance = 140
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false
	bb.ResetOnSpawn = false
	bb.Parent = gui
	local title = label({ Name = "Title", Text = "READY UP", Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(190, 255, 200), TextStrokeTransparency = 0.2, Size = UDim2.fromScale(1, 0.64) }, bb)
	local sub = label({ Name = "Sub", Text = "", TextColor3 = WARM, TextStrokeTransparency = 0.3, Position = UDim2.fromScale(0, 0.64), Size = UDim2.fromScale(1, 0.36) }, bb)
	queue = { gui = bb, title = title, sub = sub }
end

local function drawQueue()
	local q = queue
	if not q then
		return
	end
	local title, sub = LobbyText.QueueText(State.Get("Lobby"))
	q.title.Text = title
	q.sub.Text = sub
end

-- Start ----------------------------------------------------------------------------------------

local function visible()
	local on = not player:GetAttribute("InMatch") and workspace:GetAttribute("ServerMode") ~= "Match"
	if board then
		board.gui.Enabled = on
	end
	if queue then
		queue.gui.Enabled = on
	end
end

function LobbyBoards.Start()
	local lobby = workspace:WaitForChild("Lobby", 30)
	if not lobby then
		return -- match servers have no lobby
	end
	local gui = player:WaitForChild("PlayerGui")
	local face = lobby:WaitForChild("ChallengeBoard", 20)
	face = face and face:WaitForChild("ChallengeBoardFace", 10)
	if face and face:IsA("BasePart") then
		buildBoard(face, gui)
	end
	local zone = lobby:WaitForChild("QueueZone", 20)
	local anchor = zone and zone:WaitForChild("QueueBoard", 10)
	if anchor and anchor:IsA("BasePart") then
		buildQueue(anchor, gui)
	end
	State.On("Profile", drawBoard)
	State.On("Lobby", drawQueue)
	drawBoard()
	drawQueue()
	player:GetAttributeChangedSignal("InMatch"):Connect(visible)
	workspace:GetAttributeChangedSignal("ServerMode"):Connect(visible)
	visible()
	-- keep the reset timer ticking
	task.spawn(function()
		while true do
			task.wait(30)
			pcall(drawBoard)
		end
	end)
end

return LobbyBoards
