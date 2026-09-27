--!strict
-- PSX bodycam screen overlay: scanlines plus a faint vertical grid (together they read as big
-- pixels), a vignette, a slow brightness flicker, moving film grain and, in the store, a bodycam
-- readout (REC, a date and time stamp that follows the shift clock, the unit number). The line
-- frames are static and only rebuilt on resize; the flicker and grain update at 20 Hz. Each part
-- has a toggle in Config.PSX. The lobby uses exactly the same screen.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Fonts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Fonts"))
local Prefs = require(script.Parent:WaitForChild("Prefs"))

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

local function buildGrain(gui: ScreenGui)
	local holder = frame(gui, { Name = "Grain", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	local rng = Random.new()
	local specks: { Frame } = {}
	for _ = 1, 90 do
		table.insert(specks, frame(holder, { Size = UDim2.fromOffset(2, 2), BackgroundTransparency = 0.8 }))
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.05 then
			return
		end
		acc = 0
		for _, f in specks do
			f.Position = UDim2.fromScale(rng:NextNumber(), rng:NextNumber())
			local v = if rng:NextNumber() < 0.5 then 1 else 0
			f.BackgroundColor3 = Color3.new(v, v, v)
			f.BackgroundTransparency = rng:NextNumber(0.7, 0.9)
		end
	end)
end

-- The time stamp: the shift's in-game clock (2:00 -> 6:00 AM) with seconds, otherwise 1:45 AM.
local function stamp(): string
	local phase = ReplicatedStorage:GetAttribute("Phase")
	local secs = 105 * 60 -- 1:45 AM before a shift
	if phase == "Shift" or phase == "Payoff" or phase == "LightsOut" then
		local start = (ReplicatedStorage:GetAttribute("ShiftStart") or 0) :: number
		local length = (ReplicatedStorage:GetAttribute("ShiftLength") or 480) :: number
		local span = (Config.ShiftEndHour - Config.ShiftStartHour) * 3600
		local f = math.clamp((workspace:GetServerTimeNow() - start) / length, 0, 1)
		secs = Config.ShiftStartHour * 3600 + math.floor(f * span)
	end
	local date = os.date("!%Y-%m-%d", os.time()) :: string
	return string.format("%s  %02d:%02d:%02d", date, secs // 3600, (secs % 3600) // 60, secs % 60)
end

local function buildOsd(gui: ScreenGui)
	local function osdText(name: string, pos: UDim2, anchor: Vector2, align: Enum.TextXAlignment): TextLabel
		local t = Instance.new("TextLabel")
		t.Name = name
		t.BackgroundTransparency = 1
		t.AnchorPoint = anchor
		t.Position = pos
		t.Size = UDim2.fromOffset(360, 20)
		t.FontFace = Fonts.Mono
		t.TextSize = 17
		t.TextXAlignment = align
		t.TextColor3 = Color3.fromRGB(235, 235, 225)
		t.TextTransparency = 0.15
		t.TextStrokeTransparency = 0.6
		t.Parent = gui
		return t
	end
	local rec = osdText("Rec", UDim2.new(1, -24, 0, 18), Vector2.new(1, 0), Enum.TextXAlignment.Right)
	rec.RichText = true
	local time = osdText("Stamp", UDim2.new(1, -24, 0, 40), Vector2.new(1, 0), Enum.TextXAlignment.Right)
	local unit = osdText("Unit", UDim2.new(0, 24, 1, -20), Vector2.new(0, 1), Enum.TextXAlignment.Left)
	unit.Text = string.format("QUIK STOP #047  NIGHT CREW  CAM %02d", ((Players.LocalPlayer :: Player).UserId % 90) + 10)
	unit.TextTransparency = 0.35
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		local on = os.clock() % 1.2 < 0.7
		rec.Text = (if on then '<font color="#E0322B">●</font>' else "  ") .. " REC"
		time.Text = stamp()
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
	if PSX.Grain then
		buildGrain(gui)
	end
	-- the gear menu's SCREEN EFFECTS switch
	Prefs.Watch("ScreenFx", function(on)
		for _, name in { "Lines", "Grain", "Flicker" } do
			local f = gui:FindFirstChild(name)
			if f and f:IsA("GuiObject") then
				f.Visible = on
			end
		end
	end)
	-- the bodycam readout is for the store (the lobby shares this module)
	if PSX.BodycamOsd then
		buildOsd(gui)
	end
end

return Overlay
