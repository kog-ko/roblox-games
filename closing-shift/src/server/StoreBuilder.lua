--!strict
-- Builds Workspace.Store from plain Parts (PSX look: blocky, flat, SmoothPlastic).
-- Runs at server start if no Store exists. You can also bake it in edit mode by running
-- this in the Studio command bar:
--   require(game.ServerScriptService.Server.StoreBuilder).Build()

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local StoreBuilder = {}

-- Layout constants (main room interior is x -30..30, z -20..20; front faces +Z)
local WALL_H = 14
local AISLE_X = { -8, 2, 12, 22 }
local AISLE_Z0, AISLE_Z1 = -11, 7
local SHELF_LEVELS = { 0.8, 2.95, 5.35 } -- top surfaces products sit on
local GLASS_COLOR = Color3.fromRGB(40, 50, 55)

local PALETTE = {
	Color3.fromRGB(150, 60, 55), Color3.fromRGB(60, 95, 140), Color3.fromRGB(170, 150, 70),
	Color3.fromRGB(80, 120, 80), Color3.fromRGB(190, 180, 160), Color3.fromRGB(120, 70, 110),
	Color3.fromRGB(200, 110, 50), Color3.fromRGB(70, 130, 130), Color3.fromRGB(160, 160, 170),
}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
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

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function model(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function label(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.Arcade
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = Color3.fromRGB(20, 20, 20)
	if props then
		for k, v in props do
			(t :: any)[k] = v
		end
	end
	t.Parent = parent
	return t
end

local function surfaceGui(adornee: BasePart, face: Enum.NormalId, ppu: number?): SurfaceGui
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = ppu or 40
	g.LightInfluence = 0.6
	g.Parent = adornee
	return g
end

local function tube(parent: Instance, name: string, pos: Vector3, len: number, tag: string, enabled: boolean): Part
	local t = part({
		Name = name, Size = Vector3.new(0.5, 0.3, len), Position = pos,
		Material = Enum.Material.Neon, Color = Color3.fromRGB(215, 235, 210), CanCollide = false, Parent = parent,
	})
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = 18
	light.Angle = 120
	light.Brightness = 1.3
	light.Color = Color3.fromRGB(215, 240, 210)
	light.Enabled = enabled
	light.Parent = t
	if not enabled then
		t.Material = Enum.Material.SmoothPlastic
		t.Color = Color3.fromRGB(90, 95, 90)
	end
	CollectionService:AddTag(t, tag)
	return t
end

local function buildStructure(store: Instance)
	local s = folder("Structure", store)
	local wallColor = Color3.fromRGB(165, 170, 150)
	part({ Name = "Floor", Size = Vector3.new(62, 1, 42), Position = Vector3.new(0, -0.5, 0), Color = Color3.fromRGB(185, 185, 170), Parent = s })
	-- checker tiles for that cheap linoleum look
	local tiles = folder("FloorTiles", s)
	for ix = 0, 6 do
		for iz = 0, 4 do
			if (ix + iz) % 2 == 0 then
				part({
					Name = "Tile", Size = Vector3.new(8, 0.05, 8), Position = Vector3.new(-28 + ix * 8 + 4, 0.025, -20 + iz * 8 + 4),
					Color = Color3.fromRGB(150, 155, 140), CanCollide = false, Parent = tiles,
				})
			end
		end
	end
	part({ Name = "Ceiling", Size = Vector3.new(62, 1, 42), Position = Vector3.new(0, WALL_H + 0.5, 0), Color = Color3.fromRGB(95, 98, 90), Parent = s })
	part({ Name = "BackWall", Size = Vector3.new(62, WALL_H, 1), Position = Vector3.new(0, WALL_H / 2, -20.5), Color = wallColor, Parent = s })
	part({ Name = "LeftWall", Size = Vector3.new(1, WALL_H, 42), Position = Vector3.new(-30.5, WALL_H / 2, 0), Color = wallColor, Parent = s })
	-- right wall has the doorway into the back room (z -15..-10, 9 high)
	part({ Name = "RightWallA", Size = Vector3.new(1, WALL_H, 5.5), Position = Vector3.new(30.5, WALL_H / 2, -17.75), Color = wallColor, Parent = s })
	part({ Name = "RightWallB", Size = Vector3.new(1, WALL_H, 30.5), Position = Vector3.new(30.5, WALL_H / 2, 5.25), Color = wallColor, Parent = s })
	part({ Name = "RightWallTop", Size = Vector3.new(1, WALL_H - 9, 5), Position = Vector3.new(30.5, 9 + (WALL_H - 9) / 2, -12.5), Color = wallColor, Parent = s })
	-- front wall: sill + big dark windows + top band, gap for the door at x 4..10
	for _, seg in { { -13.5, 35 }, { 20.5, 21 } } do
		local cx, w = seg[1], seg[2]
		part({ Name = "FrontSill", Size = Vector3.new(w, 3, 1), Position = Vector3.new(cx, 1.5, 20.5), Color = wallColor, Parent = s })
		part({
			Name = "FrontWindow", Size = Vector3.new(w, 8, 0.4), Position = Vector3.new(cx, 7, 20.5), Color = GLASS_COLOR,
			Transparency = 0.55, Parent = s,
		})
	end
	part({ Name = "FrontTop", Size = Vector3.new(62, 3, 1), Position = Vector3.new(0, 12.5, 20.5), Color = wallColor, Parent = s })
	for _, x in { 3.7, 10.3 } do
		part({ Name = "DoorPost", Size = Vector3.new(0.6, 11, 1.2), Position = Vector3.new(x, 5.5, 20.5), Color = Color3.fromRGB(60, 60, 60), Parent = s })
	end
end

local function buildFrontDoor(store: Instance)
	local door = model("FrontDoor", store)
	local glass = part({
		Name = "DoorGlass", Size = Vector3.new(6, 11, 0.3), Position = Vector3.new(7, 5.5, 20.5),
		Color = GLASS_COLOR, Transparency = 0.5, Parent = door,
	})
	part({ Name = "PushBar", Size = Vector3.new(4, 0.3, 0.3), Position = Vector3.new(7, 4, 20.2), Color = Color3.fromRGB(150, 150, 150), CanCollide = false, Parent = door })
	local bell = part({ Name = "Chime", Size = Vector3.new(0.6, 0.6, 0.6), Position = Vector3.new(7, 11.4, 19.8), Color = Color3.fromRGB(170, 150, 80), CanCollide = false, Parent = door })
	local sign = part({ Name = "OpenSign", Size = Vector3.new(3, 1, 0.1), Position = Vector3.new(-6, 9, 20.2), Material = Enum.Material.Neon, Color = Color3.fromRGB(200, 60, 50), CanCollide = false, Parent = door })
	label(surfaceGui(sign, Enum.NormalId.Back, 50), "OPEN 24H", { TextColor3 = Color3.fromRGB(255, 220, 210) })
	door.PrimaryPart = glass
	CollectionService:AddTag(bell, "DoorChime")
end

local function buildCounter(store: Instance)
	local c = model("Counter", store)
	local wood = Color3.fromRGB(110, 85, 60)
	part({ Name = "CounterBody", Size = Vector3.new(3, 3.8, 12), Position = Vector3.new(-20, 1.9, 10), Color = wood, Parent = c })
	part({ Name = "CounterTop", Size = Vector3.new(3.4, 0.3, 12.4), Position = Vector3.new(-20, 3.95, 10), Color = Color3.fromRGB(70, 70, 65), Parent = c })
	local reg = model("Register", c)
	part({ Name = "RegisterBase", Size = Vector3.new(2, 1, 2), Position = Vector3.new(-20, 4.6, 12.5), Color = Color3.fromRGB(45, 45, 45), Parent = reg })
	local screen = part({
		Name = "RegisterScreen", Size = Vector3.new(0.2, 1, 1.4), Position = Vector3.new(-20.6, 5.6, 12.5),
		Material = Enum.Material.Neon, Color = Color3.fromRGB(80, 170, 90), Parent = reg,
	})
	label(surfaceGui(screen, Enum.NormalId.Left, 60), "$0.00", { TextColor3 = Color3.fromRGB(10, 40, 10) })
	CollectionService:AddTag(screen, "PoweredNeon")
	part({ Name = "CashDrawer", Size = Vector3.new(1.6, 0.4, 1.6), Position = Vector3.new(-20, 4, 12.5), Color = Color3.fromRGB(30, 30, 30), Parent = reg })
	-- back shelf behind the counter
	part({ Name = "BackShelf", Size = Vector3.new(1.5, 7, 12), Position = Vector3.new(-29.2, 3.5, 10), Color = wood, Parent = c })
	for i = 0, 7 do
		part({
			Name = "Product", Size = Vector3.new(0.8, 0.9, 1), Position = Vector3.new(-28.2, 7.45, 4.8 + i * 1.5),
			Color = PALETTE[(i % #PALETTE) + 1], Parent = c,
		})
	end
	-- floor mat where you spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnPoint"
	spawn.Anchored = true
	spawn.Size = Vector3.new(5, 0.2, 5)
	spawn.Position = Vector3.new(-25, 0.1, 10)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Color = Color3.fromRGB(60, 70, 60)
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = store
end

local function stockShelf(products: Instance, rng: Random, x: number, side: number, y: number)
	local z = AISLE_Z0 + 0.8
	while z < AISLE_Z1 - 0.8 do
		local w = rng:NextNumber(0.8, 1.3)
		local h = rng:NextNumber(0.8, 1.7)
		local color = PALETTE[rng:NextInteger(1, #PALETTE)]
		local size = Vector3.new(rng:NextNumber(0.7, 1.1), h, w)
		local p = part({
			Name = "Product", Size = size, Position = Vector3.new(x + side * 0.85, y + h / 2, z + w / 2),
			Color = color, Parent = products,
		})
		p:SetAttribute("OrigColor", color)
		p:SetAttribute("OrigSize", size)
		z += w + rng:NextNumber(0.2, 0.5)
	end
end

local function buildAisles(store: Instance)
	local aisles = folder("Aisles", store)
	local rng = Random.new(2006)
	local len = AISLE_Z1 - AISLE_Z0
	local midZ = (AISLE_Z0 + AISLE_Z1) / 2
	local shelfColor = Color3.fromRGB(175, 175, 165)
	for i, x in AISLE_X do
		local a = model("Aisle" .. i, aisles)
		a:SetAttribute("AisleNumber", i)
		part({ Name = "Plinth", Size = Vector3.new(3, 0.8, len), Position = Vector3.new(x, 0.4, midZ), Color = Color3.fromRGB(80, 80, 75), Parent = a })
		part({ Name = "Spine", Size = Vector3.new(0.4, 7, len), Position = Vector3.new(x, 4.3, midZ), Color = shelfColor, Parent = a })
		for _, y in { SHELF_LEVELS[2], SHELF_LEVELS[3] } do
			part({ Name = "Shelf", Size = Vector3.new(3, 0.3, len), Position = Vector3.new(x, y - 0.15, midZ), Color = shelfColor, Parent = a })
		end
		local products = folder("Products", a)
		for _, y in SHELF_LEVELS do
			stockShelf(products, rng, x, -1, y)
			stockShelf(products, rng, x, 1, y)
		end
		-- hanging number sign above the aisle, readable from the front and back
		local sign = part({
			Name = "Sign", Size = Vector3.new(3.4, 2.4, 0.3), Position = Vector3.new(x, 11.4, 8.5),
			Color = Color3.fromRGB(230, 225, 200), CanCollide = false, Parent = a,
		})
		part({ Name = "SignWire", Size = Vector3.new(0.1, 2.3, 0.1), Position = Vector3.new(x, 13.8, 8.5), Color = Color3.fromRGB(40, 40, 40), CanCollide = false, Parent = a })
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local g = surfaceGui(sign, face, 40)
			g.Name = "SignGui_" .. face.Name
			label(g, "AISLE", { Size = UDim2.fromScale(1, 0.3), TextColor3 = Color3.fromRGB(60, 60, 60) })
			label(g, tostring(i), {
				Name = "Number", Position = UDim2.fromScale(0, 0.28), Size = UDim2.fromScale(1, 0.72),
				TextColor3 = Color3.fromRGB(150, 40, 35),
			})
		end
	end
end

local function buildCoolers(store: Instance)
	local coolers = folder("Coolers", store)
	local rng = Random.new(1999)
	for i, x in { -20, -11, -2, 7, 16 } do
		local c = model("Cooler" .. i, coolers)
		part({ Name = "Body", Size = Vector3.new(8, 9.5, 3), Position = Vector3.new(x, 4.75, -18.5), Color = Color3.fromRGB(55, 60, 65), Parent = c })
		part({
			Name = "Glass", Size = Vector3.new(7.2, 7.8, 0.2), Position = Vector3.new(x, 4.5, -16.9),
			Color = Color3.fromRGB(150, 190, 200), Transparency = 0.6, Parent = c,
		})
		part({
			Name = "CoolerLight", Size = Vector3.new(7, 0.2, 0.2), Position = Vector3.new(x, 8.5, -17.3),
			Material = Enum.Material.Neon, Color = Color3.fromRGB(190, 225, 235), CanCollide = false, Parent = c,
		})
		CollectionService:AddTag(c:FindFirstChild("CoolerLight") :: Instance, "PoweredNeon")
		for _, y in { 1.2, 3.6, 6.0 } do
			for k = 0, 5 do
				part({
					Name = "Drink", Size = Vector3.new(0.7, 1.4, 0.7), Position = Vector3.new(x - 3 + k * 1.2, y + 0.7, -17.6),
					Color = PALETTE[rng:NextInteger(1, #PALETTE)], CanCollide = false, Parent = c,
				})
			end
		end
	end
end

local function buildLights(store: Instance)
	local lights = folder("Lights", store)
	local n = 0
	for _, x in { -24, -13, -3, 7, 17, 26 } do
		for _, z in { -8, 10 } do
			n += 1
			tube(lights, "Tube" .. n, Vector3.new(x, WALL_H - 0.3, z), 8, "FluorescentTube", true)
		end
	end
end

local function buildOutside(store: Instance)
	local o = folder("Outside", store)
	part({ Name = "Ground", Size = Vector3.new(400, 1, 400), Position = Vector3.new(0, -1.2, 0), Color = Color3.fromRGB(20, 22, 20), Parent = o })
	part({ Name = "Sidewalk", Size = Vector3.new(120, 0.4, 5), Position = Vector3.new(0, -0.3, 23.5), Color = Color3.fromRGB(90, 90, 85), Parent = o })
	part({ Name = "ParkingLot", Size = Vector3.new(120, 0.6, 60), Position = Vector3.new(0, -0.7, 56), Color = Color3.fromRGB(38, 38, 42), Parent = o })
	for i = -3, 3 do
		part({ Name = "Line", Size = Vector3.new(0.4, 0.05, 10), Position = Vector3.new(i * 9, -0.38, 33), Color = Color3.fromRGB(170, 165, 140), CanCollide = false, Parent = o })
	end
	-- one lonely street lamp
	local lamp = model("StreetLamp", o)
	part({ Name = "Pole", Size = Vector3.new(0.8, 16, 0.8), Position = Vector3.new(22, 7.5, 44), Color = Color3.fromRGB(50, 50, 50), Parent = lamp })
	part({ Name = "Arm", Size = Vector3.new(0.5, 0.5, 4.5), Position = Vector3.new(22, 15.3, 42), Color = Color3.fromRGB(50, 50, 50), Parent = lamp })
	local head = part({
		Name = "LampHead", Size = Vector3.new(1.8, 0.6, 1.8), Position = Vector3.new(22, 14.9, 39.9),
		Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 190, 120), CanCollide = false, Parent = lamp,
	})
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Range = 30
	spot.Angle = 90
	spot.Brightness = 3
	spot.Color = Color3.fromRGB(255, 180, 110)
	spot.Parent = head
	CollectionService:AddTag(head, "StreetLamp")
	-- a parked car, because someone is still here
	local car = model("ParkedCar", o)
	part({ Name = "Body", Size = Vector3.new(5.5, 2, 11), Position = Vector3.new(-9, 1, 36), Color = Color3.fromRGB(70, 80, 95), Parent = car })
	part({ Name = "Cabin", Size = Vector3.new(5, 1.8, 5.5), Position = Vector3.new(-9, 2.9, 36.5), Color = Color3.fromRGB(30, 35, 40), Parent = car })
end

local function buildBackRoom(store: Instance)
	local b = model("BackRoom", store)
	local wall = Color3.fromRGB(120, 115, 100)
	part({ Name = "Floor", Size = Vector3.new(18, 1, 18), Position = Vector3.new(39, -0.5, -12), Color = Color3.fromRGB(110, 105, 95), Parent = b })
	part({ Name = "Ceiling", Size = Vector3.new(18, 1, 18), Position = Vector3.new(39, WALL_H + 0.5, -12), Color = Color3.fromRGB(70, 70, 65), Parent = b })
	part({ Name = "BackWall", Size = Vector3.new(18, WALL_H, 1), Position = Vector3.new(39, WALL_H / 2, -20.5), Color = wall, Parent = b })
	part({ Name = "FrontWall", Size = Vector3.new(18, WALL_H, 1), Position = Vector3.new(39, WALL_H / 2, -3.5), Color = wall, Parent = b })
	part({ Name = "SideWall", Size = Vector3.new(1, WALL_H, 18), Position = Vector3.new(47.5, WALL_H / 2, -12), Color = wall, Parent = b })
	-- door hangs open ~70 degrees into the back room (hinge at z = -10)
	local a = math.rad(70)
	local hinge = Vector3.new(30.8, 4.5, -10)
	local dir = Vector3.new(math.sin(a), 0, -math.cos(a))
	part({
		Name = "Door", Size = Vector3.new(0.3, 9, 5), CFrame = CFrame.new(hinge + dir * 2.5) * CFrame.Angles(0, -a, 0),
		Color = Color3.fromRGB(95, 85, 70), Parent = b,
	})
	local sign = part({
		Name = "EmployeesOnlySign", Size = Vector3.new(0.2, 1.3, 5), Position = Vector3.new(29.9, 10.3, -12.5),
		Color = Color3.fromRGB(235, 230, 215), CanCollide = false, Parent = b,
	})
	label(surfaceGui(sign, Enum.NormalId.Left, 40), "EMPLOYEES ONLY", { TextColor3 = Color3.fromRGB(170, 30, 30) })
	-- manager's desk
	local desk = model("ManagerDesk", b)
	part({ Name = "DeskTop", Size = Vector3.new(3, 0.3, 5), Position = Vector3.new(44.5, 3, -12), Color = Color3.fromRGB(100, 75, 55), Parent = desk })
	for _, off in { Vector3.new(-1.3, 0, -2.3), Vector3.new(1.3, 0, -2.3), Vector3.new(-1.3, 0, 2.3), Vector3.new(1.3, 0, 2.3) } do
		part({ Name = "Leg", Size = Vector3.new(0.3, 2.85, 0.3), Position = Vector3.new(44.5, 1.43, -12) + off, Color = Color3.fromRGB(80, 60, 45), Parent = desk })
	end
	part({ Name = "Chair", Size = Vector3.new(1.8, 2, 1.8), Position = Vector3.new(42, 1, -12), Color = Color3.fromRGB(50, 50, 55), Parent = desk })
	local note = part({
		Name = "Note", Size = Vector3.new(1, 0.05, 1.3), Position = Vector3.new(44, 3.18, -12.3),
		Color = Color3.fromRGB(240, 235, 200), CanCollide = false, Parent = desk,
	})
	note.Orientation = Vector3.new(0, 12, 0)
	local noteText = label(surfaceGui(note, Enum.NormalId.Top, 100), "", { Name = "NoteText", TextColor3 = Color3.fromRGB(30, 30, 60) })
	noteText.Font = Enum.Font.Arcade
	-- photo frame on the wall above the desk
	local frame = part({
		Name = "PhotoFrame", Size = Vector3.new(0.2, 4.6, 3.6), Position = Vector3.new(46.9, 7.2, -12),
		Color = Color3.fromRGB(60, 45, 30), Parent = b,
	})
	local pg = surfaceGui(frame, Enum.NormalId.Left, 60)
	pg.Name = "PhotoGui"
	label(pg, "EMPLOYEE OF THE MONTH", { Size = UDim2.fromScale(1, 0.18), TextColor3 = Color3.fromRGB(230, 200, 120) })
	local img = Instance.new("ImageLabel")
	img.Name = "Photo"
	img.Position = UDim2.fromScale(0.1, 0.2)
	img.Size = UDim2.fromScale(0.8, 0.62)
	img.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	img.BorderSizePixel = 0
	img.Image = ""
	img.Parent = pg
	CollectionService:AddTag(img, "PayoffPhoto")
	label(pg, "", { Name = "PhotoName", Position = UDim2.fromScale(0, 0.84), Size = UDim2.fromScale(1, 0.14), TextColor3 = Color3.fromRGB(230, 230, 220) })
	-- a row of older "employee of the month" frames (the payoff fills them all with your face)
	for i, month in { "JAN", "FEB", "MAR", "APR" } do
		local f = part({
			Name = "OldPhoto" .. i, Size = Vector3.new(2.4, 2.8, 0.2), Position = Vector3.new(33 + i * 2.8, 8, -19.9),
			Color = Color3.fromRGB(60, 45, 30), Parent = b,
		})
		local g = surfaceGui(f, Enum.NormalId.Back, 50)
		label(g, month, { Size = UDim2.fromScale(1, 0.2), TextColor3 = Color3.fromRGB(230, 200, 120) })
		local im = Instance.new("ImageLabel")
		im.Name = "Photo"
		im.Position = UDim2.fromScale(0.1, 0.22)
		im.Size = UDim2.fromScale(0.8, 0.7)
		im.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		im.BorderSizePixel = 0
		im.Parent = g
		CollectionService:AddTag(im, "PayoffPhoto")
	end
	-- mop bucket for flavour
	part({ Name = "Bucket", Size = Vector3.new(1.6, 1.6, 1.6), Position = Vector3.new(33, 0.8, -18.5), Color = Color3.fromRGB(190, 170, 40), Parent = b })
	tube(b, "BackRoomLight", Vector3.new(39, WALL_H - 0.3, -12), 6, "BackRoomLight", false)
	part({ Name = "FinalSpillMarker", Size = Vector3.new(1, 0.1, 1), Position = Vector3.new(37.5, 0.05, -12), Transparency = 1, CanCollide = false, CanQuery = false, Parent = b })
end

local function buildSpillMarkers(store: Instance)
	local m = folder("SpillMarkers", store)
	local points = {}
	for _, x in { -13, -3, 7, 17, 26.5 } do
		for _, z in { -8, -2, 4 } do
			table.insert(points, Vector3.new(x, 0.05, z))
		end
	end
	for _, x in { -10, 0, 10, 20 } do
		table.insert(points, Vector3.new(x, 0.05, 13))
		table.insert(points, Vector3.new(x + 3, 0.05, -14))
	end
	for i, p in points do
		part({ Name = "Marker" .. i, Size = Vector3.new(1, 0.1, 1), Position = p, Transparency = 1, CanCollide = false, CanQuery = false, Parent = m })
	end
end

local function buildLeaderboard(store: Instance)
	local lb = model("Leaderboard", store)
	local board = part({
		Name = "Board", Size = Vector3.new(0.4, 7, 9), Position = Vector3.new(-29.8, 7, -3),
		Color = Color3.fromRGB(30, 35, 30), Parent = lb,
	})
	local g = surfaceGui(board, Enum.NormalId.Right, 30)
	g.Name = "BoardGui"
	g.LightInfluence = 0
	label(g, "FASTEST SHIFTS", { Size = UDim2.fromScale(1, 0.14), TextColor3 = Color3.fromRGB(220, 210, 140) })
	local list = label(g, "loading...", {
		Name = "List", Position = UDim2.fromScale(0.05, 0.16), Size = UDim2.fromScale(0.9, 0.82),
		TextColor3 = Color3.fromRGB(190, 220, 190), TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, TextScaled = false, TextSize = 18,
	})
	list.TextWrapped = false
end

function StoreBuilder.SetupLighting()
	Lighting.ClockTime = 1
	Lighting.Brightness = 0.4
	Lighting.Ambient = Color3.fromRGB(45, 48, 45)
	Lighting.OutdoorAmbient = Color3.fromRGB(20, 22, 25)
	Lighting.GlobalShadows = false
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0
	for _, name in { "PSX_Atmosphere", "PSX_ColorCorrection" } do
		local old = Lighting:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local atm = Instance.new("Atmosphere")
	atm.Name = "PSX_Atmosphere"
	atm.Density = 0.45
	atm.Offset = 0
	atm.Color = Color3.fromRGB(18, 22, 20)
	atm.Decay = Color3.fromRGB(8, 10, 10)
	atm.Glare = 0
	atm.Haze = 2.5
	atm.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "PSX_ColorCorrection"
	cc.Saturation = -0.35
	cc.Contrast = 0.25
	cc.TintColor = Color3.fromRGB(225, 245, 225)
	cc.Parent = Lighting
end

function StoreBuilder.Build(): Model
	local existing = workspace:FindFirstChild("Store")
	if existing then
		existing:Destroy()
	end
	local store = Instance.new("Model")
	store.Name = "Store"
	buildStructure(store)
	buildFrontDoor(store)
	buildCounter(store)
	buildAisles(store)
	buildCoolers(store)
	buildLights(store)
	buildOutside(store)
	buildBackRoom(store)
	buildSpillMarkers(store)
	buildLeaderboard(store)
	folder("Spills", store)
	folder("EventProps", store)
	store:SetAttribute("Power", true)
	store:SetAttribute("BackRoomLit", false)
	store.Parent = workspace
	StoreBuilder.SetupLighting()
	return store
end

-- Put an aisle's products back the way they were built.
function StoreBuilder.RestockAll(store: Instance)
	for _, p in store:GetDescendants() do
		if p:IsA("BasePart") and p.Name == "Product" then
			local c = p:GetAttribute("OrigColor")
			local s = p:GetAttribute("OrigSize")
			if typeof(c) == "Color3" and typeof(s) == "Vector3" then
				local bottom = p.Position.Y - p.Size.Y / 2
				p.Color = c
				p.Size = s
				p.Position = Vector3.new(p.Position.X, bottom + s.Y / 2, p.Position.Z)
			end
		end
	end
end

return StoreBuilder
