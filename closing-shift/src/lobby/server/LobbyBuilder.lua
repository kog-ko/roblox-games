--!strict
-- The lobby: the Quik Stop's parking lot at night. Everyone spawns here, sees everyone else's rank,
-- trophies and VIP status, and queues for a shift on one of the neon pads by the storefront.
--
-- Built from Parts in code (like the store). Names the rest of the lobby code looks for:
--   SpawnPoint, QueuePads/<Key> (Pad, Sign/SignGui with Title, Sub, Status), Boards/<Key>
--   (BoardGui with Title, List), VendingMachine, MyLocker, VIPDoor, VIPLoungeSpawn, VIPLoungeExit.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local LobbyBuilder = {}

local M = Enum.Material
local ASPHALT = Color3.fromRGB(36, 37, 40)
local CONCRETE = Color3.fromRGB(95, 95, 90)
local STEEL = Color3.fromRGB(70, 72, 70)
local WARM = Color3.fromRGB(255, 205, 140)

-- One queue pad per night, plus Quick Play. Colours are the pads' neon edges.
LobbyBuilder.Pads = {
	{ Key = "Night1", Night = 1, Color = Color3.fromRGB(110, 220, 120) },
	{ Key = "Night2", Night = 2, Color = Color3.fromRGB(255, 190, 70) },
	{ Key = "Night3", Night = 3, Color = Color3.fromRGB(230, 70, 60) },
	{ Key = "Quick", Night = nil, Color = Color3.fromRGB(110, 170, 255) },
}

-- The lobby's leaderboards (kind as understood by Leaderboard.Entries).
LobbyBuilder.Boards = {
	{ Key = "Weekly", Title = "EMPLOYEE OF THE WEEK", Kind = "weekly" },
	{ Key = "Fastest", Title = "FASTEST SHIFTS", Kind = "night" },
	{ Key = "Earnings", Title = "LIFETIME EARNINGS", Kind = "earnings" },
	{ Key = "Career", Title = "MOST SPILLS EVER", Kind = "career" },
}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = false
	for k, v in props do
		if k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

local function model(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function surfaceGui(adornee: BasePart, face: Enum.NormalId, ppu: number?): SurfaceGui
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = ppu or 30
	g.LightInfluence = 0
	g.Parent = adornee
	return g
end

local function label(parent: Instance, name: string, text: string, props: { [string]: any }?): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.Arcade
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = Color3.fromRGB(230, 230, 220)
	if props then
		for k, v in props do
			(t :: any)[k] = v
		end
	end
	t.Parent = parent
	return t
end

local function lamp(parent: Instance, pos: Vector3)
	part({ Name = "LampPole", Size = Vector3.new(0.6, 16, 0.6), Position = pos + Vector3.new(0, 8, 0), Material = M.Metal, Color = STEEL, Parent = parent })
	local head = part({ Name = "LampHead", Size = Vector3.new(3, 0.6, 1.4), Position = pos + Vector3.new(0, 16, 0), Material = M.Neon, Color = WARM, CanCollide = false, Parent = parent })
	local light = Instance.new("PointLight")
	light.Range = 55
	light.Brightness = 2.2
	light.Color = WARM
	light.Parent = head
end

local function car(parent: Instance, pos: Vector3, color: Color3, yaw: number)
	local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw), 0)
	local c = model("ParkedCar", parent)
	part({ Name = "Body", Size = Vector3.new(6, 2.2, 12), CFrame = cf * CFrame.new(0, 1.6, 0), Color = color, Material = M.Metal, Parent = c })
	part({ Name = "Cabin", Size = Vector3.new(5.4, 1.8, 6), CFrame = cf * CFrame.new(0, 3.6, 0.5), Color = color:Lerp(Color3.new(0, 0, 0), 0.3), Material = M.Metal, Parent = c })
	part({ Name = "Glass", Size = Vector3.new(5.5, 1.3, 6.1), CFrame = cf * CFrame.new(0, 3.7, 0.5), Color = Color3.fromRGB(30, 40, 45), Transparency = 0.35, Parent = c })
	for _, x in { -2.9, 2.9 } do
		for _, z in { -3.8, 3.8 } do
			part({ Name = "Wheel", Size = Vector3.new(0.8, 1.6, 1.6), CFrame = cf * CFrame.new(x, 0.8, z), Color = Color3.fromRGB(20, 20, 20), Parent = c })
		end
	end
