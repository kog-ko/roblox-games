--!strict
-- The lobby's fun bits on the client: the obby timer (reads ObbyRun / ObbyStart, set by the server's
-- Obby module), the trampolines (BouncePad tag, Power attribute: bounced locally so it feels instant)
-- and the flickering neon (Blinker tag).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)

local ObbyUi = {}

local player = Players.LocalPlayer

local function timer()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ObbyTimer"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 70)
	label.Size = UDim2.fromOffset(360, 44)
	label.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
	label.BackgroundTransparency = 0.3
	label.Font = Enum.Font.Arcade
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(110, 230, 120)
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
	gui.Parent = player:WaitForChild("PlayerGui")
	RunService.RenderStepped:Connect(function()
		local run = player:GetAttribute("ObbyRun")
		local started = player:GetAttribute("ObbyStart")
		if type(run) ~= "string" or type(started) ~= "number" then
			gui.Enabled = false
			return
		end
		local info = Config.Obbies[run]
		gui.Enabled = true
		label.Text = string.format("%s  %.1fs", if info then info.Name else run, workspace:GetServerTimeNow() - started)
	end)
end

local function bouncePads()
	local last = 0
	local function hook(pad: Instance)
		if not pad:IsA("BasePart") then
			return
		end
		pad.Touched:Connect(function(hit)
			local char = player.Character
			if not char or hit.Parent ~= char then
				return
			end
			local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
			local now = os.clock()
			if not root or now - last < 0.3 then
				return
			end
			last = now
			local power = (pad:GetAttribute("Power") or 80) :: number
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(v.X, power, v.Z)
		end)
	end
	for _, p in CollectionService:GetTagged("BouncePad") do
		hook(p)
	end
	CollectionService:GetInstanceAddedSignal("BouncePad"):Connect(hook)
end

local function blinkers()
	local rng = Random.new()
	task.spawn(function()
		while true do
			for _, p in CollectionService:GetTagged("Blinker") do
				if p:IsA("BasePart") and rng:NextNumber() < 0.25 then
					p.Transparency = if p.Transparency > 0 then 0 else (if rng:NextNumber() < 0.5 then 0.6 else 0)
				end
			end
			task.wait(0.15)
		end
	end)
end

function ObbyUi.Start()
	timer()
	bouncePads()
	blinkers()
end

return ObbyUi
