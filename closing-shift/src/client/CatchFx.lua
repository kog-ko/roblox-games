--!strict
-- When the Night Manager catches someone: the caught player gets a burst of TV static and a
-- distorted sting; everyone else sees who was sent home. No gore.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Caught = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Caught") :: RemoteEvent

local CatchFx = {}
local player = Players.LocalPlayer :: Player
local COLS, ROWS = 32, 18

local function sting()
	local s = Instance.new("Sound")
	s.SoundId = Config.Sounds.StingFired
	s.Volume = 1
	s.PlaybackSpeed = 0.55
	local d = Instance.new("DistortionSoundEffect")
	d.Level = 0.75
	d.Parent = s
	s.Parent = SoundService
	s:Play()
	task.delay(8, function()
		s:Destroy()
	end)
	local crackle = Instance.new("Sound")
	crackle.SoundId = Config.Sounds.Buzz
	crackle.Looped = true
	crackle.Volume = 0.6
	crackle.PlaybackSpeed = 0.5
	crackle.Parent = SoundService
	crackle:Play()
	task.delay(1.4, function()
		crackle:Destroy()
	end)
end

function CatchFx.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CatchFx"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 150
	gui.Parent = player:WaitForChild("PlayerGui")

	local static = Instance.new("Frame")
	static.Size = UDim2.fromScale(1, 1)
	static.BackgroundColor3 = Color3.new(0, 0, 0)
	static.BorderSizePixel = 0
	static.Visible = false
	static.Parent = gui
	local cells: { Frame } = {}
	for y = 0, ROWS - 1 do
		for x = 0, COLS - 1 do
			local c = Instance.new("Frame")
			c.BorderSizePixel = 0
			c.Position = UDim2.fromScale(x / COLS, y / ROWS)
			c.Size = UDim2.fromScale(1 / COLS + 0.002, 1 / ROWS + 0.002)
			c.Parent = static
			table.insert(cells, c)
		end
	end
	local msg = Instance.new("TextLabel")
	msg.BackgroundTransparency = 1
	msg.AnchorPoint = Vector2.new(0.5, 0.5)
	msg.Position = UDim2.fromScale(0.5, 0.5)
	msg.Size = UDim2.fromOffset(520, 70)
	msg.Font = Enum.Font.Arcade
	msg.TextScaled = true
	msg.TextColor3 = Color3.fromRGB(230, 40, 35)
	msg.TextStrokeTransparency = 0
	msg.ZIndex = 2
	msg.Text = ""
	msg.Parent = gui

	local rng = Random.new()
	local staticUntil = 0
	RunService.RenderStepped:Connect(function()
		if os.clock() > staticUntil then
			static.Visible = false
			return
		end
		static.Visible = true
		for _, c in cells do
			local v = rng:NextNumber(0.05, 0.85)
			c.BackgroundColor3 = Color3.new(v, v, v * 1.05)
		end
	end)

	local penalty = Config.Manager.TimePenalty
	Caught.OnClientEvent:Connect(function(who: Player)
		if who == player then
			staticUntil = os.clock() + 1.3
			sting()
			msg.Text = string.format("SENT HOME  -0:%02d", penalty)
		else
			msg.Text = string.format("%s WAS SENT HOME  -0:%02d", string.upper(who.DisplayName), penalty)
		end
		msg.TextTransparency = 0
		msg.TextStrokeTransparency = 0
		local id = {}
		msg:SetAttribute("Shown", tostring(id))
		task.delay(2.5, function()
			if msg:GetAttribute("Shown") == tostring(id) then
				TweenService:Create(msg, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			end
		end)
	end)
end

return CatchFx