end

local function queuePad(parent: Instance, info: any, x: number)
	local m = model(info.Key, parent)
	m:SetAttribute("Night", info.Night)
	local z = -38
	part({ Name = "Pad", Size = Vector3.new(14, 0.4, 14), Position = Vector3.new(x, 0.2, z), Color = Color3.fromRGB(28, 30, 32), Parent = m })
	-- neon edge
	for _, e in {
		{ Vector3.new(14, 0.3, 0.5), Vector3.new(0, 0, -6.75) },
		{ Vector3.new(14, 0.3, 0.5), Vector3.new(0, 0, 6.75) },
		{ Vector3.new(0.5, 0.3, 14), Vector3.new(-6.75, 0, 0) },
		{ Vector3.new(0.5, 0.3, 14), Vector3.new(6.75, 0, 0) },
	} do
		part({ Name = "Edge", Size = e[1], Position = Vector3.new(x, 0.45, z) + e[2], Material = M.Neon, Color = info.Color, CanCollide = false, Parent = m })
	end
	local glow = Instance.new("PointLight")
	glow.Color = info.Color
	glow.Range = 14
	glow.Brightness = 1.2
	glow.Parent = m:FindFirstChild("Pad")
	-- sign above the back edge, facing the lot
	for _, dx in { -5.5, 5.5 } do
		part({ Name = "SignLeg", Size = Vector3.new(0.4, 8, 0.4), Position = Vector3.new(x + dx, 4, z - 7.2), Material = M.Metal, Color = STEEL, Parent = m })
	end
	local sign = part({ Name = "Sign", Size = Vector3.new(12, 5, 0.4), Position = Vector3.new(x, 9.5, z - 7.2), Color = Color3.fromRGB(14, 15, 16), Parent = m })
	local g = surfaceGui(sign, Enum.NormalId.Back, 30)
	g.Name = "SignGui"
	local title = if info.Night then "NIGHT " .. info.Night else "QUICK PLAY"
	local night = info.Night and Config.Nights[info.Night]
	local sub = if night then string.upper(night.Name) else "BEST NIGHT FOR YOUR CREW"
	label(g, "Title", title, { Size = UDim2.fromScale(1, 0.38), TextColor3 = info.Color })
	label(g, "Sub", sub, { Position = UDim2.fromScale(0.05, 0.38), Size = UDim2.fromScale(0.9, 0.22) })
	label(g, "Status", "STEP ON TO QUEUE", { Position = UDim2.fromScale(0.05, 0.64), Size = UDim2.fromScale(0.9, 0.3), TextColor3 = Color3.fromRGB(255, 230, 150) })
end

local function board(parent: Instance, info: any, z: number)
	local m = model(info.Key, parent)
	m:SetAttribute("Kind", info.Kind)
	local b = part({ Name = "Board", Size = Vector3.new(0.6, 12, 16), Position = Vector3.new(-86, 8, z), Color = Color3.fromRGB(22, 26, 24), Parent = m })
	for _, dz in { -7, 7 } do
		part({ Name = "Leg", Size = Vector3.new(0.5, 2, 0.5), Position = Vector3.new(-86, 1, z + dz), Material = M.Metal, Color = STEEL, Parent = m })
	end
	-- gold neon frame so the boards read from across the lot
	for _, t in {
		{ Vector3.new(0.3, 0.4, 16.8), Vector3.new(0, 6.2, 0) },
		{ Vector3.new(0.3, 0.4, 16.8), Vector3.new(0, -6.2, 0) },
		{ Vector3.new(0.3, 12.8, 0.4), Vector3.new(0, 0, -8.2) },
		{ Vector3.new(0.3, 12.8, 0.4), Vector3.new(0, 0, 8.2) },
	} do
		part({ Name = "Trim", Size = t[1], Position = Vector3.new(-85.6, 8, z) + t[2], Material = M.Neon, Color = Color3.fromRGB(255, 190, 70), CanCollide = false, Parent = m })
	end
	local g = surfaceGui(b, Enum.NormalId.Right, 30)
	g.Name = "BoardGui"
	label(g, "Title", info.Title, { Size = UDim2.new(1, 0, 0, 48), TextColor3 = Color3.fromRGB(255, 205, 70) })
	label(g, "List", "loading...", {
		Position = UDim2.new(0, 16, 0, 56), Size = UDim2.new(1, -32, 1, -64), TextScaled = false, TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(200, 225, 200),
	})
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Right
	light.Range = 10
	light.Brightness = 0.6
	light.Color = Color3.fromRGB(200, 230, 200)
	light.Parent = b
