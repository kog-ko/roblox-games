--!strict
-- The shop: opened from the break-room vending machine (any time) or the SHOP button in the lobby
-- HUD (lobby only). Every buy button just asks the server (RequestPurchase); the server decides
-- whether it's allowed right now and shows the Roblox prompt.
-- Products whose ID is 0 are hidden, except in Studio where they show as "ID NOT SET".
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local RequestPurchase = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestPurchase") :: RemoteEvent

local Shop = {}
Shop.Open = nil :: (() -> ())? -- set by Start
local player = Players.LocalPlayer :: Player
local MON = Config.Monetization
local STUDIO = RunService:IsStudio()

local INK = Color3.fromRGB(225, 230, 210)
local BOX = Color3.fromRGB(12, 14, 12)
local GOLD = Color3.fromRGB(255, 215, 90)
local GREEN = Color3.fromRGB(120, 190, 110)
local GREY = Color3.fromRGB(70, 70, 66)

local SECTIONS = {
	{ Title = "STARTER PACK", Keys = { "StarterPack" } },
	{ Title = "BOOSTS (EVERYONE, DURING A SHIFT)", Keys = { "LightsOn", "HireJanitor", "SpillStorm", "ManagerDayOff" } },
	{ Title = "FOR YOU", Keys = { "ExtraCoffee", "PaycheckSmall", "PaycheckMedium", "PaycheckLarge" } },
	{ Title = "PASSES", Keys = { "VIP", "IndustrialMop", "BigFlashlight" } },
}
local BOOSTS = { LightsOn = true, HireJanitor = true, SpillStorm = true, ManagerDayOff = true }
local PASS = { VIP = true, IndustrialMop = true, BigFlashlight = true }

local function idOf(key: string): number
	return MON.GamePasses[key] or MON.Products[key] or 0
end

local function label(parent: Instance, t: string, size: UDim2, pos: UDim2, color: Color3?, align: Enum.TextXAlignment?): TextLabel
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

