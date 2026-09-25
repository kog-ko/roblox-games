--!strict
-- PSX/CRT screen overlay: scanlines plus a faint vertical grid (together they read as big
-- pixels), a vignette and a slow brightness flicker. The line frames are static and only
-- rebuilt on resize; the flicker updates at 20 Hz. Each part has a toggle in Config.PSX.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Overlay = {}
local PSX = Config.PSX
local SPACING = 4

local function frame(parent: Instance, props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.Active = false
	for k, v in props do
		(f :: any)[k] = v
	end
	f.Parent = parent
	return f
end

local function buildLines(gui: ScreenGui)
	local holder = frame(gui, { Name = "Lines", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	local built = Vector2.zero
	local function rebuild()
		local size = gui.AbsoluteSize
		if size == built then
			return
		end
		built = size
		holder:ClearAllChildren()
		for i = 0, math.ceil(size.Y / SPACING) - 1 do
			frame(holder, { BackgroundTransparency = 0.82, Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, i * SPACING) })
		end
		if PSX.PixelGrid then
			for i = 0, math.ceil(size.X / SPACING) - 1 do
				frame(holder, { BackgroundTransparency = 0.92, Size = UDim2.new(0, 1, 1, 0), Position = UDim2.fromOffset(i * SPACING, 0) })
			end
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rebuild)
	rebuild()
end

-- Four edge strips whose gradient fades from dark at the edge to clear toward the middle.
local function buildVignette(gui: ScreenGui)
	local edges = {
		{ size = UDim2.fromScale(1, 0.22), pos = UDim2.fromScale(0, 0), rot = 90 },
		{ size = UDim2.fromScale(1, 0.22), pos = UDim2.fromScale(0, 0.78), rot = -90 },
		{ size = UDim2.fromScale(0.16, 1), pos = UDim2.fromScale(0, 0), rot = 0 },
		{ size = UDim2.fromScale(0.16, 1), pos = UDim2.fromScale(0.84, 0), rot = 180 },
	}
	for _, e in edges do
		local f = frame(gui, { Name = "Vignette", Size = e.size, Position = e.pos, BackgroundTransparency = 0 })
		local g = Instance.new("UIGradient")
		g.Rotation = e.rot
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = f
	end
end

local function buildFlicker(gui: ScreenGui)
	local f = frame(gui, { Name = "Flicker", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	local rng = Random.new()
	local dipUntil = 0
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.05 then
			return
		end
		acc = 0
		local t = os.clock()
		if t > dipUntil and rng:NextNumber() < 0.01 then
			dipUntil = t + rng:NextNumber(0.05, 0.15)
		end
		local dark = 0.03 + 0.025 * math.sin(t * 0.8) + (if t < dipUntil then 0.08 else 0)
		f.BackgroundTransparency = 1 - dark
	end)
end

function Overlay.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "PsxOverlay"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	if PSX.Vignette then
		buildVignette(gui)
	end
	if PSX.Flicker then
		buildFlicker(gui)
	end
	if PSX.Overlay then
		buildLines(gui)
	end
end

return Overlay
