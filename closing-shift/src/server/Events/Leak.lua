--!strict
-- A drink cooler springs a leak: a red shut-off valve appears beside it and a new spill runs out in
-- front of it every few seconds (up to MaxSpills) until someone holds the valve closed. A job for one
-- player while the others keep mopping.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

return function(ctx)
	local coolers = ctx.store:FindFirstChild("Coolers")
	if not coolers or #coolers:GetChildren() == 0 then
		return
	end
	local list = coolers:GetChildren()
	local cooler = list[ctx.rng:NextInteger(1, #list)]
	local glass = cooler:FindFirstChild("Glass") :: BasePart?
	if not glass then
		return
	end
	local front = glass.Position * Vector3.new(1, 0, 1) + Vector3.new(0, 0.05, 2.2)

	-- the valve: a red wheel on a pipe at the cooler's side
	local valve = Instance.new("Model")
	valve.Name = "LeakValve"
	local pipe = Instance.new("Part")
	pipe.Name = "Pipe"
	pipe.Anchored = true
	pipe.CanCollide = false
	pipe.Size = Vector3.new(0.4, 2.2, 0.4)
	pipe.Position = glass.Position * Vector3.new(1, 0, 1) + Vector3.new(4.4, 1.1, 1.6)
	pipe.Material = Enum.Material.Metal
	pipe.Color = Color3.fromRGB(150, 155, 150)
	pipe.Parent = valve
	local wheel = Instance.new("Part")
	wheel.Name = "Wheel"
	wheel.Anchored = true
	wheel.CanCollide = false
	wheel.Shape = Enum.PartType.Cylinder
	wheel.Size = Vector3.new(0.3, 1.4, 1.4)
	wheel.CFrame = CFrame.new(pipe.Position + Vector3.new(0, 1.2, 0.3)) * CFrame.Angles(0, math.rad(90), 0)
	wheel.Material = Enum.Material.Metal
	wheel.Color = Color3.fromRGB(200, 40, 35)
	wheel.Parent = valve
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 60, 50)
	light.Range = 8
	light.Brightness = 1.5
	light.Parent = wheel
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Shut Valve"
	prompt.ObjectText = "LEAK"
	prompt.HoldDuration = ctx.tuning.ValveHold or 3
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = wheel
	valve.Parent = ctx.props

	local drip = Instance.new("Sound")
	drip.SoundId = Config.Sounds.Splash
	drip.Volume = 0.5
	drip.RollOffMaxDistance = 60
	drip.Parent = pipe

	local closed = false
	prompt.Triggered:Connect(function(player)
		if closed then
			return
		end
		closed = true
		prompt.Enabled = false
		light.Color = Color3.fromRGB(90, 220, 90)
		wheel.Color = Color3.fromRGB(60, 160, 60)
		local banner = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Banner")
		if banner then
			(banner :: RemoteEvent):FireAllClients(string.upper(player.DisplayName) .. " SHUT OFF THE LEAK", "Leak")
		end
		task.delay(4, function()
			valve:Destroy()
		end)
	end)

	-- the leak: a spill now, then another every few seconds until it's shut
	task.spawn(function()
		local spawned = 0
		while not closed and ctx.isCurrent() and spawned < (ctx.tuning.MaxSpills or 4) do
			if ctx.spills.CanAddSpills() then
				local offset = Vector3.new(ctx.rng:NextNumber(-2.5, 2.5), 0, ctx.rng:NextNumber(0, 2.5))
				ctx.spills.Spawn(front + offset)
				drip:Play()
				spawned += 1
			end
			task.wait(ctx.tuning.Every or 10)
		end
		if not ctx.isCurrent() and valve.Parent then
			valve:Destroy()
		end
	end)
end
