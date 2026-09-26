--!strict
-- On-screen tutorial for nights whose data has Tutorial = true (Night 1):
--   1. MOP THE SPILL      highlights the nearest spill until the first clean
--   2. BEAT THE CLOCK     a few seconds on clean-everything-before-6
--   3. CHECK THE BACK ROOM when the final spill appears, highlighted through walls
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rules"))
local Cleaned = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Cleaned") :: RemoteEvent

local Tutorial = {}
local player = Players.LocalPlayer :: Player

local function makeHint(): (Frame, TextLabel)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Tutorial"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12
	gui.Parent = player:WaitForChild("PlayerGui")
	local box = Instance.new("Frame")
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = UDim2.new(0.5, 0, 1, -44)
	box.Size = UDim2.fromOffset(460, 64)
	box.BackgroundColor3 = Color3.fromRGB(12, 14, 12)
	box.BackgroundTransparency = 0.2
	box.BorderSizePixel = 0
	box.Visible = false
	box.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 215, 90)
	stroke.Thickness = 2
	stroke.Parent = box
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromOffset(10, 6)
	t.Size = UDim2.new(1, -20, 1, -12)
	t.Font = Enum.Font.Arcade
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(255, 235, 170)
	t.Parent = box
	return box, t
end

local function highlight(): Highlight
	local h = Instance.new("Highlight")
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.FillColor = Color3.fromRGB(255, 215, 90)
	h.FillTransparency = 0.75
	h.OutlineColor = Color3.fromRGB(255, 225, 120)
	h.Enabled = false
	h.Parent = workspace
	return h
end

function Tutorial.Start()
	local box, text = makeHint()
	local hl = highlight()
	local active = false -- this shift has the tutorial
	local step = 0 -- visible hint (0 = none)
	local stepEndsAt = 0
	local cleanedOnce = false

	local function show(s: number, msg: string, seconds: number?)
		step = s
		text.Text = msg
		box.Visible = true
		stepEndsAt = if seconds then os.clock() + seconds else math.huge
	end
	local function hide()
		step = 0
		box.Visible = false
		hl.Enabled = false
		hl.Adornee = nil
	end

	local function onPhase()
		local phase = ReplicatedStorage:GetAttribute("Phase")
		local rules = Rules.Resolve((ReplicatedStorage:GetAttribute("Night") or 1) :: number, nil, #game:GetService("Players"):GetPlayers())
		active = phase == "Shift" and rules.Tutorial
		if active then
			cleanedOnce = false
			local key = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then "HOLD MOP" else "HOLD E"
			show(1, "MOP THE SPILL: WALK UP TO IT AND " .. key)
		else
			hide()
		end
	end
	ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(onPhase)

	Cleaned.OnClientEvent:Connect(function()
		if step == 1 and not cleanedOnce then
			cleanedOnce = true
			show(2, "NICE. BEAT THE CLOCK: CLEAN EVERY SPILL BEFORE 6:00 AM", 6)
		end
	end)

	local store = workspace:WaitForChild("Store")
	local spills = store:WaitForChild("Spills")
	spills.ChildAdded:Connect(function(c)
		if c.Name == "FinalSpill" and active then
			show(3, "ONE LEFT. CHECK THE BACK ROOM")
			hl.Adornee = c
			hl.Enabled = true
		end
	end)
	spills.ChildRemoved:Connect(function(c)
		if c.Name == "FinalSpill" and step == 3 then
			hide()
		end
	end)

	-- keep the step-1 highlight on the nearest spill; time out timed steps
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.3 then
			return
		end
		acc = 0
		if step ~= 0 and os.clock() > stepEndsAt then
			hide()
			return
		end
		if step ~= 1 then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		local best, bestD = nil, math.huge
		for _, m in spills:GetChildren() do
			local p = m:FindFirstChild("PromptAnchor") :: BasePart?
			if p then
				local d = (p.Position - root.Position).Magnitude
				if d < bestD then
					best, bestD = m, d
				end
			end
		end
		hl.Adornee = best
		hl.Enabled = best ~= nil
	end)
	onPhase()
end

return Tutorial
