--!strict
-- The only in-play purchase prompts, each at its moment:
--   SECOND CHANCE  on the catch screen, for a few seconds after you're caught
--   CLOCK IN LATE  on the YOU'RE FIRED screen, for a few seconds
--   STARTER PACK   a one-time popup after your first completed night
-- Plus the big banner that announces server-wide boosts and gifts.
-- Buttons only ask the server (RequestPurchase); it checks the moment is still valid.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RequestPurchase = Remotes:WaitForChild("RequestPurchase") :: RemoteEvent
local Banner = Remotes:WaitForChild("Banner") :: RemoteEvent
local Offer = Remotes:WaitForChild("Offer") :: RemoteEvent
local Caught = Remotes:WaitForChild("Caught") :: RemoteEvent

local Offers = {}
local player = Players.LocalPlayer :: Player
local MON = Config.Monetization
local STUDIO = RunService:IsStudio()

local function available(key: string): boolean
	return (MON.Products[key] or 0) ~= 0 or STUDIO
end

local function make(className: string, props: { [string]: any }): any
	local i = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(i :: any)[k] = v
		end
	end
	i.Parent = props.Parent
	return i
end

local function offerButton(gui: ScreenGui, name: string, text: string, pos: UDim2): TextButton
	local b = make("TextButton", {
		Name = name, Text = text, Visible = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = pos,
		Size = UDim2.fromOffset(340, 58), BackgroundColor3 = Color3.fromRGB(255, 205, 70), BorderSizePixel = 0,
		Font = Enum.Font.Arcade, TextScaled = true, TextColor3 = Color3.fromRGB(20, 15, 5), ZIndex = 10, Parent = gui,
	})
	make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = b })
	make("UIStroke", { Color = Color3.fromRGB(40, 30, 10), Thickness = 2, Parent = b })
	b.Modal = true -- free the mouse from first person while it's up
	return b
end

function Offers.Start()
	local gui = make("ScreenGui", {
		Name = "Offers", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 160,
		Parent = player:WaitForChild("PlayerGui"),
	}) :: ScreenGui

	-- Banner --------------------------------------------------------------
	local banner = make("TextLabel", {
		Name = "Banner", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.fromOffset(640, 54), BackgroundColor3 = Color3.fromRGB(20, 16, 6), BackgroundTransparency = 0.15,
		BorderSizePixel = 0, Font = Enum.Font.Arcade, TextScaled = true, TextColor3 = Color3.fromRGB(255, 215, 90),
		Visible = false, Text = "", Parent = gui,
	}) :: TextLabel
	make("UIStroke", { Color = Color3.fromRGB(255, 215, 90), Thickness = 2, Parent = banner })
	make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = banner })
	local bannerScale = make("UIScale", { Parent = banner }) :: UIScale
	local bannerId = 0
	Banner.OnClientEvent:Connect(function(text: string)
		bannerId += 1
		local id = bannerId
		banner.Text = text
		banner.Visible = true
		bannerScale.Scale = 1.4
		TweenService:Create(bannerScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		task.delay(4, function()
			if id == bannerId then
				banner.Visible = false
			end
		end)
	end)

	-- Second Chance --------------------------------------------------------
	local second = offerButton(gui, "SecondChance", "SECOND CHANCE: KEEP YOUR SPOT", UDim2.fromScale(0.5, 0.7))
	local secondUntil = 0
	second.Activated:Connect(function()
		RequestPurchase:FireServer("SecondChance")
	end)
	Caught.OnClientEvent:Connect(function(who: Player)
		if who == player and available("SecondChance") then
			secondUntil = os.clock() + MON.Rewards.SecondChanceWindow
		end
	end)

	-- Clock In Late ----------------------------------------------------------
	local late = offerButton(gui, "ClockInLate", "CLOCK IN LATE: BACK AT 5:00 AM", UDim2.fromScale(0.5, 0.86))
	late.Activated:Connect(function()
		RequestPurchase:FireServer("ClockInLate")
	end)

	RunService.Heartbeat:Connect(function()
		-- Second Chance: until the window closes or the catch is undone
		local caughtAt = player:GetAttribute("CaughtAt")
		second.Visible = os.clock() < secondUntil and caughtAt ~= nil
		if second.Visible then
			second.Text = string.format("SECOND CHANCE: KEEP YOUR SPOT (%ds)", math.ceil(secondUntil - os.clock()))
		end
		-- Clock In Late: only while the server holds the offer open
		local reviveUntil = ReplicatedStorage:GetAttribute("ReviveOfferUntil")
		local left = if type(reviveUntil) == "number" then reviveUntil - workspace:GetServerTimeNow() else 0
		late.Visible = left > 0 and available("ClockInLate")
		if late.Visible then
			late.Text = string.format("CLOCK IN LATE: BACK AT 5:00 AM (%ds)", math.ceil(left))
		end
	end)

	-- Starter Pack popup (once) ---------------------------------------------
	local pop = make("Frame", {
		Name = "StarterPack", Visible = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 230), BackgroundColor3 = Color3.fromRGB(14, 16, 14), BorderSizePixel = 0, ZIndex = 20, Parent = gui,
	}) :: Frame
	make("UIStroke", { Color = Color3.fromRGB(255, 215, 90), Thickness = 3, Parent = pop })
	make("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 0, 40), Font = Enum.Font.Arcade,
		TextScaled = true, TextColor3 = Color3.fromRGB(255, 215, 90), Text = "STARTER PACK", ZIndex = 21, Parent = pop,
	})
	make("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 56), Size = UDim2.new(1, -24, 0, 70), Font = Enum.Font.Arcade,
		TextScaled = true, TextColor3 = Color3.fromRGB(225, 230, 210), ZIndex = 21, Parent = pop,
		Text = string.format("$%d CASH + 2X PAYCHECK FOR %d HOURS. ONE-TIME OFFER, %d HOURS ONLY.",
			MON.Rewards.StarterCash, MON.Rewards.StarterDoublePayHours, MON.Rewards.StarterOfferHours),
	})
	local buy = make("TextButton", {
		Name = "Buy", Text = "BUY", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.5, -8, 1, -14), Size = UDim2.fromOffset(160, 50),
		BackgroundColor3 = Color3.fromRGB(120, 190, 110), BorderSizePixel = 0, Font = Enum.Font.Arcade, TextScaled = true,
		TextColor3 = Color3.fromRGB(15, 15, 15), ZIndex = 21, Parent = pop,
	}) :: TextButton
	local later = make("TextButton", {
		Name = "Later", Text = "LATER", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.5, 8, 1, -14), Size = UDim2.fromOffset(160, 50),
		BackgroundColor3 = Color3.fromRGB(90, 90, 85), BorderSizePixel = 0, Font = Enum.Font.Arcade, TextScaled = true,
		TextColor3 = Color3.fromRGB(15, 15, 15), ZIndex = 21, Modal = true, Parent = pop,
	}) :: TextButton
	buy.Activated:Connect(function()
		pop.Visible = false
		RequestPurchase:FireServer("StarterPack")
	end)
	later.Activated:Connect(function()
		pop.Visible = false -- still in the shop until the offer ends
	end)
	Offer.OnClientEvent:Connect(function(key: string)
		if key == "StarterPack" and available("StarterPack") then
			pop.Visible = true
		end
	end)
end

return Offers
