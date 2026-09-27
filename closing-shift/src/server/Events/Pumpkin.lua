--!strict
-- Halloween only. A carved jack-o'-lantern sits on the floor at the end of the aisle furthest from
-- everyone, flickering. Nobody put it there. Get close and its face flares red, the lights die for
-- a second, and when they come back it's gone, with candy where it sat.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Candy = require(script.Parent.Parent.Candy)

local function build(cf: CFrame, parent: Instance): (Model, { BasePart }, PointLight)
	local m = Instance.new("Model")
	m.Name = "JackOLantern"
	local function block(name: string, shape: Enum.PartType?, size: Vector3, offset: CFrame, color: Color3, mat: Enum.Material): BasePart
		local p = Instance.new("Part")
		p.Name = name
		if shape then
			p.Shape = shape
		end
		p.Anchored = true
		p.CanCollide = false
		p.Material = mat
		p.Color = color
		p.Size = size
		p.CFrame = cf * offset
		p.Parent = m
		return p
	end
	local body = block("Body", Enum.PartType.Ball, Vector3.new(2.6, 2.6, 2.6), CFrame.new(0, 1.2, 0), Color3.fromRGB(230, 110, 20), Enum.Material.SmoothPlastic)
	body.Size = Vector3.new(2.6, 2.6, 2.6)
	block("Stem", nil, Vector3.new(0.3, 0.6, 0.3), CFrame.new(0, 2.7, 0), Color3.fromRGB(70, 90, 30), Enum.Material.Wood)
	local face: { BasePart } = {}
	for _, f in {
		{ "EyeL", Vector3.new(0.5, 0.45, 0.1), CFrame.new(-0.5, 1.6, -1.2) * CFrame.Angles(0, 0, math.rad(45)) },
		{ "EyeR", Vector3.new(0.5, 0.45, 0.1), CFrame.new(0.5, 1.6, -1.2) * CFrame.Angles(0, 0, math.rad(45)) },
		{ "Mouth", Vector3.new(1.4, 0.35, 0.1), CFrame.new(0, 0.8, -1.2) },
	} do
		table.insert(face, block(f[1], nil, f[2], f[3], Color3.fromRGB(255, 200, 80), Enum.Material.Neon))
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 50)
	light.Range = 12
	light.Brightness = 1.5
	light.Parent = body
	m.Parent = parent
	return m, face, light
end

return function(ctx)
	local rs = ctx.roots()
	local bestPos, bestScore = nil, -1
	for _, a in ctx.aisles() do
		local plinth = a:FindFirstChild("Plinth") :: BasePart
		local pos = Vector3.new(plinth.Position.X, 0, plinth.Position.Z - plinth.Size.Z / 2 - 2)
		local nearest = math.huge
		for _, r in rs do
			nearest = math.min(nearest, (r.Position - pos).Magnitude)
		end
		if nearest > bestScore then
			bestPos, bestScore = pos, nearest
		end
	end
	if not bestPos then
		return
	end
	local pos = bestPos :: Vector3
	local m, face, light = build(CFrame.lookAt(pos, pos + Vector3.zAxis), ctx.props)
	local trigger = ctx.tuning.TriggerDistance or 9
	local t0 = os.clock()
	while m.Parent and ctx.isCurrent() and os.clock() - t0 < (ctx.tuning.MaxLifetime or 100) do
		-- candle flicker
		light.Brightness = 1.1 + ctx.rng:NextNumber() * 0.9
		local close = false
		for _, r in ctx.roots() do
			if (r.Position - pos).Magnitude < trigger then
				close = true
			end
		end
		if close then
			for _, f in face do
				f.Color = Color3.fromRGB(255, 40, 30)
			end
			light.Color = Color3.fromRGB(255, 40, 30)
			light.Brightness = 4
			ctx.playSound(face[1], Config.Sounds.PumpkinSting, 1)
			task.wait(0.6)
			local release = ctx.cutPower()
			-- gone (hidden now, removed once its sound has finished)
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					d.Transparency = 1
				elseif d:IsA("PointLight") then
					d.Enabled = false
				end
			end
			task.delay(6, function()
				m:Destroy()
			end)
			task.wait(1.4)
			release()
			Candy.Drop(pos, ctx.tuning.Candy or 3)
			return
		end
		task.wait(0.12)
	end
	m:Destroy()
end
