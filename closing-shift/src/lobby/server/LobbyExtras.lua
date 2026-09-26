--!strict
-- Everything around the Quik Stop lot that makes the lobby worth hanging out in:
--   Roof Run       obby up dumpsters, pallets, AC units and the fire escape to the store's roof
--   Spill Cleanup  obby over a pool of neon mop water: crates, sliding pallets, a spinning mop,
--                  runaway shopping carts
--   Sign Climb     obby spiralling up the giant roadside sign
--   the street     road, bus stop, and a row of storefronts: arcade, laundromat (coming soon), pawn shop
--   the plaza      trampolines, a mop-bucket fountain, fire barrels and benches
--   neon           floating signs, the Employee of the Week billboard on the roof
--
-- Obby parts are tagged for Obby.lua: ObbyStart / ObbyCheckpoint / ObbyFinish / ObbyKill, each with an
-- Obby attribute ("Roof", "Spill", "Sign"). Moving parts are tagged Mover (Axis, Distance, Period) or
-- Spinner (Period). Trampolines are tagged BouncePad (Power); the client does the bounce.
local CollectionService = game:GetService("CollectionService")

local LobbyExtras = {}

local M = Enum.Material
local STEEL = Color3.fromRGB(70, 72, 70)
local NEON_GREEN = Color3.fromRGB(110, 230, 120)
local NEON_GOLD = Color3.fromRGB(255, 200, 70)

type Helpers = {
	part: ({ [string]: any }) -> Part,
	model: (string, Instance) -> Model,
	folder: (string, Instance) -> Folder,
	label: (Instance, string, string, { [string]: any }?) -> TextLabel,
	surfaceGui: (BasePart, Enum.NormalId, number?) -> SurfaceGui,
	lamp: (Instance, Vector3) -> (),
}

local H: Helpers

local function tag(p: Instance, name: string, obby: string?)
	CollectionService:AddTag(p, name)
	if obby then
		p:SetAttribute("Obby", obby)
	end
end

local function pad(parent: Instance, name: string, pos: Vector3, color: Color3, kind: string, obby: string, size: Vector3?): Part
	local p = H.part({ Name = name, Size = size or Vector3.new(8, 0.5, 8), Position = pos, Material = M.Neon, Color = color, Parent = parent })
	tag(p, kind, obby)
	return p
end

-- a sign on two posts with a big label, facing -Z by default (use yaw to turn it)
local function signpost(parent: Instance, pos: Vector3, text: string, color: Color3, yaw: number?)
	local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	local board = H.part({ Name = "Sign", Size = Vector3.new(10, 3, 0.4), CFrame = cf * CFrame.new(0, 6, 0), Color = Color3.fromRGB(14, 15, 16), Parent = parent })
	for _, dx in { -4.5, 4.5 } do
		H.part({ Name = "Post", Size = Vector3.new(0.4, 6, 0.4), CFrame = cf * CFrame.new(dx, 3, 0), Material = M.Metal, Color = STEEL, Parent = parent })
	end
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		H.label(H.surfaceGui(board, face, 25), "Text", text, { TextColor3 = color })
	end
end

