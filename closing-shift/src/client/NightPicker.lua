--!strict
-- Night picker: opens when you use the shift board in the lobby. Lists every night with what it
-- adds; nights past the party's unlock are locked. Picking sends PickNight (the server re-checks).
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("Rules"))
local PickNight = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PickNight") :: RemoteEvent

local NightPicker = {}
local player = Players.LocalPlayer :: Player

local INK = Color3.fromRGB(225, 230, 210)
local BOX = Color3.fromRGB(12, 14, 12)

local function describe(n: number): string
	local r = Rules.Resolve(n, nil, #game:GetService("Players"):GetPlayers())
	local tags = { string.format("%d SPILLS", r.SpillCount), string.format("%d MIN", math.floor(r.ShiftLength / 60)) }
	if r.Manager.Enabled then
		table.insert(tags, "MANAGER")
	end
	if r.PowerCuts.Enabled then
		table.insert(tags, "POWER CUTS")
	end
	if r.Tutorial then
		table.insert(tags, "TUTORIAL")
	end
	return table.concat(tags, "  ")
end

function NightPicker.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "NightPicker"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(440, 110 + #Config.Nights * 70)
	panel.BackgroundColor3 = BOX
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 2
	stroke.Transparency = 0.4
	stroke.Parent = panel
	local sizeCap = Instance.new("UISizeConstraint")
	sizeCap.MaxSize = Vector2.new(440, 10000)
	sizeCap.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(10, 8)
	title.Size = UDim2.new(1, -20, 0, 34)
	title.Font = Enum.Font.Arcade
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(240, 225, 180)
	title.Text = "PICK TONIGHT'S SHIFT"
	title.Parent = panel

	-- the lobby panel sits behind the picker; hide it while the picker is open
	local function setOpen(open: boolean)
		gui.Enabled = open
		local hud = player.PlayerGui:FindFirstChild("HUD")
		local lobby = hud and hud:FindFirstChild("Lobby")
		if lobby and lobby:IsA("GuiObject") then
			lobby.Visible = not open and ReplicatedStorage:GetAttribute("Phase") == "Lobby"
		end
	end

	local buttons: { TextButton } = {}
	for i, n in Config.Nights do
		local b = Instance.new("TextButton")
		b.Name = "Night" .. i
		b.Position = UDim2.fromOffset(12, 48 + (i - 1) * 70)
		b.Size = UDim2.new(1, -24, 0, 62)
		b.BorderSizePixel = 0
		b.Font = Enum.Font.Arcade
		b.TextScaled = true
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.AutoButtonColor = true
		b.Parent = panel
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingTop = UDim.new(0, 4)
		pad.PaddingBottom = UDim.new(0, 4)
		pad.Parent = b
		b:SetAttribute("Label", string.format("NIGHT %d: %s\n%s", i, string.upper(n.Name), describe(i)))
		b.Activated:Connect(function()
			if i <= ((ReplicatedStorage:GetAttribute("GroupUnlocked") or 1) :: number) then
				PickNight:FireServer(i)
				setOpen(false)
			end
		end)
		buttons[i] = b
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
	close.Modal = true -- frees the mouse from first person while the picker is open
	close.Parent = panel
	close.Activated:Connect(function()
		setOpen(false)
	end)

	local function refresh()
		local unlocked = (ReplicatedStorage:GetAttribute("GroupUnlocked") or 1) :: number
		local selected = ReplicatedStorage:GetAttribute("Night")
		for i, b in buttons do
			local open = i <= unlocked
			b.Text = (b:GetAttribute("Label") :: string) .. (if open then "" else "\nLOCKED: BEAT NIGHT " .. (i - 1) .. " FIRST")
			b.BackgroundColor3 = if i == selected then Color3.fromRGB(215, 180, 70)
				elseif open then Color3.fromRGB(120, 190, 110)
				else Color3.fromRGB(60, 60, 58)
			b.TextColor3 = if open then Color3.fromRGB(15, 15, 15) else Color3.fromRGB(150, 150, 140)
			b.AutoButtonColor = open
		end
	end
	for _, attr in { "GroupUnlocked", "Night" } do
		ReplicatedStorage:GetAttributeChangedSignal(attr):Connect(refresh)
	end
	ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(function()
		if ReplicatedStorage:GetAttribute("Phase") ~= "Lobby" and gui.Enabled then
			setOpen(false)
		end
	end)
	refresh()

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "ShiftBoardPrompt" and ReplicatedStorage:GetAttribute("Phase") == "Lobby" then
			refresh()
			setOpen(true)
		end
	end)
end

return NightPicker
