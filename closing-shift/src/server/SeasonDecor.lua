--!strict
-- Decorations for the running event (Data/Seasons), in both places. Checks the date every minute,
-- so a server that's up when an event starts or ends dresses or undresses itself. Everything goes
-- in one "SeasonDecor" model (nothing else is touched), so removing it is one Destroy.
--   Store: jack-o'-lanterns on the counter, by the door and at the aisle ends, cobwebs in the
--          corners, orange and purple string lights along the front windows.
--   Lobby: pumpkins by every queue pad, a banner across the storefront, bats over the lot.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Season = require(ReplicatedStorage.Shared.Season)
local Fonts = require(ReplicatedStorage.Shared.Fonts)

local SeasonDecor = {}
local ORANGE = Color3.fromRGB(235, 115, 25)
local PURPLE = Color3.fromRGB(140, 60, 210)

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

-- A jack-o'-lantern standing on a surface at `pos` (its bottom), facing `face` (a direction).
local function pumpkin(parent: Instance, pos: Vector3, size: number, face: Vector3)
	local m = Instance.new("Model")
	m.Name = "Pumpkin"
	local cf = CFrame.lookAt(pos + Vector3.new(0, size / 2, 0), pos + Vector3.new(0, size / 2, 0) + face)
	local body = part({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.one * size, CFrame = cf, Color = ORANGE, Parent = m })
	part({ Name = "Stem", Size = Vector3.new(0.12, 0.25, 0.12) * size, CFrame = cf * CFrame.new(0, size * 0.55, 0), Color = Color3.fromRGB(70, 90, 30), Material = Enum.Material.Wood, Parent = m })
	for _, f in {
		{ Vector3.new(0.2, 0.18, 0.04), CFrame.new(-0.2, 0.12, -0.47) * CFrame.Angles(0, 0, math.rad(45)) },
		{ Vector3.new(0.2, 0.18, 0.04), CFrame.new(0.2, 0.12, -0.47) * CFrame.Angles(0, 0, math.rad(45)) },
		{ Vector3.new(0.55, 0.13, 0.04), CFrame.new(0, -0.18, -0.46) },
	} do
		part({ Name = "Face", Size = f[1] * size, CFrame = cf * CFrame.new(f[2].Position * size) * f[2].Rotation, Color = Color3.fromRGB(255, 200, 80), Material = Enum.Material.Neon, Parent = m })
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 60)
	light.Range = 5 + size * 2
	light.Brightness = 1
	light.Parent = body
	m.Parent = parent
end

-- A cobweb: a pale sheet across a corner.
local function cobweb(parent: Instance, corner: Vector3, dirX: number, dirZ: number)
	local w = part({
		ClassName = "WedgePart", Name = "Cobweb", Size = Vector3.new(0.05, 3, 3),
		CFrame = CFrame.new(corner + Vector3.new(dirX * 1.2, -1.5, dirZ * 1.2)) * CFrame.Angles(0, math.atan2(dirX, dirZ) + math.rad(45), 0),
		Color = Color3.fromRGB(230, 230, 225), Transparency = 0.55, Parent = parent,
	})
	w.Material = Enum.Material.Fabric
end

-- A row of little bulbs from a to b, alternating colours.
local function stringLights(parent: Instance, a: Vector3, b: Vector3)
	local n = math.max(2, math.floor((b - a).Magnitude / 1.6))
	for i = 0, n do
		local p = a:Lerp(b, i / n) + Vector3.new(0, -math.sin(i / n * math.pi) * 0.6, 0)
		part({ Name = "Bulb", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.35, Position = p, Color = if i % 2 == 0 then ORANGE else PURPLE, Material = Enum.Material.Neon, Parent = parent })
	end
end

