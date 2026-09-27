--!strict
-- The Shift Pass window (PASS button): this season's tiers with the free and premium reward for
-- each, your XP toward the next tier, and the premium upgrade (the ShiftPass game pass, through the
-- usual RequestPurchase). Rewards are handed out by the server as you reach them (ShiftPass.lua);
-- this only shows them. Reads PassSeason / PassXp / PassTier / PassFree / PassPremium / ShiftPass.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Fonts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Fonts"))
local RequestPurchase = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestPurchase") :: RemoteEvent

local PassUi = {}
PassUi.Open = nil :: (() -> ())?

local player = Players.LocalPlayer :: Player
local P = Config.Pass
local TEAL = Color3.fromRGB(90, 220, 200)
local GOLD = Color3.fromRGB(255, 215, 90)
local INK = Color3.fromRGB(230, 230, 220)
local DIM = Color3.fromRGB(120, 120, 115)
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

local function label(parent: Instance, t: string, size: UDim2, pos: UDim2, color: Color3?, font: Font?): TextLabel
	return new("TextLabel", {
		Text = t, Size = size, Position = pos, BackgroundTransparency = 1, FontFace = font or Fonts.Body, TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color or INK, Parent = parent,
	})
end

local function describe(r: any?): string
	if not r then
		return "-"
	end
	local parts = {}
	if r.Cosmetic then
		local item
		for _, it in Config.Cosmetics.Items do
			if it.Id == r.Cosmetic then
				item = it
			end
		end
		table.insert(parts, if item then item.Name else r.Cosmetic)
	end
	if r.Cash then
		table.insert(parts, "$" .. r.Cash)
	end
	if r.Candy then
		table.insert(parts, r.Candy .. " CANDY*")
	end
	return table.concat(parts, " + ")
end

local function season(): any?
	local id = player:GetAttribute("PassSeason")
	for _, s in P.Seasons do
		if s.Id == id then
			return s
		end
	end
	return nil
end

function PassUi.Start()
	local gui = new("ScreenGui", { Name = "ShiftPass", ResetOnSpawn = false, DisplayOrder = 150, Parent = player:WaitForChild("PlayerGui") })
	local frame = new("Frame", {
		Size = UDim2.fromOffset(560, 460), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Visible = false,
		BackgroundColor3 = Color3.fromRGB(12, 16, 18), BorderSizePixel = 0, Parent = gui,
	})
	new("UIStroke", { Color = TEAL, Thickness = 3, Parent = frame })
	local scale = new("UIScale", { Parent = frame })
	local function fit()
		local vp = Workspace.CurrentCamera.ViewportSize
		scale.Scale = math.min(1, (vp.X - 20) / 560, (vp.Y - 60) / 460)
	end
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()
	local title = label(frame, "SHIFT PASS", UDim2.new(1, -70, 0, 32), UDim2.fromOffset(12, 6), TEAL, Fonts.Title)
	local close = new("TextButton", {
		Text = "X", Size = UDim2.fromOffset(40, 34), Position = UDim2.new(1, -48, 0, 6), BackgroundColor3 = Color3.fromRGB(200, 70, 60),
		BorderSizePixel = 0, FontFace = Fonts.Bold, TextScaled = true, Parent = frame,
	})
	local sub = label(frame, "", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 42), Color3.fromRGB(170, 180, 175))
	local barBack = new("Frame", { Size = UDim2.new(1, -24, 0, 12), Position = UDim2.fromOffset(12, 64), BackgroundColor3 = Color3.fromRGB(40, 44, 46), BorderSizePixel = 0, Parent = frame })
	local barFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = TEAL, BorderSizePixel = 0, Parent = barBack })
	local premium = new("TextButton", {
		Text = "GET PREMIUM", Size = UDim2.new(1, -24, 0, 40), Position = UDim2.fromOffset(12, 84), BackgroundColor3 = GOLD,
		BorderSizePixel = 0, FontFace = Fonts.Bold, TextScaled = true, TextColor3 = Color3.fromRGB(20, 15, 5), Parent = frame,
	})
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = premium })
	-- column headers
	label(frame, "TIER", UDim2.fromOffset(60, 16), UDim2.fromOffset(16, 132), DIM)
	label(frame, "FREE", UDim2.fromOffset(200, 16), UDim2.fromOffset(76, 132), DIM)
	label(frame, "PREMIUM", UDim2.fromOffset(200, 16), UDim2.fromOffset(306, 132), GOLD)
	local list = new("ScrollingFrame", {
		Size = UDim2.new(1, -24, 1, -170), Position = UDim2.fromOffset(12, 152), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = frame,
	})
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	local function render()
		for _, c in list:GetChildren() do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		local s = season()
		if not s then
			title.Text = "SHIFT PASS"
			sub.Text = "NO SEASON RIGHT NOW. CHECK BACK SOON."
			premium.Visible = false
			return
		end
		local xp = (player:GetAttribute("PassXp") or 0) :: number
		local tier = (player:GetAttribute("PassTier") or 0) :: number
		local freePaid = (player:GetAttribute("PassFree") or 0) :: number
		local premPaid = (player:GetAttribute("PassPremium") or 0) :: number
		local owns = player:GetAttribute("ShiftPass") == true
		local left = math.max(0, s.End - os.time())
		title.Text = string.format("%s  -  TIER %d/%d", s.Name, tier, #s.Tiers)
		local into = if tier >= #s.Tiers then P.XpPerTier else xp % P.XpPerTier
		sub.Text = string.format("%d/%d XP TO THE NEXT TIER  -  ENDS IN %dD  -  *CANDY DURING EVENTS", into, P.XpPerTier, left // 86400)
		barFill.Size = UDim2.fromScale(into / P.XpPerTier, 1)
		local passId = Config.Monetization.GamePasses.ShiftPass or 0
		premium.Visible = not owns and passId ~= 0
		premium.Text = "GET PREMIUM: A REWARD ON EVERY TIER + 5 EXCLUSIVE LOOKS"
		for i, t in s.Tiers do
			local reached = i <= tier
			local row = new("Frame", { Size = UDim2.new(1, -8, 0, 34), BackgroundColor3 = if reached then Color3.fromRGB(24, 38, 36) else Color3.fromRGB(24, 24, 28), BorderSizePixel = 0, LayoutOrder = i, Parent = list })
			label(row, tostring(i), UDim2.fromOffset(44, 22), UDim2.fromOffset(6, 6), if reached then TEAL else DIM, Fonts.Mono)
			local free = label(row, (if i <= freePaid then "✓ " else "") .. describe(t.Free), UDim2.fromOffset(220, 20), UDim2.fromOffset(62, 7), if reached then GREEN else INK)
			free.TextTruncate = Enum.TextTruncate.AtEnd
			local prem = label(row, (if i <= premPaid then "✓ " elseif not owns then "🔒 " else "") .. describe(t.Premium), UDim2.fromOffset(220, 20), UDim2.fromOffset(292, 7),
				if i <= premPaid then GREEN elseif owns then GOLD else DIM)
			prem.TextTruncate = Enum.TextTruncate.AtEnd
		end
	end

	local function open()
		render()
		frame.Visible = true
	end
	PassUi.Open = open
	close.Activated:Connect(function()
		frame.Visible = false
	end)
	premium.Activated:Connect(function()
		RequestPurchase:FireServer("ShiftPass")
	end)
	player.AttributeChanged:Connect(function(attr)
		if frame.Visible and (attr:sub(1, 4) == "Pass" or attr == "ShiftPass") then
			render()
		end
	end)
end

return PassUi
