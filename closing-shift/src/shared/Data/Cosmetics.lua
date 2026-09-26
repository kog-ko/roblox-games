--!strict
-- Cosmetics, bought with shift cash in the lobby's WARDROBE and shown to everyone. Nothing here
-- changes gameplay. One item per slot is equipped at a time; the first item of each slot is free
-- and owned by everyone. Vip = true: needs the VIP pass as well as the cash. Earned = true: can't be
-- bought; the game grants it (Hint says how).
--
-- Slots and where they show:
--   Vest   a work vest over your avatar (lobby and shift)
--   Trail  a trail behind you (lobby only; the store is dark and cramped)
--   Tag    the colour of your name tag (lobby and shift)
--   Mop    your mop's handle and head (shift, first and third person)
--   Beam   your flashlight's colour (shift)
-- Colors are Color3s; Material is an Enum.Material name.
export type Item = {
	Id: string,
	Slot: string,
	Name: string,
	Price: number,
	Vip: boolean?,
	Color: Color3?,
	Color2: Color3?, -- second colour (mop head, trail end)
	Material: string?,
	Rainbow: boolean?, -- tag / trail cycles colours
	Earned: boolean?,
	Hint: string?,
}

local C = Color3.fromRGB

local Cosmetics: { Slots: { string }, SlotNames: { [string]: string }, Items: { Item } } = {
	Slots = { "Vest", "Trail", "Tag", "Mop", "Beam" },
	SlotNames = { Vest = "VESTS", Trail = "TRAILS", Tag = "NAME TAGS", Mop = "MOPS", Beam = "FLASHLIGHT" },
	Items = {
		-- Vests
		{ Id = "VestNone", Slot = "Vest", Name = "NO VEST", Price = 0 },
		{ Id = "VestRed", Slot = "Vest", Name = "QUIK STOP RED", Price = 300, Color = C(170, 35, 30) },
		{ Id = "VestBlue", Slot = "Vest", Name = "NIGHT BLUE", Price = 800, Color = C(35, 60, 130) },
		{ Id = "VestHazard", Slot = "Vest", Name = "HAZARD ORANGE", Price = 2500, Color = C(240, 120, 20), Material = "Neon" },
		{ Id = "VestBlack", Slot = "Vest", Name = "MIDNIGHT", Price = 6000, Color = C(15, 15, 18), Material = "Metal" },
		{ Id = "VestHolo", Slot = "Vest", Name = "HOLOGRAPHIC", Price = 25000, Color = C(150, 220, 255), Material = "Glass" },
		{ Id = "VestGold", Slot = "Vest", Name = "GOLD FOIL", Price = 100000, Color = C(230, 190, 60), Material = "Foil", Vip = true },
		-- Trails
		{ Id = "TrailNone", Slot = "Trail", Name = "NO TRAIL", Price = 0 },
		{ Id = "TrailMop", Slot = "Trail", Name = "WET FLOOR", Price = 2000, Color = C(120, 200, 230), Color2 = C(255, 255, 255) },
		{ Id = "TrailEmber", Slot = "Trail", Name = "EMBERS", Price = 6000, Color = C(255, 120, 30), Color2 = C(120, 20, 10) },
		{ Id = "TrailToxic", Slot = "Trail", Name = "TOXIC SPILL", Price = 15000, Color = C(120, 255, 80), Color2 = C(20, 90, 20) },
		{ Id = "TrailRainbow", Slot = "Trail", Name = "RAINBOW", Price = 40000, Rainbow = true },
		{ Id = "TrailGold", Slot = "Trail", Name = "MANAGER GOLD", Price = 120000, Color = C(255, 215, 80), Color2 = C(255, 250, 200), Vip = true },
		{ Id = "TrailParkour", Slot = "Trail", Name = "PARKOUR", Price = 0, Earned = true, Hint = "CLEAR ALL 3 LOBBY OBBIES", Color = C(110, 230, 120), Color2 = C(255, 200, 70) },
		-- Name tags
		{ Id = "TagPlain", Slot = "Tag", Name = "PLAIN", Price = 0 },
		{ Id = "TagMint", Slot = "Tag", Name = "MINT", Price = 1500, Color = C(120, 240, 180) },
		{ Id = "TagBlood", Slot = "Tag", Name = "CRIMSON", Price = 4000, Color = C(230, 50, 50) },
		{ Id = "TagIce", Slot = "Tag", Name = "ICE", Price = 8000, Color = C(170, 220, 255) },
		{ Id = "TagRainbow", Slot = "Tag", Name = "RAINBOW", Price = 30000, Rainbow = true },
		-- Mops
		{ Id = "MopPlain", Slot = "Mop", Name = "STANDARD ISSUE", Price = 0 },
		{ Id = "MopMint", Slot = "Mop", Name = "MINT FRESH", Price = 500, Color = C(90, 200, 160), Color2 = C(220, 250, 240) },
		{ Id = "MopCrimson", Slot = "Mop", Name = "CRIMSON", Price = 1500, Color = C(150, 20, 25), Color2 = C(60, 10, 10) },
		{ Id = "MopChrome", Slot = "Mop", Name = "CHROME", Price = 5000, Color = C(200, 205, 210), Color2 = C(160, 165, 170), Material = "Metal" },
		{ Id = "MopNeon", Slot = "Mop", Name = "NEON PINK", Price = 15000, Color = C(255, 80, 200), Color2 = C(255, 180, 240), Material = "Neon" },
		{ Id = "MopVoid", Slot = "Mop", Name = "VOID", Price = 50000, Color = C(10, 10, 12), Color2 = C(80, 30, 120), Material = "Neon" },
		-- Flashlight beams
		{ Id = "BeamWarm", Slot = "Beam", Name = "WARM WHITE", Price = 0 },
		{ Id = "BeamCool", Slot = "Beam", Name = "COOL WHITE", Price = 1000, Color = C(210, 230, 255) },
		{ Id = "BeamGreen", Slot = "Beam", Name = "NIGHT VISION", Price = 3000, Color = C(120, 255, 140) },
		{ Id = "BeamRed", Slot = "Beam", Name = "DARKROOM RED", Price = 3000, Color = C(255, 90, 80) },
		{ Id = "BeamUV", Slot = "Beam", Name = "BLACKLIGHT", Price = 20000, Color = C(160, 90, 255) },
	},
}

return Cosmetics
