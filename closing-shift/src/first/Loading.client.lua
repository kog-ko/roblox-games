--!strict
-- CLOSING SHIFT loading screen (ReplicatedFirst, both places). Replaces Roblox's default loading
-- screen as soon as this script runs: a dark screen, the title, a flickering tube for a progress
-- bar and a tip. It's also set as the teleport screen, so the trip lobby -> shift -> lobby shows
-- it too, and it picks up seamlessly on arrival.
-- (The very first second of joining the experience is Roblox's own screen with the game icon;
-- no game can replace that part.)
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local TIPS = {
	"THE NIGHT MANAGER ONLY MOVES WHEN NOBODY IS LOOKING AT HIM.",
	"HEAR FOOTSTEPS? TURN AROUND.",
	"IF HE GRABS YOU, WAIT FOR THE GREEN. THEN PRESS.",
	"YOUR FLASHLIGHT RECHARGES WHILE IT'S OFF.",
	"BIGGER CREWS OPEN THE STOCKROOM AND THE FREEZER.",
	"BIG SPILLS TAKE TWO CLEANS.",
	"SHUT THE VALVE BEFORE THE LEAK FLOODS THE AISLE.",
	"CLEAR ALL THREE LOBBY OBBIES FOR THE PARKOUR TRAIL.",
	"CLOCK IN EVERY DAY. THE STREAK BONUS GROWS.",
	"SOMETIMES SOMEONE ELSE IS SHOPPING AT 3 AM.",
}

local function family(name: string, weight: Enum.FontWeight?): Font
	return Font.new("rbxasset://fonts/families/" .. name .. ".json", weight or Enum.FontWeight.Regular)
end

local function build(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "LoadingScreen"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 1000
	gui.ResetOnSpawn = false
	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(8, 10, 9)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.42)
	title.Size = UDim2.new(0.8, 0, 0, 90)
	title.BackgroundTransparency = 1
	title.FontFace = family("SpecialElite")
	title.TextScaled = true
	title.Text = "CLOSING SHIFT"
	title.TextColor3 = Color3.fromRGB(205, 45, 38)
	title.Parent = bg
	local size = Instance.new("UITextSizeConstraint")
	size.MaxTextSize = 84
	size.Parent = title
	local tube = Instance.new("Frame")
	tube.Name = "Tube"
	tube.AnchorPoint = Vector2.new(0.5, 0.5)
	tube.Position = UDim2.fromScale(0.5, 0.56)
	tube.Size = UDim2.fromOffset(320, 8)
	tube.BackgroundColor3 = Color3.fromRGB(30, 34, 32)
	tube.BorderSizePixel = 0
	tube.Parent = bg
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(215, 240, 215)
	fill.BorderSizePixel = 0
	fill.Parent = tube
	local tip = Instance.new("TextLabel")
	tip.Name = "Tip"
	tip.AnchorPoint = Vector2.new(0.5, 0)
	tip.Position = UDim2.fromScale(0.5, 0.62)
	tip.Size = UDim2.new(0.8, 0, 0, 22)
	tip.BackgroundTransparency = 1
	tip.FontFace = family("GothamSSm", Enum.FontWeight.Medium)
	tip.TextSize = 18
	tip.TextColor3 = Color3.fromRGB(170, 178, 165)
	tip.Text = TIPS[math.random(1, #TIPS)]
	tip.Parent = bg
	local rec = Instance.new("TextLabel")
	rec.Name = "Rec"
	rec.AnchorPoint = Vector2.new(1, 0)
	rec.Position = UDim2.new(1, -24, 0, 18)
	rec.Size = UDim2.fromOffset(200, 20)
	rec.BackgroundTransparency = 1
	rec.FontFace = family("RobotoMono", Enum.FontWeight.Medium)
	rec.TextSize = 17
	rec.TextXAlignment = Enum.TextXAlignment.Right
	rec.TextColor3 = Color3.fromRGB(235, 235, 225)
	rec.Text = "● REC"
	rec.Parent = bg
	return gui
end

-- arriving by teleport: keep showing the screen we left with
local arriving = TeleportService:GetArrivingTeleportGui()
local gui = if arriving and arriving.Name == "LoadingScreen" then arriving else build()
gui.Parent = playerGui
ReplicatedFirst:RemoveDefaultLoadingScreen()
-- anything that teleports this player later shows the same screen
pcall(TeleportService.SetTeleportGui, TeleportService, build())

local bg = gui:WaitForChild("Background") :: Frame
local fill = bg:WaitForChild("Tube"):WaitForChild("Fill") :: Frame
local rec = bg:WaitForChild("Rec") :: TextLabel
local title = bg:WaitForChild("Title") :: TextLabel

local t0 = os.clock()
local flick = Random.new()
local conn = RunService.RenderStepped:Connect(function()
	local queued = ContentProvider.RequestQueueSize
	local p = math.clamp((os.clock() - t0) / 6, 0, 0.9)
	if game:IsLoaded() then
		p = math.max(p, 1 - math.min(queued, 200) / 250)
	end
	fill.Size = fill.Size:Lerp(UDim2.fromScale(p, 1), 0.1)
	-- the tube flickers like a failing fluorescent
	fill.BackgroundTransparency = if flick:NextNumber() < 0.06 then 0.7 else 0
	rec.TextTransparency = if os.clock() % 1.2 < 0.7 then 0 else 1
	title.TextTransparency = if flick:NextNumber() < 0.02 then 0.5 else 0
end)

if not game:IsLoaded() then
	game.Loaded:Wait()
end
-- give the world a moment to stream in, but never hold players for long
local deadline = os.clock() + 6
while ContentProvider.RequestQueueSize > 30 and os.clock() < deadline do
	task.wait(0.2)
end
task.wait(math.max(0, 1.2 - (os.clock() - t0)))
conn:Disconnect()
fill.Size = UDim2.fromScale(1, 1)
fill.BackgroundTransparency = 0
task.wait(0.2)
local fade = TweenInfo.new(0.8)
TweenService:Create(bg, fade, { BackgroundTransparency = 1 }):Play()
for _, d in bg:GetDescendants() do
	if d:IsA("TextLabel") then
		TweenService:Create(d, fade, { TextTransparency = 1 }):Play()
	elseif d:IsA("Frame") then
		TweenService:Create(d, fade, { BackgroundTransparency = 1 }):Play()
	end
end
task.wait(0.9)
gui:Destroy()
