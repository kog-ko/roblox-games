--!strict
-- Flashlight: F / gamepad Y / touch "LIGHT". Your own beam is two shadow-casting SpotLights (a
-- round beam and a brighter hotspot in its middle) on a local part that follows the camera with a
-- slight handheld lag. The on/off state goes to the server,
-- and every client draws other players' beams from their heads.
-- The battery drains while on and slowly recharges while off; it shows as a small bar.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Controls = require(script.Parent:WaitForChild("Controls"))
local SoundFx = require(script.Parent:WaitForChild("SoundFx"))
local Fonts = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Fonts"))
local Remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Flashlight") :: RemoteEvent

local Flashlight = {}
local player = Players.LocalPlayer :: Player
local FL = Config.Flashlight

local DEFAULT_BEAM = Color3.fromRGB(255, 244, 214)

-- A player's beam colour: the BeamColor cosmetic (a Color3 attribute) or warm white.
local function beamColor(p: Player): Color3
	local c = p:GetAttribute("BeamColor")
	return if typeof(c) == "Color3" then c else DEFAULT_BEAM
end

local function spot(parent: Instance, hotspot: boolean?): SpotLight
	local s = Instance.new("SpotLight")
	s.Name = if hotspot then "Hotspot" else "Beam"
	s.Face = Enum.NormalId.Front
	s.Brightness = if hotspot then FL.HotspotBrightness else FL.Brightness
	s.Range = FL.Range
	s.Color = DEFAULT_BEAM
	s.Shadows = true
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
	label.FontFace = Fonts.Mono
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
			light.Color = beamColor(p)
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
	local hot = spot(rig, true)
	light.Color = beamColor(player)
	hot.Color = beamColor(player)
	player:GetAttributeChangedSignal("BeamColor"):Connect(function()
		light.Color = beamColor(player)
		hot.Color = beamColor(player)
	end)

	local on = false
	local aim = CFrame.identity
	local battery = batteryMax()
	local back, fill = buildBar()

	local function jammed(): boolean
		local untilT = player:GetAttribute("JammedUntil")
		return type(untilT) == "number" and workspace:GetServerTimeNow() < untilT
	end
	local function set(state: boolean)
		if state and (battery < FL.MinToTurnOn or jammed()) then
			if jammed() then
				SoundFx.Play(Config.Sounds.FlashClick, 0.6, 0.7) -- click, nothing
			end
			return
		end
		if state == on then
			return
		end
		on = state
		light.Enabled = on
		hot.Enabled = on
		SoundFx.Play(Config.Sounds.FlashClick, 0.6, if on then 1.1 else 0.95)
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
		-- the beam trails your view a little, like a light in your hand
		local goal = camera.CFrame * CFrame.new(0.3, -0.2, 0)
		aim = aim:Lerp(goal.Rotation, math.min(1, dt * FL.Lag))
		rig.CFrame = CFrame.new(goal.Position) * aim
		light.Angle = angleFor(player)
		hot.Angle = FL.HotspotAngle * ((player:GetAttribute("BeamMult") or 1) :: number)
		local cap = batteryMax()
		if on and jammed() then
			set(false) -- the Late Customer killed it
		end
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
		fill.BackgroundColor3 = if jammed() then Color3.fromRGB(120, 60, 200) elseif battery < FL.MinToTurnOn then Color3.fromRGB(200, 70, 60) else Color3.fromRGB(240, 220, 150)
	end)

	watchOthers()
end

return Flashlight
