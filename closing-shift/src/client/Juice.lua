--!strict
-- Clean feedback. Everyone sees a droplet burst, sparkles, a shockwave ring and a rising "+1".
-- The player who cleaned also gets the cash-register ka-ching, a mop flick, a small camera nod
-- and a pop on their HUD counter. All of it is local and short-lived.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local SoundFx = require(script.Parent:WaitForChild("SoundFx"))
local Viewmodel = require(script.Parent:WaitForChild("Viewmodel"))
local CameraFx = require(script.Parent:WaitForChild("CameraFx"))
local Cleaned = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Cleaned") :: RemoteEvent

local Juice = {}
local player = Players.LocalPlayer :: Player

local function tween(inst: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- Scale-bounce a HUD element (adds a UIScale the first time).
local function pop(gui: Instance?, amount: number)
	if not (gui and gui:IsA("GuiObject")) then
		return
	end
	local s = gui:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	s.Parent = gui
	s.Scale = amount
	tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

local function burst(pos: Vector3, color: Color3, big: boolean)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one * 0.2
	holder.Position = pos + Vector3.new(0, 0.3, 0)
	holder.Parent = workspace
	local at = Instance.new("Attachment")
	at.Parent = holder

	local drops = Instance.new("ParticleEmitter")
	drops.Enabled = false
	drops.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.25))
	drops.LightEmission = 0.2
	drops.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	drops.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.6) })
	drops.Lifetime = NumberRange.new(0.35, 0.65)
	drops.Speed = NumberRange.new(10, 18)
	drops.SpreadAngle = Vector2.new(55, 55)
	drops.Acceleration = Vector3.new(0, -55, 0)
	drops.EmissionDirection = Enum.NormalId.Top
	drops.Parent = at
	drops:Emit(if big then 60 else 28)

	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Enabled = false
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 245, 200))
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Lifetime = NumberRange.new(0.5, 0.9)
	sparkle.Speed = NumberRange.new(2, 5)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = at
	sparkle:Emit(if big then 30 else 12)

	-- shockwave ring across the floor
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = color:Lerp(Color3.new(1, 1, 1), 0.5)
	ring.Transparency = 0.3
	ring.Size = Vector3.new(0.05, 1, 1)
	ring.CFrame = CFrame.new(pos.X, 0.15, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	local reach = if big then 16 else 9
	tween(ring, 0.45, { Size = Vector3.new(0.05, reach, reach), Transparency = 1 })

	-- rising "+1"
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(3, 1.2)
	bb.StudsOffset = Vector3.new(0, 1.5, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = holder
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.Arcade
	t.TextScaled = true
	t.Text = if big then "CLEAN!" else "+1"
	t.TextColor3 = Color3.fromRGB(235, 255, 200)
	t.TextStrokeTransparency = 0.2
	t.Parent = bb
	tween(bb, 1, { StudsOffset = Vector3.new(0, 4, 0) })
	tween(t, 1, { TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	Debris:AddItem(holder, 1.5)
	Debris:AddItem(ring, 0.6)
end

function Juice.Start()
	local hud: Instance? = nil
	Cleaned.OnClientEvent:Connect(function(pos: Vector3, color: Color3, cleaner: Player?, isFinal: boolean)
		burst(pos, color, isFinal == true)
		hud = hud or player:WaitForChild("PlayerGui"):FindFirstChild("HUD")
		local bar = hud and hud:FindFirstChild("ShiftBar")
		pop(bar and bar:FindFirstChild("Spills"), 1.15)
		if cleaner == player then
			SoundFx.Play(Config.Sounds.Kaching, 0.5, 1.05)
			Viewmodel.Flourish()
			CameraFx.Kick(if isFinal then 4 else 2.2)
			pop(bar and bar:FindFirstChild("Mine"), 1.3)
		end
	end)
end

return Juice