-- Roof Run: from the corner of the lot up the store's west side to the roof ---------------------
local function roofRun(lobby: Instance)
	local m = H.model("RoofRun", lobby)
	pad(m, "Start", Vector3.new(-72, 0.25, -44), NEON_GREEN, "ObbyStart", "Roof")
	signpost(m, Vector3.new(-72, 0, -38), "ROOF RUN  >", NEON_GREEN, 180)
	local steps = {
		{ "Crates", Vector3.new(4, 4, 4), Vector3.new(-73, 2, -53), M.Cardboard, Color3.fromRGB(170, 135, 90) },
		{ "Dumpster", Vector3.new(8, 5, 4), Vector3.new(-66, 2.5, -60), M.Metal, Color3.fromRGB(40, 80, 50) },
		{ "PalletTower", Vector3.new(4, 8, 4), Vector3.new(-58, 4, -66), M.WoodPlanks, Color3.fromRGB(150, 115, 75) },
		{ "ACUnit", Vector3.new(4, 3, 4), Vector3.new(-52.5, 9.5, -73), M.Metal, Color3.fromRGB(170, 175, 170) },
		{ "Pipe", Vector3.new(1, 0.6, 9), Vector3.new(-50.6, 12, -65), M.Metal, Color3.fromRGB(120, 125, 120) },
		{ "Landing1", Vector3.new(3.4, 0.4, 6), Vector3.new(-50.6, 14.4, -56), M.DiamondPlate, STEEL },
		{ "Landing2", Vector3.new(3.4, 0.4, 5), Vector3.new(-50.6, 17.2, -63.5), M.DiamondPlate, STEEL },
		{ "Ledge", Vector3.new(3.4, 0.4, 4), Vector3.new(-50.6, 19.4, -70.5), M.DiamondPlate, STEEL },
	}
	for _, s in steps do
		H.part({ Name = s[1], Size = s[2], Position = s[3], Material = s[4], Color = s[5], Parent = m })
	end
	-- brackets under the AC unit and the fire escape landings, so they read as bolted to the wall
	for _, pos in { Vector3.new(-50.2, 7.8, -73), Vector3.new(-49.4, 13.8, -56), Vector3.new(-49.4, 16.6, -63.5) } do
		H.part({ Name = "Bracket", Size = Vector3.new(2, 0.3, 0.3), Position = pos, Material = M.Metal, Color = STEEL, CanCollide = false, Parent = m })
	end
	local cp = H.part({ Name = "Checkpoint", Size = Vector3.new(3.2, 0.1, 5.6), Position = Vector3.new(-50.6, 14.65, -56), Material = M.Neon, Color = NEON_GOLD, Transparency = 0.5, CanCollide = false, Parent = m })
	tag(cp, "ObbyCheckpoint", "Roof")

	-- the roof: parapet, lawn chairs, antenna, finish pad
	local roof = H.model("Roof", lobby)
	for _, w in {
		{ Vector3.new(96, 1.2, 0.6), Vector3.new(0, 20.6, -81) },
		{ Vector3.new(0.6, 1.2, 22), Vector3.new(48, 20.6, -70) },
	} do
		H.part({ Name = "Parapet", Size = w[1], Position = w[2], Material = M.Concrete, Color = Color3.fromRGB(110, 105, 98), Parent = roof })
	end
	pad(roof, "Finish", Vector3.new(0, 20.25, -70), NEON_GOLD, "ObbyFinish", "Roof")
	for i, x in { -30, -24, -18 } do
		H.part({ Name = "LawnChair", Size = Vector3.new(2.4, 0.6, 5), CFrame = CFrame.new(x, 20.8, -74) * CFrame.Angles(math.rad(-12), 0, 0), Material = M.Fabric, Color = if i % 2 == 0 then Color3.fromRGB(230, 120, 40) else Color3.fromRGB(60, 140, 200), Parent = roof })
	end
	H.part({ Name = "Cooler", Size = Vector3.new(2, 1.6, 1.4), Position = Vector3.new(-21, 20.8, -70.5), Color = Color3.fromRGB(200, 40, 40), Parent = roof })
	H.part({ Name = "Antenna", Size = Vector3.new(0.4, 14, 0.4), Position = Vector3.new(38, 27, -76), Material = M.Metal, Color = STEEL, Parent = roof })
	local blink = H.part({ Name = "AntennaLight", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), Position = Vector3.new(38, 34.4, -76), Material = M.Neon, Color = Color3.fromRGB(255, 50, 40), CanCollide = false, Parent = roof })
	CollectionService:AddTag(blink, "Blinker")
	-- Employee of the Week billboard on the roof, facing the lot (the name is filled in by LobbyBoards)
	local bb = H.part({ Name = "WeeklyBillboard", Size = Vector3.new(40, 12, 1), Position = Vector3.new(0, 30, -79), Color = Color3.fromRGB(15, 15, 18), Parent = roof })
	for _, dx in { -16, 16 } do
		H.part({ Name = "BillboardLeg", Size = Vector3.new(0.8, 10, 0.8), Position = Vector3.new(dx, 25, -79.5), Material = M.Metal, Color = STEEL, Parent = roof })
	end
	local g = H.surfaceGui(bb, Enum.NormalId.Back, 12)
	g.Name = "BillboardGui"
	H.label(g, "Title", "EMPLOYEE OF THE WEEK", { Size = UDim2.fromScale(1, 0.35), TextColor3 = NEON_GOLD })
	H.label(g, "Name", "COULD BE YOU", { Position = UDim2.fromScale(0.05, 0.38), Size = UDim2.fromScale(0.9, 0.44), TextColor3 = Color3.fromRGB(255, 255, 255) })
	H.label(g, "Sub", "MOST SPILLS CLEANED THIS WEEK", { Position = UDim2.fromScale(0, 0.84), Size = UDim2.fromScale(1, 0.14), TextColor3 = Color3.fromRGB(200, 200, 190) })
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Back
	light.Range = 30
	light.Brightness = 1.5
	light.Color = NEON_GOLD
	light.Parent = bb
