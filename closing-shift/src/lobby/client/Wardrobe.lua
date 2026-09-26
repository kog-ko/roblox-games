--!strict
-- The wardrobe: buy and equip cosmetics with shift cash. Opened by the wardrobe mirror's prompt
-- or the STYLE button. Reads the catalog from Config.Cosmetics and your OwnedCosmetics /
-- Equip_<Slot> / Cash / VIP attributes; the server does the buying (BuyCosmetic / EquipCosmetic).
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Wardrobe = {}
Wardrobe.Open = nil :: (() -> ())?

local player = Players.LocalPlayer :: Player
local DATA = Config.Cosmetics
local GOLD = Color3.fromRGB(255, 215, 90)
local GREEN = Color3.fromRGB(120, 200, 110)
local GREY = Color3.fromRGB(90, 90, 85)

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

local function button(parent: Instance, name: string, t: string, size: UDim2, pos: UDim2, color: Color3): TextButton
	local b = new("TextButton", {
		Name = name, Text = t, Size = size, Position = pos, BackgroundColor3 = color, BorderSizePixel = 0, Font = Enum.Font.Arcade,
		TextScaled = true, TextColor3 = Color3.fromRGB(15, 15, 15), Parent = parent,
	})
	new("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5), Parent = b })
	return b
end

local function owned(id: string): boolean
	local list = (player:GetAttribute("OwnedCosmetics") or "") :: string
	for _, o in string.split(list, ",") do
		if o == id then
			return true
		end
	end
	return false
end

function Wardrobe.Start(openShop: () -> ())
	local buy = Remotes:WaitForChild("BuyCosmetic") :: RemoteEvent
	local equip = Remotes:WaitForChild("EquipCosmetic") :: RemoteEvent
	local gui = new("ScreenGui", { Name = "Wardrobe", ResetOnSpawn = false, Enabled = false, DisplayOrder = 150, Parent = player:WaitForChild("PlayerGui") })
	local frame = new("Frame", {
		Name = "Frame", Size = UDim2.fromOffset(560, 380), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(14, 14, 16), BorderSizePixel = 0, Parent = gui,
	})
	new("UIStroke", { Color = Color3.fromRGB(200, 90, 200), Thickness = 3, Parent = frame })
	local scale = new("UIScale", { Parent = frame })
	local function fit()
		local vp = Workspace.CurrentCamera.ViewportSize
		scale.Scale = math.min(1, (vp.X - 20) / 560, (vp.Y - 60) / 380)
	end
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()
	new("TextLabel", {
		Text = "WARDROBE", Size = UDim2.new(1, -140, 0, 36), Position = UDim2.fromOffset(12, 6), BackgroundTransparency = 1,
		Font = Enum.Font.Arcade, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(230, 160, 230), Parent = frame,
	})
	local cashText = new("TextLabel", {
		Text = "$0", Size = UDim2.fromOffset(120, 28), Position = UDim2.new(1, -176, 0, 10), BackgroundTransparency = 1,
		Font = Enum.Font.Arcade, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = GOLD, Parent = frame,
	})
	local close = button(frame, "Close", "X", UDim2.fromOffset(40, 36), UDim2.new(1, -48, 0, 6), Color3.fromRGB(200, 70, 60))
	local tabs = new("Frame", { Size = UDim2.new(1, -24, 0, 34), Position = UDim2.fromOffset(12, 48), BackgroundTransparency = 1, Parent = frame })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabs })
	local list = new("ScrollingFrame", {
		Size = UDim2.new(1, -24, 1, -96), Position = UDim2.fromOffset(12, 88), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = frame,
	})
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	local slot = DATA.Slots[1]
	local tabButtons: { [string]: TextButton } = {}

	local function render()
		cashText.Text = "$" .. tostring(player:GetAttribute("Cash") or 0)
		for s, b in tabButtons do
			b.BackgroundColor3 = if s == slot then Color3.fromRGB(230, 160, 230) else GREY
		end
		for _, c in list:GetChildren() do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		local cash = (player:GetAttribute("Cash") or 0) :: number
		local vip = player:GetAttribute("VIP") == true
		local equipped = player:GetAttribute("Equip_" .. slot)
		local order = 0
		for _, item in DATA.Items do
			if item.Slot ~= slot then
				continue
			end
			order += 1
			local row = new("Frame", { Size = UDim2.new(1, -8, 0, 48), BackgroundColor3 = Color3.fromRGB(28, 28, 32), BorderSizePixel = 0, LayoutOrder = order, Parent = list })
			local swatch = new("Frame", {
				Size = UDim2.fromOffset(36, 36), Position = UDim2.fromOffset(6, 6), BorderSizePixel = 0,
				BackgroundColor3 = item.Color or Color3.fromRGB(60, 60, 60), Parent = row,
			})
			if item.Rainbow then
				local keys = {}
				for i = 0, 6 do
					table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 0.8, 1)))
				end
				swatch.BackgroundColor3 = Color3.new(1, 1, 1)
				new("UIGradient", { Color = ColorSequence.new(keys), Parent = swatch })
			end
			new("TextLabel", {
				Text = item.Name .. (if item.Vip then "  (VIP)" else ""), Size = UDim2.new(1, -250, 0, 24), Position = UDim2.fromOffset(50, 4),
				BackgroundTransparency = 1, Font = Enum.Font.Arcade, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = if item.Vip then GOLD else Color3.fromRGB(230, 230, 220), Parent = row,
			})
			local have = item.Price == 0 or owned(item.Id)
			new("TextLabel", {
				Text = if have then "OWNED" else "$" .. item.Price, Size = UDim2.new(1, -250, 0, 16), Position = UDim2.fromOffset(50, 28),
				BackgroundTransparency = 1, Font = Enum.Font.Arcade, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = if have then Color3.fromRGB(150, 220, 150) elseif cash >= item.Price then GOLD else Color3.fromRGB(200, 120, 110), Parent = row,
			})
			local b
			if equipped == item.Id then
				b = button(row, "Action", "EQUIPPED", UDim2.fromOffset(180, 36), UDim2.new(1, -186, 0, 6), GREY)
				b.AutoButtonColor = false
			elseif have then
				b = button(row, "Action", "EQUIP", UDim2.fromOffset(180, 36), UDim2.new(1, -186, 0, 6), GREEN)
				b.Activated:Connect(function()
					equip:FireServer(item.Id)
				end)
			elseif item.Vip and not vip then
				b = button(row, "Action", "VIP ONLY", UDim2.fromOffset(180, 36), UDim2.new(1, -186, 0, 6), GOLD)
				b.Activated:Connect(function()
					gui.Enabled = false
					openShop() -- the VIP pass is in the shop
				end)
			else
				b = button(row, "Action", "BUY $" .. item.Price, UDim2.fromOffset(180, 36), UDim2.new(1, -186, 0, 6), if cash >= item.Price then GOLD else GREY)
				b.Activated:Connect(function()
					buy:FireServer(item.Id)
				end)
			end
		end
	end

	for i, s in DATA.Slots do
		local b = button(tabs, s, DATA.SlotNames[s] or s, UDim2.fromOffset(100, 32), UDim2.new(), GREY)
		b.LayoutOrder = i
		tabButtons[s] = b
		b.Activated:Connect(function()
			slot = s
			render()
		end)
	end

	local function open()
		render()
		gui.Enabled = true
	end
	Wardrobe.Open = open
	close.Activated:Connect(function()
		gui.Enabled = false
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "WardrobePrompt" then
			open()
		end
	end)
	player.AttributeChanged:Connect(function(attr)
		if gui.Enabled and (attr == "Cash" or attr == "OwnedCosmetics" or attr == "VIP" or attr:sub(1, 6) == "Equip_") then
			render()
		end
	end)
end

return Wardrobe
