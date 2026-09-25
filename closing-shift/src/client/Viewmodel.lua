--!strict
-- First-person mop: a local copy of the equipped mop's parts, drawn in a full-screen ViewportFrame
-- so walls and shelves can never clip through it. It lags a little behind camera turns, bobs while
-- walking and scrubs while a spill prompt is held. The real tool stays visible to everyone else;
-- it's only hidden on this screen.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Movement = require(script.Parent:WaitForChild("Movement"))

local Viewmodel = {}
local player = Players.LocalPlayer :: Player
local FP = Config.FirstPerson

-- The hotbar is gone: the server equips the mop, so there's nothing to pick.
local function hideBackpack()
	for _ = 1, 10 do
		if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false) then
			return
		end
		task.wait(0.5)
	end
end

function Viewmodel.Start()
	task.spawn(hideBackpack)

	-- Viewport overlay: its own camera sits at the origin, so part CFrames are camera-space.
	local gui = Instance.new("ScreenGui")
	gui.Name = "MopView"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5 -- under the HUD and the scanlines
	gui.Parent = player:WaitForChild("PlayerGui")
	local vf = Instance.new("ViewportFrame")
	vf.Size = UDim2.fromScale(1, 1)
	vf.BackgroundTransparency = 1
	vf.ImageColor3 = FP.Tint -- stands in for the world's colour grade, which GUIs don't get
	vf.LightDirection = Vector3.new(-0.4, -1, -0.6)
	vf.Parent = gui
	local vpCam = Instance.new("Camera")
	vpCam.CFrame = CFrame.identity
	vpCam.Parent = vf
	vf.CurrentCamera = vpCam

	local handle: BasePart? = nil
	local head: BasePart? = nil
	local relHead = CFrame.identity -- head relative to handle, copied from the real tool
	local holder: Model? = nil
	local scrubbing = false

	local function clear()
		if holder then
			holder:Destroy()
		end
		holder, handle, head = nil, nil, nil
	end

	local function copy(part: BasePart, parent: Instance): BasePart
		local c = part:Clone()
		c:ClearAllChildren()
		c.Anchored = true
		c.CanCollide = false
		c.CanQuery = false
		c.CanTouch = false
		c.CastShadow = false
		c.Parent = parent
		return c
	end

	local function build(tool: Tool)
		clear()
		local h = tool:WaitForChild("Handle", 5) :: BasePart?
		local hd = tool:WaitForChild("MopHead", 5) :: BasePart?
		if not (h and hd) or tool.Parent ~= player.Character then
			return
		end
		relHead = h.CFrame:ToObjectSpace(hd.CFrame)
		local m = Instance.new("Model")
		m.Name = "MopViewmodel"
		handle = copy(h, m)
		head = copy(hd, m)
		m.Parent = vf
		holder = m
		for _, p in tool:GetDescendants() do
			if p:IsA("BasePart") then
				p.LocalTransparencyModifier = 1
			end
		end
	end

	local function watch(char: Model)
		clear()
		char.ChildAdded:Connect(function(c)
			if c:IsA("Tool") and c:GetAttribute("IsMop") then
				build(c)
			end
		end)
		char.ChildRemoved:Connect(function(c)
			if c:IsA("Tool") and c:GetAttribute("IsMop") then
				clear()
			end
		end)
		local t = char:FindFirstChildOfClass("Tool")
		if t and t:GetAttribute("IsMop") then
			task.spawn(build, t)
		end
	end
	if player.Character then
		watch(player.Character)
	end
	player.CharacterAdded:Connect(watch)

	local function isSpill(prompt: ProximityPrompt): boolean
		return CollectionService:HasTag(prompt, "SpillPrompt")
	end
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
		if isSpill(prompt) then
			scrubbing = true
		end
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
		if isSpill(prompt) then
			scrubbing = false
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if isSpill(prompt) then
			scrubbing = false
		end
	end)

	local camera = workspace.CurrentCamera
	local prevLook = camera.CFrame.LookVector
	local sway = Vector3.zero
	local bobT, scrubT, scrubAmt = 0, 0, 0
	RunService:BindToRenderStep("MopViewmodel", Enum.RenderPriority.Camera.Value + 1, function(dt)
		camera = workspace.CurrentCamera
		-- Hidden during scripted shots (the back-room payoff).
		local show = holder ~= nil and camera.CameraType == Enum.CameraType.Custom
		vf.Visible = show
		if not (show and handle and head) then
			return
		end
		vpCam.FieldOfView = camera.FieldOfView
		-- Flat PSX lighting that follows the store's power.
		local store = workspace:FindFirstChild("Store")
		local power = not store or store:GetAttribute("Power") ~= false
		local boost = (player:GetAttribute("ViewmodelLight") or 0) :: number -- set by the flashlight
		local lit = if power then 1 else boost
		vf.Ambient = FP.Ambient:Lerp(Color3.new(), 1 - math.max(lit, 0.15))
		vf.LightColor = FP.LightColor:Lerp(Color3.new(), 1 - lit)

		local cf = camera.CFrame
		-- Sway: where last frame's look direction sits now, in camera space.
		local d = cf:VectorToObjectSpace(prevLook)
		prevLook = cf.LookVector
		local target = Vector3.new(math.clamp(d.X * 6, -1, 1), math.clamp(d.Y * 6, -1, 1), 0) * FP.SwayAmount * 4
		sway = sway:Lerp(target, math.min(1, dt * 10))

		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local moving = hum ~= nil and hum.MoveDirection.Magnitude > 0.1 and hum.FloorMaterial ~= Enum.Material.Air
		local bob = Vector3.zero
		if moving then
			bobT += dt * (if Movement.Sprinting then 15 else 10)
			local amt = FP.BobAmount * (if Movement.Sprinting then 1.8 else 1)
			bob = Vector3.new(math.sin(bobT) * amt, -math.abs(math.cos(bobT)) * amt, 0)
		end

		scrubAmt += ((if scrubbing then 1 else 0) - scrubAmt) * math.min(1, dt * 12)
		scrubT += dt * FP.ScrubSpeed
		local stroke = math.sin(scrubT) * FP.ScrubAmount * scrubAmt
		local scrubHead = Vector3.new(stroke * 0.3, -0.25 * scrubAmt, stroke)
		local scrubHand = Vector3.new(0, -0.1 * scrubAmt, stroke * 0.45)

		local hand = FP.HandOffset + bob + sway + scrubHand
		local aim = FP.HeadOffset + bob * 0.5 + sway * 0.5 + scrubHead
		local up = (hand - aim).Unit
		local right = (Vector3.xAxis - up * up.X).Unit
		-- The hand grips 1 stud above the handle's centre (matches Tool.Grip in Mop.lua).
		local handleCF = CFrame.fromMatrix(hand - up, right, up)
		handle.CFrame = handleCF
		head.CFrame = handleCF * relHead
	end)
end

return Viewmodel
