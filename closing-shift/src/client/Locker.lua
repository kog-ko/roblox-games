--!strict
-- Upgrade menu: opens from your locker in the break room. Shows each upgrade's tier, the next
-- tier's cost and a BUY button. The server checks cash and applies everything (BuyUpgrade).
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local BuyUpgrade = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BuyUpgrade") :: RemoteEvent

local Locker = {}
local player = Players.LocalPlayer :: Player

local INK = Color3.fromRGB(225, 230, 210)
local BOX = Color3.fromRGB(12, 14, 12)
local GOLD = Color3.fromRGB(255, 215, 90)

local function text(parent: Instance, t: string, size: UDim2, pos: UDim2, color: Color3?, align: Enum.TextXAlignment?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Font = Enum.Font.Arcade
	l.TextScaled = true
	l.TextColor3 = color or INK
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Text = t
	l.Parent = parent
	return l
end

function Locker.Start()
	local ids = {}
	for id in Config.Upgrades do
		table.insert(ids, id)
	end
	table.sort(ids)

	local gui = Instance.new("ScreenGui")
	gui.Name = "Locker"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(480, 120 + #ids * 78)
	panel.BackgroundColor3 = BOX
	panel.BackgroundTransparency = 0.12
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 2
	stroke.Transparency = 0.4
	stroke.Parent = panel

	text(panel, "YOUR LOCKER", UDim2.new(0.6, 0, 0, 34), UDim2.fromOffset(14, 8), Color3.fromRGB(240, 225, 180))
	local cash = text(panel, "$0", UDim2.new(0.35, 0, 0, 30), UDim2.new(0.62, 0, 0, 10), GOLD, Enum.TextXAlignment.Right)

	type Row = { tier: TextLabel, info: TextLabel, buy: TextButton }
	local rows: { [string]: Row } = {}
	for i, id in ids do
		local u = Config.Upgrades[id]
		local y = 50 + (i - 1) * 78
		local row = Instance.new("Frame")
		row.BackgroundColor3 = Color3.fromRGB(30, 34, 30)
		row.BorderSizePixel = 0
		row.Position = UDim2.fromOffset(12, y)
		row.Size = UDim2.new(1, -24, 0, 70)
		row.Parent = panel
		text(row, string.upper(u.Name), UDim2.new(0.62, 0, 0, 26), UDim2.fromOffset(10, 6))
		local info = text(row, "", UDim2.new(0.62, 0, 0, 18), UDim2.fromOffset(10, 34), Color3.fromRGB(170, 180, 160))
		local tier = text(row, "", UDim2.new(0.62, 0, 0, 14), UDim2.fromOffset(10, 52), GOLD)
		local buy = Instance.new("TextButton")
		buy.Name = "Buy_" .. id
		buy.AnchorPoint = Vector2.new(1, 0.5)
		buy.Position = UDim2.new(1, -10, 0.5, 0)
		buy.Size = UDim2.fromOffset(140, 48)
		buy.BorderSizePixel = 0
		buy.Font = Enum.Font.Arcade
		buy.TextScaled = true
		buy.TextColor3 = Color3.fromRGB(15, 15, 15)
		buy.Parent = row
		buy.Activated:Connect(function()
			BuyUpgrade:FireServer(id)
		end)
		rows[id] = { tier = tier, info = info, buy = buy }
	end

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(0.5, 1)
	close.Position = UDim2.new(0.5, 0, 1, -10)
	close.Size = UDim2.fromOffset(140, 40)
	close.BackgroundColor3 = Color3.fromRGB(90, 90, 85)
	close.BorderSizePixel = 0
	close.Font = Enum.Font.Arcade
	close.TextScaled = true
	close.Text = "CLOSE"
	close.Modal = true -- frees the mouse from first person while open
	close.Parent = panel
	close.Activated:Connect(function()
		gui.Enabled = false
	end)

	local function refresh()
		local money = (player:GetAttribute("Cash") or 0) :: number
		cash.Text = "$" .. money
		for id, r in rows do
			local u = Config.Upgrades[id]
			local tierNow = (player:GetAttribute("Upgrade_" .. id) or 0) :: number
			local nextTier = u.Tiers[tierNow + 1]
			r.tier.Text = string.rep("#", tierNow) .. string.rep("-", #u.Tiers - tierNow) .. string.format("  TIER %d/%d", tierNow, #u.Tiers)
			r.info.Text = string.upper(u.Description)
			if nextTier then
				local afford = money >= nextTier.Cost
				r.buy.Text = "BUY $" .. nextTier.Cost
				r.buy.BackgroundColor3 = if afford then Color3.fromRGB(120, 190, 110) else Color3.fromRGB(70, 70, 66)
				r.buy.AutoButtonColor = afford
			else
				r.buy.Text = "MAXED"
				r.buy.BackgroundColor3 = Color3.fromRGB(215, 180, 70)
				r.buy.AutoButtonColor = false
			end
		end
	end
	player.AttributeChanged:Connect(function(attr)
		if attr == "Cash" or attr:sub(1, 8) == "Upgrade_" then
			refresh()
		end
	end)
	refresh()

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "LockerPrompt" then
			refresh()
			gui.Enabled = true
		end
	end)
end

return Locker
