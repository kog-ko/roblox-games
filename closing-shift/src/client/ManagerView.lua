--!strict
-- Tells the server where this player's camera is looking, ~10 times a second, while the Night
-- Manager exists. Unreliable on purpose: only the latest view matters. The server checks it.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local ViewReport = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ViewReport") :: UnreliableRemoteEvent

local ManagerView = {}

function ManagerView.Start()
	local props = workspace:WaitForChild("Store"):WaitForChild("EventProps")
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < Config.Manager.ReportInterval then
			return
		end
		acc = 0
		if props:FindFirstChild("Manager") then
			ViewReport:FireServer(workspace.CurrentCamera.CFrame)
		end
	end)
end

return ManagerView
