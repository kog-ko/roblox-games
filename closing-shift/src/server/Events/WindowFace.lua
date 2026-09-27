--!strict
-- A pale face is pressed against the front window from outside, hands flat on the glass, looking
-- in. The moment anyone actually looks at it, it's gone (with a sting for whoever saw it).
-- Nobody looks: it leaves on its own after a while.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Manager = require(script.Parent.Parent.Manager)
local Players = game:GetService("Players")

return function(ctx)
	-- pick a spot on the big front windows
	local windows = {}
	for _, d in ctx.store:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "FrontWindow" then
			table.insert(windows, d)
		end
	end
	if #windows == 0 then
		return
	end
	local w = windows[ctx.rng:NextInteger(1, #windows)] :: BasePart
	local x = w.Position.X + ctx.rng:NextNumber(-w.Size.X / 2 + 2, w.Size.X / 2 - 2)
	local z = w.Position.Z + w.Size.Z / 2 + 0.35 -- just outside the glass
	local m = Instance.new("Model")
	m.Name = "WindowFace"
	local skin = Color3.fromRGB(215, 210, 200)
	local function block(name: string, size: Vector3, pos: Vector3, color: Color3)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = color
		p.Size = size
		p.Position = pos
		p.Parent = m
		return p
	end
	block("Head", Vector3.new(1.3, 1.6, 0.6), Vector3.new(x, 6.2, z + 0.3), skin)
	for _, dx in { -0.3, 0.3 } do
		block("Eye", Vector3.new(0.26, 0.2, 0.05), Vector3.new(x + dx, 6.45, z), Color3.new(0, 0, 0))
	end
	block("Mouth", Vector3.new(0.45, 0.12, 0.05), Vector3.new(x, 5.8, z), Color3.fromRGB(40, 10, 10))
	for _, dx in { -1.6, 1.6 } do
		block("Hand", Vector3.new(0.7, 1, 0.1), Vector3.new(x + dx, 6.6, z + 0.05), skin) -- flat on the glass
	end
	m.Parent = ctx.props
	local at = Vector3.new(x, 6.2, z)
	local t0 = os.clock()
	while m.Parent and ctx.isCurrent() and os.clock() - t0 < (ctx.tuning.MaxLifetime or 25) do
		for _, p in Players:GetPlayers() do
			local view = Manager.ViewOf(p)
			if view then
				local to = at - view.Position
				local d = to.Magnitude
				if d < 60 and view.LookVector:Dot(to / d) > math.cos(math.rad(18)) then
					ctx.playSound(m:FindFirstChild("Head") :: BasePart, Config.Sounds.StingPayoff, 0.9)
					task.wait(0.15)
					m:Destroy()
					return
				end
			end
		end
		task.wait(0.1)
	end
	m:Destroy()
end
