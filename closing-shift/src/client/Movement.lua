--!strict
-- Owns the local Humanoid's WalkSpeed: base speed (or coffee speed) x sprint.
-- Sprint drains a small stamina pool that refills after a short pause. Stamina shows as a thin bar.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Controls = require(script.Parent:WaitForChild("Controls"))

local Movement = {}
Movement.Sprinting = false -- read by camera effects (head-bob)

local player = Players.LocalPlayer :: Player

local function maxStamina(): number
	return Config.Sprint.Stamina * ((player:GetAttribute("StaminaMult") or 1) :: number)
end

local function buildBar(): (Frame, Frame)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Stamina"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 11
	gui.Parent = player:WaitForChild("PlayerGui")
	local back = Instance.new("Frame")
	back.AnchorPoint = Vector2.new(0.5, 1)
	back.Position = UDim2.new(0.5, 0, 1, -18)
	back.Size = UDim2.fromOffset(160, 6)
	back.BackgroundColor3 = Color3.fromRGB(12, 14, 12)
	back.BackgroundTransparency = 0.3
	back.BorderSizePixel = 0
	back.Visible = false
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(190, 220, 160)
	fill.BorderSizePixel = 0
	fill.Parent = back
	return back, fill
end

function Movement.Start()
	local want = false
	local stamina = maxStamina()
	local lastSprint = 0
	local exhausted = false -- ran dry: must regain some stamina before sprinting again
	local back, fill = buildBar()

	Controls.Bind("Sprint", "RUN", function(began)
		want = began
	end, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)

	RunService.Heartbeat:Connect(function(dt)
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum then
			return
		end
		local cap = maxStamina()
		local moving = hum.MoveDirection.Magnitude > 0.1
		local sprinting = want and moving and not exhausted and stamina > 0
		if sprinting then
			stamina = math.max(0, stamina - dt)
			lastSprint = os.clock()
			if stamina <= 0 then
				exhausted = true
			end
		elseif os.clock() - lastSprint >= Config.Sprint.RegenDelay then
			stamina = math.min(cap, stamina + Config.Sprint.RegenPerSecond * dt)
			if exhausted and stamina >= cap * 0.3 then
				exhausted = false
			end
		end
		Movement.Sprinting = sprinting

		local coffeeUntil = player:GetAttribute("CoffeeUntil") :: number?
		local base = if coffeeUntil and workspace:GetServerTimeNow() < coffeeUntil then Config.CoffeeWalkSpeed else Config.WalkSpeed
		local speed = if sprinting then base * Config.Sprint.Multiplier else base
		if hum.WalkSpeed ~= speed then
			hum.WalkSpeed = speed
		end

		back.Visible = stamina < cap - 0.01
		fill.Size = UDim2.fromScale(stamina / cap, 1)
		fill.BackgroundColor3 = if exhausted then Color3.fromRGB(200, 70, 60) else Color3.fromRGB(190, 220, 160)
	end)
end

return Movement
