--!strict
-- PSX camera feel: fixed FOV, head-bob while walking (stronger sprinting) and rotation snapped
-- to small steps for a low-framerate look.
-- The camera module reads Camera.CFrame back each frame to apply mouse input, so the untouched
-- CFrame is saved after our edits and restored right before the camera module runs again.
-- Otherwise small mouse movements would be rounded away by the snapping.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Movement = require(script.Parent:WaitForChild("Movement"))

local CameraFx = {}
local player = Players.LocalPlayer :: Player
local PSX = Config.PSX

local function snap(angle: number, step: number): number
	return math.floor(angle / step + 0.5) * step
end

function CameraFx.Start()
	local trueCF: CFrame? = nil
	local bobT = 0
	local bobAmt = 0

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

		if PSX.CameraSnap then
			local rx, ry, rz = cf:ToOrientation()
			local step = math.rad(PSX.SnapDegrees)
			cf = CFrame.new(cf.Position) * CFrame.fromOrientation(snap(rx, step), snap(ry, step), rz)
		end

		if PSX.HeadBob then
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

		camera.CFrame = cf
	end)
end

return CameraFx
