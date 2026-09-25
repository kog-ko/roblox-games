--!strict
-- Lobby UI: your cash, rank progress and weekly spills; SHOP and INVITE buttons; and the queue
-- panel while you're standing on a pad (the server publishes QueuePad / QueueCount / QueueCountdown).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Progress = require(Shared:WaitForChild("Progress"))

local LobbyHud = {}
local player = Players.LocalPlayer :: Player

local INK = Color3.fromRGB(225, 230, 210)
local GOLD = Color3.fromRGB(255, 215, 90)

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

local function box(parent: Instance, name: string, size: UDim2, pos: UDim2, anchor: Vector2): Frame
	local f = new("Frame", {
		Name = name, Size = size, Position = pos, AnchorPoint = anchor, BackgroundColor3 = Color3.fromRGB(12, 14, 12),
		BackgroundTransparency = 0.25, BorderSizePixel = 0, Parent = parent,
	})
	new("UIStroke", { Color = Color3.fromRGB(60, 70, 60), Thickness = 2, Parent = f })
	return f
end

local function text(parent: Instance, name: string, t: string, size: UDim2, pos: UDim2, color: Color3?): TextLabel
	return new("TextLabel", {
		Name = name, Text = t, Size = size, Position = pos, BackgroundTransparency = 1, Font = Enum.Font.Arcade,
		TextScaled = true, TextColor3 = color or INK, Parent = parent,
	})
end

local function button(parent: Instance, name: string, t: string, size: UDim2, pos: UDim2, anchor: Vector2, color: Color3): TextButton
	local b = new("TextButton", {
		Name = name, Text = t, Size = size, Position = pos, AnchorPoint = anchor, BackgroundColor3 = color, BorderSizePixel = 0,
		Font = Enum.Font.Arcade, TextScaled = true, TextColor3 = Color3.fromRGB(15, 15, 15), AutoButtonColor = true, Parent = parent,
	})
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = b })
	return b
end

function LobbyHud.Start(openShop: () -> ())
	local gui = new("ScreenGui", { Name = "LobbyHud", ResetOnSpawn = false, IgnoreGuiInset = false, Parent = player:WaitForChild("PlayerGui") })

	-- you: cash, rank, this week
	local me = box(gui, "Me", UDim2.fromOffset(260, 84), UDim2.new(0, 12, 0, 8), Vector2.new(0, 0))
	local cash = text(me, "Cash", "$0", UDim2.new(1, -16, 0, 30), UDim2.fromOffset(8, 4), GOLD)
	local rank = text(me, "Rank", "TRAINEE", UDim2.new(1, -16, 0, 20), UDim2.fromOffset(8, 36))
	local week = text(me, "Week", "", UDim2.new(1, -16, 0, 18), UDim2.fromOffset(8, 60), Color3.fromRGB(170, 190, 170))

	local shopBtn = button(gui, "Shop", "SHOP", UDim2.fromOffset(150, 44), UDim2.new(0, 12, 0.45, -26), Vector2.new(0, 0.5), GOLD)
	local inviteBtn = button(gui, "Invite", "INVITE: +10% PAY", UDim2.fromOffset(150, 44), UDim2.new(0, 12, 0.45, 26), Vector2.new(0, 0.5), Color3.fromRGB(110, 160, 220))

	-- queue panel (only while on a pad)
	local q = box(gui, "Queue", UDim2.fromOffset(360, 74), UDim2.new(0.5, 0, 1, -16), Vector2.new(0.5, 1))
	q.Visible = false
	local qTitle = text(q, "Title", "", UDim2.new(1, -16, 0, 34), UDim2.fromOffset(8, 4), GOLD)
	local qSub = text(q, "Sub", "STEP OFF THE PAD TO LEAVE THE QUEUE", UDim2.new(1, -16, 0, 18), UDim2.fromOffset(8, 44))
	local qScale = new("UIScale", { Parent = q })

	local hint = text(gui, "Hint", "STEP ON A NEON PAD BY THE STORE TO START A SHIFT", UDim2.fromOffset(480, 22), UDim2.new(0.5, 0, 1, -24), INK)
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.TextStrokeTransparency = 0.4

	local function refresh()
		cash.Text = "$" .. tostring(player:GetAttribute("Cash") or 0)
		local total = (player:GetAttribute("TotalCleaned") or 0) :: number
		local _, rankName, nextAt = Progress.Rank(total)
		rank.Text = if nextAt then string.format("%s  (%d TO NEXT RANK)", rankName, nextAt - total) else rankName
		local friends = (player:GetAttribute("CrewFriends") or 0) :: number
		week.Text = string.format("THIS WEEK: %d SPILLS%s", (player:GetAttribute("WeeklyCleaned") or 0) :: number,
			if friends > 0 then string.format("   CREW +%d%%", math.floor(friends * Config.Pay.CrewBonusPerFriend * 100 + 0.5)) else "")
		local pad = player:GetAttribute("QueuePad")
		local wasVisible = q.Visible
		q.Visible = pad ~= nil
		hint.Visible = pad == nil
		if pad then
			local n = player:GetAttribute("QueueNight") or 1
			local left = player:GetAttribute("QueueCountdown")
			qTitle.Text = string.format("NIGHT %d  -  %d/%d  -  %s", n, (player:GetAttribute("QueueCount") or 1) :: number, Config.Queue.MaxCrew,
				if left == 0 then "CLOCKING IN..." else "STARTS IN " .. tostring(left or ""))
			if not wasVisible then
				qScale.Scale = 0.7
				TweenService:Create(qScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			end
		end
	end
	player.AttributeChanged:Connect(refresh)
	refresh()

	shopBtn.Activated:Connect(openShop)
	inviteBtn.Activated:Connect(function()
		local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		if ok and can then
			pcall(SocialService.PromptGameInvite, SocialService, player)
		end
	end)
end

return LobbyHud
