--!strict
-- The shift board by the counter. It lists every night; the party can pick any night up to the
-- lowest one everyone has unlocked. Picking happens in the lobby, through a prompt on the board
-- (the client shows a picker and sends PickNight; the server re-checks everything).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local RoundManager = require(script.Parent.RoundManager)

local PickNight = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PickNight") :: RemoteEvent

local ShiftBoard = {}
local list: Instance
local footer: TextLabel
local prompt: ProximityPrompt
local lastPick: { [Player]: number } = {}

local INK = Color3.fromRGB(240, 235, 215)
local PICKED = Color3.fromRGB(255, 215, 90)
local LOCKED = Color3.fromRGB(120, 105, 85)

local function render()
	local selected = RoundManager.GetNight()
	local unlocked = RoundManager.GroupUnlocked()
	for _, c in list:GetChildren() do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	for i, n in Config.Nights do
		local t = Instance.new("TextLabel")
		t.Name = "Night" .. i
		t.LayoutOrder = i
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, 0.3, -4)
		t.Font = Enum.Font.Arcade
		t.TextScaled = true
		t.TextXAlignment = Enum.TextXAlignment.Left
		local mark = if i == selected then "> " elseif i > unlocked then "x " else "  "
		t.Text = string.format("%sNIGHT %d  %s", mark, i, string.upper(n.Name))
		t.TextColor3 = if i == selected then PICKED elseif i > unlocked then LOCKED else INK
		t.Parent = list
	end
	local phase = ReplicatedStorage:GetAttribute("Phase")
	footer.Text = if phase == "Lobby" then "HOLD TO PICK TONIGHT'S SHIFT" else "SHIFT IN PROGRESS"
	prompt.Enabled = phase == "Lobby"
end

function ShiftBoard.Init(store: Instance)
	local model = store:FindFirstChild("ShiftBoard")
	if not model then
		warn("[ShiftBoard] this Store has no ShiftBoard; rebuild it with StoreBuilder.Build()")
		return
	end
	local board = model:WaitForChild("Board") :: BasePart
	local gui = board:WaitForChild("BoardGui")
	list = gui:WaitForChild("List")
	footer = gui:WaitForChild("Footer") :: TextLabel

	prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShiftBoardPrompt"
	prompt.ActionText = "Pick Night"
	prompt.ObjectText = "Shift Board"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = board
	-- the client opens its picker when this prompt triggers (see NightPicker.lua)

	PickNight.OnServerEvent:Connect(function(player, n)
		if typeof(n) ~= "number" or n ~= n or n % 1 ~= 0 then
			return
		end
		if ReplicatedStorage:GetAttribute("Phase") ~= "Lobby" then
			return
		end
		local now = os.clock()
		if lastPick[player] and now - lastPick[player] < 0.3 then
			return
		end
		lastPick[player] = now
		if n < 1 or n > RoundManager.GroupUnlocked() then
			return
		end
		RoundManager.SetNight(n)
	end)
	Players.PlayerRemoving:Connect(function(p)
		lastPick[p] = nil
	end)

	for _, attr in { "Night", "GroupUnlocked", "Phase" } do
		ReplicatedStorage:GetAttributeChangedSignal(attr):Connect(render)
	end
	render()
end

return ShiftBoard
