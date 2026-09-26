--!strict
-- Builds Workspace.Store from plain Parts (PSX look: blocky, low-poly, Roblox materials).
-- Runs at server start if no Store exists. You can also bake it in edit mode by running
-- this in the Studio command bar:
--   require(game.ServerScriptService.Server.StoreBuilder).Build()
--
-- Other scripts find things here by name or tag, so keep these when editing:
--   Aisles/AisleN (Plinth, Products/Product, Sign "Number" labels), SpillMarkers, FinalSpillMarker,
--   SpawnPoint, Lights, Spills, EventProps, Leaderboard/List, BackRoom (Note, NoteText, PhotoFrame,
--   PhotoName), Stockroom (StockroomDoor, Freezer/FreezerDoor), tags FluorescentTube, BackRoomLight,
--   StreetLamp, PoweredNeon, DoorChime, PayoffPhoto. Spill markers carry a Zone attribute
--   ("Floor", "Stockroom", "Freezer"); bigger crews open more zones (see Zones.lua).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local StoreBuilder = {}

-- Layout constants (main room interior is x -30..30, z -20..20; front faces +Z)
local WALL_H = 14
local AISLE_X = { -8, 2, 12, 22 }
local AISLE_Z0, AISLE_Z1 = -11, 7
local SHELF_LEVELS = { 0.8, 2.95, 5.35 } -- top surfaces products sit on
local GLASS_COLOR = Color3.fromRGB(40, 50, 55)
local M = Enum.Material

local PALETTE = {
	Color3.fromRGB(150, 60, 55), Color3.fromRGB(60, 95, 140), Color3.fromRGB(170, 150, 70),
	Color3.fromRGB(80, 120, 80), Color3.fromRGB(190, 180, 160), Color3.fromRGB(120, 70, 110),
	Color3.fromRGB(200, 110, 50), Color3.fromRGB(70, 130, 130), Color3.fromRGB(160, 160, 170),
}
local STEEL = Color3.fromRGB(150, 155, 150)
local DARK_STEEL = Color3.fromRGB(70, 72, 70)

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