end

-- Spill Cleanup Course: over a pool of neon mop water (west side) --------------------------------
local function spillCourse(lobby: Instance)
	local m = H.model("SpillCourse", lobby)
	local cx = -135
	-- the pool (touching it sends you back) and a curb around it
	local pool = H.part({ Name = "MopWater", Size = Vector3.new(44, 0.6, 150), Position = Vector3.new(cx, 0.3, -12), Material = M.Neon, Color = Color3.fromRGB(60, 200, 170), Transparency = 0.25, Parent = m })
	tag(pool, "ObbyKill", "Spill")
	for _, w in {
		{ Vector3.new(46, 1.2, 1), Vector3.new(cx, 0.6, -87.5) },
		{ Vector3.new(46, 1.2, 1), Vector3.new(cx, 0.6, 63.5) },
		{ Vector3.new(1, 1.2, 152), Vector3.new(cx - 22.5, 0.6, -12) },
		{ Vector3.new(1, 1.2, 152), Vector3.new(cx + 22.5, 0.6, -12) },
	} do
		H.part({ Name = "Curb", Size = w[1], Position = w[2], Material = M.Concrete, Color = Color3.fromRGB(150, 150, 140), Parent = m })
	end
	pad(m, "Start", Vector3.new(cx, 1.45, -84), NEON_GREEN, "ObbyStart", "Spill", Vector3.new(10, 0.5, 5))
	H.part({ Name = "StartDeck", Size = Vector3.new(12, 1.2, 6), Position = Vector3.new(cx, 0.6, -84), Material = M.Concrete, Color = Color3.fromRGB(150, 150, 140), Parent = m })
	signpost(m, Vector3.new(cx + 16, 0, -92), "SPILL CLEANUP  ^", Color3.fromRGB(60, 220, 190), 0)
	local crate = function(pos: Vector3, size: Vector3?)
		return H.part({ Name = "Crate", Size = size or Vector3.new(5, 3, 5), Position = pos, Material = M.Cardboard, Color = Color3.fromRGB(170, 135, 90), Parent = m })
	end
	-- first stretch: crates
	local z = -76
	for i, dx in { 0, 5, -3, 4, -5, 2 } do
		crate(Vector3.new(cx + dx, 1.5 + (i % 2) * 0.8, z))
		z += 7.5
	end
	-- sliding pallets
	for i = 1, 2 do
		local p = H.part({ Name = "SlidingPallet", Size = Vector3.new(6, 0.8, 5), Position = Vector3.new(cx, 2.6, z), Material = M.WoodPlanks, Color = Color3.fromRGB(150, 115, 75), Parent = m })
		tag(p, "Mover")
		p:SetAttribute("Axis", Vector3.new(1, 0, 0))
		p:SetAttribute("Distance", 12)
		p:SetAttribute("Period", 4 + i)
		z += 8
	end
	-- the island: a spinning mop sweeps the near half, the checkpoint is on the far end
	H.part({ Name = "Island", Size = Vector3.new(14, 3, 15), Position = Vector3.new(cx, 1.5, z + 2.5), Material = M.Concrete, Color = Color3.fromRGB(150, 150, 140), Parent = m })
	local cp = H.part({ Name = "Checkpoint", Size = Vector3.new(4, 0.1, 3.6), Position = Vector3.new(cx, 3.05, z + 8), Material = M.Neon, Color = NEON_GOLD, Transparency = 0.4, CanCollide = false, Parent = m })
	tag(cp, "ObbyCheckpoint", "Spill")
	H.part({ Name = "MopPole", Size = Vector3.new(1, 4, 1), Position = Vector3.new(cx, 5, z - 0.5), Material = M.Metal, Color = STEEL, Parent = m })
	local sweep = H.part({ Name = "MopSweeper", Size = Vector3.new(8, 0.8, 1.2), Position = Vector3.new(cx, 3.9, z - 0.5), Material = M.Neon, Color = Color3.fromRGB(245, 215, 110), CanCollide = false, Parent = m })
	tag(sweep, "Spinner")
	tag(sweep, "ObbyKill", "Spill")
	sweep:SetAttribute("Period", 3.2)
	z += 14
	-- runaway carts: a long walkway with carts rolling across it
	H.part({ Name = "Walkway", Size = Vector3.new(8, 3, 30), Position = Vector3.new(cx, 1.5, z + 12), Material = M.Concrete, Color = Color3.fromRGB(150, 150, 140), Parent = m })
	for i = 1, 3 do
		local cart = H.part({ Name = "Cart", Size = Vector3.new(3, 3, 4), Position = Vector3.new(cx, 4.5, z + 4 + i * 7), Material = M.Metal, Color = Color3.fromRGB(200, 60, 50), CanCollide = false, Parent = m })
		tag(cart, "Mover")
		tag(cart, "ObbyKill", "Spill")
		cart:SetAttribute("Axis", Vector3.new(1, 0, 0))
		cart:SetAttribute("Distance", 18)
		cart:SetAttribute("Period", 2.2 + i * 0.4)
	end
	z += 30
	-- last crates up to the finish
	for i, dx in { -4, 3, 0 } do
		crate(Vector3.new(cx + dx, 2 + i, z + i * 6.5))
	end
	local finishZ = z + 26
	H.part({ Name = "FinishDeck", Size = Vector3.new(12, 6, 8), Position = Vector3.new(cx, 3, finishZ), Material = M.Concrete, Color = Color3.fromRGB(150, 150, 140), Parent = m })
	pad(m, "Finish", Vector3.new(cx, 6.25, finishZ), NEON_GOLD, "ObbyFinish", "Spill")
