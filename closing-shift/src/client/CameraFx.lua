--!strict
-- PSX bodycam feel: a wide fixed FOV, head-bob while walking (stronger sprinting), roll into
-- strafes and turns, and rotation snapped to small steps for a low-framerate look. The mouse
-- cursor is hidden whenever the mouse is locked to the centre (first person with no menu open).
-- The camera module reads Camera.CFrame back each frame to apply mouse input, so the untouched
-- CFrame is saved after our edits and restored right before the camera module runs again.
-- Otherwise small mouse movements would be rounded away by the snapping.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Movement = require(script.Parent:WaitForChild("Movement"))
local Prefs = require(script.Parent:WaitForChild("Prefs"))

local CameraFx = {}
local player = Players.LocalPlayer :: Player
local PSX = Config.PSX
local kick = 0 -- degrees of downward nod, decays quickly

local shake = 0 -- degrees of constant jitter (the Manager close by), set every frame by Tension
local shakeRng = Random.new()

function CameraFx.SetShake(degrees: number)
	shake = degrees
end

-- A small camera nod, e.g. when a clean lands.
function CameraFx.Kick(degrees: number)
	kick = math.min(kick + degrees, 6)
end

local function snap(angle: number, step: number): number
	return math.floor(angle / step + 0.5) * step
end

function CameraFx.Start()
	local trueCF: CFrame? = nil
	local bobT = 0
	local bobAmt = 0
	local roll = 0
	local lastYaw: number? = nil

	-- no cursor in first person; menus (Modal buttons) unlock the mouse and bring it back
	RunService.RenderStepped:Connect(function()
		local locked = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter or player:GetAttribute("Grabbed") == true
		if UserInputService.MouseIconEnabled == locked then
			UserInputService.MouseIconEnabled = not locked
		end
	end)

	RunService:BindToRenderStep("PsxCameraRestore", Enum.RenderPriority.Camera.Value - 1, function()
		local camera = workspace.CurrentCamera
		if trueCF and camera.CameraType == Enum.CameraType.Custom then
			camera.CFrame = trueCF
		end
		trueCF = nil
	end)

	RunService:BindToRenderStep("PsxCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local camera = workspace.CurrentCamera
		if camera.CameraType ~= Enum.CameraType.Custom then
			return -- scripted shots (the payoff) are left alone
		end
		camera.FieldOfView = PSX.FieldOfView
		local cf = camera.CFrame
		trueCF = cf
		local view = cf

		if PSX.CameraSnap then
			local rx, ry, rz = cf:ToOrientation()
			local step = math.rad(PSX.SnapDegrees)
			cf = CFrame.new(cf.Position) * CFrame.fromOrientation(snap(rx, step), snap(ry, step), rz)
		end

		if PSX.HeadBob and Prefs.On("Bob") then
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local moving = hum ~= nil and hum.MoveDirection.Magnitude > 0.1 and hum.FloorMaterial ~= Enum.Material.Air
			local target = if not moving then 0 elseif Movement.Sprinting then PSX.BobSprint else PSX.BobWalk
			bobAmt += (target - bobAmt) * math.min(1, dt * 8)
			if bobAmt > 0.001 then
				bobT += dt * (if Movement.Sprinting then 14 else 9)
				local x = math.sin(bobT) * bobAmt
				local y = -math.abs(math.cos(bobT)) * bobAmt
				cf = cf * CFrame.new(x, y, 0) * CFrame.Angles(0, 0, math.sin(bobT) * bobAmt * 0.06)
			end
		end

		if PSX.Tilt and Prefs.On("Shake") then
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			local _, yaw = view:ToOrientation()
			local turn = 0
			if lastYaw and dt > 0 then
				local d = yaw - lastYaw
				d = (d + math.pi) % (2 * math.pi) - math.pi
				turn = math.deg(d) / dt
			end
			lastYaw = yaw
			local side = 0
			if root then
				local v = root.AssemblyLinearVelocity
				side = view.RightVector:Dot(Vector3.new(v.X, 0, v.Z)) / math.max(Config.WalkSpeed, 1)
			end
			local target = math.clamp(-side * PSX.TiltStrafe - turn * PSX.TiltTurn, -PSX.TiltMax, PSX.TiltMax)
			roll += (target - roll) * math.min(1, dt * 6)
			cf = cf * CFrame.Angles(0, 0, math.rad(roll))
		end

		if shake > 0.01 and Prefs.On("Shake") then
			cf = cf * CFrame.Angles(math.rad(shakeRng:NextNumber(-shake, shake)), math.rad(shakeRng:NextNumber(-shake, shake)), 0)
		end

		if kick > 0.01 and Prefs.On("Shake") then
			cf = cf * CFrame.Angles(math.rad(-kick), 0, 0)
			kick *= math.exp(-dt * 10)
		end

		camera.CFrame = cf
	end)
end

return CameraFx
