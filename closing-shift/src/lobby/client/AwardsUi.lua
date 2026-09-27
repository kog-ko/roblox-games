--!strict
-- Awards window (AWARDS button): every achievement with your progress, and the clock-in streak
-- milestones. Reads the Achievements / AchProgress / DailyStreak attributes the server publishes.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Fonts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Fonts"))

local AwardsUi = {}
AwardsUi.Open = nil :: (() -> ())?

local player = Players.LocalPlayer :: Player
local ORANGE = Color3.fromRGB(255, 160, 70)
local GREEN = Color3.fromRGB(120, 200, 110)
local GOLD = Color3.fromRGB(255, 215, 90)
local INK = Color3.fromRGB(230, 230, 220)

local function new(className: string, props: { [string]: any }): any
	local i = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(i :: any)[k] = v
		end
	end
	i.Parent = props.Parent
	return i
end

local function label(parent: Instance, t: string, size: UDim2, pos: UDim2, color: Color3?, font: Font?): TextLabel
	return new("TextLabel", {
		Text = t, Size = size, Position = pos, BackgroundTransparency = 1, FontFace = font or Fonts.Body, TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color or INK, Parent = parent,
	})
end

function AwardsUi.Start()
	local gui = new("ScreenGui", { Name = "Awards", ResetOnSpawn = false, DisplayOrder = 150, Parent = player:WaitForChild("PlayerGui") })
	local frame = new("Frame", {
		Size = UDim2.fromOffset(500, 420), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Visible = false,
		BackgroundColor3 = Color3.fromRGB(14, 14, 16), BorderSizePixel = 0, Parent = gui,
	})
	new("UIStroke", { Color = ORANGE, Thickness = 3, Parent = frame })
	local scale = new("UIScale", { Parent = frame })
	local function fit()
		local vp = Workspace.CurrentCamera.ViewportSize
		scale.Scale = math.min(1, (vp.X - 20) / 500, (vp.Y - 60) / 420)
	end
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()
	local title = label(frame, "AWARDS", UDim2.new(1, -70, 0, 34), UDim2.fromOffset(12, 6), ORANGE, Fonts.Title)
	local close = new("TextButton", {
		Text = "X", Size = UDim2.fromOffset(40, 34), Position = UDim2.new(1, -48, 0, 6), BackgroundColor3 = Color3.fromRGB(200, 70, 60),
		BorderSizePixel = 0, FontFace = Fonts.Bold, TextScaled = true, Parent = frame,
	})
	local list = new("ScrollingFrame", {
		Size = UDim2.new(1, -24, 1, -52), Position = UDim2.fromOffset(12, 46), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = frame,
	})
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	local function render()
		for _, c in list:GetChildren() do
			if c:IsA("Frame") or c:IsA("TextLabel") then
				c:Destroy()
			end
		end
		local have: { [string]: boolean } = {}
		for id in string.gmatch((player:GetAttribute("Achievements") or "") :: string, "[^,]+") do
			have[id] = true
		end
		local ok, progress = pcall(HttpService.JSONDecode, HttpService, (player:GetAttribute("AchProgress") or "{}") :: string)
		if not ok or type(progress) ~= "table" then
			progress = {}
		end
		local count = 0
		for _, a in Config.Achievements.List do
			if have[a.Id] then
				count += 1
			end
		end
		title.Text = string.format("AWARDS  %d/%d", count, #Config.Achievements.List)

		-- streak milestones
		local order = 1
		local days = (player:GetAttribute("DailyStreak") or 0) :: number
		label(list, string.format("CLOCK-IN STREAK: %d DAYS", days), UDim2.new(1, -8, 0, 22), UDim2.new(), ORANGE).LayoutOrder = order
		local parts = {}
		for _, m in Config.Achievements.Streaks do
			table.insert(parts, string.format("%s%dD $%d%s", if days >= m.Days then "✓ " else "", m.Days, m.Reward, if m.Cosmetic then "+LOOK" else ""))
		end
		order += 1
		local s = label(list, table.concat(parts, "   "), UDim2.new(1, -8, 0, 32), UDim2.new(), Color3.fromRGB(190, 190, 180))
		s.TextWrapped = true
		s.LayoutOrder = order

		-- earned first, then closest to done
		local rows = table.clone(Config.Achievements.List)
		local function frac(a: any): number
			return if have[a.Id] then 2 else math.clamp(((progress[a.Stat] or 0) :: number) / a.Goal, 0, 1)
		end
		table.sort(rows, function(a, b)
			return frac(a) > frac(b)
		end)
		for _, a in rows do
			order += 1
			local done = have[a.Id] == true
			local row = new("Frame", { Size = UDim2.new(1, -8, 0, 54), BackgroundColor3 = if done then Color3.fromRGB(30, 40, 30) else Color3.fromRGB(28, 28, 32), BorderSizePixel = 0, LayoutOrder = order, Parent = list })
			label(row, a.Name, UDim2.new(1, -110, 0, 20), UDim2.fromOffset(8, 4), if done then GREEN else INK, Fonts.Bold)
			label(row, a.Text, UDim2.new(1, -110, 0, 15), UDim2.fromOffset(8, 25), Color3.fromRGB(170, 175, 165))
			label(row, if done then "EARNED" else "$" .. a.Reward, UDim2.fromOffset(94, 20), UDim2.new(1, -100, 0, 4), if done then GREEN else GOLD)
			local value = math.min((progress[a.Stat] or 0) :: number, a.Goal)
			local bar = new("Frame", { Size = UDim2.new(1, -110, 0, 6), Position = UDim2.fromOffset(8, 44), BackgroundColor3 = Color3.fromRGB(50, 50, 55), BorderSizePixel = 0, Parent = row })
			new("Frame", { Size = UDim2.fromScale(if done then 1 else value / a.Goal, 1), BorderSizePixel = 0, BackgroundColor3 = if done then GREEN else ORANGE, Parent = bar })
			label(row, if done then "" else string.format("%d/%d", value, a.Goal), UDim2.fromOffset(94, 16), UDim2.new(1, -100, 0, 30), Color3.fromRGB(170, 175, 165), Fonts.Mono)
		end
	end

	local function open()
		render()
		frame.Visible = true
	end
	AwardsUi.Open = open
	close.Activated:Connect(function()
		frame.Visible = false
	end)
	player.AttributeChanged:Connect(function(attr)
		if frame.Visible and (attr == "Achievements" or attr == "AchProgress" or attr == "DailyStreak") then
			render()
		end
	end)
end

return AwardsUi
