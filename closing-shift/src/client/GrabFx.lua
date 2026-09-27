--!strict
-- The Night Manager's grab, on the grabbed player's screen (the server's Manager.grab):
-- the camera is wrenched round to his face (which he only has when he's got you), a scream, a red
-- flash and a shake, then a skill check: a needle sweeps across a bar and you press when it's in
-- the zone, once per zone. Space / click / gamepad A / the STRUGGLE button. Every press is sent to
-- the server with its time and the server judges it (Manager.judge); this module only draws it.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Fonts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Fonts"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GrabRemote = Remotes:WaitForChild("Grab") :: RemoteEvent
local GrabResult = Remotes:WaitForChild("GrabResult") :: RemoteEvent

local GrabFx = {}
local player = Players.LocalPlayer :: Player
local S = Config.Sounds

local function oneShot(id: string, volume: number, speed: number, distort: number?)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = speed
	if distort then
		local d = Instance.new("DistortionSoundEffect")
		d.Level = distort
		d.Parent = s
	end
	s.Parent = SoundService
	s:Play()
	task.delay(8, function()
		s:Destroy()
	end)
end

local function new(className: string, props: { [string]: any }): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	inst.Parent = props.Parent
	return inst
end

function GrabFx.Start()
	local gui = new("ScreenGui", {
		Name = "GrabFx", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 160, Parent = player:WaitForChild("PlayerGui"),
	})
	local flash = new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(150, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = gui,
	})
	local panel = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.fromOffset(460, 96),
		BackgroundTransparency = 1, Visible = false, Parent = gui,
	})
	local title = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, FontFace = Fonts.Title, TextScaled = true,
		TextColor3 = Color3.fromRGB(235, 60, 50), TextStrokeTransparency = 0.2, Text = "BREAK FREE", Parent = panel,
	})
	local bar = new("Frame", {
		Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = Color3.fromRGB(20, 18, 18),
		BorderSizePixel = 0, Parent = panel,
	})
	new("UIStroke", { Color = Color3.fromRGB(230, 225, 215), Thickness = 2, Parent = bar })
	local zone = new("Frame", {
		Size = UDim2.fromScale(0.2, 1), BackgroundColor3 = Color3.fromRGB(120, 210, 110), BorderSizePixel = 0, Parent = bar,
	})
	local needle = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0, 5, 1, 12),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0, ZIndex = 2, Parent = bar,
	})
	local hint = new("TextLabel", {
		Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, FontFace = Fonts.Body,
		TextScaled = true, TextColor3 = Color3.fromRGB(230, 225, 215), Text = "", Parent = panel,
	})
	local pips = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(90, 34),
		BackgroundTransparency = 1, FontFace = Fonts.Mono, TextScaled = true, TextColor3 = Color3.fromRGB(230, 225, 215), Parent = panel,
	})

	local active = false
	GrabRemote.OnClientEvent:Connect(function(info: any)
		if active or type(info) ~= "table" or type(info.Zones) ~= "table" then
			return
		end
		active = true
		local camera = workspace.CurrentCamera
		local store = workspace:FindFirstChild("Store")
		local props = store and store:FindFirstChild("EventProps")
		local model = props and props:FindFirstChild("Manager")
		local head = model and model:FindFirstChild("Head") :: BasePart?
		local myHead = player.Character and player.Character:FindFirstChild("Head") :: BasePart?

		-- the scare
		oneShot(S.GrabScream, 1, 0.8, 0.6)
		oneShot(S.JumpScare, 1, 0.9, 0.3)
		flash.BackgroundTransparency = 0.15
		TweenService:Create(flash, TweenInfo.new(0.7), { BackgroundTransparency = 1 }):Play()

		-- nothing on screen but him (and the check)
		local hidden: { ScreenGui } = {}
		for _, g in player.PlayerGui:GetChildren() do
			if g:IsA("ScreenGui") and g.Enabled and (g.Name == "HUD" or g.Name == "Stamina" or g.Name == "Battery") then
				g.Enabled = false
				table.insert(hidden, g)
			end
		end
		-- the camera: whipped round to his face and pulled in
		local from = camera.CFrame
		local fov0 = camera.FieldOfView
		camera.CameraType = Enum.CameraType.Scriptable
		local t0 = os.clock()
		local rng = Random.new()
		local camConn = RunService.RenderStepped:Connect(function()
			local t = os.clock() - t0
			local eye = if myHead then myHead.Position + Vector3.new(0, 0.5, 0) else from.Position
			local look = if head then head.Position else eye + from.LookVector
			local goal = CFrame.lookAt(eye, look)
			local a = math.min(1, t / 0.16)
			a = 1 - (1 - a) ^ 3
			local shake = if t < 0.6 then 1.6 else 0.45
			camera.CFrame = from:Lerp(goal, a)
				* CFrame.Angles(math.rad(rng:NextNumber(-shake, shake)), math.rad(rng:NextNumber(-shake, shake)), math.rad(rng:NextNumber(-shake, shake) * 1.5))
			camera.FieldOfView = fov0 + (62 - fov0) * math.min(1, t / 0.5)
		end)

		-- the skill check (all times are server time)
		local zones = info.Zones :: { number }
		local width = info.Width :: number
		local hits = 0
		local presses: { number } = {}
		local sent = false
		local function send()
			if not sent then
				sent = true
				GrabResult:FireServer(presses)
			end
		end
		local function place()
			local z = zones[hits + 1]
			if z then
				zone.Position = UDim2.fromScale(z, 0)
				zone.Size = UDim2.fromScale(width, 1)
			end
			pips.Text = string.format("%d/%d", hits, #zones)
		end
		local function needleAt(t: number): number
			local x = ((t - info.Start) / info.Period) % 2
			return if x < 1 then x else 2 - x
		end
		local function press()
			local now = workspace:GetServerTimeNow()
			if sent or now < info.Start then
				return
			end
			table.insert(presses, now)
			local z = zones[hits + 1]
			local x = needleAt(now)
			if z and x >= z and x <= z + width then
				hits += 1
				oneShot(S.UIClick, 0.9, 0.7)
				zone.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				task.delay(0.08, function()
					zone.BackgroundColor3 = Color3.fromRGB(120, 210, 110)
				end)
				place()
				if hits >= #zones then
					send()
				end
			else
				zone.BackgroundColor3 = Color3.fromRGB(220, 50, 40)
				send() -- a miss ends it
			end
		end
		local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		hint.Text = if touch then "TAP STRUGGLE WHEN THE NEEDLE IS IN THE GREEN" else "PRESS SPACE / CLICK WHEN THE NEEDLE IS IN THE GREEN"
		ContextActionService:BindActionAtPriority("Struggle", function(_, state: Enum.UserInputState)
			if state == Enum.UserInputState.Begin then
				press()
			end
			return Enum.ContextActionResult.Sink
		end, true, Enum.ContextActionPriority.High.Value + 100, Enum.KeyCode.Space, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonR2)
		ContextActionService:SetTitle("Struggle", "STRUGGLE")
		local btn = ContextActionService:GetButton("Struggle")
		if btn then
			btn.Size = UDim2.fromOffset(110, 110)
			btn.Position = UDim2.new(1, -140, 1, -260)
		end
		zone.BackgroundColor3 = Color3.fromRGB(120, 210, 110)
		place()
		local barConn = RunService.RenderStepped:Connect(function()
			local now = workspace:GetServerTimeNow()
			panel.Visible = now >= info.Start and not sent
			needle.Position = UDim2.fromScale(needleAt(now), 0.5)
			if not sent and now > info.Start + info.Window then
				send()
			end
		end)

		-- the server settles it by clearing Grabbed
		local function finish()
			if not active then
				return
			end
			active = false
			camConn:Disconnect()
			barConn:Disconnect()
			ContextActionService:UnbindAction("Struggle")
			panel.Visible = false
			camera.CameraType = Enum.CameraType.Custom
			camera.FieldOfView = fov0
			for _, g in hidden do
				g.Enabled = true
			end
			task.delay(0.25, function()
				if player:GetAttribute("Caught") ~= true then
					oneShot(S.Escape, 0.8, 1)
					flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
					flash.BackgroundTransparency = 0.6
					TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
					task.delay(0.6, function()
						flash.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
					end)
				end
			end)
		end
		local conn: RBXScriptConnection
		conn = player:GetAttributeChangedSignal("Grabbed"):Connect(function()
			if player:GetAttribute("Grabbed") == nil then
				conn:Disconnect()
				finish()
			end
		end)
		-- safety net: never leave the camera stuck
		task.delay((info.Start - workspace:GetServerTimeNow()) + info.Window + 3, function()
			if active then
				conn:Disconnect()
				finish()
			end
		end)
	end)
end

return GrabFx