-- Upright cylinder (Roblox cylinders run along X, so turn them onto Y).
local function cylinder(props: { [string]: any }, pos: Vector3, height: number, diameter: number): Part
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, diameter, diameter)
	props.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	return part(props)
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
	-- metal housing above the tube
	part({ Name = "Fixture", Size = Vector3.new(1.4, 0.15, len + 0.6), Position = pos + Vector3.new(0, 0.2, 0), Material = M.Metal, Color = STEEL, CanCollide = false, Parent = parent })
	local t = part({
		Name = name, Size = Vector3.new(0.5, 0.3, len), Position = pos,
		Material = M.Neon, Color = Color3.fromRGB(215, 235, 210), CanCollide = false, Parent = parent,
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
		t.Material = M.SmoothPlastic
		t.Color = Color3.fromRGB(90, 95, 90)
	end
	CollectionService:AddTag(t, tag)
	return t
end

-- A glowing panel that goes dark with the store's power (LightsFx handles the switching).
local function poweredNeon(props: { [string]: any }, lightColor: Color3?, range: number?): Part
	props.Material = M.Neon
	local p = part(props)
	if lightColor then
		local l = Instance.new("PointLight")
		l.Color = lightColor
		l.Range = range or 8
		l.Brightness = 1.2
		l.Parent = p
	end
	CollectionService:AddTag(p, "PoweredNeon")
	return p
end

local function buildStructure(store: Instance)
	local s = folder("Structure", store)
	local wallColor = Color3.fromRGB(165, 170, 150)
	local function wall(name: string, size: Vector3, pos: Vector3)
		part({ Name = name, Size = size, Position = pos, Material = M.Plaster, Color = wallColor, Parent = s })
	end
	part({ Name = "Floor", Size = Vector3.new(62, 1, 42), Position = Vector3.new(0, -0.5, 0), Material = M.CeramicTiles, Color = Color3.fromRGB(190, 190, 175), Parent = s })
	-- a darker walkway stripe down the front of the store, scuffed by years of night shifts
	part({ Name = "Walkway", Size = Vector3.new(60, 0.04, 5), Position = Vector3.new(0, 0.02, 11.5), Material = M.CeramicTiles, Color = Color3.fromRGB(150, 155, 140), CanCollide = false, Parent = s })
	-- base trim along the walls
	for _, t in { { Vector3.new(62, 0.8, 0.2), Vector3.new(0, 0.4, -19.9) }, { Vector3.new(0.2, 0.8, 40), Vector3.new(-29.9, 0.4, 0) } } do
		part({ Name = "Trim", Size = t[1], Position = t[2], Material = M.Rubber, Color = Color3.fromRGB(40, 42, 40), CanCollide = false, Parent = s })
	end

	part({ Name = "Ceiling", Size = Vector3.new(62, 1, 42), Position = Vector3.new(0, WALL_H + 0.5, 0), Material = M.Plaster, Color = Color3.fromRGB(120, 122, 112), Parent = s })
	-- drop-ceiling grid
	local grid = folder("CeilingGrid", s)
	for x = -28, 28, 4 do
		part({ Name = "GridX", Size = Vector3.new(0.12, 0.1, 42), Position = Vector3.new(x, WALL_H - 0.05, 0), Material = M.Metal, Color = Color3.fromRGB(85, 88, 82), CanCollide = false, Parent = grid })
	end
	for z = -18, 18, 4 do
		part({ Name = "GridZ", Size = Vector3.new(62, 0.1, 0.12), Position = Vector3.new(0, WALL_H - 0.05, z), Material = M.Metal, Color = Color3.fromRGB(85, 88, 82), CanCollide = false, Parent = grid })
	end
	for _, v in { Vector3.new(-14, WALL_H - 0.1, -4), Vector3.new(14, WALL_H - 0.1, 14) } do
		part({ Name = "Vent", Size = Vector3.new(2.6, 0.12, 2.6), Position = v, Material = M.DiamondPlate, Color = Color3.fromRGB(110, 112, 105), CanCollide = false, Parent = grid })
	end

	-- back wall has the doorway into the stockroom (x 22..28, 9 high; see buildStockroom)
	wall("BackWall", Vector3.new(53, WALL_H, 1), Vector3.new(-4.5, WALL_H / 2, -20.5))
	wall("BackWallB", Vector3.new(3, WALL_H, 1), Vector3.new(29.5, WALL_H / 2, -20.5))
	wall("BackWallTop", Vector3.new(6, WALL_H - 9, 1), Vector3.new(25, 9 + (WALL_H - 9) / 2, -20.5))
	-- left wall has the doorway into the restroom hallway (z -15..-11, 9 high)
	wall("LeftWallA", Vector3.new(1, WALL_H, 5.5), Vector3.new(-30.5, WALL_H / 2, -17.75))
	wall("LeftWallB", Vector3.new(1, WALL_H, 31.5), Vector3.new(-30.5, WALL_H / 2, 4.75))
	wall("LeftWallTop", Vector3.new(1, WALL_H - 9, 4), Vector3.new(-30.5, 9 + (WALL_H - 9) / 2, -13))
	-- right wall has the doorway into the back room (z -15..-10, 9 high)
	wall("RightWallA", Vector3.new(1, WALL_H, 5.5), Vector3.new(30.5, WALL_H / 2, -17.75))
	wall("RightWallB", Vector3.new(1, WALL_H, 30.5), Vector3.new(30.5, WALL_H / 2, 5.25))
	wall("RightWallTop", Vector3.new(1, WALL_H - 9, 5), Vector3.new(30.5, 9 + (WALL_H - 9) / 2, -12.5))
	-- front wall: sill + big dark windows + top band, gap for the door at x 4..10
	for _, seg in { { -13.5, 35 }, { 20.5, 21 } } do
		local cx, w = seg[1], seg[2]
		wall("FrontSill", Vector3.new(w, 3, 1), Vector3.new(cx, 1.5, 20.5))
		part({
			Name = "FrontWindow", Size = Vector3.new(w, 8, 0.4), Position = Vector3.new(cx, 7, 20.5), Reflectance = 0.1,
			Color = GLASS_COLOR, Transparency = 0.55, Parent = s,
		})
		-- window mullions
		for x = cx - w / 2 + 5, cx + w / 2 - 1, 6 do
			part({ Name = "Mullion", Size = Vector3.new(0.3, 8, 0.6), Position = Vector3.new(x, 7, 20.5), Material = M.Metal, Color = DARK_STEEL, Parent = s })
		end
	end
	wall("FrontTop", Vector3.new(62, 3, 1), Vector3.new(0, 12.5, 20.5))
	for _, x in { 3.7, 10.3 } do
		part({ Name = "DoorPost", Size = Vector3.new(0.6, 11, 1.2), Position = Vector3.new(x, 5.5, 20.5), Material = M.Metal, Color = Color3.fromRGB(60, 60, 60), Parent = s })
	end
	-- window posters (seen from inside, reversed text is too much work, so they face in)
	for i, t in { { -24, "ICE $2" }, { -2, "LOTTO" }, { 16, "HOT COFFEE" }, { 26, "2 FOR $3" } } do
		local p = part({ Name = "Poster" .. i, Size = Vector3.new(3.2, 2.2, 0.05), Position = Vector3.new(t[1], 6.5, 20.25), Color = Color3.fromRGB(230, 220, 190), CanCollide = false, Parent = s })
		label(surfaceGui(p, Enum.NormalId.Front, 40), t[2], { TextColor3 = if i % 2 == 0 then Color3.fromRGB(170, 40, 35) else Color3.fromRGB(40, 70, 140) })
	end
end

local function buildFrontDoor(store: Instance)
	local door = model("FrontDoor", store)
	local glass = part({
		Name = "DoorGlass", Size = Vector3.new(6, 11, 0.3), Position = Vector3.new(7, 5.5, 20.5), Reflectance = 0.1,
		Color = GLASS_COLOR, Transparency = 0.5, Parent = door,
	})
	part({ Name = "PushBar", Size = Vector3.new(4, 0.3, 0.3), Position = Vector3.new(7, 4, 20.2), Material = M.Metal, Color = Color3.fromRGB(150, 150, 150), CanCollide = false, Parent = door })
	local bell = part({ Name = "Chime", Size = Vector3.new(0.6, 0.6, 0.6), Position = Vector3.new(7, 11.4, 19.8), Material = M.Metal, Color = Color3.fromRGB(170, 150, 80), CanCollide = false, Parent = door })
	local sign = part({ Name = "OpenSign", Size = Vector3.new(3, 1, 0.1), Position = Vector3.new(-6, 9, 20.2), Material = M.Neon, Color = Color3.fromRGB(200, 60, 50), CanCollide = false, Parent = door })
	label(surfaceGui(sign, Enum.NormalId.Back, 50), "OPEN 24H", { TextColor3 = Color3.fromRGB(255, 220, 210) })
	-- EXIT sign runs on its own battery: it stays lit when the power cuts
	local exit = part({ Name = "ExitSign", Size = Vector3.new(2.6, 0.9, 0.3), Position = Vector3.new(7, 12.3, 19.8), Material = M.Neon, Color = Color3.fromRGB(190, 30, 30), CanCollide = false, Parent = door })
	label(surfaceGui(exit, Enum.NormalId.Front, 50), "EXIT", { TextColor3 = Color3.fromRGB(255, 200, 190) })
	local exitGlow = Instance.new("PointLight")
	exitGlow.Color = Color3.fromRGB(255, 60, 50)
	exitGlow.Range = 9
	exitGlow.Brightness = 0.8
	exitGlow.Parent = exit
	-- welcome mat
	local mat = part({ Name = "WelcomeMat", Size = Vector3.new(6, 0.08, 3.5), Position = Vector3.new(7, 0.04, 17.8), Material = M.Carpet, Color = Color3.fromRGB(55, 60, 70), CanCollide = false, Parent = door })
	label(surfaceGui(mat, Enum.NormalId.Top, 20), "WELCOME", { TextColor3 = Color3.fromRGB(150, 150, 140), Rotation = 180 })
	door.PrimaryPart = glass
	CollectionService:AddTag(bell, "DoorChime")
end

local function buildCounter(store: Instance)
	local c = model("Counter", store)
	local wood = Color3.fromRGB(110, 85, 60)
	part({ Name = "CounterBody", Size = Vector3.new(3, 3.8, 12), Position = Vector3.new(-20, 1.9, 10), Material = M.WoodPlanks, Color = wood, Parent = c })
	part({ Name = "CounterTop", Size = Vector3.new(3.4, 0.3, 12.4), Position = Vector3.new(-20, 3.95, 10), Material = M.Slate, Color = Color3.fromRGB(70, 70, 65), Parent = c })
	-- impulse buys on the counter
	local rng = Random.new(77)
	for i = 0, 5 do
		part({ Name = "Candy", Size = Vector3.new(0.5, 0.25, 0.9), Position = Vector3.new(-18.8, 4.25, 5.2 + i * 0.7), Color = PALETTE[rng:NextInteger(1, #PALETTE)], Parent = c })
	end
	part({ Name = "LotteryCase", Size = Vector3.new(1.4, 1.2, 2.6), Position = Vector3.new(-20, 4.7, 8.2), Material = M.Glass, Color = Color3.fromRGB(170, 200, 190), Transparency = 0.5, Parent = c })
	local reg = model("Register", c)
	part({ Name = "RegisterBase", Size = Vector3.new(2, 1, 2), Position = Vector3.new(-20, 4.6, 12.5), Material = M.Metal, Color = Color3.fromRGB(45, 45, 45), Parent = reg })
	local screen = part({
		Name = "RegisterScreen", Size = Vector3.new(0.2, 1, 1.4), Position = Vector3.new(-20.6, 5.6, 12.5),
		Material = M.Neon, Color = Color3.fromRGB(80, 170, 90), Parent = reg,
	})
	label(surfaceGui(screen, Enum.NormalId.Left, 60), "$0.00", { TextColor3 = Color3.fromRGB(10, 40, 10) })
	CollectionService:AddTag(screen, "PoweredNeon")
	part({ Name = "CashDrawer", Size = Vector3.new(1.6, 0.4, 1.6), Position = Vector3.new(-20, 4, 12.5), Material = M.Metal, Color = Color3.fromRGB(30, 30, 30), Parent = reg })
	-- back shelf behind the counter: unlabeled packs and bottles
	part({ Name = "BackShelf", Size = Vector3.new(1.5, 7, 12), Position = Vector3.new(-29.2, 3.5, 10), Material = M.WoodPlanks, Color = wood, Parent = c })
	for row = 0, 2 do
		for i = 0, 9 do
			part({
				Name = "Pack", Size = Vector3.new(0.5, 0.7, 0.9), Position = Vector3.new(-28.2, 2.3 + row * 1.8, 5 + i * 1.1),
				Color = PALETTE[((i + row * 3) % #PALETTE) + 1], Parent = c,
			})
		end
	end
	for i = 0, 7 do
		cylinder({ Name = "Bottle", Material = M.Glass, Color = PALETTE[(i % #PALETTE) + 1], Transparency = 0.2, Parent = c }, Vector3.new(-28.3, 7.7, 4.8 + i * 1.5), 1.1, 0.5)
	end
	-- security monitors above the back shelf (they die with the power)
	for i, z in { 8, 12 } do
		part({ Name = "MonitorCase", Size = Vector3.new(1, 2, 2.6), Position = Vector3.new(-29.4, 9.3, z), Material = M.Metal, Color = Color3.fromRGB(35, 35, 35), Parent = c })
		local scr = poweredNeon({ Name = "MonitorScreen", Size = Vector3.new(0.1, 1.6, 2.2), Position = Vector3.new(-28.85, 9.3, z), Color = Color3.fromRGB(60, 90, 80), Parent = c })
		local g = surfaceGui(scr, Enum.NormalId.Right, 60)
		label(g, "CAM 0" .. i, { Size = UDim2.fromScale(0.6, 0.25), TextColor3 = Color3.fromRGB(200, 230, 200) })
		label(g, "REC", { Position = UDim2.fromScale(0.65, 0), Size = UDim2.fromScale(0.35, 0.25), TextColor3 = Color3.fromRGB(230, 60, 50) })
	end
	-- floor mat where you spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnPoint"
	spawn.Anchored = true
	spawn.Size = Vector3.new(5, 0.2, 5)
	spawn.Position = Vector3.new(-25, 0.1, 10)
	spawn.Material = M.Rubber
	spawn.Color = Color3.fromRGB(45, 50, 45)
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = store
end

-- Products: a mix of boxes (with a label band), cans, bottles and chip bags. Each remembers how it was
-- built so events can swap it for a plain box and Restock can put it back.
local function remember(p: BasePart)
	p:SetAttribute("OrigColor", p.Color)
	p:SetAttribute("OrigSize", p.Size)
	p:SetAttribute("OrigCFrame", p.CFrame)
	p:SetAttribute("OrigShape", (p :: Part).Shape.Name)
	p:SetAttribute("OrigMaterial", p.Material.Name)
end

local function detail(props: { [string]: any }): Part
	props.Name = "ProductDetail"
	props.CanCollide = false
	return part(props)
end

local function stockShelf(products: Instance, rng: Random, x: number, side: number, y: number)
	local z = AISLE_Z0 + 0.8
	local kind = rng:NextInteger(1, 4) -- runs of the same kind read as real merchandising
	local run = 0
	while z < AISLE_Z1 - 0.8 do
		if run <= 0 then
			kind = rng:NextInteger(1, 4)
			run = rng:NextInteger(3, 7)
		end
		run -= 1
		local color = PALETTE[rng:NextInteger(1, #PALETTE)]
		local px = x + side * 0.85
		local w: number
		if kind == 1 then -- cereal-style box with a pale label band
			w = rng:NextNumber(0.9, 1.3)
			local h = rng:NextNumber(1.2, 1.8)
			local p = part({ Name = "Product", Size = Vector3.new(0.5, h, w), Position = Vector3.new(px, y + h / 2, z + w / 2), Material = M.Cardboard, Color = color, Parent = products })
			remember(p)
			detail({ Size = Vector3.new(0.52, h * 0.25, w * 0.9), Position = Vector3.new(px, y + h * 0.6, z + w / 2), Color = Color3.fromRGB(225, 220, 200), Parent = products })
		elseif kind == 2 then -- cans
			w = 0.6
			local p = cylinder({ Name = "Product", Material = M.Foil, Color = color, Parent = products }, Vector3.new(px, y + 0.45, z + 0.3), 0.9, 0.55)
			remember(p)
		elseif kind == 3 then -- bottles with a neck and cap
			w = 0.6
			local p = cylinder({ Name = "Product", Material = M.Glass, Color = color, Transparency = 0.15, Parent = products }, Vector3.new(px, y + 0.6, z + 0.3), 1.2, 0.5)
			remember(p)
			local neck = cylinder({ Color = color, Material = M.Glass, Transparency = 0.15, Parent = products }, Vector3.new(px, y + 1.4, z + 0.3), 0.4, 0.22)
			neck.Name = "ProductDetail"
			neck.CanCollide = false
		else -- puffy chip bag
			w = rng:NextNumber(0.9, 1.2)
			local h = rng:NextNumber(1.1, 1.4)
			local p = part({ Name = "Product", Size = Vector3.new(0.6, h, w), CFrame = CFrame.new(px, y + h / 2, z + w / 2) * CFrame.Angles(0, 0, math.rad(side * -8)), Material = M.Foil, Color = color, Parent = products })
			remember(p)
		end
		z += w + rng:NextNumber(0.1, 0.35)
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
		part({ Name = "Plinth", Size = Vector3.new(3, 0.8, len), Position = Vector3.new(x, 0.4, midZ), Material = M.DiamondPlate, Color = Color3.fromRGB(80, 80, 75), Parent = a })
		part({ Name = "Spine", Size = Vector3.new(0.4, 7, len), Position = Vector3.new(x, 4.3, midZ), Material = M.Metal, Color = shelfColor, Parent = a })
		for _, y in { SHELF_LEVELS[2], SHELF_LEVELS[3] } do
			part({ Name = "Shelf", Size = Vector3.new(3, 0.3, len), Position = Vector3.new(x, y - 0.15, midZ), Material = M.Metal, Color = shelfColor, Parent = a })
		end
		-- white price strips along the shelf edges
		for _, y in SHELF_LEVELS do
			for _, side in { -1, 1 } do
				part({ Name = "PriceStrip", Size = Vector3.new(0.05, 0.25, len), Position = Vector3.new(x + side * 1.52, y - 0.2, midZ), Color = Color3.fromRGB(225, 225, 215), CanCollide = false, Parent = a })
			end
		end
		-- end posts
		for _, z in { AISLE_Z0, AISLE_Z1 } do
			part({ Name = "EndPost", Size = Vector3.new(3.1, 7.6, 0.25), Position = Vector3.new(x, 3.8, z), Material = M.Metal, Color = shelfColor, Parent = a })
		end
		local products = folder("Products", a)
		for _, y in SHELF_LEVELS do
			stockShelf(products, rng, x, -1, y)
			stockShelf(products, rng, x, 1, y)
		end
		-- SALE endcap: a little pyramid of cases at the front end of the aisle
		for row = 0, 2 do
			for k = 0, 2 - row do
				part({
					Name = "Case", Size = Vector3.new(0.9, 0.8, 0.9),
					Position = Vector3.new(x - (2 - row) * 0.5 + k * 1.0, 0.4 + row * 0.8, AISLE_Z1 + 0.8), Material = M.Cardboard,
					Color = PALETTE[((i + row + k) % #PALETTE) + 1], Parent = a,
				})
			end
		end
		local sale = part({ Name = "SaleSign", Size = Vector3.new(2.4, 0.9, 0.1), Position = Vector3.new(x, 3.1, AISLE_Z1 + 0.4), Color = Color3.fromRGB(230, 60, 45), CanCollide = false, Parent = a })
		label(surfaceGui(sale, Enum.NormalId.Back, 40), "SALE", { TextColor3 = Color3.fromRGB(255, 240, 200) })
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
		-- hollow cabinet so the drinks show through the glass ("Body" is the back panel)
		local shell = Color3.fromRGB(55, 60, 65)
		part({ Name = "Body", Size = Vector3.new(8, 9.5, 0.5), Position = Vector3.new(x, 4.75, -19.75), Material = M.Metal, Color = shell, Parent = c })
		for _, dx in { -3.8, 3.8 } do
			part({ Name = "Side", Size = Vector3.new(0.4, 9.5, 3), Position = Vector3.new(x + dx, 4.75, -18.5), Material = M.Metal, Color = shell, Parent = c })
		end
		part({ Name = "Top", Size = Vector3.new(8, 0.9, 3), Position = Vector3.new(x, 9.05, -18.5), Material = M.Metal, Color = shell, Parent = c })
		part({ Name = "Bottom", Size = Vector3.new(8, 0.6, 3), Position = Vector3.new(x, 0.3, -18.5), Material = M.Metal, Color = shell, Parent = c })
		part({ Name = "Liner", Size = Vector3.new(7.2, 8, 0.1), Position = Vector3.new(x, 4.6, -19.45), Color = Color3.fromRGB(200, 215, 220), Parent = c })
		for _, y in { 1.15, 3.55, 5.95 } do
			part({ Name = "WireShelf", Size = Vector3.new(7.2, 0.1, 2.4), Position = Vector3.new(x, y, -18.4), Material = M.Metal, Color = Color3.fromRGB(170, 175, 170), Parent = c })
		end
		part({
			Name = "Glass", Size = Vector3.new(7.2, 7.8, 0.2), Position = Vector3.new(x, 4.5, -16.9), Reflectance = 0.15,
			Color = Color3.fromRGB(150, 190, 200), Transparency = 0.72, Parent = c,
		})
		-- two doors per cooler: centre mullion + handles
		part({ Name = "Mullion", Size = Vector3.new(0.3, 7.8, 0.3), Position = Vector3.new(x, 4.5, -16.8), Material = M.Metal, Color = STEEL, Parent = c })
		for _, dx in { -0.6, 0.6 } do
			part({ Name = "Handle", Size = Vector3.new(0.15, 2.4, 0.2), Position = Vector3.new(x + dx, 4.6, -16.6), Material = M.Metal, Color = Color3.fromRGB(200, 200, 195), CanCollide = false, Parent = c })
		end
		part({
			Name = "CoolerLight", Size = Vector3.new(7, 0.2, 0.2), Position = Vector3.new(x, 8.5, -17.3),
			Material = M.Neon, Color = Color3.fromRGB(190, 225, 235), CanCollide = false, Parent = c,
		})
		CollectionService:AddTag(c:FindFirstChild("CoolerLight") :: Instance, "PoweredNeon")
		local header = poweredNeon({ Name = "Header", Size = Vector3.new(7.8, 0.9, 0.2), Position = Vector3.new(x, 9.2, -16.95), Color = Color3.fromRGB(70, 140, 190), CanCollide = false, Parent = c })
		label(surfaceGui(header, Enum.NormalId.Back, 40), if i % 2 == 0 then "COLD DRINKS" else "ICE COLD", { TextColor3 = Color3.fromRGB(235, 245, 255) })
		for _, y in { 1.2, 3.6, 6.0 } do
			for k = 0, 5 do
				local color = PALETTE[rng:NextInteger(1, #PALETTE)]
				if (k + i) % 3 == 0 then
					cylinder({ Name = "Drink", Material = M.Foil, Color = color, CanCollide = false, Parent = c }, Vector3.new(x - 3 + k * 1.2, y + 0.55, -17.6), 1.1, 0.6)
				else
					cylinder({ Name = "Drink", Material = M.Glass, Color = color, Transparency = 0.2, CanCollide = false, Parent = c }, Vector3.new(x - 3 + k * 1.2, y + 0.75, -17.6), 1.5, 0.6)
				end
			end
		end
	end
end

-- Hot food wall: hot dog roller under a heat lamp, coffee machine, slushie machine.
local function buildHotFood(store: Instance)
	local h = model("HotFood", store)
	local X = 28.8
	part({ Name = "StationBase", Size = Vector3.new(2.6, 3.6, 10.5), Position = Vector3.new(X, 1.8, 14), Material = M.Metal, Color = STEEL, Parent = h })
	part({ Name = "StationTop", Size = Vector3.new(2.8, 0.2, 10.7), Position = Vector3.new(X, 3.7, 14), Material = M.Slate, Color = Color3.fromRGB(60, 60, 58), Parent = h })
	-- hot dog roller
	part({ Name = "Roller", Size = Vector3.new(2, 0.4, 2.6), Position = Vector3.new(X, 4, 10.4), Material = M.Metal, Color = Color3.fromRGB(120, 120, 115), Parent = h })
	for k = 0, 4 do
		local dog = part({ Name = "HotDog", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.8, 0.28, 0.28), CFrame = CFrame.new(X, 4.35, 9.5 + k * 0.45) , Color = Color3.fromRGB(160, 70, 50), Parent = h })
		dog.CanCollide = false
	end
	poweredNeon({ Name = "HeatLamp", Size = Vector3.new(2.2, 0.25, 2.8), Position = Vector3.new(X, 6.2, 10.4), Color = Color3.fromRGB(255, 120, 40), CanCollide = false, Parent = h }, Color3.fromRGB(255, 110, 40), 7)
	part({ Name = "LampPost", Size = Vector3.new(0.15, 2, 0.15), Position = Vector3.new(X + 0.9, 5.1, 10.4), Material = M.Metal, Color = STEEL, CanCollide = false, Parent = h })
	-- coffee machine with two pots
	part({ Name = "CoffeeMachine", Size = Vector3.new(1.8, 3, 2.4), Position = Vector3.new(X + 0.3, 5.3, 14), Material = M.Metal, Color = Color3.fromRGB(40, 40, 42), Parent = h })
	for k, z in { 13.4, 14.6 } do
		cylinder({ Name = "Pot", Material = M.Glass, Color = Color3.fromRGB(60, 40, 25), Transparency = 0.25, Parent = h }, Vector3.new(X - 0.6, 4.3, z), 1, 0.7)
		poweredNeon({ Name = "PotLight", Size = Vector3.new(0.1, 0.15, 0.15), Position = Vector3.new(X - 0.62, 6.2, z), Color = if k == 1 then Color3.fromRGB(230, 60, 40) else Color3.fromRGB(60, 220, 80), CanCollide = false, Parent = h })
	end
	for k = 0, 3 do
		cylinder({ Name = "Cups", Color = Color3.fromRGB(235, 235, 225), Parent = h }, Vector3.new(X - 0.5, 4.3 + k * 0.01, 16.2), 1 + k * 0.1, 0.45)
	end
	-- slushie machine: two glowing tanks
	part({ Name = "SlushieBase", Size = Vector3.new(2, 1, 3), Position = Vector3.new(X, 4.3, 18.2), Material = M.Metal, Color = Color3.fromRGB(200, 200, 205), Parent = h })
	for k, col in { Color3.fromRGB(60, 140, 230), Color3.fromRGB(220, 50, 60) } do
		local z = 17.5 + (k - 1) * 1.4
		cylinder({ Name = "Tank", Material = M.Glass, Color = Color3.fromRGB(200, 220, 230), Transparency = 0.6, Parent = h }, Vector3.new(X, 5.9, z), 2.2, 1.2)
		local slush = poweredNeon({ Name = "Slush", Size = Vector3.new(1.6, 0.95, 0.95), CFrame = CFrame.new(X, 5.7, z) * CFrame.Angles(0, 0, math.rad(90)), Color = col, CanCollide = false, Parent = h }, col, 6)
		slush.Shape = Enum.PartType.Cylinder
	end
	local sign = part({ Name = "HotFoodSign", Size = Vector3.new(0.2, 1.6, 7), Position = Vector3.new(29.9, 9, 14), Color = Color3.fromRGB(190, 60, 40), Parent = h })
	label(surfaceGui(sign, Enum.NormalId.Left, 40), "HOT FOOD & COFFEE", { TextColor3 = Color3.fromRGB(255, 230, 190) })
end

-- Odds and ends that make it feel like a real store.
local function buildProps(store: Instance)
	local p = model("Props", store)
	-- ATM by the door
	part({ Name = "ATM", Size = Vector3.new(2.2, 5.5, 1.6), Position = Vector3.new(1.2, 2.75, 19.2), Material = M.Metal, Color = Color3.fromRGB(60, 65, 75), Parent = p })
	local atm = poweredNeon({ Name = "ATMScreen", Size = Vector3.new(1.4, 1, 0.1), Position = Vector3.new(1.2, 4.2, 18.37), Color = Color3.fromRGB(60, 120, 200), Parent = p })
	label(surfaceGui(atm, Enum.NormalId.Front, 60), "INSERT CARD", { TextColor3 = Color3.fromRGB(230, 240, 255) })
	-- magazine rack under the left windows
	part({ Name = "MagRack", Size = Vector3.new(7, 3.4, 1.2), Position = Vector3.new(-10, 1.7, 19.3), Material = M.Metal, Color = DARK_STEEL, Parent = p })
	local rng = Random.new(5)
	for i = 0, 9 do
		local mag = part({ Name = "Magazine", Size = Vector3.new(0.6, 0.9, 0.05), CFrame = CFrame.new(-13 + i * 0.66, 2.5 + (i % 2) * 0.9, 18.65) * CFrame.Angles(math.rad(-15), 0, 0), Color = PALETTE[rng:NextInteger(1, #PALETTE)], CanCollide = false, Parent = p })
		mag.Material = M.SmoothPlastic
	end
	-- wet floor signs (someone always forgets one)
	for i, v in { Vector3.new(-6, 0, 16.8), Vector3.new(-27, 0, -12) } do
		local s = model("WetFloorSign" .. i, p)
		for _, side in { -1, 1 } do
			local leaf = part({ Name = "Leaf", Size = Vector3.new(1.3, 2.4, 0.08), CFrame = CFrame.new(v + Vector3.new(0, 1.15, side * 0.28)) * CFrame.Angles(math.rad(side * 13), math.rad(20 * i), 0), Material = M.Plastic, Color = Color3.fromRGB(235, 200, 40), Parent = s })
			label(surfaceGui(leaf, if side > 0 then Enum.NormalId.Back else Enum.NormalId.Front, 60), "CAUTION\nWET\nFLOOR", { TextColor3 = Color3.fromRGB(30, 30, 30) })
		end
	end
	-- security dome camera
	part({ Name = "DomeCamera", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2), Position = Vector3.new(-18, WALL_H - 0.4, 2), Material = M.Glass, Color = Color3.fromRGB(20, 20, 25), CanCollide = false, Parent = p })
	-- trash can by the door
	cylinder({ Name = "TrashCan", Material = M.Metal, Color = Color3.fromRGB(70, 75, 70), Parent = p }, Vector3.new(12, 1.3, 18.8), 2.6, 1.6)
end

-- Restroom hallway off the left wall: somewhere dark to send you for a spill.
local function buildHallway(store: Instance)
	local hall = model("RestroomHall", store)
	local H = 10
	local wall = Color3.fromRGB(140, 150, 145)
	part({ Name = "Floor", Size = Vector3.new(15, 1, 8), Position = Vector3.new(-38, -0.5, -13), Material = M.CeramicTiles, Color = Color3.fromRGB(170, 175, 170), Parent = hall })
	part({ Name = "Ceiling", Size = Vector3.new(15, 1, 8), Position = Vector3.new(-38, H + 0.5, -13), Material = M.Plaster, Color = Color3.fromRGB(100, 102, 98), Parent = hall })
	-- north wall has the doorway into the break room (x -41..-37, 7 high)
	part({ Name = "NorthWallA", Size = Vector3.new(4.5, H, 1), Position = Vector3.new(-43.25, H / 2, -8.5), Material = M.Plaster, Color = wall, Parent = hall })
	part({ Name = "NorthWallB", Size = Vector3.new(6.5, H, 1), Position = Vector3.new(-33.75, H / 2, -8.5), Material = M.Plaster, Color = wall, Parent = hall })
	part({ Name = "NorthWallTop", Size = Vector3.new(4, H - 7, 1), Position = Vector3.new(-39, 7 + (H - 7) / 2, -8.5), Material = M.Plaster, Color = wall, Parent = hall })
	part({ Name = "SouthWall", Size = Vector3.new(15, H, 1), Position = Vector3.new(-38, H / 2, -17.5), Material = M.Plaster, Color = wall, Parent = hall })
	part({ Name = "EndWall", Size = Vector3.new(1, H, 8), Position = Vector3.new(-45.5, H / 2, -13), Material = M.Plaster, Color = wall, Parent = hall })
	-- tiled wainscot on both long walls
	part({ Name = "Wainscot", Size = Vector3.new(14, 3.5, 0.1), Position = Vector3.new(-38, 1.75, -16.95), Material = M.CeramicTiles, Color = Color3.fromRGB(120, 150, 150), CanCollide = false, Parent = hall })
	for _, seg in { { -43.25, 4 }, { -34, 6 } } do
		part({ Name = "Wainscot", Size = Vector3.new(seg[2], 3.5, 0.1), Position = Vector3.new(seg[1], 1.75, -9.05), Material = M.CeramicTiles, Color = Color3.fromRGB(120, 150, 150), CanCollide = false, Parent = hall })
	end
	local bsign = part({ Name = "BreakRoomSign", Size = Vector3.new(3.6, 0.8, 0.05), Position = Vector3.new(-39, 7.6, -9.03), Color = Color3.fromRGB(230, 230, 220), CanCollide = false, Parent = hall })
	label(surfaceGui(bsign, Enum.NormalId.Back, 50), "BREAK ROOM", { TextColor3 = Color3.fromRGB(40, 40, 60) })
	-- restroom doors
	for _, d in { { -35, "MEN" }, { -40.5, "WOMEN" } } do
		part({ Name = "Door", Size = Vector3.new(3.2, 7, 0.3), Position = Vector3.new(d[1], 3.5, -16.85), Material = M.Wood, Color = Color3.fromRGB(70, 90, 110), Parent = hall })
		part({ Name = "DoorKnob", Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.3, 0.3), Position = Vector3.new(d[1] + 1.1, 3.4, -16.6), Material = M.Metal, Color = STEEL, CanCollide = false, Parent = hall })
		local sign = part({ Name = "DoorSign", Size = Vector3.new(2.4, 0.6, 0.05), Position = Vector3.new(d[1], 6, -16.67), Color = Color3.fromRGB(230, 230, 220), CanCollide = false, Parent = hall })
		label(surfaceGui(sign, Enum.NormalId.Back, 50), d[2], { TextColor3 = Color3.fromRGB(40, 40, 60) })
	end
	-- janitor closet at the end, door left ajar
	local janitor = part({ Name = "JanitorDoor", Size = Vector3.new(0.3, 7, 3), CFrame = CFrame.new(-44.2, 3.5, -12.2) * CFrame.Angles(0, math.rad(-25), 0), Material = M.Wood, Color = Color3.fromRGB(95, 85, 70), Parent = hall })
	label(surfaceGui(janitor, Enum.NormalId.Right, 40), "JANITOR", { Size = UDim2.fromScale(1, 0.12), TextColor3 = Color3.fromRGB(200, 190, 160) })
	-- water fountain
	part({ Name = "Fountain", Size = Vector3.new(1.6, 1, 1.2), Position = Vector3.new(-33, 3, -9.4), Material = M.Metal, Color = STEEL, Parent = hall })
	-- flickery light and a sign pointing the way
	tube(hall, "HallTube", Vector3.new(-38, H - 0.3, -13), 6, "FluorescentTube", true)
	local arrow = part({ Name = "RestroomSign", Size = Vector3.new(0.2, 1, 4), Position = Vector3.new(-29.9, 10, -13), Color = Color3.fromRGB(230, 230, 220), CanCollide = false, Parent = hall })
	label(surfaceGui(arrow, Enum.NormalId.Right, 40), "< RESTROOMS", { TextColor3 = Color3.fromRGB(40, 40, 60) })
end

-- Break room behind the restroom hallway: your locker (upgrades), the vending machine (shop) and the
-- VIP lounge door. Somewhere to spend your paycheck between shifts.
local function buildBreakRoom(store: Instance)
	local b = model("BreakRoom", store)
	local H = 10
	local wall = Color3.fromRGB(150, 145, 125)
	part({ Name = "Floor", Size = Vector3.new(15, 1, 15), Position = Vector3.new(-38, -0.5, -1), Material = M.CeramicTiles, Color = Color3.fromRGB(160, 150, 130), Parent = b })
	part({ Name = "Ceiling", Size = Vector3.new(15, 1, 15), Position = Vector3.new(-38, H + 0.5, -1), Material = M.Plaster, Color = Color3.fromRGB(105, 100, 92), Parent = b })
	part({ Name = "WestWall", Size = Vector3.new(1, H, 15), Position = Vector3.new(-46, H / 2, -1), Material = M.Plaster, Color = wall, Parent = b })
	part({ Name = "NorthWall", Size = Vector3.new(16, H, 1), Position = Vector3.new(-38, H / 2, 7), Material = M.Plaster, Color = wall, Parent = b })
	part({ Name = "EastWall", Size = Vector3.new(0.5, H, 15), Position = Vector3.new(-31.25, H / 2, -1), Material = M.Plaster, Color = wall, Parent = b })
	-- lockers down the west wall; yours is marked
	for i = 0, 5 do
		local z = -6.5 + i * 1.9
		local mine = i == 2
		local l = part({
			Name = if mine then "MyLocker" else "Locker", Size = Vector3.new(1.3, 7, 1.8), Position = Vector3.new(-44.85, 3.5, z),
			Material = M.Metal, Color = if mine then Color3.fromRGB(90, 120, 150) else Color3.fromRGB(95, 105, 115), Parent = b,
		})
		for v = 0, 2 do
			part({ Name = "Vent", Size = Vector3.new(0.05, 0.08, 1.2), Position = Vector3.new(-44.18, 6.2 - v * 0.25, z), Color = Color3.fromRGB(40, 45, 50), CanCollide = false, Parent = b })
		end
		if mine then
			local plate = part({ Name = "NamePlate", Size = Vector3.new(0.05, 0.6, 1.4), Position = Vector3.new(-44.17, 5.2, z), Color = Color3.fromRGB(235, 225, 170), CanCollide = false, Parent = b })
			label(surfaceGui(plate, Enum.NormalId.Right, 60), "YOUR LOCKER", { TextColor3 = Color3.fromRGB(40, 40, 30) })
		end
	end
	-- table and chairs
	part({ Name = "Table", Size = Vector3.new(4, 0.3, 3), Position = Vector3.new(-37.5, 2.6, -2), Material = M.WoodPlanks, Color = Color3.fromRGB(150, 120, 85), Parent = b })
	part({ Name = "TableLeg", Size = Vector3.new(0.4, 2.5, 0.4), Position = Vector3.new(-37.5, 1.25, -2), Material = M.Metal, Color = DARK_STEEL, Parent = b })
	for _, off in { Vector3.new(-2.6, 0, 0), Vector3.new(2.6, 0, 0), Vector3.new(0, 0, 2.2), Vector3.new(0, 0, -2.2) } do
		part({ Name = "Chair", Size = Vector3.new(1.4, 1.6, 1.4), Position = Vector3.new(-37.5, 0.8, -2) + off, Material = M.Plastic, Color = Color3.fromRGB(170, 70, 50), Parent = b })
	end
	-- counter, microwave, fridge, bulletin board
	part({ Name = "Counter", Size = Vector3.new(5, 3.4, 1.8), Position = Vector3.new(-40, 1.7, 5.6), Material = M.Wood, Color = Color3.fromRGB(120, 95, 70), Parent = b })
	part({ Name = "Microwave", Size = Vector3.new(1.6, 1, 1.1), Position = Vector3.new(-41, 3.9, 5.6), Material = M.Metal, Color = Color3.fromRGB(220, 220, 215), Parent = b })
	poweredNeon({ Name = "MicrowaveClock", Size = Vector3.new(0.4, 0.2, 0.05), Position = Vector3.new(-40.5, 4.1, 5.03), Color = Color3.fromRGB(90, 220, 110), CanCollide = false, Parent = b })
	part({ Name = "Fridge", Size = Vector3.new(2.4, 6.5, 2), Position = Vector3.new(-44.5, 3.25, 5.4), Material = M.Metal, Color = Color3.fromRGB(215, 215, 210), Parent = b })
	local board = part({ Name = "BulletinBoard", Size = Vector3.new(3.5, 2.4, 0.1), Position = Vector3.new(-37, 6.4, 6.45), Material = M.Fabric, Color = Color3.fromRGB(130, 95, 60), CanCollide = false, Parent = b })
	label(surfaceGui(board, Enum.NormalId.Front, 40), "NIGHT CREW\nDO NOT LOOK AWAY\nFROM MANAGEMENT", { TextColor3 = Color3.fromRGB(240, 235, 210) })
	-- vending machine (the shop, Phase 7)
	part({ Name = "VendingMachine", Size = Vector3.new(3, 6.5, 2.2), Position = Vector3.new(-33.2, 3.25, 5.4), Material = M.Metal, Color = Color3.fromRGB(160, 40, 40), Parent = b })
	local vfront = poweredNeon({ Name = "VendingFront", Size = Vector3.new(2.2, 4, 0.1), Position = Vector3.new(-33.4, 3.9, 4.25), Color = Color3.fromRGB(230, 220, 170), CanCollide = false, Parent = b }, Color3.fromRGB(255, 230, 170), 8)
	label(surfaceGui(vfront, Enum.NormalId.Front, 40), "SNACKS\n& MORE", { TextColor3 = Color3.fromRGB(150, 40, 35) })
	-- VIP lounge door (Phase 7)
	part({ Name = "VIPDoor", Size = Vector3.new(3, 7, 0.3), Position = Vector3.new(-36.2, 3.5, 6.4), Material = M.Wood, Color = Color3.fromRGB(60, 45, 30), Parent = b })
	local vip = part({ Name = "VIPSign", Size = Vector3.new(2.8, 0.7, 0.05), Position = Vector3.new(-36.2, 7.6, 6.2), Material = M.Neon, Color = Color3.fromRGB(215, 175, 60), CanCollide = false, Parent = b })
	label(surfaceGui(vip, Enum.NormalId.Front, 50), "STAFF LOUNGE - VIP", { TextColor3 = Color3.fromRGB(40, 30, 10) })
	tube(b, "BreakRoomTube", Vector3.new(-38, H - 0.3, -1), 6, "FluorescentTube", true)

	-- VIP lounge behind the VIP door (VIPs are teleported in; see Monetization.lua)
	local v = model("VIPLounge", b)
	local gold = Color3.fromRGB(215, 175, 60)
	part({ Name = "Floor", Size = Vector3.new(15, 1, 10), Position = Vector3.new(-38, -0.5, 12.5), Material = M.Carpet, Color = Color3.fromRGB(90, 25, 35), Parent = v })
	part({ Name = "Ceiling", Size = Vector3.new(15, 1, 10), Position = Vector3.new(-38, H + 0.5, 12.5), Material = M.Plaster, Color = Color3.fromRGB(60, 40, 40), Parent = v })
	part({ Name = "NorthWall", Size = Vector3.new(16, H, 1), Position = Vector3.new(-38, H / 2, 18), Material = M.WoodPlanks, Color = Color3.fromRGB(80, 50, 35), Parent = v })
	part({ Name = "WestWall", Size = Vector3.new(1, H, 11), Position = Vector3.new(-46, H / 2, 12.5), Material = M.WoodPlanks, Color = Color3.fromRGB(80, 50, 35), Parent = v })
	part({ Name = "EastWall", Size = Vector3.new(0.5, H, 11), Position = Vector3.new(-31.25, H / 2, 12.5), Material = M.WoodPlanks, Color = Color3.fromRGB(80, 50, 35), Parent = v })
	part({ Name = "GoldTrim", Size = Vector3.new(15, 0.3, 0.2), Position = Vector3.new(-38, 3, 17.4), Material = M.Metal, Color = gold, CanCollide = false, Parent = v })
	part({ Name = "Couch", Size = Vector3.new(7, 1.6, 2.4), Position = Vector3.new(-38, 0.8, 16), Material = M.Leather, Color = Color3.fromRGB(40, 25, 20), Parent = v })
	part({ Name = "CouchBack", Size = Vector3.new(7, 2, 0.8), Position = Vector3.new(-38, 2.2, 17), Material = M.Leather, Color = Color3.fromRGB(40, 25, 20), Parent = v })
	part({ Name = "CoffeeTable", Size = Vector3.new(3, 0.3, 1.6), Position = Vector3.new(-38, 1.5, 13), Material = M.Marble, Color = Color3.fromRGB(230, 225, 215), Parent = v })
	local tv = poweredNeon({ Name = "TV", Size = Vector3.new(0.2, 3, 5), Position = Vector3.new(-45.4, 5, 12.5), Color = Color3.fromRGB(60, 90, 140), CanCollide = false, Parent = v }, Color3.fromRGB(120, 150, 220), 12)
	label(surfaceGui(tv, Enum.NormalId.Right, 30), "EMPLOYEE\nOF THE MONTH", { TextColor3 = Color3.fromRGB(255, 225, 150) })
	local lamp = part({ Name = "GoldLamp", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2), Position = Vector3.new(-33, 4, 16.5), Material = M.Neon, Color = Color3.fromRGB(255, 210, 120), CanCollide = false, Parent = v })
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 200, 120)
	glow.Range = 16
	glow.Brightness = 1.2
	glow.Parent = lamp
	part({ Name = "VIPLoungeSpawn", Size = Vector3.new(2, 0.2, 2), Position = Vector3.new(-38, 0.1, 10), Transparency = 1, CanCollide = false, CanQuery = false, Parent = v })
	local exitDoor = part({ Name = "VIPLoungeExit", Size = Vector3.new(3, 7, 0.3), Position = Vector3.new(-36.2, 3.5, 7.6), Material = M.Wood, Color = Color3.fromRGB(60, 45, 30), Parent = v })
	label(surfaceGui(exitDoor, Enum.NormalId.Back, 40), "EXIT", { Size = UDim2.fromScale(1, 0.12), TextColor3 = gold })
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
	part({ Name = "Ground", Size = Vector3.new(400, 1, 400), Position = Vector3.new(0, -1.2, 0), Material = M.Ground, Color = Color3.fromRGB(20, 24, 20), Parent = o })
	part({ Name = "Sidewalk", Size = Vector3.new(120, 0.4, 5), Position = Vector3.new(0, -0.3, 23.5), Material = M.Pavement, Color = Color3.fromRGB(90, 90, 85), Parent = o })
	part({ Name = "Curb", Size = Vector3.new(120, 0.5, 0.4), Position = Vector3.new(0, -0.25, 26), Material = M.Concrete, Color = Color3.fromRGB(150, 150, 140), Parent = o })
	part({ Name = "ParkingLot", Size = Vector3.new(120, 0.6, 60), Position = Vector3.new(0, -0.7, 56), Material = M.Asphalt, Color = Color3.fromRGB(38, 38, 42), Parent = o })
	for i = -3, 3 do
		part({ Name = "Line", Size = Vector3.new(0.4, 0.05, 10), Position = Vector3.new(i * 9, -0.38, 33), Color = Color3.fromRGB(170, 165, 140), CanCollide = false, Parent = o })
	end
	-- road past the lot
	part({ Name = "Road", Size = Vector3.new(400, 0.6, 16), Position = Vector3.new(0, -0.75, 94), Material = M.Asphalt, Color = Color3.fromRGB(30, 30, 33), Parent = o })
	for x = -150, 150, 10 do
		part({ Name = "RoadLine", Size = Vector3.new(4, 0.05, 0.35), Position = Vector3.new(x, -0.43, 94), Color = Color3.fromRGB(200, 170, 60), CanCollide = false, Parent = o })
	end
	-- storefront name sign (flickers like the street lamp)
	local front = part({ Name = "StoreSign", Size = Vector3.new(22, 2.4, 0.3), Position = Vector3.new(-12, 12.5, 21.2), Material = M.Neon, Color = Color3.fromRGB(200, 40, 40), CanCollide = false, Parent = o })
	label(surfaceGui(front, Enum.NormalId.Back, 30), "QUIK STOP", { TextColor3 = Color3.fromRGB(255, 235, 200) })
	CollectionService:AddTag(front, "StreetLamp")
	-- tall pylon sign by the road
	local pylon = model("PylonSign", o)
	part({ Name = "Pole", Size = Vector3.new(1.2, 26, 1.2), Position = Vector3.new(-32, 12.5, 80), Material = M.Metal, Color = DARK_STEEL, Parent = pylon })
	local box = part({ Name = "SignBox", Size = Vector3.new(10, 6, 1.2), Position = Vector3.new(-32, 26, 80), Material = M.Neon, Color = Color3.fromRGB(210, 50, 45), CanCollide = false, Parent = pylon })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local g = surfaceGui(box, face, 20)
		label(g, "QUIK STOP", { Size = UDim2.fromScale(1, 0.6), TextColor3 = Color3.fromRGB(255, 240, 210) })
		label(g, "OPEN 24/7", { Position = UDim2.fromScale(0, 0.6), Size = UDim2.fromScale(1, 0.4), TextColor3 = Color3.fromRGB(255, 220, 120) })
	end
	CollectionService:AddTag(box, "StreetLamp")
	-- gas canopy with two pump islands
	local gas = model("GasStation", o)
	part({ Name = "Canopy", Size = Vector3.new(30, 1.4, 16), Position = Vector3.new(5, 14, 50), Material = M.Metal, Color = Color3.fromRGB(215, 215, 210), Parent = gas })
	part({ Name = "CanopyBand", Size = Vector3.new(30.4, 1, 16.4), Position = Vector3.new(5, 14.2, 50), Material = M.Neon, Color = Color3.fromRGB(190, 40, 40), CanCollide = false, Parent = gas })
	for _, x in { -6, 16 } do
		for _, z in { 44, 56 } do
			part({ Name = "Column", Size = Vector3.new(1, 13.5, 1), Position = Vector3.new(x, 6.5, z), Material = M.Metal, Color = STEEL, Parent = gas })
		end
	end
	for _, x in { 0, 10 } do
		local down = part({ Name = "CanopyLight", Size = Vector3.new(4, 0.2, 4), Position = Vector3.new(x, 13.2, 50), Material = M.Neon, Color = Color3.fromRGB(235, 240, 225), CanCollide = false, Parent = gas })
		local l = Instance.new("SurfaceLight")
		l.Face = Enum.NormalId.Bottom
		l.Range = 20
		l.Angle = 110
		l.Brightness = 1.4
		l.Color = Color3.fromRGB(225, 240, 220)
		l.Parent = down
		part({ Name = "Island", Size = Vector3.new(2.4, 0.6, 8), Position = Vector3.new(x, -0.1, 50), Material = M.Concrete, Color = Color3.fromRGB(150, 150, 140), Parent = gas })
		for _, z in { 47.5, 52.5 } do
			part({ Name = "Pump", Size = Vector3.new(1.8, 5, 1.4), Position = Vector3.new(x, 2.7, z), Material = M.Metal, Color = Color3.fromRGB(200, 200, 195), Parent = gas })
			local scr = part({ Name = "PumpScreen", Size = Vector3.new(1.3, 0.7, 0.1), Position = Vector3.new(x, 4, z - 0.72), Material = M.Neon, Color = Color3.fromRGB(40, 60, 50), CanCollide = false, Parent = gas })
			label(surfaceGui(scr, Enum.NormalId.Front, 60), "$4.19", { TextColor3 = Color3.fromRGB(120, 255, 140) })
		end
	end
	-- one lonely street lamp
	local lamp = model("StreetLamp", o)
	part({ Name = "Pole", Size = Vector3.new(0.8, 16, 0.8), Position = Vector3.new(22, 7.5, 44), Material = M.Metal, Color = Color3.fromRGB(50, 50, 50), Parent = lamp })
	part({ Name = "Arm", Size = Vector3.new(0.5, 0.5, 4.5), Position = Vector3.new(22, 15.3, 42), Material = M.Metal, Color = Color3.fromRGB(50, 50, 50), Parent = lamp })
	local head = part({
		Name = "LampHead", Size = Vector3.new(1.8, 0.6, 1.8), Position = Vector3.new(22, 14.9, 39.9),
		Material = M.Neon, Color = Color3.fromRGB(255, 190, 120), CanCollide = false, Parent = lamp,
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
	part({ Name = "Body", Size = Vector3.new(5.5, 2, 11), Position = Vector3.new(-9, 1, 36), Material = M.Metal, Color = Color3.fromRGB(70, 80, 95), Parent = car })
	part({ Name = "Cabin", Size = Vector3.new(5, 1.8, 5.5), Position = Vector3.new(-9, 2.9, 36.5), Material = M.Glass, Color = Color3.fromRGB(30, 35, 40), Parent = car })
	for _, v in { Vector3.new(-11.8, 0.6, 32.5), Vector3.new(-6.2, 0.6, 32.5), Vector3.new(-11.8, 0.6, 39.5), Vector3.new(-6.2, 0.6, 39.5) } do
		part({ Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 1.6, 1.6), Position = v, Material = M.Rubber, Color = Color3.fromRGB(20, 20, 20), Parent = car })
	end
	-- dumpster round the side and a payphone out front
	part({ Name = "Dumpster", Size = Vector3.new(6, 3.6, 3.5), Position = Vector3.new(38, 1.6, 8), Material = M.CorrodedMetal, Color = Color3.fromRGB(40, 80, 50), Parent = o })
	part({ Name = "DumpsterLid", Size = Vector3.new(6.2, 0.3, 3.7), CFrame = CFrame.new(38, 3.55, 8) * CFrame.Angles(math.rad(-6), 0, 0), Material = M.Plastic, Color = Color3.fromRGB(25, 30, 25), Parent = o })
	part({ Name = "PayphonePole", Size = Vector3.new(0.4, 5, 0.4), Position = Vector3.new(-22, 2.3, 24), Material = M.Metal, Color = DARK_STEEL, Parent = o })
	part({ Name = "Payphone", Size = Vector3.new(1.6, 2.2, 1), Position = Vector3.new(-22, 4.6, 23.6), Material = M.Metal, Color = Color3.fromRGB(150, 150, 150), Parent = o })
end

local function buildBackRoom(store: Instance)
	local b = model("BackRoom", store)
	local wall = Color3.fromRGB(120, 115, 100)
	part({ Name = "Floor", Size = Vector3.new(18, 1, 18), Position = Vector3.new(39, -0.5, -12), Material = M.Concrete, Color = Color3.fromRGB(110, 105, 95), Parent = b })
	part({ Name = "Ceiling", Size = Vector3.new(18, 1, 18), Position = Vector3.new(39, WALL_H + 0.5, -12), Material = M.Concrete, Color = Color3.fromRGB(70, 70, 65), Parent = b })
	part({ Name = "BackWall", Size = Vector3.new(18, WALL_H, 1), Position = Vector3.new(39, WALL_H / 2, -20.5), Material = M.Brick, Color = wall, Parent = b })
	part({ Name = "FrontWall", Size = Vector3.new(18, WALL_H, 1), Position = Vector3.new(39, WALL_H / 2, -3.5), Material = M.Brick, Color = wall, Parent = b })
	part({ Name = "SideWall", Size = Vector3.new(1, WALL_H, 18), Position = Vector3.new(47.5, WALL_H / 2, -12), Material = M.Brick, Color = wall, Parent = b })
	-- door hangs open ~70 degrees into the back room (hinge at z = -10)
	local a = math.rad(70)
	local hinge = Vector3.new(30.8, 4.5, -10)
	local dir = Vector3.new(math.sin(a), 0, -math.cos(a))
	part({
		Name = "Door", Size = Vector3.new(0.3, 9, 5), CFrame = CFrame.new(hinge + dir * 2.5) * CFrame.Angles(0, -a, 0),
		Material = M.Wood, Color = Color3.fromRGB(95, 85, 70), Parent = b,
	})
	local sign = part({
		Name = "EmployeesOnlySign", Size = Vector3.new(0.2, 1.3, 5), Position = Vector3.new(29.9, 10.3, -12.5),
		Color = Color3.fromRGB(235, 230, 215), CanCollide = false, Parent = b,
	})
	label(surfaceGui(sign, Enum.NormalId.Left, 40), "EMPLOYEES ONLY", { TextColor3 = Color3.fromRGB(170, 30, 30) })
	-- manager's desk
	local desk = model("ManagerDesk", b)
	part({ Name = "DeskTop", Size = Vector3.new(3, 0.3, 5), Position = Vector3.new(44.5, 3, -12), Material = M.WoodPlanks, Color = Color3.fromRGB(100, 75, 55), Parent = desk })
	for _, off in { Vector3.new(-1.3, 0, -2.3), Vector3.new(1.3, 0, -2.3), Vector3.new(-1.3, 0, 2.3), Vector3.new(1.3, 0, 2.3) } do
		part({ Name = "Leg", Size = Vector3.new(0.3, 2.85, 0.3), Position = Vector3.new(44.5, 1.43, -12) + off, Material = M.Wood, Color = Color3.fromRGB(80, 60, 45), Parent = desk })
	end
	part({ Name = "Chair", Size = Vector3.new(1.8, 2, 1.8), Position = Vector3.new(42, 1, -12), Material = M.Leather, Color = Color3.fromRGB(50, 50, 55), Parent = desk })
	part({ Name = "DeskLampBase", Size = Vector3.new(0.6, 0.2, 0.6), Position = Vector3.new(45.3, 3.25, -14), Material = M.Metal, Color = DARK_STEEL, Parent = desk })
	part({ Name = "OldMonitor", Size = Vector3.new(1.4, 1.2, 1.4), Position = Vector3.new(45.2, 3.75, -10.2), Material = M.Plastic, Color = Color3.fromRGB(190, 185, 165), Parent = desk })
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
		Material = M.Wood, Color = Color3.fromRGB(60, 45, 30), Parent = b,
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
			Material = M.Wood, Color = Color3.fromRGB(60, 45, 30), Parent = b,
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
	-- stock shelf of boxes in the far corner
	part({ Name = "StockShelf", Size = Vector3.new(2, 8, 5), Position = Vector3.new(46.2, 4, -17.5), Material = M.Metal, Color = DARK_STEEL, Parent = b })
	local rng = Random.new(11)
	for row = 0, 2 do
		for k = 0, 1 do
			part({ Name = "Box", Size = Vector3.new(1.6, rng:NextNumber(1.2, 1.9), 2.1), Position = Vector3.new(46.2, 1 + row * 2.6, -18.6 + k * 2.3), Material = M.Cardboard, Color = Color3.fromRGB(170, 135, 90), Parent = b })
		end
	end
	-- mop bucket for flavour
	part({ Name = "Bucket", Size = Vector3.new(1.6, 1.6, 1.6), Position = Vector3.new(33, 0.8, -18.5), Material = M.Plastic, Color = Color3.fromRGB(190, 170, 40), Parent = b })
	tube(b, "BackRoomLight", Vector3.new(39, WALL_H - 0.3, -12), 6, "BackRoomLight", false)
	part({ Name = "FinalSpillMarker", Size = Vector3.new(1, 0.1, 1), Position = Vector3.new(37.5, 0.05, -12), Transparency = 1, CanCollide = false, CanQuery = false, Parent = b })
end

-- The stockroom behind the store (x -30..30, z -21..-60): tall pallet racks, a loading dock, a
-- forklift, and the walk-in freezer in the west corner. Its roll-up door (back wall, x 22..28) and the
-- freezer door open for bigger crews (Zones.lua); closed, they are solid.
local function buildStockroom(store: Instance)
	local sr = model("Stockroom", store)
	local H = 20
	local brick = Color3.fromRGB(105, 100, 92)
	part({ Name = "Floor", Size = Vector3.new(62, 1, 40), Position = Vector3.new(0, -0.5, -40.5), Material = M.Concrete, Color = Color3.fromRGB(120, 118, 110), Parent = sr })
	part({ Name = "Ceiling", Size = Vector3.new(62, 1, 40), Position = Vector3.new(0, H + 0.5, -40.5), Material = M.Metal, Color = Color3.fromRGB(60, 62, 60), Parent = sr })
	for _, w in {
		{ Vector3.new(62, H, 1), Vector3.new(0, H / 2, -60.5) },
		{ Vector3.new(1, H, 40), Vector3.new(-30.5, H / 2, -40.5) },
		{ Vector3.new(1, H, 40), Vector3.new(30.5, H / 2, -40.5) },
	} do
		part({ Name = "Wall", Size = w[1], Position = w[2], Material = M.Brick, Color = brick, Parent = sr })
	end
	-- the stockroom is taller than the store: brick above the shared back wall
	part({ Name = "UpperWall", Size = Vector3.new(62, H - WALL_H, 1), Position = Vector3.new(0, WALL_H + (H - WALL_H) / 2, -20.5), Material = M.Brick, Color = brick, Parent = sr })
	-- yellow safety lines along the walkways
	for _, x in { -3.5, 3.5, 12.5, 19.5, 25.5 } do
		part({ Name = "SafetyLine", Size = Vector3.new(0.3, 0.03, 30), Position = Vector3.new(x, 0.02, -40), Color = Color3.fromRGB(220, 190, 40), CanCollide = false, Parent = sr })
	end
	-- pallet racks: orange uprights, blue beams, boxes on every level
	local rng = Random.new(77)
	local racks = folder("Racks", sr)
	for _, x in { -6.5, 9, 23 } do
		local r = model("Rack", racks)
		for _, z in { -27, -35, -43, -51 } do
			for _, dx in { -1.4, 1.4 } do
				part({ Name = "Upright", Size = Vector3.new(0.3, 16, 0.3), Position = Vector3.new(x + dx, 8, z), Material = M.Metal, Color = Color3.fromRGB(230, 110, 30), Parent = r })
			end
		end
		for _, y in { 0.4, 5.3, 10.3, 15.3 } do
			part({ Name = "Beam", Size = Vector3.new(3.2, 0.35, 25), Position = Vector3.new(x, y, -39), Material = M.Metal, Color = Color3.fromRGB(40, 80, 170), Parent = r })
			for z = -50, -28, 2.6 do
				if rng:NextNumber() < 0.8 then
					local h = rng:NextNumber(1.6, 3.6)
					part({
						Name = "Box", Size = Vector3.new(rng:NextNumber(2, 2.8), h, 2.2), Position = Vector3.new(x + rng:NextNumber(-0.2, 0.2), y + 0.2 + h / 2, z),
						Material = M.Cardboard, Color = Color3.fromRGB(165 + rng:NextInteger(-15, 15), 130, 85), Parent = r,
					})
				end
			end
		end
	end
	-- loading dock: two roll-up bay doors (shut), bumpers
	for _, x in { -5, 15 } do
		part({ Name = "BayDoor", Size = Vector3.new(10, 12, 0.4), Position = Vector3.new(x, 6, -59.9), Material = M.DiamondPlate, Color = Color3.fromRGB(150, 150, 140), Parent = sr })
		part({ Name = "BayStripe", Size = Vector3.new(10, 0.6, 0.45), Position = Vector3.new(x, 1.2, -59.85), Color = Color3.fromRGB(220, 190, 40), CanCollide = false, Parent = sr })
		for _, dx in { -5.6, 5.6 } do
			part({ Name = "Bumper", Size = Vector3.new(0.8, 1.6, 0.6), Position = Vector3.new(x + dx, 1.2, -59.6), Material = M.Rubber, Color = Color3.fromRGB(25, 25, 25), Parent = sr })
		end
		local sign = part({ Name = "BaySign", Size = Vector3.new(3, 1.2, 0.1), Position = Vector3.new(x, 13.2, -59.9), Color = Color3.fromRGB(230, 225, 210), CanCollide = false, Parent = sr })
		label(surfaceGui(sign, Enum.NormalId.Back, 40), if x < 0 then "BAY 1" else "BAY 2", { TextColor3 = Color3.fromRGB(40, 40, 40) })
	end
	-- forklift, parked badly
	local fk = model("Forklift", sr)
	local fcf = CFrame.new(3, 0, -54) * CFrame.Angles(0, math.rad(35), 0)
	part({ Name = "Chassis", Size = Vector3.new(3.4, 2.2, 5), CFrame = fcf * CFrame.new(0, 1.6, 0), Material = M.Metal, Color = Color3.fromRGB(230, 170, 30), Parent = fk })
	part({ Name = "Cage", Size = Vector3.new(3.2, 3, 0.2), CFrame = fcf * CFrame.new(0, 4.2, 0.8), Material = M.Metal, Color = DARK_STEEL, Parent = fk })
	part({ Name = "Mast", Size = Vector3.new(2.6, 6, 0.4), CFrame = fcf * CFrame.new(0, 3.6, -2.7), Material = M.Metal, Color = DARK_STEEL, Parent = fk })
	for _, dx in { -0.8, 0.8 } do
		part({ Name = "Fork", Size = Vector3.new(0.3, 0.2, 3.2), CFrame = fcf * CFrame.new(dx, 0.3, -4.4), Material = M.Metal, Color = DARK_STEEL, Parent = fk })
	end
	for _, o in { Vector3.new(-1.8, 0.7, 1.6), Vector3.new(1.8, 0.7, 1.6), Vector3.new(-1.8, 0.7, -1.6), Vector3.new(1.8, 0.7, -1.6) } do
		part({ Name = "Wheel", Size = Vector3.new(0.6, 1.4, 1.4), CFrame = fcf * CFrame.new(o), Color = Color3.fromRGB(20, 20, 20), Parent = fk })
	end
	for i = 0, 3 do
		part({ Name = "Pallet", Size = Vector3.new(4, 0.5, 4), Position = Vector3.new(27, 0.25 + i * 0.5, -56), Material = M.WoodPlanks, Color = Color3.fromRGB(150, 115, 75), Parent = sr })
	end
	-- lights: rows of hanging tubes (they go out with the power like the rest)
	for _, x in { -13, 0, 16, 27 } do
		for _, z in { -28, -40, -52 } do
			tube(sr, "StockTube", Vector3.new(x, H - 3, z), 6, "FluorescentTube", true)
		end
	end
	-- roll-up door into the store (back wall, x 22..28)
	local door = part({ Name = "StockroomDoor", Size = Vector3.new(6, 9, 0.4), Position = Vector3.new(25, 4.5, -20.5), Material = M.DiamondPlate, Color = Color3.fromRGB(150, 155, 150), Parent = sr })
	door:SetAttribute("ClosedCFrame", door.CFrame)
	local ds = part({ Name = "StockroomSign", Size = Vector3.new(6, 1.4, 0.1), Position = Vector3.new(25, 10.2, -19.95), Color = Color3.fromRGB(230, 225, 210), CanCollide = false, Parent = sr })
	local dg = surfaceGui(ds, Enum.NormalId.Front, 40)
	label(dg, "STOCKROOM", { Size = UDim2.fromScale(1, 0.6), TextColor3 = Color3.fromRGB(40, 40, 40) })
	label(dg, "CREW OF 2+", { Name = "Sub", Position = UDim2.fromScale(0, 0.6), Size = UDim2.fromScale(1, 0.4), TextColor3 = Color3.fromRGB(170, 40, 35) })

	-- walk-in freezer (x -30..-17, z -40..-59), door on its east side
	local fz = model("Freezer", sr)
	local frost = Color3.fromRGB(200, 225, 235)
	local fw = Color3.fromRGB(185, 200, 205)
	part({ Name = "FreezerFloor", Size = Vector3.new(13, 0.2, 19), Position = Vector3.new(-23.5, 0.1, -49.5), Material = M.Glacier, Color = frost, Parent = fz })
	part({ Name = "FreezerCeiling", Size = Vector3.new(13, 0.6, 19), Position = Vector3.new(-23.5, 10.3, -49.5), Material = M.Metal, Color = fw, Parent = fz })
	part({ Name = "FreezerNorth", Size = Vector3.new(13, 10, 0.6), Position = Vector3.new(-23.5, 5, -40.3), Material = M.Metal, Color = fw, Parent = fz })
	part({ Name = "FreezerEastA", Size = Vector3.new(0.6, 10, 5), Position = Vector3.new(-17.3, 5, -42.5), Material = M.Metal, Color = fw, Parent = fz })
	part({ Name = "FreezerEastB", Size = Vector3.new(0.6, 10, 9), Position = Vector3.new(-17.3, 5, -54.5), Material = M.Metal, Color = fw, Parent = fz })
	part({ Name = "FreezerEastTop", Size = Vector3.new(0.6, 2, 5), Position = Vector3.new(-17.3, 9, -47.5), Material = M.Metal, Color = fw, Parent = fz })
	local fdoor = part({ Name = "FreezerDoor", Size = Vector3.new(0.5, 8, 5), Position = Vector3.new(-17.3, 4, -47.5), Material = M.DiamondPlate, Color = Color3.fromRGB(170, 185, 190), Parent = fz })
	fdoor:SetAttribute("ClosedCFrame", fdoor.CFrame)
	local fsign = part({ Name = "FreezerSign", Size = Vector3.new(0.1, 1.4, 5), Position = Vector3.new(-16.95, 9.1, -47.5), Color = Color3.fromRGB(230, 240, 245), CanCollide = false, Parent = fz })
	local fg = surfaceGui(fsign, Enum.NormalId.Right, 40)
	label(fg, "WALK-IN FREEZER", { Size = UDim2.fromScale(1, 0.6), TextColor3 = Color3.fromRGB(40, 70, 120) })
	label(fg, "CREW OF 3+", { Name = "Sub", Position = UDim2.fromScale(0, 0.6), Size = UDim2.fromScale(1, 0.4), TextColor3 = Color3.fromRGB(170, 40, 35) })
	-- frozen crates, hanging meat, icicles, cold blue light
	for i = 0, 5 do
		part({ Name = "FrozenCrate", Size = Vector3.new(3, 2.4, 2.4), Position = Vector3.new(-28.5, 1.3 + (i % 2) * 2.5, -43 - math.floor(i / 2) * 5), Material = M.Ice, Color = Color3.fromRGB(170, 200, 215), Transparency = 0.1, Parent = fz })
	end
	for i = 0, 3 do
		local x = -24 + (i % 2) * 3
		local z = -46 - i * 3
		part({ Name = "Hook", Size = Vector3.new(0.15, 3, 0.15), Position = Vector3.new(x, 8.6, z), Material = M.Metal, Color = STEEL, CanCollide = false, Parent = fz })
		part({ Name = "Carcass", Size = Vector3.new(1.4, 3.4, 1), Position = Vector3.new(x, 5.6, z), Material = M.Plastic, Color = Color3.fromRGB(150, 70, 70), CanCollide = false, Parent = fz })
	end
	for i = 1, 10 do
		part({ Name = "Icicle", Size = Vector3.new(0.2, rng:NextNumber(0.6, 1.6), 0.2), Position = Vector3.new(-29 + i * 1.2, 9.4, -40.8), Material = M.Ice, Color = frost, CanCollide = false, Parent = fz })
	end
	poweredNeon({ Name = "FreezerLight", Size = Vector3.new(6, 0.2, 0.6), Position = Vector3.new(-23.5, 9.9, -49.5), Color = Color3.fromRGB(150, 200, 255), CanCollide = false, Parent = fz }, Color3.fromRGB(140, 190, 255), 22)
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
	-- restroom hallway
	table.insert(points, Vector3.new(-35, 0.05, -13))
	table.insert(points, Vector3.new(-41, 0.05, -13))
	local zones = {}
	for _ in points do
		table.insert(zones, "Floor")
	end
	-- stockroom walkways and cross aisles
	for _, x in { -13, 0, 16, 27 } do
		for _, z in { -30, -38, -46 } do
			table.insert(points, Vector3.new(x, 0.05, z))
			table.insert(zones, "Stockroom")
		end
	end
	for _, x in { -10, 5, 20 } do
		for _, z in { -24.5, -56 } do
			table.insert(points, Vector3.new(x, 0.05, z))
			table.insert(zones, "Stockroom")
		end
	end
	-- walk-in freezer
	for _, p in { Vector3.new(-24, 0.05, -44), Vector3.new(-24, 0.05, -50), Vector3.new(-21, 0.05, -55), Vector3.new(-27, 0.05, -54) } do
		table.insert(points, p)
		table.insert(zones, "Freezer")
	end
	for i, p in points do
		local mk = part({ Name = "Marker" .. i, Size = Vector3.new(1, 0.1, 1), Position = p, Transparency = 1, CanCollide = false, CanQuery = false, Parent = m })
		mk:SetAttribute("Zone", zones[i])
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

-- Shift board by the spawn: the party picks tonight's night here (ShiftBoard.lua fills it in).
local function buildShiftBoard(store: Instance)
	local m = model("ShiftBoard", store)
	for _, dx in { -2.2, 2.2 } do
		part({ Name = "Leg", Size = Vector3.new(0.25, 6.5, 0.25), Position = Vector3.new(-26 + dx, 3.25, 18.4), Material = M.Metal, Color = DARK_STEEL, Parent = m })
	end
	local board = part({ Name = "Board", Size = Vector3.new(5, 3.6, 0.2), Position = Vector3.new(-26, 4.8, 18.3), Material = M.Fabric, Color = Color3.fromRGB(120, 90, 60), Parent = m })
	local g = surfaceGui(board, Enum.NormalId.Front, 50)
	g.Name = "BoardGui"
	g.LightInfluence = 0.3
	label(g, "SHIFT BOARD", { Name = "Title", Size = UDim2.fromScale(1, 0.2), TextColor3 = Color3.fromRGB(240, 225, 180) })
	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromScale(0.05, 0.22)
	list.Size = UDim2.fromScale(0.9, 0.62)
	list.Parent = g
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.Parent = list
	label(g, "", { Name = "Footer", Position = UDim2.fromScale(0, 0.86), Size = UDim2.fromScale(1, 0.12), TextColor3 = Color3.fromRGB(230, 210, 150) })
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
	-- Only one Atmosphere renders, so drop any other (e.g. the default one in new places),
	-- plus the template's post effects, which fight the PSX grade.
	for _, other in Lighting:GetChildren() do
		if other:IsA("Atmosphere") or other:IsA("BloomEffect") or other:IsA("SunRaysEffect") or other:IsA("DepthOfFieldEffect") then
			other:Destroy()
		end
	end
	local atm = Instance.new("Atmosphere")
	atm.Name = "PSX_Atmosphere"
	atm.Density = Config.PSX.FogDensity
	atm.Offset = 0
	atm.Color = Color3.fromRGB(18, 22, 20)
	atm.Decay = Color3.fromRGB(8, 10, 10)
	atm.Glare = 0
	atm.Haze = Config.PSX.FogHaze
	atm.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "PSX_ColorCorrection"
	cc.Saturation = Config.PSX.Saturation
	cc.Contrast = Config.PSX.Contrast
	cc.TintColor = Config.PSX.Tint
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
	buildHotFood(store)
	buildProps(store)
	buildHallway(store)
	buildBreakRoom(store)
	buildLights(store)
	buildOutside(store)
	buildBackRoom(store)
	buildStockroom(store)
	buildSpillMarkers(store)
	buildLeaderboard(store)
	buildShiftBoard(store)
	folder("Spills", store)
	folder("EventProps", store)
	store:SetAttribute("Power", true)
	store:SetAttribute("BackRoomLit", false)
	store.Parent = workspace
	StoreBuilder.SetupLighting()
	return store
end

-- Turns every product in an aisle into the same plain white box (the IdenticalAisle event).
function StoreBuilder.MakeIdentical(aisle: Instance)
	local color = Color3.fromRGB(205, 205, 195)
	local size = Vector3.new(0.9, 1.3, 1.0)
	for _, p in aisle:GetDescendants() do
		if p:IsA("Part") and p.Name == "Product" then
			local orig = p:GetAttribute("OrigCFrame")
			local base = if typeof(orig) == "CFrame" then orig.Position else p.Position
			local bottom = base.Y - ((p:GetAttribute("OrigSize") or p.Size) :: Vector3).Y / 2
			if p.Shape == Enum.PartType.Cylinder then
				bottom = base.Y - ((p:GetAttribute("OrigSize") or p.Size) :: Vector3).X / 2
			end
			p.Shape = Enum.PartType.Block
			p.Material = M.SmoothPlastic
			p.Transparency = 0
			p.Color = color
			p.Size = size
			p.CFrame = CFrame.new(base.X, bottom + size.Y / 2, base.Z)
		elseif p:IsA("BasePart") and p.Name == "ProductDetail" then
			p.Transparency = 1
		end
	end
end

-- Put every product back the way it was built.
function StoreBuilder.RestockAll(store: Instance)
	for _, p in store:GetDescendants() do
		if p:IsA("Part") and p.Name == "Product" then
			local c, s, cf = p:GetAttribute("OrigColor"), p:GetAttribute("OrigSize"), p:GetAttribute("OrigCFrame")
			local shape, mat = p:GetAttribute("OrigShape"), p:GetAttribute("OrigMaterial")
			if typeof(c) == "Color3" and typeof(s) == "Vector3" and typeof(cf) == "CFrame" then
				p.Shape = (Enum.PartType :: any)[shape] or Enum.PartType.Block
				p.Material = (Enum.Material :: any)[mat] or M.SmoothPlastic
				p.Transparency = if p.Material == M.Glass then 0.15 else 0
				p.Color = c
				p.Size = s
				p.CFrame = cf
			end
		elseif p:IsA("BasePart") and p.Name == "ProductDetail" then
			p.Transparency = if p.Material == M.Glass then 0.15 else 0
		end
	end
end

return StoreBuilder
