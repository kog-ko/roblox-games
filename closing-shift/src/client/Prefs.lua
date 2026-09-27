--!strict
-- The gear menu (both places): toggles from Config.Settings, saved on the server (PlayerPrefs) and
-- read back from Set_<Key> attributes. Effects ask Prefs.On(key) every time they run, so a change
-- applies at once. Everything is on until turned off.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Fonts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Fonts"))

local Prefs = {}
local player = Players.LocalPlayer :: Player

function Prefs.On(key: string): boolean
	return player:GetAttribute("Set_" .. key) ~= false
end

-- Calls fn now and whenever that setting changes.
function Prefs.Watch(key: string, fn: (boolean) -> ())
	player:GetAttributeChangedSignal("Set_" .. key):Connect(function()
		fn(Prefs.On(key))
	end)
	fn(Prefs.On(key))
end

function Prefs.Set(key: string, on: boolean)
	local r = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SetSetting", 10) :: RemoteEvent?
	player:SetAttribute("Set_" .. key, on) -- show it at once; the server's copy follows
	if r then
		r:FireServer(key, on)
	end
end

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

function Prefs.Start()
	local gui = new("ScreenGui", { Name = "Settings", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 170, Parent = player:WaitForChild("PlayerGui") })
	-- the gear sits in the top bar, just right of Roblox's own buttons
	local gear = new("TextButton", {
		Name = "Gear", Text = "⚙", Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(250, 10),
		BackgroundColor3 = Color3.fromRGB(20, 22, 24), BackgroundTransparency = 0.25, BorderSizePixel = 0,
		FontFace = Fonts.Bold, TextScaled = true, TextColor3 = Color3.fromRGB(230, 230, 220), Parent = gui,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = gear })
	local panel = new("Frame", {
		Name = "Panel", Visible = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(440, 90 + #Config.Settings * 54), BackgroundColor3 = Color3.fromRGB(14, 14, 16), BorderSizePixel = 0, Parent = gui,
	})
	new("UIStroke", { Color = Color3.fromRGB(230, 230, 220), Thickness = 2, Parent = panel })
	new("TextLabel", {
		Text = "SETTINGS", Size = UDim2.new(1, -24, 0, 34), Position = UDim2.fromOffset(12, 8), BackgroundTransparency = 1,
		FontFace = Fonts.Title, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(230, 230, 220), Parent = panel,
	})
	local rows: { [string]: TextButton } = {}
	for i, s in Config.Settings do
		new("TextLabel", {
			Text = s.Name, Size = UDim2.new(1, -150, 0, 24), Position = UDim2.fromOffset(16, 52 + (i - 1) * 54 + 8), BackgroundTransparency = 1,
			FontFace = Fonts.Body, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(220, 220, 210), Parent = panel,
		})
		local b = new("TextButton", {
			Name = s.Key, Size = UDim2.fromOffset(110, 40), Position = UDim2.new(1, -126, 0, 52 + (i - 1) * 54), BorderSizePixel = 0,
			FontFace = Fonts.Bold, TextScaled = true, TextColor3 = Color3.fromRGB(15, 15, 15), Parent = panel,
		})
		new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = b })
		rows[s.Key] = b
		b.Activated:Connect(function()
			Prefs.Set(s.Key, not Prefs.On(s.Key))
		end)
		Prefs.Watch(s.Key, function(on)
			b.Text = if on then "ON" else "OFF"
			b.BackgroundColor3 = if on then Color3.fromRGB(120, 190, 110) else Color3.fromRGB(90, 90, 85)
		end)
	end
	local close = new("TextButton", {
		Name = "Close", Text = "DONE", Size = UDim2.fromOffset(140, 38), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10),
		BackgroundColor3 = Color3.fromRGB(230, 230, 220), BorderSizePixel = 0, FontFace = Fonts.Bold, TextScaled = true, Modal = true, Parent = panel,
	})
	new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = close })
	local fitter = script.Parent:FindFirstChild("Fit")
	if fitter then
		require(fitter :: ModuleScript).Scale(panel, Vector2.new(440, 90 + #Config.Settings * 54), Vector2.new(24, 40))
	end
	gear.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
end

return Prefs