end

local function storefront(parent: Instance)
	local m = model("Storefront", parent)
	part({ Name = "Building", Size = Vector3.new(96, 20, 22), Position = Vector3.new(0, 10, -70), Material = M.Brick, Color = Color3.fromRGB(78, 70, 64), Parent = m })
	-- lit windows with shelves behind them
	local glass = part({ Name = "Window", Size = Vector3.new(64, 10, 0.4), Position = Vector3.new(0, 6, -58.8), Color = Color3.fromRGB(190, 230, 215), Material = M.Neon, Transparency = 0.55, CanCollide = false, Parent = m })
	local l = Instance.new("SurfaceLight")
	l.Face = Enum.NormalId.Back
	l.Range = 24
	l.Brightness = 1.2
	l.Color = Color3.fromRGB(200, 240, 220)
	l.Parent = glass
	for i = -3, 3 do
		part({ Name = "Mullion", Size = Vector3.new(0.6, 10, 0.6), Position = Vector3.new(i * 9.2, 6, -58.5), Material = M.Metal, Color = STEEL, Parent = m })
	end
	part({ Name = "Awning", Size = Vector3.new(96, 1, 8), Position = Vector3.new(0, 12, -56), Material = M.Metal, Color = Color3.fromRGB(150, 35, 30), Parent = m })
	local sign = part({ Name = "Sign", Size = Vector3.new(40, 5, 1), Position = Vector3.new(0, 16.5, -58.4), Color = Color3.fromRGB(170, 25, 25), Material = M.Neon, Parent = m })
	local g = surfaceGui(sign, Enum.NormalId.Back, 20)
	label(g, "Name", "QUIK STOP", { Size = UDim2.fromScale(1, 0.7), TextColor3 = Color3.fromRGB(255, 240, 210) })
	label(g, "Hours", "OPEN 24/7 - NOW HIRING NIGHT CREW", { Position = UDim2.fromScale(0, 0.7), Size = UDim2.fromScale(1, 0.3), TextColor3 = Color3.fromRGB(255, 220, 120) })
	part({ Name = "Sidewalk", Size = Vector3.new(110, 0.6, 12), Position = Vector3.new(0, 0.3, -53), Material = M.Concrete, Color = CONCRETE, Parent = m })
end

local function shopArea(parent: Instance)
	local m = model("ShopArea", parent)
	part({ Name = "Slab", Size = Vector3.new(16, 0.4, 40), Position = Vector3.new(76, 0.2, -12), Material = M.Concrete, Color = CONCRETE, Parent = m })
	local vend = part({ Name = "VendingMachine", Size = Vector3.new(3, 8, 5), Position = Vector3.new(82, 4.4, -24), Color = Color3.fromRGB(40, 90, 170), Parent = m })
	local vg = surfaceGui(vend, Enum.NormalId.Left, 30)
	label(vg, "Label", "SHOP", { Size = UDim2.fromScale(1, 0.3), TextColor3 = Color3.fromRGB(255, 255, 255) })
	local vl = Instance.new("SurfaceLight")
	vl.Face = Enum.NormalId.Left
	vl.Range = 10
	vl.Color = Color3.fromRGB(150, 190, 255)
	vl.Parent = vend
	-- employee lockers: upgrades bought with shift cash
	for i = 0, 3 do
		local name = if i == 1 then "MyLocker" else "Locker"
		local lk = part({ Name = name, Size = Vector3.new(2, 7, 2.4), Position = Vector3.new(83, 3.9, -8 + i * 2.5), Material = M.Metal, Color = if i == 1 then Color3.fromRGB(200, 170, 60) else Color3.fromRGB(90, 100, 110), Parent = m })
		if i == 1 then
			local lg = surfaceGui(lk, Enum.NormalId.Left, 40)
			label(lg, "Label", "UPGRADES", { Size = UDim2.fromScale(1, 0.15), TextColor3 = Color3.fromRGB(20, 20, 20) })
		end
	end
	local sign = part({ Name = "Sign", Size = Vector3.new(0.4, 3, 14), Position = Vector3.new(84, 11, -14), Color = Color3.fromRGB(14, 15, 16), Parent = m })
	local sg = surfaceGui(sign, Enum.NormalId.Left, 30)
	label(sg, "Title", "BREAK ROOM", { TextColor3 = Color3.fromRGB(255, 205, 70) })
