--!strict
-- Knowing the Night Manager is close. The nearer he is (Config.Manager.Tension.Range), the faster and
-- louder your heartbeat, the more the colour drains, and the more your bodycam breaks up
-- (interference bars, a red edge, a small camera shake). When he's close *behind* you there's a
-- sharp cue: a breath in your ear and a burst of static. Nothing here tells you exactly where he
-- is; it tells you to turn around.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CameraFx = require(script.Parent:WaitForChild("CameraFx"))
local Music = require(script.Parent:WaitForChild("Music"))

local Tension = {}
local player = Players.LocalPlayer :: Player
local T = Config.Manager.Tension
local S = Config.Sounds

local function frame(parent: Instance, props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in props do
		(f :: any)[k] = v
	end
	f.Parent = parent
	return f
end

function Tension.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Tension"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 105
	gui.Parent = player:WaitForChild("PlayerGui")

	-- red edges
	local edges: { Frame } = {}
	for _, e in {
		{ UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 0), 90 },
		{ UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 0.7), -90 },
		{ UDim2.fromScale(0.25, 1), UDim2.fromScale(0, 0), 0 },
		{ UDim2.fromScale(0.25, 1), UDim2.fromScale(0.75, 0), 180 },
	} do
		local f = frame(gui, { Size = e[1], Position = e[2], BackgroundColor3 = Color3.fromRGB(90, 0, 0), BackgroundTransparency = 1 })
		local g = Instance.new("UIGradient")
		g.Rotation = e[3]
		g.Transparency = NumberSequence.new(0, 1)
		g.Parent = f
		table.insert(edges, f)
	end
	-- interference: thin bright bars that jump around, and a full-screen static wash
	local bars: { Frame } = {}
	for _ = 1, 7 do
		table.insert(bars, frame(gui, { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 3) }))
	end
	local wash = frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(200, 200, 200), BackgroundTransparency = 1 })

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "TensionGrade"
	cc.Parent = Lighting

	local heart = Instance.new("Sound")
	heart.SoundId = S.Heartbeat
	heart.Looped = true
	heart.Volume = 0
	heart.Parent = SoundService
	heart:Play()

	local rng = Random.new()
	local level = 0
	local wasBehind = false
	local lastCue = 0
	local burstUntil = 0
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		local store = workspace:FindFirstChild("Store")
		local props = store and store:FindFirstChild("EventProps")
		local model = props and props:FindFirstChild("Manager") :: Model?
		local target, behind = 0, false
		if model then
			local at = model:GetPivot().Position + Vector3.new(0, 5, 0)
			local to = at - camera.CFrame.Position
			local d = to.Magnitude
			target = math.clamp(1 - (d - 5) / (T.Range - 5), 0, 1) ^ 1.4
			behind = d < T.BehindRange and camera.CFrame.LookVector:Dot(to.Unit) < -0.2
		end
		if player:GetAttribute("Grabbed") then
			target = 1
		end
		if player:GetAttribute("Caught") then
			target = 0
		end
		level += (target - level) * math.min(1, dt * (if target > level then 3 else 1.2))

		Music.SetDanger(level)
		heart.Volume = level * 1.1
		heart.PlaybackSpeed = 0.85 + level * 0.75
		for _, e in edges do
			e.BackgroundTransparency = 1 - level * 0.6
		end
		cc.Saturation = -0.5 * level
		cc.Contrast = 0.25 * level
		CameraFx.SetShake(if level > 0.45 then (level - 0.45) * 0.9 else 0)

		-- the "behind you" cue: once per approach, not constantly
		local now = os.clock()
		local jam = player:GetAttribute("JammedUntil")
		if type(jam) == "number" and workspace:GetServerTimeNow() < jam and math.random() < 0.08 then
			burstUntil = now + 0.25 -- the bodycam keeps glitching while your light is jammed
		end
		if behind and not wasBehind and now - lastCue > 6 then
			lastCue = now
			burstUntil = now + 0.35
			local s = Instance.new("Sound")
			s.SoundId = S.Whisper
			s.Volume = 0.9
			s.Parent = SoundService
			s:Play()
			task.delay(6, function()
				s:Destroy()
			end)
		end
		wasBehind = behind

		acc += dt
		if acc >= 0.05 then
			acc = 0
			local burst = now < burstUntil
			for _, b in bars do
				if (burst or level > 0.35) and rng:NextNumber() < (if burst then 0.9 else level * 0.45) then
					b.Position = UDim2.fromScale(0, rng:NextNumber())
					b.Size = UDim2.new(1, 0, 0, rng:NextInteger(1, if burst then 14 else 5))
					b.BackgroundTransparency = rng:NextNumber(0.55, 0.85)
				else
					b.BackgroundTransparency = 1
				end
			end
			wash.BackgroundTransparency = if burst then rng:NextNumber(0.55, 0.75) else 1 - math.max(0, level - 0.6) * rng:NextNumber(0.05, 0.25)
		end
	end)
end

return Tension
