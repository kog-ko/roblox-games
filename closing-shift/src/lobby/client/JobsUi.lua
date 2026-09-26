--!strict
-- Jobs window (JOBS button): your progress on today's and this week's jobs, from the Jobs
-- attribute the server publishes (JSON). Jobs pay out automatically when finished.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local JobsUi = {}
JobsUi.Open = nil :: (() -> ())?

local player = Players.LocalPlayer :: Player
local GOLD = Color3.fromRGB(255, 215, 90)
local GREEN = Color3.fromRGB(120, 200, 110)

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

local function label(parent: Instance, t: string, size: UDim2, pos: UDim2, color: Color3?): TextLabel
	return new("TextLabel", {
		Text = t, Size = size, Position = pos, BackgroundTransparency = 1, Font = Enum.Font.Arcade, TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color or Color3.fromRGB(230, 230, 220), Parent = parent,
	})
end

function JobsUi.Start()
	local gui = new("ScreenGui", { Name = "Jobs", ResetOnSpawn = false, DisplayOrder = 150, Parent = player:WaitForChild("PlayerGui") })
	local frame = new("Frame", {
		Size = UDim2.fromOffset(460, 360), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Visible = false,
		BackgroundColor3 = Color3.fromRGB(14, 14, 16), BorderSizePixel = 0, Parent = gui,
	})
	new("UIStroke", { Color = GOLD, Thickness = 3, Parent = frame })
	local scale = new("UIScale", { Parent = frame })
	local function fit()
		local vp = Workspace.CurrentCamera.ViewportSize
		scale.Scale = math.min(1, (vp.X - 20) / 460, (vp.Y - 60) / 360)
	end
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()
	label(frame, "JOBS", UDim2.new(1, -70, 0, 34), UDim2.fromOffset(12, 6), GOLD)
	local close = new("TextButton", {
		Text = "X", Size = UDim2.fromOffset(40, 34), Position = UDim2.new(1, -48, 0, 6), BackgroundColor3 = Color3.fromRGB(200, 70, 60),
		BorderSizePixel = 0, Font = Enum.Font.Arcade, TextScaled = true, Parent = frame,
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
		local ok, jobs = pcall(HttpService.JSONDecode, HttpService, (player:GetAttribute("Jobs") or "[]") :: string)
		if not ok or type(jobs) ~= "table" then
			return
		end
		local order = 0
		local lastWeekly: boolean? = nil
		for _, j in jobs do
			if j.Weekly ~= lastWeekly then
				lastWeekly = j.Weekly
				order += 1
				local h = label(list, if j.Weekly then "THIS WEEK" else "TODAY", UDim2.new(1, -8, 0, 20), UDim2.new(), Color3.fromRGB(170, 190, 170))
				h.LayoutOrder = order
			end
			order += 1
			local row = new("Frame", { Size = UDim2.new(1, -8, 0, 50), BackgroundColor3 = Color3.fromRGB(28, 28, 32), BorderSizePixel = 0, LayoutOrder = order, Parent = list })
			local t = label(row, j.Text, UDim2.new(1, -100, 0, 22), UDim2.fromOffset(8, 4), if j.Done then GREEN else nil)
			t.TextWrapped = true
			label(row, if j.Done then "PAID" else "$" .. j.Reward, UDim2.fromOffset(84, 22), UDim2.new(1, -92, 0, 4), if j.Done then GREEN else GOLD)
			local bar = new("Frame", { Size = UDim2.new(1, -100, 0, 10), Position = UDim2.fromOffset(8, 32), BackgroundColor3 = Color3.fromRGB(50, 50, 55), BorderSizePixel = 0, Parent = row })
			new("Frame", {
				Size = UDim2.fromScale(math.clamp(j.Progress / math.max(j.Goal, 1), 0, 1), 1), BorderSizePixel = 0,
				BackgroundColor3 = if j.Done then GREEN else GOLD, Parent = bar,
			})
			label(row, string.format("%d/%d", j.Progress, j.Goal), UDim2.fromOffset(84, 16), UDim2.new(1, -92, 0, 29))
		end
	end

	local function open()
		render()
		frame.Visible = true
	end
	JobsUi.Open = open
	close.Activated:Connect(function()
		frame.Visible = false
	end)
	player:GetAttributeChangedSignal("Jobs"):Connect(function()
		if frame.Visible then
			render()
		end
	end)
end

return JobsUi
