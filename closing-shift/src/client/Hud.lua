--!strict
-- All 2D UI: clock, spill counters, lobby/ready, coffee + gold mop buttons, results, note.
-- Chunky Arcade font, fixed pixel sizes that fit a landscape phone.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Clock = require(Shared:WaitForChild("Clock"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ReadyUp = Remotes:WaitForChild("ReadyUp") :: RemoteEvent
local RequestCoffee = Remotes:WaitForChild("RequestCoffee") :: RemoteEvent
local ResultsRemote = Remotes:WaitForChild("Results") :: RemoteEvent
local ShowNote = Remotes:WaitForChild("ShowNote") :: RemoteEvent

local Hud = {}
local player = Players.LocalPlayer :: Player

local INK = Color3.fromRGB(225, 230, 210)
local BOX = Color3.fromRGB(12, 14, 12)
local RED = Color3.fromRGB(200, 40, 35)

local function new(className: string, props: { [string]: any }): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	inst.Parent = props.Parent
	return inst
end

local function box(parent: Instance, name: string, size: UDim2, pos: UDim2, anchor: Vector2): Frame
	local f = new("Frame", {
		Name = name, Size = size, Position = pos, AnchorPoint = anchor,
		BackgroundColor3 = BOX, BackgroundTransparency = 0.25, BorderSizePixel = 0, Parent = parent,
	})
	new("UIStroke", { Color = INK, Thickness = 2, Transparency = 0.4, Parent = f })
	return f
end

local function text(parent: Instance, name: string, t: string, size: UDim2?, pos: UDim2?, color: Color3?): TextLabel
	return new("TextLabel", {
		Name = name, Text = t, Size = size or UDim2.fromScale(1, 1), Position = pos or UDim2.new(),
		BackgroundTransparency = 1, Font = Enum.Font.Arcade, TextScaled = true, TextColor3 = color or INK, Parent = parent,
	})
end

local function button(parent: Instance, name: string, t: string, size: UDim2, pos: UDim2, anchor: Vector2, color: Color3): TextButton
	local b = new("TextButton", {
		Name = name, Text = t, Size = size, Position = pos, AnchorPoint = anchor, AutoButtonColor = true,
		BackgroundColor3 = color, BorderSizePixel = 0, Font = Enum.Font.Arcade, TextScaled = true,
		TextColor3 = Color3.fromRGB(15, 15, 15), Parent = parent,
	})
	new("UIPadding", {
		PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = b,
	})
	return b
end

function Hud.Start()
	local gui = new("ScreenGui", {
		Name = "HUD", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 10,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Shift bar
	local bar = new("Frame", { Name = "ShiftBar", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
	local clockBox = box(bar, "Clock", UDim2.fromOffset(200, 50), UDim2.new(0.5, 0, 0, 8), Vector2.new(0.5, 0))
	local clockText = text(clockBox, "Time", "2:00 AM")
	local spillBox = box(bar, "Spills", UDim2.fromOffset(170, 38), UDim2.new(0, 12, 0, 60), Vector2.zero)
	local spillText = text(spillBox, "Text", "SPILLS 0")
	local mineBox = box(bar, "Mine", UDim2.fromOffset(170, 38), UDim2.new(0, 12, 0, 102), Vector2.zero)
	local mineText = text(mineBox, "Text", "YOU 0")
	local boostText = text(bar, "Boost", "", UDim2.fromOffset(170, 26), UDim2.new(0, 12, 0, 146), Color3.fromRGB(230, 180, 110))
	local coffeeBtn = button(bar, "Coffee", "COFFEE", UDim2.fromOffset(130, 46), UDim2.new(1, -12, 0.42, 0), Vector2.new(1, 0.5), Color3.fromRGB(190, 140, 80))

	-- Lobby panel
	local lobby = box(gui, "Lobby", UDim2.fromOffset(340, 200), UDim2.new(0.5, 0, 0, 10), Vector2.new(0.5, 0))
	text(lobby, "Title", "CLOSING SHIFT", UDim2.new(1, -20, 0, 42), UDim2.fromOffset(10, 8), RED)
	text(lobby, "Goal", "MOP EVERY SPILL BEFORE 6:00 AM", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 54))
	local countText = text(lobby, "Countdown", "SHIFT STARTS IN 15", UDim2.new(1, -20, 0, 24), UDim2.fromOffset(10, 80))
	local bestText = text(lobby, "Best", "BEST: --", UDim2.new(1, -20, 0, 18), UDim2.fromOffset(10, 108))
	local readyBtn = button(lobby, "Ready", "READY", UDim2.fromOffset(150, 50), UDim2.new(0.5, -6, 1, -10), Vector2.new(1, 1), Color3.fromRGB(120, 190, 110))
	local mopBtn = button(lobby, "GoldMop", "GOLD MOP", UDim2.fromOffset(150, 50), UDim2.new(0.5, 6, 1, -10), Vector2.new(0, 1), Color3.fromRGB(215, 180, 70))

	-- Results
	local results = box(gui, "Results", UDim2.fromOffset(420, 260), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	local resTitle = text(results, "Title", "", UDim2.new(1, -20, 0, 70), UDim2.fromOffset(10, 10))
	local resBody = text(results, "Body", "", UDim2.new(1, -30, 1, -100), UDim2.fromOffset(15, 90))
	resBody.TextXAlignment = Enum.TextXAlignment.Left
	resBody.TextYAlignment = Enum.TextYAlignment.Top

	-- Toast + note
	local toast = text(gui, "Toast", "", UDim2.fromOffset(460, 30), UDim2.new(0.5, 0, 1, -140), Color3.fromRGB(200, 210, 190))
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.TextStrokeTransparency = 0.3
	local note = new("Frame", {
		Name = "Note", Size = UDim2.fromOffset(300, 220), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(235, 228, 195), BorderSizePixel = 0, Rotation = -3, Visible = false, Parent = gui,
	})
	local noteText = text(note, "Text", "", UDim2.new(1, -30, 1, -30), UDim2.fromOffset(15, 15), Color3.fromRGB(35, 35, 70))
	local noteClose = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = note })

	local toastId = 0
	local function showToast(t: string, seconds: number)
		toastId += 1
		local id = toastId
		toast.Text = t
		task.delay(seconds, function()
			if id == toastId then
				toast.Text = ""
			end
		end)
	end

	-- State -> UI
	local function refreshCounts()
		spillText.Text = "SPILLS " .. tostring(ReplicatedStorage:GetAttribute("SpillsRemaining") or 0)
		mineText.Text = "YOU " .. tostring(player:GetAttribute("Cleaned") or 0)
		local best = player:GetAttribute("Best")
		bestText.Text = if type(best) == "number" then "BEST: " .. Clock.Duration(best) else "BEST: --"
		local passId = Config.GamePasses.IndustrialMop
		mopBtn.Visible = passId ~= 0 and player:GetAttribute("IndustrialMop") ~= true
		readyBtn.Position = if mopBtn.Visible then UDim2.new(0.5, -6, 1, -10) else UDim2.new(0.5, 75, 1, -10)
		local credits = (player:GetAttribute("CoffeeCredits") or 0) :: number
		local used = player:GetAttribute("CoffeeUsed") == true
		local inShift = ReplicatedStorage:GetAttribute("Phase") == "Shift"
		coffeeBtn.Visible = inShift and not used and (credits > 0 or Config.DevProducts.ExtraCoffee ~= 0)
		coffeeBtn.Text = if credits > 0 then "COFFEE x" .. credits else "COFFEE"
	end

	local function refreshPhase()
		local phase = ReplicatedStorage:GetAttribute("Phase")
		lobby.Visible = phase == "Lobby"
		bar.Visible = phase == "Shift" or phase == "Payoff" or phase == "LightsOut"
		if phase == "Lobby" then
			results.Visible = false
			note.Visible = false
			readyBtn.Text = "READY"
		elseif phase == "Shift" then
			results.Visible = false
			showToast("MOP EVERY SPILL BEFORE 6:00 AM", 4)
		end
		refreshCounts()
	end

	ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(refreshPhase)
	ReplicatedStorage:GetAttributeChangedSignal("SpillsRemaining"):Connect(refreshCounts)
	player.AttributeChanged:Connect(refreshCounts)
	refreshPhase()

	RunService.Heartbeat:Connect(function()
		local phase = ReplicatedStorage:GetAttribute("Phase")
		if phase == "Lobby" then
			countText.Text = "SHIFT STARTS IN " .. tostring(ReplicatedStorage:GetAttribute("Countdown") or 0)
		elseif phase == "Shift" then
			local start = (ReplicatedStorage:GetAttribute("ShiftStart") or 0) :: number
			clockText.Text = Clock.Format(workspace:GetServerTimeNow() - start)
			local untilT = player:GetAttribute("CoffeeUntil")
			local left = if type(untilT) == "number" then untilT - workspace:GetServerTimeNow() else 0
			boostText.Text = if left > 0 then "COFFEE " .. math.ceil(left) .. "s" else ""
		elseif phase == "LightsOut" then
			clockText.Text = "6:00 AM"
			clockText.TextColor3 = RED
		end
		if phase ~= "LightsOut" then
			clockText.TextColor3 = INK
		end
	end)

	-- Input
	readyBtn.Activated:Connect(function()
		ReadyUp:FireServer()
		readyBtn.Text = "READY!"
	end)
	mopBtn.Activated:Connect(function()
		MarketplaceService:PromptGamePassPurchase(player, Config.GamePasses.IndustrialMop)
	end)
	coffeeBtn.Activated:Connect(function()
		if ((player:GetAttribute("CoffeeCredits") or 0) :: number) > 0 then
			RequestCoffee:FireServer()
		elseif Config.DevProducts.ExtraCoffee ~= 0 then
			MarketplaceService:PromptProductPurchase(player, Config.DevProducts.ExtraCoffee)
		end
	end)
	noteClose.Activated:Connect(function()
		note.Visible = false
	end)

	-- Server messages
	ResultsRemote.OnClientEvent:Connect(function(r: any)
		results.Visible = true
		if r.Outcome == "Fired" then
			resTitle.Text = "YOU'RE FIRED"
			resTitle.TextColor3 = RED
			resBody.Text = string.format("6:00 AM. SPILLS LEFT ON THE FLOOR.\n\nYOU CLEANED  %d\nTEAM CLEANED %d\nLIFETIME     %d",
				r.Cleaned, r.TeamCleaned, r.TotalCleaned)
		else
			resTitle.Text = "SHIFT COMPLETE"
			resTitle.TextColor3 = Color3.fromRGB(150, 220, 140)
			resBody.Text = string.format("CLEAN TIME   %s%s\nBEST         %s\n\nYOU CLEANED  %d\nTEAM CLEANED %d\nLIFETIME     %d",
				Clock.Duration(r.CleanTime), if r.NewBest then "  NEW BEST!" else "",
				if r.Best then Clock.Duration(r.Best) else "--", r.Cleaned, r.TeamCleaned, r.TotalCleaned)
		end
	end)
	ShowNote.OnClientEvent:Connect(function()
		noteText.Text = "thanks for covering my shift.\n\n- " .. string.lower(player.DisplayName)
		note.Visible = true
		task.delay(6, function()
			note.Visible = false
		end)
	end)

	-- The final spill appearing is worth a line of text.
	local store = workspace:WaitForChild("Store")
	local spills = store:WaitForChild("Spills")
	spills.ChildAdded:Connect(function(c)
		if c.Name == "FinalSpill" then
			showToast("...something spilled in the back room.", 5)
		end
	end)
end

return Hud