local function button(parent: Instance, name: string, t: string, size: UDim2, pos: UDim2, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Font = Enum.Font.Arcade
	b.TextScaled = true
	b.TextColor3 = Color3.fromRGB(15, 15, 15)
	b.Text = t
	b.Parent = parent
	return b
end

function Shop.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Shop"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 22
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0, 560, 0.86, 0)
	panel.BackgroundColor3 = BOX
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local cap = Instance.new("UISizeConstraint")
	cap.MaxSize = Vector2.new(560, 640)
	cap.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 2
	stroke.Transparency = 0.4
	stroke.Parent = panel

	label(panel, "QUIK STOP VENDING", UDim2.new(0.6, 0, 0, 30), UDim2.fromOffset(14, 8), Color3.fromRGB(240, 225, 180))
	local cash = label(panel, "$0", UDim2.new(0.35, 0, 0, 28), UDim2.new(0.62, 0, 0, 10), GOLD, Enum.TextXAlignment.Right)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Position = UDim2.fromOffset(10, 46)
	scroll.Size = UDim2.new(1, -20, 1, -104)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll

	type Row = { frame: Frame, key: string, buy: TextButton, gift: TextButton?, note: TextLabel }
	local rows: { Row } = {}
	local headers: { [string]: TextLabel } = {}
	local order = 0
	for _, sec in SECTIONS do
		order += 1
		local h = label(scroll, sec.Title, UDim2.new(1, 0, 0, 22), UDim2.new(), GOLD)
		h.LayoutOrder = order
		headers[sec.Title] = h
		for _, key in sec.Keys do
			order += 1
			local info = MON.Catalog[key]
			local row = Instance.new("Frame")
			row.Name = key
			row.LayoutOrder = order
			row.Size = UDim2.new(1, -8, 0, 58)
			row.BackgroundColor3 = Color3.fromRGB(30, 34, 30)
			row.BorderSizePixel = 0
			row.Parent = scroll
			label(row, if info then info.Name else key, UDim2.new(0.55, 0, 0, 24), UDim2.fromOffset(10, 4))
			local note = label(row, if info then string.upper(info.Description) else "", UDim2.new(0.55, 0, 0, 18), UDim2.fromOffset(10, 32), Color3.fromRGB(170, 180, 160))
			local buy = button(row, "Buy_" .. key, "BUY", UDim2.fromOffset(110, 42), UDim2.new(1, if PASS[key] then -236 else -118, 0.5, -21), GREEN)
			buy.Activated:Connect(function()
				RequestPurchase:FireServer(key)
			end)
			local gift: TextButton? = nil
			if PASS[key] then
				local g = button(row, "Gift_" .. key, "GIFT", UDim2.fromOffset(110, 42), UDim2.new(1, -118, 0.5, -21), Color3.fromRGB(150, 170, 220))
				gift = g
			end
			table.insert(rows, { frame = row, key = key, buy = buy, gift = gift, note = note })
		end
	end

	-- Gift picker: choose someone in this server.
	local picker = Instance.new("Frame")
	picker.Visible = false
	picker.AnchorPoint = Vector2.new(0.5, 0.5)
	picker.Position = UDim2.fromScale(0.5, 0.5)
	picker.Size = UDim2.fromOffset(320, 260)
	picker.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	picker.BorderSizePixel = 0
	picker.ZIndex = 5
	picker.Parent = panel
	local pickTitle = label(picker, "GIFT TO...", UDim2.new(1, -20, 0, 26), UDim2.fromOffset(10, 6), GOLD)
	pickTitle.ZIndex = 6
	local pickList = Instance.new("Frame")
	pickList.BackgroundTransparency = 1
	pickList.Position = UDim2.fromOffset(10, 38)
	pickList.Size = UDim2.new(1, -20, 1, -88)
	pickList.ZIndex = 6
	pickList.Parent = picker
	local pl = Instance.new("UIListLayout")
	pl.Padding = UDim.new(0, 4)
	pl.Parent = pickList
	local pickClose = button(picker, "CancelGift", "CANCEL", UDim2.fromOffset(120, 36), UDim2.new(0.5, -60, 1, -44), GREY)
	pickClose.ZIndex = 6
	pickClose.Activated:Connect(function()
		picker.Visible = false
	end)
	local function openPicker(key: string)
		for _, c in pickList:GetChildren() do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
		pickTitle.Text = "GIFT " .. ((MON.Catalog[key] and MON.Catalog[key].Name) or key) .. " TO..."
		local any = false
		for _, other in Players:GetPlayers() do
			if other ~= player then
				any = true
				local b = button(pickList, "To_" .. other.UserId, string.upper(other.DisplayName), UDim2.new(1, 0, 0, 34), UDim2.new(), GREEN)
				b.ZIndex = 7
				b.Activated:Connect(function()
					picker.Visible = false
					RequestPurchase:FireServer("Gift" .. key, other.UserId)
				end)
			end
		end
		if not any then
			local b = button(pickList, "Nobody", "NOBODY ELSE IS HERE", UDim2.new(1, 0, 0, 34), UDim2.new(), GREY)
			b.ZIndex = 7
		end
		picker.Visible = true
	end
	for _, r in rows do
		if r.gift then
			r.gift.Activated:Connect(function()
				openPicker(r.key)
			end)
		end
	end

	local close = button(panel, "Close", "CLOSE", UDim2.fromOffset(140, 40), UDim2.new(0.5, -70, 1, -50), Color3.fromRGB(90, 90, 85))
	close.Modal = true -- frees the mouse from first person while open
	close.Activated:Connect(function()
		gui.Enabled = false
	end)

	local function refresh()
		cash.Text = "$" .. tostring(player:GetAttribute("Cash") or 0)
		local phase = ReplicatedStorage:GetAttribute("Phase")
		local cooldown = ReplicatedStorage:GetAttribute("BoostCooldownUntil")
		local cdLeft = if type(cooldown) == "number" then math.ceil(cooldown - workspace:GetServerTimeNow()) else 0
		local starterUntil = player:GetAttribute("StarterOfferUntil")
		local visibleIn: { [string]: boolean } = {}
		for _, r in rows do
			local id = idOf(r.key)
			local show = id ~= 0 or STUDIO
			if r.key == "StarterPack" then
				show = show and type(starterUntil) == "number" and os.time() < starterUntil
			end
			r.frame.Visible = show
			local enabled = id ~= 0
			local text = "BUY"
			if id == 0 then
				text = "ID NOT SET"
			elseif PASS[r.key] and player:GetAttribute(r.key) then
				text, enabled = "OWNED", false
			elseif BOOSTS[r.key] and phase ~= "Shift" then
				text, enabled = "SHIFT ONLY", false
			elseif BOOSTS[r.key] and cdLeft > 0 then
				text = "QUEUE (" .. cdLeft .. "s)"
			end
			if r.key == "StarterPack" and type(starterUntil) == "number" then
				local left = starterUntil - os.time()
				r.note.Text = string.format("$1,500 + 2X PAYCHECK 24H  (OFFER ENDS IN %dH %02dM)", left // 3600, (left % 3600) // 60)
			end
			r.buy.Text = text
			r.buy.AutoButtonColor = enabled
			r.buy.Active = enabled
			r.buy.BackgroundColor3 = if enabled then GREEN elseif text == "OWNED" then GOLD else GREY
			if r.gift then
				r.gift.Visible = id ~= 0 and idOf("Gift" .. r.key) ~= 0
			end
			if show then
				visibleIn[r.key] = true
			end
		end
		for _, sec in SECTIONS do
			local any = false
			for _, k in sec.Keys do
				any = any or visibleIn[k] == true
			end
			headers[sec.Title].Visible = any
		end
	end

	local function open()
		refresh()
		gui.Enabled = true
	end
	Shop.Open = open -- the lobby place opens the shop from its own button

	-- vending machine: any time
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "VendingPrompt" then
			open()
		end
	end)
	-- lobby SHOP button (added to the HUD's lobby panel)
	task.spawn(function()
		local hud = player.PlayerGui:WaitForChild("HUD", 20)
		local lobby = hud and hud:WaitForChild("Lobby", 10)
		if not lobby then
			return
		end
		local b = button(lobby, "ShopButton", "SHOP", UDim2.fromOffset(150, 50), UDim2.new(0.5, 6, 1, -10), GOLD)
		b.AnchorPoint = Vector2.new(0, 1)
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 6)
		pad.PaddingBottom = UDim.new(0, 6)
		pad.Parent = b
		b.Activated:Connect(function()
			if ReplicatedStorage:GetAttribute("Phase") == "Lobby" then
				open()
			end
		end)
	end)
	ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(function()
		if gui.Enabled then
			refresh()
		end
	end)
	player.AttributeChanged:Connect(function()
		if gui.Enabled then
			refresh()
		end
	end)
	-- keep countdowns ticking while open
	task.spawn(function()
		while true do
			task.wait(1)
			if gui.Enabled then
				refresh()
			end
		end
	end)
end

return Shop