end

local function vipLounge(parent: Instance)
	local m = model("VIPLounge", parent)
	local cx, cz = 62, 40
	part({ Name = "Deck", Size = Vector3.new(30, 1, 24), Position = Vector3.new(cx, 0.5, cz), Material = M.WoodPlanks, Color = Color3.fromRGB(90, 60, 40), Parent = m })
	-- walls with a gold rope along the top; the door is on the west side
	for _, w in {
		{ Vector3.new(30, 8, 1), Vector3.new(0, 4.5, -12) },
		{ Vector3.new(30, 8, 1), Vector3.new(0, 4.5, 12) },
		{ Vector3.new(1, 8, 24), Vector3.new(15, 4.5, 0) },
		{ Vector3.new(1, 8, 9), Vector3.new(-15, 4.5, -7.5) },
		{ Vector3.new(1, 8, 9), Vector3.new(-15, 4.5, 7.5) },
	} do
		part({ Name = "Wall", Size = w[1], Position = Vector3.new(cx, 0, cz) + w[2], Color = Color3.fromRGB(25, 22, 18), Transparency = 0.2, Parent = m })
		part({ Name = "Rope", Size = Vector3.new(w[1].X + 0.2, 0.4, w[1].Z + 0.2), Position = Vector3.new(cx, 8.7, cz) + Vector3.new(w[2].X, 0, w[2].Z), Material = M.Neon, Color = Color3.fromRGB(255, 200, 70), CanCollide = false, Parent = m })
	end
	-- turned so its front faces out of the lounge: leaving puts you just outside it
	local door = part({
		Name = "VIPDoor", Size = Vector3.new(6, 8, 1), CFrame = CFrame.new(cx - 15, 4.5, cz) * CFrame.Angles(0, math.rad(90), 0),
		Material = M.Neon, Color = Color3.fromRGB(255, 200, 70), Transparency = 0.3, Parent = m,
	})
	local dg = surfaceGui(door, Enum.NormalId.Front, 30)
	label(dg, "Label", "VIP", { Size = UDim2.fromScale(1, 0.25), TextColor3 = Color3.fromRGB(40, 25, 5) })
	part({ Name = "VIPLoungeSpawn", Size = Vector3.new(2, 1, 2), Position = Vector3.new(cx + 4, 1.5, cz), Transparency = 1, CanCollide = false, Parent = m })
	part({ Name = "VIPLoungeExit", Size = Vector3.new(2, 4, 2), Position = Vector3.new(cx - 12, 2.5, cz), Transparency = 1, CanCollide = false, Parent = m })
	-- a couch and a neon sign so it reads as the good spot from across the lot
	part({ Name = "Couch", Size = Vector3.new(10, 2, 3), Position = Vector3.new(cx + 6, 2, cz + 9), Material = M.Fabric, Color = Color3.fromRGB(120, 30, 40), Parent = m })
	local sign = part({ Name = "Sign", Size = Vector3.new(12, 3, 0.4), Position = Vector3.new(cx, 11, cz - 12), Material = M.Neon, Color = Color3.fromRGB(255, 200, 70), Parent = m })
	local sg = surfaceGui(sign, Enum.NormalId.Back, 20)
	label(sg, "Label", "VIP LOUNGE", { TextColor3 = Color3.fromRGB(40, 25, 5) })
