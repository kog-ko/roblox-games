--!strict
-- First-time tips (Config.Tips): the first time each moment happens to you (the Manager arrives,
-- he grabs you, the Late Customer walks in, a dark night, Overtime, a leak, a big spill, event
-- candy), a card explains it for a few seconds. Each is shown once ever: the server remembers
-- (TipSeen -> TipsSeen attribute), so a tip is never repeated across sessions.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Fonts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Fonts"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Tips = {}
local player = Players.LocalPlayer :: Player

local TEXT: { [string]: string } = {}
for _, t in Config.Tips do
	TEXT[t.Id] = t.Text
end

function Tips.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Tips"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 165 -- above the grab screen, so the grab tip shows over his face
	gui.Parent = player:WaitForChild("PlayerGui")
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, 120)
	card.Size = UDim2.fromOffset(560, 74)
	card.BackgroundColor3 = Color3.fromRGB(235, 228, 195) -- a sticky note from the day manager
	card.BorderSizePixel = 0
	card.Rotation = -1.5
	card.Visible = false
	card.Parent = gui
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(14, 8)
	label.Size = UDim2.new(1, -28, 1, -16)
	label.FontFace = Fonts.Title
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = Color3.fromRGB(35, 35, 60)
	label.Parent = card
	local fitter = script.Parent:FindFirstChild("Fit")
	if fitter then
		require(fitter :: ModuleScript).Scale(card, Vector2.new(560, 74), Vector2.new(40, 200))
	end

	local shownThisSession: { [string]: boolean } = {}
	local queue: { string } = {}
	local busy = false
	local function seen(id: string): boolean
		for s in string.gmatch((player:GetAttribute("TipsSeen") or "") :: string, "[^,]+") do
			if s == id then
				return true
			end
		end
		return shownThisSession[id] == true
	end
	local function pump()
		if busy or #queue == 0 then
			return
		end
		busy = true
		local id = table.remove(queue, 1) :: string
		label.Text = TEXT[id] or id
		card.Visible = true
		card.BackgroundTransparency = 1
		label.TextTransparency = 1
		TweenService:Create(card, TweenInfo.new(0.3), { BackgroundTransparency = 0 }):Play()
		TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
		local r = Remotes:FindFirstChild("TipSeen") :: RemoteEvent?
		if r then
			r:FireServer(id)
		end
		task.delay(if id == "Grab" then 3.5 else 7, function()
			TweenService:Create(card, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			task.wait(0.5)
			card.Visible = false
			busy = false
			pump()
		end)
	end
	local function show(id: string)
		if seen(id) or not TEXT[id] then
			return
		end
		shownThisSession[id] = true
		if id == "Grab" then
			table.insert(queue, 1, id) -- this one can't wait
			if busy then
				-- cut the current card short
				card.Visible = false
				busy = false
			end
		else
			table.insert(queue, id)
		end
		pump()
	end

	-- the moments
	local store = workspace:WaitForChild("Store")
	local props = store:WaitForChild("EventProps")
	props.ChildAdded:Connect(function(c)
		if c.Name == "Manager" then
			task.delay(2, show, "Manager")
		elseif c.Name == "LateCustomer" then
			show("LateCustomer")
		elseif c.Name == "LeakValve" then
			show("Leak")
		end
	end)
	local grab = Remotes:WaitForChild("Grab") :: RemoteEvent
	grab.OnClientEvent:Connect(function()
		show("Grab")
	end)
	local function phase()
		if ReplicatedStorage:GetAttribute("Phase") ~= "Shift" then
			return
		end
		if ReplicatedStorage:GetAttribute("Overtime") then
			show("Overtime")
		end
		if ReplicatedStorage:GetAttribute("DarkNight") then
			show("Dark")
		end
	end
	ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(phase)
	ReplicatedStorage:GetAttributeChangedSignal("DarkNight"):Connect(phase)
	local spills = store:WaitForChild("Spills")
	spills.DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") then
			task.defer(function()
				if d.ObjectText:find("BIG") then
					show("BigSpill")
				end
			end)
		end
	end)
	task.spawn(function()
		local candy = store:WaitForChild("EventCandy", 30)
		if candy then
			candy.ChildAdded:Connect(function()
				task.delay(3, show, "Candy")
			end)
		end
	end)
end

return Tips