end

-- Sign Climb: platforms spiralling up the roadside sign (east side) ------------------------------
local function signClimb(lobby: Instance)
	local m = H.model("SignClimb", lobby)
	local c = Vector3.new(135, 0, -10)
	H.part({ Name = "Pole", Size = Vector3.new(4, 82, 4), Position = c + Vector3.new(0, 41, 0), Material = M.Metal, Color = STEEL, Parent = m })
	local sign = H.part({ Name = "BigSign", Size = Vector3.new(30, 12, 3), Position = c + Vector3.new(0, 90, 0), Material = M.Neon, Color = Color3.fromRGB(170, 25, 25), Parent = m })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local g = H.surfaceGui(sign, face, 10)
		H.label(g, "Name", "QUIK STOP", { Size = UDim2.fromScale(1, 0.7), TextColor3 = Color3.fromRGB(255, 240, 210) })
		H.label(g, "Sub", "GAS  -  FOOD  -  24 HRS", { Position = UDim2.fromScale(0, 0.7), Size = UDim2.fromScale(1, 0.3), TextColor3 = NEON_GOLD })
	end
	pad(m, "Start", c + Vector3.new(0, 0.25, 12), NEON_GREEN, "ObbyStart", "Sign")
	signpost(m, c + Vector3.new(10, 0, 18), "SIGN CLIMB", Color3.fromRGB(255, 120, 60), 180)
	local letters = { "Q", "U", "I", "K", "S", "T", "O", "P" }
	local steps = 18
	local top = Vector3.zero
	for i = 1, steps do
		local a = math.rad(i * 42)
		local pos = c + Vector3.new(math.cos(a) * 9, 2 + i * 4.1, math.sin(a) * 9)
		local neon = i % 3 == 0
		local p = H.part({
			Name = "Step" .. i, Size = Vector3.new(4.2, 1, 4.2), Position = pos, Material = if neon then M.Neon else M.Metal,
			Color = if neon then Color3.fromHSV((i / steps), 0.7, 1) else Color3.fromRGB(110, 112, 110), Parent = m,
		})
		if neon then
			local g = H.surfaceGui(p, Enum.NormalId.Top, 20)
			H.label(g, "Letter", letters[(i / 3 - 1) % #letters + 1], { TextColor3 = Color3.fromRGB(20, 20, 20) })
		end
		if i == 6 or i == 12 then
			local cp = H.part({ Name = "Checkpoint", Size = Vector3.new(3.6, 0.1, 3.6), Position = pos + Vector3.new(0, 0.55, 0), Material = M.Neon, Color = NEON_GOLD, Transparency = 0.4, CanCollide = false, Parent = m })
			tag(cp, "ObbyCheckpoint", "Sign")
		end
		top = pos
	end
	local finishPos = c + Vector3.new(0, top.Y + 3, 0) + Vector3.new(0, 0, 7)
	H.part({ Name = "TopDeck", Size = Vector3.new(10, 1, 10), Position = finishPos - Vector3.new(0, 0.75, 0), Material = M.DiamondPlate, Color = Color3.fromRGB(110, 112, 110), Parent = m })
	pad(m, "Finish", finishPos, NEON_GOLD, "ObbyFinish", "Sign")
end

-- The street, bus stop and the storefront row across it -----------------------------------------
local function street(lobby: Instance)
	local m = H.model("Street", lobby)
	H.part({ Name = "Road", Size = Vector3.new(340, 0.2, 26), Position = Vector3.new(0, 0.05, 95), Material = M.Asphalt, Color = Color3.fromRGB(28, 28, 30), Parent = m })
	for x = -160, 160, 12 do
		H.part({ Name = "Dash", Size = Vector3.new(6, 0.05, 0.5), Position = Vector3.new(x, 0.18, 95), Color = Color3.fromRGB(230, 200, 60), CanCollide = false, Parent = m })
	end
	for _, z in { 79, 111 } do
		H.part({ Name = "Sidewalk", Size = Vector3.new(340, 0.5, 6), Position = Vector3.new(0, 0.25, z), Material = M.Concrete, Color = Color3.fromRGB(110, 110, 105), Parent = m })
	end
	-- bus stop
	local stop = H.model("BusStop", m)
	H.part({ Name = "Bench", Size = Vector3.new(8, 1, 2), Position = Vector3.new(24, 1.5, 77.5), Material = M.WoodPlanks, Color = Color3.fromRGB(110, 80, 55), Parent = stop })
	H.part({ Name = "Roof", Size = Vector3.new(10, 0.4, 4), Position = Vector3.new(24, 8, 77.5), Material = M.Metal, Color = STEEL, Parent = stop })
	H.part({ Name = "BackPanel", Size = Vector3.new(10, 6, 0.3), Position = Vector3.new(24, 4.5, 75.8), Material = M.Glass, Color = Color3.fromRGB(150, 190, 200), Transparency = 0.5, Parent = stop })
	signpost(stop, Vector3.new(31, 0, 80), "NIGHT BUS", Color3.fromRGB(120, 200, 255), 180)
	-- storefront row across the street
	local shops = {
		{ "LAUNDROMAT", -60, Color3.fromRGB(80, 170, 255), "COMING SOON" },
		{ "ARCADE", 0, Color3.fromRGB(255, 80, 200), "OPEN LATE" },
		{ "PAWN", 60, Color3.fromRGB(255, 200, 60), "WE BUY GOLD" },
	}
	for _, s in shops do
		local x = s[2] :: number
		local b = H.model(s[1] :: string, m)
		H.part({ Name = "Building", Size = Vector3.new(34, 18, 1), Position = Vector3.new(x, 9, 128), Material = M.Brick, Color = Color3.fromRGB(80, 72, 66), Parent = b })
		for _, dx in { -16.5, 16.5 } do
			H.part({ Name = "Side", Size = Vector3.new(1, 18, 14), Position = Vector3.new(x + dx, 9, 121), Material = M.Brick, Color = Color3.fromRGB(80, 72, 66), Parent = b })
		end
		H.part({ Name = "Roof", Size = Vector3.new(34, 1, 14), Position = Vector3.new(x, 18.5, 121), Material = M.Concrete, Color = Color3.fromRGB(70, 68, 64), Parent = b })
		H.part({ Name = "Floor", Size = Vector3.new(32, 0.4, 13), Position = Vector3.new(x, 0.2, 121), Material = M.CeramicTiles, Color = Color3.fromRGB(60, 58, 70), Parent = b })
		local sign = H.part({ Name = "ShopSign", Size = Vector3.new(26, 4, 0.6), Position = Vector3.new(x, 15, 114.2), Material = M.Neon, Color = s[3] :: Color3, Parent = b })
		local sg = H.surfaceGui(sign, Enum.NormalId.Front, 20)
		H.label(sg, "Name", s[1] :: string, { Size = UDim2.fromScale(1, 0.7), TextColor3 = Color3.fromRGB(20, 20, 20) })
		H.label(sg, "Sub", s[4] :: string, { Position = UDim2.fromScale(0, 0.7), Size = UDim2.fromScale(1, 0.3), TextColor3 = Color3.fromRGB(20, 20, 20) })
		local glow = Instance.new("PointLight")
		glow.Color = s[3] :: Color3
		glow.Range = 26
		glow.Brightness = 1.4
		glow.Parent = sign
	end
	-- the laundromat is shut for now (the next store): a shutter across its front
	H.part({ Name = "Shutter", Size = Vector3.new(32, 12, 0.4), Position = Vector3.new(-60, 6, 114.4), Material = M.DiamondPlate, Color = Color3.fromRGB(120, 120, 115), Parent = m })
	-- the arcade is open: cabinets glowing inside
	for i = 0, 5 do
		local x = -12 + i * 4.8
		H.part({ Name = "Cabinet", Size = Vector3.new(3, 6, 2.4), Position = Vector3.new(x, 3.2, 125.5), Material = M.SmoothPlastic, Color = Color3.fromRGB(25, 25, 35), Parent = m })
		local screen = H.part({ Name = "Screen", Size = Vector3.new(2.4, 1.8, 0.1), Position = Vector3.new(x, 4.4, 124.25), Material = M.Neon, Color = Color3.fromHSV(i / 6, 0.8, 1), CanCollide = false, Parent = m })
		local sg = H.surfaceGui(screen, Enum.NormalId.Front, 40)
		H.label(sg, "Text", ({ "MOP KOMBAT", "SPILL RUN", "MANAGER", "HI SCORE", "INSERT COIN", "GAME OVER" })[i + 1], { TextColor3 = Color3.fromRGB(10, 10, 10) })
		CollectionService:AddTag(screen, "Blinker")
	end
	-- pawn shop: bars on the window
	for i = 0, 8 do
		H.part({ Name = "Bar", Size = Vector3.new(0.3, 10, 0.3), Position = Vector3.new(48 + i * 3, 5, 114.3), Material = M.Metal, Color = STEEL, Parent = m })
	end
	-- lamps along the street
	for x = -150, 150, 50 do
		H.lamp(m, Vector3.new(x, 0, 81))
	end
end

-- The plaza between the lot and the street -------------------------------------------------------
local function plaza(lobby: Instance)
	local m = H.model("Plaza", lobby)
	H.part({ Name = "Paving", Size = Vector3.new(90, 0.3, 16), Position = Vector3.new(0, 0.15, 67), Material = M.Pebble, Color = Color3.fromRGB(95, 92, 88), Parent = m })
	-- mop-bucket fountain
	H.part({ Name = "Bucket", Size = Vector3.new(9, 4, 9), Position = Vector3.new(0, 2, 67), Material = M.Plastic, Color = Color3.fromRGB(220, 190, 40), Parent = m })
	local water = H.part({ Name = "Suds", Size = Vector3.new(8, 0.4, 8), Position = Vector3.new(0, 4, 67), Material = M.Neon, Color = Color3.fromRGB(120, 200, 230), Transparency = 0.2, CanCollide = false, Parent = m })
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	bubbles.Rate = 18
	bubbles.Lifetime = NumberRange.new(1.5, 2.5)
	bubbles.Speed = NumberRange.new(4, 8)
	bubbles.SpreadAngle = Vector2.new(20, 20)
	bubbles.Size = NumberSequence.new(0.5)
	bubbles.Color = ColorSequence.new(Color3.fromRGB(200, 240, 255))
	bubbles.Parent = water
	H.part({ Name = "MopHandle", Size = Vector3.new(0.6, 12, 0.6), CFrame = CFrame.new(1.5, 8, 67) * CFrame.Angles(0, 0, math.rad(-18)), Material = M.Wood, Color = Color3.fromRGB(120, 90, 60), Parent = m })
	-- trampolines
	for _, x in { -34, -22, 22, 34 } do
		H.part({ Name = "TrampolineFrame", Size = Vector3.new(7, 1, 7), Position = Vector3.new(x, 0.5, 66), Material = M.Metal, Color = STEEL, Parent = m })
		local bed = H.part({ Name = "Trampoline", Size = Vector3.new(6, 0.2, 6), Position = Vector3.new(x, 1.1, 66), Material = M.Neon, Color = Color3.fromRGB(255, 90, 200), Parent = m })
		CollectionService:AddTag(bed, "BouncePad")
		bed:SetAttribute("Power", 95)
	end
	-- fire barrels with benches
	for _, x in { -12, 12 } do
		local barrel = H.part({ Name = "Barrel", Size = Vector3.new(2.4, 3.4, 2.4), Position = Vector3.new(x, 1.7, 72), Material = M.Metal, Color = Color3.fromRGB(80, 60, 45), Parent = m })
		local fire = Instance.new("Fire")
		fire.Size = 4
		fire.Heat = 6
		fire.Parent = barrel
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 150, 60)
		glow.Range = 16
		glow.Brightness = 1.2
		glow.Parent = barrel
		for _, dz in { -3.5, 3.5 } do
			H.part({ Name = "Bench", Size = Vector3.new(5, 1, 1.6), Position = Vector3.new(x, 1.3, 72 + dz), Material = M.WoodPlanks, Color = Color3.fromRGB(110, 80, 55), Parent = m })
		end
	end
	-- floating neon signs around the lot
	for _, s in {
		{ Vector3.new(-40, 16, 30), "OPEN", Color3.fromRGB(255, 80, 80) },
		{ Vector3.new(40, 18, 20), "24/7", Color3.fromRGB(80, 200, 255) },
		{ Vector3.new(-85, 14, 55), "HOT COFFEE", Color3.fromRGB(255, 170, 60) },
		{ Vector3.new(85, 14, 55), "NOW HIRING", NEON_GREEN },
	} do
		local p = H.part({ Name = "NeonSign", Size = Vector3.new(12, 3, 0.4), Position = s[1], Material = M.Neon, Color = s[3], CanCollide = false, Parent = m })
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			H.label(H.surfaceGui(p, face, 20), "Text", s[2], { TextColor3 = Color3.fromRGB(15, 15, 15) })
		end
		H.part({ Name = "Wire", Size = Vector3.new(0.1, 40 - s[1].Y + 10, 0.1), Position = s[1] + Vector3.new(0, (40 - s[1].Y + 10) / 2 + 1.5, 0), Material = M.Metal, Color = STEEL, CanCollide = false, Parent = m })
		CollectionService:AddTag(p, "Blinker")
	end
end

function LobbyExtras.Build(lobby: Instance, helpers: Helpers)
	H = helpers
	roofRun(lobby)
	spillCourse(lobby)
	signClimb(lobby)
	street(lobby)
	plaza(lobby)
end

return LobbyExtras
