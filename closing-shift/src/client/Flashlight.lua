--!strict
-- Flashlight: F / gamepad Y / touch "LIGHT". Your own beam is a SpotLight on a local part that
-- follows the camera, so it points exactly where you look. The on/off state goes to the server,
-- and every client draws other players' beams from their heads.
-- The battery drains while on and slowly recharges while off; it shows as a small bar.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Controls = require(script.Parent:WaitForChild("Controls"))
local Remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Flashlight") :: RemoteEvent

local Flashlight = {}
local player = Players.LocalPlayer :: Player
local FL = Config.Flashlight

local function spot(parent: Instance): SpotLight
	local s = Instance.new("SpotLight")
	s.Face = Enum.NormalId.Front
	s.Brightness = FL.Brightness
	s.Range = FL.Range
	s.Color = Color3.fromRGB(255, 244, 214)
	s.Shadows = false
	s.Enabled = false
	s.Parent = parent
	return s
end

local function angleFor(p: Player): number
	return FL.Angle * ((p:GetAttribute("BeamMult") or 1) :: number)
end

local function batteryMax(): number
	return FL.Battery * ((player:GetAttribute("BatteryMult") or 1) :: number)
end

local function buildBar(): (Frame, Frame)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Battery"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 11
	gui.Parent = player:WaitForChild("PlayerGui")
	local back = Instance.new("Frame")
	back.AnchorPoint = Vector2.new(0.5, 1)
	back.Position = UDim2.new(0.5, 0, 1, -30)
	back.Size = UDim2.fromOffset(160, 6)
	back.BackgroundColor3 = Color3.fromRGB(12, 14, 12)
	back.BackgroundTransparency = 0.3
	back.BorderSizePixel = 0
	back.Visible = false
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(240, 220, 150)
	fill.BorderSizePixel = 0
	fill.Parent = back
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(1, 0.5)
	label.Position = UDim2.new(0, -6, 0.5, 0)
	label.Size = UDim2.fromOffset(60, 14)
	label.Font = Enum.Font.Arcade
	label.Text = "LIGHT"
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.TextColor3 = Color3.fromRGB(225, 230, 210)
	label.Parent = back
	return back, fill
end

-- Other players' beams, drawn locally from their heads.
local function watchOthers()
	local lights: { [Player]: SpotLight } = {}
	local function update(p: Player)
		local head = p.Character and p.Character:FindFirstChild("Head")
		local on = p:GetAttribute("FlashlightOn") == true
		local light = lights[p]
		if light and light.Parent ~= head then
			light:Destroy()
			light = nil
			lights[p] = nil
		end
		if head and on and not light then
			light = spot(head)
			lights[p] = light
		end
		if light then
			light.Angle = angleFor(p)
			light.Enabled = on
		end
	end
	local function track(p: Player)
		if p == player then
			return
		end
		p:GetAttributeChangedSignal("FlashlightOn"):Connect(function()
			update(p)
		end)
		p.CharacterAdded:Connect(function(char)
			char:WaitForChild("Head", 5)
			update(p)
		end)
		update(p)
	end
	for _, p in Players:GetPlayers() do
		track(p)
	end
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(function(p)
		if lights[p] then
			lights[p]:Destroy()
			lights[p] = nil
		end
	end)
end

function Flashlight.Start()
	local rig = Instance.new("Part")
	rig.Name = "FlashlightRig"
	rig.Anchored = true
	rig.CanCollide = false
	rig.CanQuery = false
	rig.CanTouch = false
	rig.Transparency = 1
	rig.Size = Vector3.one * 0.2
	local light = spot(rig)

	local on = false
	local battery = batteryMax()
	local back, fill = buildBar()

	local function set(state: boolean)
		if state and battery < FL.MinToTurnOn then
			return
		end
		if state == on then
			return
		end
		on = state
		light.Enabled = on
		player:SetAttribute("ViewmodelLight", if on then 1 else 0) -- lights the mop viewmodel
		Remote:FireServer(on)
	end

	Controls.Bind("Flashlight", "LIGHT", function(began)
		if began then
			set(not on)
		end
	end, Enum.KeyCode.F, Enum.KeyCode.ButtonY)

	RunService:BindToRenderStep("Flashlight", Enum.RenderPriority.Camera.Value + 2, function(dt)
		local camera = workspace.CurrentCamera
		rig.Parent = camera
		rig.CFrame = camera.CFrame * CFrame.new(0.3, -0.2, 0)
		light.Angle = angleFor(player)
		local cap = batteryMax()
		if on then
			battery = math.max(0, battery - dt)
			if battery <= 0 then
				set(false)
			end
		else
			battery = math.min(cap, battery + FL.RechargePerSecond * dt)
		end
		back.Visible = on or battery < cap - 0.01
		fill.Size = UDim2.fromScale(battery / cap, 1)
		fill.BackgroundColor3 = if battery < FL.MinToTurnOn then Color3.fromRGB(200, 70, 60) else Color3.fromRGB(240, 220, 150)
	end)

	watchOthers()
end

return Flashlight