end

function LobbyBuilder.SetupLighting()
	Lighting.ClockTime = 0.5
	Lighting.Brightness = 1.5
	Lighting.Ambient = Color3.fromRGB(115, 115, 128)
	Lighting.OutdoorAmbient = Color3.fromRGB(100, 102, 120)
	Lighting.GlobalShadows = false
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0
	for _, other in Lighting:GetChildren() do
		if other:IsA("Atmosphere") or other:IsA("PostEffect") then
			other:Destroy()
		end
	end
	local atm = Instance.new("Atmosphere")
	atm.Name = "LobbyAtmosphere"
	atm.Density = 0.22
	atm.Color = Color3.fromRGB(25, 28, 38)
	atm.Decay = Color3.fromRGB(15, 16, 24)
	atm.Glare = 0
	atm.Haze = 1.5
	atm.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "LobbyColor"
	cc.Saturation = Config.PSX.Saturation
	cc.Contrast = Config.PSX.Contrast
	cc.Parent = Lighting
end

function LobbyBuilder.Build(): Model
	local existing = workspace:FindFirstChild("Lobby")
	if existing then
		existing:Destroy()
	end
	local lobby = model("Lobby", workspace)
	part({ Name = "Ground", Size = Vector3.new(190, 1, 140), Position = Vector3.new(0, -0.5, 0), Material = M.Asphalt, Color = ASPHALT, Parent = lobby })
	-- parking lines
	for i = -4, 4 do
		part({ Name = "Line", Size = Vector3.new(0.4, 0.05, 10), Position = Vector3.new(i * 9, 0.03, 50), Color = Color3.fromRGB(200, 200, 190), CanCollide = false, Parent = lobby })
	end
	storefront(lobby)
	shopArea(lobby)
	vipLounge(lobby)
	local pads = folder("QueuePads", lobby)
	for i, info in LobbyBuilder.Pads do
		queuePad(pads, info, -39 + (i - 1) * 26)
	end
	local boards = folder("Boards", lobby)
	for i, info in LobbyBuilder.Boards do
		board(boards, info, -39 + (i - 1) * 20)
	end
	for _, pos in { Vector3.new(-50, 0, -20), Vector3.new(50, 0, -20), Vector3.new(-50, 0, 30), Vector3.new(30, 0, 30), Vector3.new(-80, 0, 45), Vector3.new(0, 0, 60) } do
		lamp(lobby, pos)
	end
	car(lobby, Vector3.new(-27, 0, 52), Color3.fromRGB(120, 30, 30), 0)
	car(lobby, Vector3.new(9, 0, 52), Color3.fromRGB(40, 60, 90), 0)
	car(lobby, Vector3.new(-45, 0, 52), Color3.fromRGB(150, 150, 140), 0)
	part({ Name = "Dumpster", Size = Vector3.new(8, 5, 4), Position = Vector3.new(-60, 2.5, -55), Material = M.Metal, Color = Color3.fromRGB(40, 80, 50), Parent = lobby })
	-- spawn in the middle of the lot, facing the storefront
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnPoint"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 0.4, 12)
	spawn.Position = Vector3.new(0, 0.2, 15)
	spawn.Orientation = Vector3.new(0, 0, 0) -- players face north, toward the storefront and pads
	spawn.Material = M.Concrete
	spawn.Color = CONCRETE
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = lobby
	-- keep everyone in the lot
	for _, w in {
		{ Vector3.new(190, 60, 1), Vector3.new(0, 30, -70.5) },
		{ Vector3.new(190, 60, 1), Vector3.new(0, 30, 70.5) },
		{ Vector3.new(1, 60, 140), Vector3.new(-95.5, 30, 0) },
		{ Vector3.new(1, 60, 140), Vector3.new(95.5, 30, 0) },
	} do
		part({ Name = "Boundary", Size = w[1], Position = w[2], Transparency = 1, Parent = lobby })
	end
	LobbyBuilder.SetupLighting()
	return lobby
end

return LobbyBuilder