local function decorateStore(store: Instance, root: Model)
	-- the counter
	local top = store:FindFirstChild("CounterTop", true) :: BasePart?
	if top then
		pumpkin(root, top.Position + Vector3.new(0, top.Size.Y / 2, top.Size.Z / 2 - 1), 1.3, Vector3.xAxis)
		pumpkin(root, top.Position + Vector3.new(0, top.Size.Y / 2, -top.Size.Z / 2 + 1.2), 0.9, Vector3.xAxis)
	end
	-- by the door, inside
	local glass = store:FindFirstChild("DoorGlass", true) :: BasePart?
	if glass then
		for _, dx in { -4.5, 4.5 } do
			pumpkin(root, Vector3.new(glass.Position.X + dx, 0, glass.Position.Z - 2), 1.8, -Vector3.zAxis)
		end
	end
	-- the front end of every aisle
	local aisles = store:FindFirstChild("Aisles")
	if aisles then
		for _, a in aisles:GetChildren() do
			local plinth = a:FindFirstChild("Plinth") :: BasePart?
			if plinth then
				pumpkin(root, Vector3.new(plinth.Position.X + 1.2, plinth.Position.Y + plinth.Size.Y / 2, plinth.Position.Z + plinth.Size.Z / 2 + 0.2), 0.8, Vector3.zAxis)
			end
		end
	end
	-- cobwebs in the main room's ceiling corners, lights along the front windows
	local floor = store:FindFirstChild("Structure") and (store :: any).Structure:FindFirstChild("Floor") :: BasePart?
	local ceiling = store:FindFirstChild("Structure") and (store :: any).Structure:FindFirstChild("Ceiling") :: BasePart?
	if floor and ceiling then
		local hx, hz = floor.Size.X / 2 - 1, floor.Size.Z / 2 - 1
		local y = ceiling.Position.Y - ceiling.Size.Y / 2
		for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			cobweb(root, Vector3.new(floor.Position.X + c[1] * hx, y, floor.Position.Z + c[2] * hz), -c[1], -c[2])
		end
		local z = floor.Position.Z + hz - 0.6
		stringLights(root, Vector3.new(floor.Position.X - hx, y - 0.5, z), Vector3.new(floor.Position.X + hx, y - 0.5, z))
	end
end

local function decorateLobby(lobby: Instance, root: Model)
	local pads = lobby:FindFirstChild("QueuePads")
	if pads then
		for _, m in pads:GetChildren() do
			local pad = m:FindFirstChild("Pad") :: BasePart?
			if pad then
				for _, dx in { -8, 8 } do
					pumpkin(root, Vector3.new(pad.Position.X + dx, 0, pad.Position.Z + 5), 2.2, Vector3.zAxis)
				end
			end
		end
	end
	local front = lobby:FindFirstChild("Storefront")
	local building = front and front:FindFirstChild("Building") :: BasePart?
	if building then
		-- standing on the front edge of the roof, above the store's own signs
		local banner = part({
			Name = "EventBanner", Size = Vector3.new(44, 5, 0.3),
			Position = building.Position + Vector3.new(0, building.Size.Y / 2 + 2.5, building.Size.Z / 2 - 0.5), Color = Color3.fromRGB(20, 12, 24), Parent = root,
		})
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Back
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 30
		g.LightInfluence = 0
		g.Parent = banner
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.FontFace = Fonts.Title
		t.TextScaled = true
		t.TextColor3 = ORANGE
		t.Text = "HALLOWEEN NIGHT SHIFT"
		t.Parent = g
		stringLights(root, banner.Position + Vector3.new(-23, 2.9, 0), banner.Position + Vector3.new(23, 2.9, 0))
	end
	-- bats circling high over the lot
	local bats = Instance.new("Model")
	bats.Name = "Bats"
	bats.Parent = root
	for i = 1, 14 do
		local b = part({ ClassName = "WedgePart", Name = "Bat", Size = Vector3.new(0.1, 0.8, 2.4), Color = Color3.fromRGB(12, 10, 14), Parent = bats })
		b:SetAttribute("Phase", i / 14 * math.pi * 2)
		b:SetAttribute("Radius", 30 + (i % 4) * 12)
		b:SetAttribute("Height", 38 + (i % 3) * 6)
	end
	CollectionService:AddTag(bats, "SeasonBats")
end

function SeasonDecor.Init(root: Instance, kind: string)
	local current: string? = nil
	local function sync()
		local s = Season.Current()
		local want = if s then s.Id else nil
		if want == current then
			return
		end
		current = want
		local old = root:FindFirstChild("SeasonDecor")
		if old then
			old:Destroy()
		end
		if want == "Halloween" then
			local m = Instance.new("Model")
			m.Name = "SeasonDecor"
			m.Parent = root
			if kind == "Store" then
				decorateStore(root, m)
			else
				decorateLobby(root, m)
			end
		end
	end
	sync()
	task.spawn(function()
		while true do
			task.wait(60)
			sync()
		end
	end)
	-- bats flap around their circles
	RunService.Heartbeat:Connect(function()
		local decor = root:FindFirstChild("SeasonDecor")
		local bats = decor and decor:FindFirstChild("Bats")
		if not bats then
			return
		end
		local t = os.clock()
		for _, b in bats:GetChildren() do
			if b:IsA("BasePart") then
				local ph = (b:GetAttribute("Phase") or 0) :: number
				local r = (b:GetAttribute("Radius") or 30) :: number
				local a = t * 0.5 + ph
				local pos = Vector3.new(math.cos(a) * r, (b:GetAttribute("Height") or 40) :: number + math.sin(t * 3 + ph) * 1.5, -20 + math.sin(a) * r)
				b.CFrame = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a))) * CFrame.Angles(0, 0, math.sin(t * 14 + ph) * 0.6)
			end
		end
	end)
end

return SeasonDecor
