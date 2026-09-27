--!strict
-- Dark nights (Data/Nights Dark = true, published as ReplicatedStorage.DarkNight): with the power
-- out, a spill is almost invisible (and can't be mopped) until your flashlight is on it, or you're
-- standing right in it. Local only: each player sees what their own light finds. If the lights
-- come back (the Lights On boost), everything shows again.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DarkSpills = {}
local player = Players.LocalPlayer :: Player
local FL = Config.Flashlight

local HIDDEN = 0.94 -- LocalTransparencyModifier for a spill in the dark
local NEAR = 5 -- studs: close enough to see it at your feet

function DarkSpills.Start()
	local store = workspace:WaitForChild("Store")
	local spills = store:WaitForChild("Spills")
	local shown: { [Model]: number } = {} -- 0 hidden .. 1 fully shown, eased
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		local dark = ReplicatedStorage:GetAttribute("DarkNight") == true and store:GetAttribute("Power") == false
		local cam = workspace.CurrentCamera.CFrame
		local lightOn = player:GetAttribute("FlashlightOn") == true
		local half = math.rad(FL.Angle * ((player:GetAttribute("BeamMult") or 1) :: number) / 2 + 4)
		local cosHalf = math.cos(half)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		for _, m in spills:GetChildren() do
			if not m:IsA("Model") then
				continue
			end
			local anchor = m:FindFirstChild("PromptAnchor") :: BasePart?
			if not anchor then
				continue
			end
			local target = 1
			if dark then
				local pos = anchor.Position - Vector3.new(0, 0.9, 0)
				local to = pos - cam.Position
				local d = to.Magnitude
				local lit = lightOn and d < FL.Range and d > 0.01 and cam.LookVector:Dot(to / d) > cosHalf
				local near = root ~= nil and (root.Position - pos).Magnitude < NEAR
				target = if lit then 1 elseif near then 0.35 else 0
			end
			local v = shown[m] or target
			v += (target - v) * math.min(1, dt * (if target > v then 10 else 2.5))
			shown[m] = v
			local mod = (1 - v) * HIDDEN
			for _, p in m:GetChildren() do
				if p:IsA("BasePart") and p ~= anchor then
					p.LocalTransparencyModifier = mod
				end
			end
			local prompt = anchor:FindFirstChildOfClass("ProximityPrompt")
			-- (a local change only; the server still decides every clean. Outside a dark night we only
			-- undo what we hid, never switch on a prompt the server turned off.)
			if prompt and (dark or prompt:GetAttribute("DarkHidden")) then
				local want = v > 0.5
				if prompt.Enabled ~= want then
					prompt.Enabled = want
				end
				prompt:SetAttribute("DarkHidden", if want then nil else true)
			end
		end
		if acc > 2 then
			acc = 0
			for m in shown do
				if not m.Parent then
					shown[m] = nil
				end
			end
		end
	end)
end

return DarkSpills
