--!strict
-- Dressing for a particular night (Data/Nights Decor), put up at the start of its shift and taken
-- down between shifts. Everything lives in one "NightDecor" model under the store.
--   GrandOpening: balloon bunches at the door, the counter and the aisle ends, streamers, and a
--                 GRAND OPENING banner over the aisles. One bunch is black. Nobody ordered those.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fonts = require(ReplicatedStorage.Shared.Fonts)

local NightDecor = {}
local store: Instance
local bobbing: { { part: BasePart, base: CFrame, phase: number } } = {}

local COLORS = { Color3.fromRGB(230, 60, 60), Color3.fromRGB(60, 140, 230), Color3.fromRGB(250, 210, 60), Color3.fromRGB(80, 200, 110), Color3.fromRGB(240, 120, 200) }

local function part(props: { [string]: any }): BasePart
	local p = Instance.new(props.ClassName or "Part") :: BasePart
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		if k ~= "Parent" and k ~= "ClassName" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

-- A bunch of balloons tied at `anchor` (a floor or counter point), floating `height` above it.
local function bunch(parent: Instance, anchor: Vector3, height: number, rng: Random, black: boolean?)
	for i = 1, 5 do
		local off = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.4, 0.6), rng:NextNumber(-1, 1))
		local top = anchor + Vector3.new(0, height, 0) + off
		local color = if black then Color3.fromRGB(12, 12, 14) else COLORS[(i % #COLORS) + 1]
		local b = part({ Name = "Balloon", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = CFrame.new(top), Color = color, Parent = parent })
		b.Reflectance = 0.15
		local mid = (anchor + top) / 2
		local len = (top - anchor).Magnitude
		part({ Name = "String", Size = Vector3.new(0.05, len, 0.05), CFrame = CFrame.lookAt(mid, top) * CFrame.Angles(math.rad(90), 0, 0), Color = Color3.fromRGB(220, 220, 215), Parent = parent })
		table.insert(bobbing, { part = b, base = b.CFrame, phase = rng:NextNumber(0, 6.28) })
	end
end

local function grandOpening(m: Model)
	local rng = Random.new(505)
	local glass = store:FindFirstChild("DoorGlass", true) :: BasePart?
	if glass then
		for _, dx in { -4.5, 4.5 } do
			bunch(m, Vector3.new(glass.Position.X + dx, 0, glass.Position.Z - 2), 6, rng)
		end
	end
	local top = store:FindFirstChild("CounterTop", true) :: BasePart?
	if top then
		bunch(m, top.Position + Vector3.new(0, top.Size.Y / 2, -top.Size.Z / 2 + 1), 4, rng)
	end
	local aisles = store:FindFirstChild("Aisles")
	local firstX, lastX, signZ, signY = math.huge, -math.huge, 0, 11
	if aisles then
		local list = aisles:GetChildren()
		for i, a in list do
			local plinth = a:FindFirstChild("Plinth") :: BasePart?
			if plinth then
				firstX = math.min(firstX, plinth.Position.X)
				lastX = math.max(lastX, plinth.Position.X)
				signZ = plinth.Position.Z + plinth.Size.Z / 2 + 3
				-- the black bunch is at the far end of the last aisle
				bunch(m, Vector3.new(plinth.Position.X, 0, plinth.Position.Z + plinth.Size.Z / 2 + 1.5), 5.5, rng, i == #list)
			end
		end
	end
	-- the banner hangs across the front of the aisles, streamers either side of it
	if firstX < lastX then
		local banner = part({
			Name = "Banner", Size = Vector3.new(lastX - firstX + 8, 3, 0.2), Position = Vector3.new((firstX + lastX) / 2, signY + 1.5, signZ + 2),
			Color = Color3.fromRGB(250, 240, 220), Parent = m,
		})
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local g = Instance.new("SurfaceGui")
			g.Face = face
			g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			g.PixelsPerStud = 30
			g.LightInfluence = 0.7
			g.Parent = banner
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(1, 1)
			t.FontFace = Fonts.Sign
			t.TextScaled = true
			t.TextColor3 = Color3.fromRGB(200, 40, 40)
			t.Text = "GRAND OPENING!"
			t.Parent = g
		end
		for i = 0, 11 do
			local x = firstX - 4 + (lastX - firstX + 8) * i / 11
			part({ Name = "Streamer", Size = Vector3.new(0.4, 2.2, 0.05), Position = Vector3.new(x, signY - 0.6, signZ + 2), Color = COLORS[(i % #COLORS) + 1], Parent = m })
		end
	end
end

function NightDecor.Apply(decor: string?)
	NightDecor.Clear()
	if decor ~= "GrandOpening" then
		return
	end
	local m = Instance.new("Model")
	m.Name = "NightDecor"
	m.Parent = store
	grandOpening(m)
end

function NightDecor.Clear()
	local old = store and store:FindFirstChild("NightDecor")
	if old then
		old:Destroy()
	end
	table.clear(bobbing)
end

function NightDecor.Init(s: Instance)
	store = s
	RunService.Heartbeat:Connect(function()
		if #bobbing == 0 then
			return
		end
		local t = os.clock()
		for _, b in bobbing do
			b.part.CFrame = b.base * CFrame.new(math.sin(t * 0.7 + b.phase) * 0.15, math.sin(t * 1.1 + b.phase) * 0.2, 0)
		end
	end)
end

return NightDecor
