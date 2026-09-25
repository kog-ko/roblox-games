--!strict
-- A mannequin stands at the end of the aisle furthest from everyone. It's gone once anyone gets close.
local function build(cf: CFrame, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = "Mannequin"
	local skin = Color3.fromRGB(205, 200, 188)
	local function block(name: string, size: Vector3, offset: Vector3)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = skin
		p.Size = size
		p.CFrame = cf * CFrame.new(offset)
		p.Parent = m
	end
	block("Head", Vector3.new(1.2, 1.3, 1.2), Vector3.new(0, 6.1, 0))
	block("Torso", Vector3.new(2, 2.4, 1), Vector3.new(0, 4.2, 0))
	block("LeftArm", Vector3.new(0.7, 2.4, 0.7), Vector3.new(-1.4, 4.2, 0))
	block("RightArm", Vector3.new(0.7, 2.4, 0.7), Vector3.new(1.4, 4.2, 0))
	block("LeftLeg", Vector3.new(0.8, 3, 0.8), Vector3.new(-0.5, 1.5, 0))
	block("RightLeg", Vector3.new(0.8, 3, 0.8), Vector3.new(0.5, 1.5, 0))
	m.Parent = parent
	return m
end

return function(ctx)
	local rs = ctx.roots()
	local bestPos, bestScore = nil, -1
	for _, a in ctx.aisles() do
		local plinth = a:FindFirstChild("Plinth") :: BasePart
		local pos = Vector3.new(plinth.Position.X, 0, plinth.Position.Z - plinth.Size.Z / 2 - 1.5)
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
	local m = build(CFrame.lookAt(bestPos, bestPos + Vector3.zAxis), ctx.props)
	local vanish = ctx.tuning.VanishDistance or 15
	local t = os.clock()
	while m.Parent and ctx.isCurrent() and os.clock() - t < (ctx.tuning.MaxLifetime or 90) do
		for _, r in ctx.roots() do
			if (r.Position - bestPos).Magnitude < vanish then
				m:Destroy()
				return
			end
		end
		task.wait(0.2)
	end
	m:Destroy()
end
